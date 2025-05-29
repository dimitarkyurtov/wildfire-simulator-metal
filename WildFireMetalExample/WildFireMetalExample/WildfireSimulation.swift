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
    var iterations: Int
}

struct XORWOWState {
    var x: UInt32
    var y: UInt32
    var z: UInt32
    var w: UInt32
    var v: UInt32
    var d: UInt32
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

    init(device: MTLDevice, width: Int = 256, height: Int = 256) {
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
        self.windField = device.makeBuffer(length: width * height * MemoryLayout<float2>.stride, options: [])!
        self.altitude = device.makeBuffer(length: width * height * MemoryLayout<Float>.stride, options: [])!
        self.params = device.makeBuffer(length: MemoryLayout<SimulationParams>.stride, options: [])!
        self.rngStates = device.makeBuffer(length: width * height * MemoryLayout<UInt32>.stride * 6, options: [])!

        // TODO: Initialize the windField and altitude matrixes.
        resetSimulation()
        setupRNG(seed: 42)
    }

    func setupRNG(seed: UInt32) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(rngSetupPipelineState)
        encoder.setBuffer(rngStates, offset: 0, index: 0)
        var s = WildfireSimulation.generateHardwareSeed(), w = UInt32(width)
        encoder.setBytes(&s, length: MemoryLayout<UInt32>.stride, index: 1)
        encoder.setBytes(&w, length: MemoryLayout<UInt32>.stride, index: 2)

//        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
//        let threadgroups = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
        
        let totalThreads = width * height
        let threadsPerGrid = MTLSize(width: totalThreads, height: 1, depth: 1)
        let threadsPerThreadgroup = MTLSize(width: min(rngSetupPipelineState.threadExecutionWidth, totalThreads), height: 1, depth: 1)

        encoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    func resetSimulation() {
        let ptr = currentState.contents().bindMemory(to: UInt8.self, capacity: width * height)
        for i in 0..<(width * height) {
//            ptr[i] = UInt8.random(in: 0...1) // Randomly Burnable or Not Burnable
            ptr[i] = 1
        }
        ptr[width * height/2 + width/2] = 2;
    }

    func step(iterations: Int = 60) {
        stepCount += 1
        var simParams = SimulationParams(baseProbability: 0.3, iterations: stepCount)
        memcpy(params.contents(), &simParams, MemoryLayout<SimulationParams>.stride)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(currentState, offset: 0, index: 0)
        encoder.setBuffer(nextState, offset: 0, index: 1)
        encoder.setBuffer(windField, offset: 0, index: 2)
        encoder.setBuffer(altitude, offset: 0, index: 3)
        encoder.setBuffer(params, offset: 0, index: 4)
        encoder.setBuffer(rngStates, offset: 0, index: 5)

        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        swap(&currentState, &nextState)
//        printFirstRNGStates()
    }
    
    func printFirstRNGStates() {
        let count = min(10, width * height)
        let ptr = rngStates.contents().bindMemory(to: XORWOWState.self, capacity: width * height)
        for i in 0..<count {
            let s = ptr[i]
            print("RNG[\(i)] = x:\(s.x) y:\(s.y) z:\(s.z) w:\(s.w) v:\(s.v) d:\(s.d)")
        }
    }

    func getState() -> [UInt8] {
        let ptr = currentState.contents().bindMemory(to: UInt8.self, capacity: width * height)
        return Array(UnsafeBufferPointer(start: ptr, count: width * height))
    }
    
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
