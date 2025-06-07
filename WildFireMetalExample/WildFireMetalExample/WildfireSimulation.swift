//
//  WildfireSimulation.swift
//  WildFireMetalExample
//
//  Created by Dimitar Kyurtov on 27.05.25.
//

import MetalKit
import SwiftUI

struct SimulationParams {
    var baseProbability: Float
    var iterations: Int32
    var width: Int32
    var height: Int32
}

class WildfireSimulation {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState
    let rngSetupPipelineState: MTLComputePipelineState

    var currentState: MTLBuffer
    var nextState: MTLBuffer
    var windField: MTLBuffer
    var altitude: MTLBuffer
    var params: MTLBuffer
    var rngStates: MTLBuffer

    let width: Int
    let height: Int
    var stepCount: Int = 0

    init(device: MTLDevice, width: Int, height: Int) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.width = width
        self.height = height

        guard let url = Bundle.main.url(forResource: "WildfireMetal", withExtension: "metallib") else {
            fatalError("❌ Could not find WildfireMetal.metallib in bundle")
        }

        let library = try! device.makeLibrary(URL: url)
        let function = library.makeFunction(name: "wildfireSimulation")!
        self.pipelineState = try! device.makeComputePipelineState(function: function)

        let rngFunction = library.makeFunction(name: "setup_rng")!
        self.rngSetupPipelineState = try! device.makeComputePipelineState(function: rngFunction)

        self.currentState = device.makeBuffer(length: width * height, options: .storageModeShared)!
        self.nextState = device.makeBuffer(length: width * height, options: .storageModeShared)!
        self.windField = device.makeBuffer(length: width * height * MemoryLayout<SIMD2<Float>>.stride, options: [])!
        self.altitude = device.makeBuffer(length: width * height * MemoryLayout<Float>.stride, options: [])!
        self.params = device.makeBuffer(length: MemoryLayout<SimulationParams>.stride, options: [])!
        self.rngStates = device.makeBuffer(length: width * height * MemoryLayout<UInt32>.stride * 6, options: [])!

        setupRNG(seed: WildfireSimulation.generateHardwareSeed())
        resetSimulation()
    }

    func setupRNG(seed: UInt32) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(rngSetupPipelineState)
        encoder.setBuffer(rngStates, offset: 0, index: 0)
        var s = seed, w = UInt32(width)
        encoder.setBytes(&s, length: MemoryLayout<UInt32>.stride, index: 1)
        encoder.setBytes(&w, length: MemoryLayout<UInt32>.stride, index: 2)

        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    /// Generates initial conditions for the terrain, altitude and wind.
    func resetSimulation() {
        // Generates randomly Burnable or Not Burnable cells.
        // The center cell becomes Burned.
        let ptr = currentState.contents().bindMemory(to: UInt8.self, capacity: width * height)
        for i in 0..<(width * height) {
            ptr[i] = Float.random(in: 0..<1) < 0.99 ? 1 : 0
        }
        ptr[width * (height/4) + width/4] = 2
        ptr[width * (height/4) + width/4*3] = 2
//        ptr[width * (height/2) + width/2] = 2
        ptr[width * (height/4*3) + width/4] = 2
        ptr[width * (height/4*3) + width/4*3] = 2
        
        // Generates the wind matrix with realistic values.
        let wind = SIMD2<Float>(x: 0.8, y: 0.2)
        let windPtr = windField.contents().bindMemory(to: SIMD2<Float>.self, capacity: width * height)
        for i in 0..<(width * height) {
            let variation = SIMD2<Float>(Float.random(in: -0.1...0.1), Float.random(in: -0.1...0.1))
            windPtr[i] = normalize(wind + variation)
        }
        
        // Generates the altitude matrix with realistic values.
        let altPtr = altitude.contents().bindMemory(to: Float.self, capacity: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * width + x
                let fx = Float(x) / Float(width)
                let fy = Float(y) / Float(height)
                altPtr[i] = sin(fx * Float.pi) * sin(fy * Float.pi) * 10.0
            }
        }
    }
    
    /// Executes a GPU kernel which calculates one step of the simulation.
    func step() {
        stepCount += 1
        var simParams = SimulationParams(baseProbability: 0.3, iterations: Int32(stepCount), width: Int32(width), height: Int32(height))
        memcpy(params.contents(), &simParams, MemoryLayout<SimulationParams>.stride)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(currentState, offset: 0, index: 0)
        encoder.setBuffer(nextState, offset: 0, index: 1)
        encoder.setBuffer(windField, offset: 0, index: 2)
        encoder.setBuffer(altitude, offset: 0, index: 3)
        encoder.setBuffer(rngStates, offset: 0, index: 4)
        encoder.setBuffer(params, offset: 0, index: 5)

        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        swap(&currentState, &nextState)
    }
    
    /// Gets the current state of the terrain.
    /// - Returns: The state.
    func getState() -> [UInt8] {
        let ptr = currentState.contents().bindMemory(to: UInt8.self, capacity: width * height)
        return Array(UnsafeBufferPointer(start: ptr, count: width * height))
    }
    
    /// Generates a truly random number.
    /// - Returns: The random number.
    static func generateHardwareSeed() -> UInt32 {
        var seed: UInt32 = 0
        let result = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt32>.size, &seed)
        if result == errSecSuccess {
            print("Seed: \(seed)")
            return seed
        } else {
            fatalError("Failed to get hardware random seed.")
        }
    }
}
