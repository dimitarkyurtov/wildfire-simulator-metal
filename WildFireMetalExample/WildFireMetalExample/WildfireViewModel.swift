//
//  WildfireViewModel.swift
//  WildFireMetalExample
//
//  Created by Dimitar Kyurtov on 27.05.25.
//

import SwiftUI

class WildfireViewModel: ObservableObject {
    @Published var cellStates: [UInt8] = []
    let simulation: WildfireSimulation
    let width = 256
    let height = 256

    init() {
        simulation = WildfireSimulation(device: MTLCreateSystemDefaultDevice()!, width: width, height: height)
        cellStates = simulation.getState()
    }

    func colorForCell(x: Int, y: Int) -> Color {
        let index = y * width + x
        switch cellStates[index] {
        case 0: return .black
        case 1: return .green
        case 2: return .red
        case 3: return .gray
        default: return .white
        }
    }

    func startSimulation() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            self.simulation.step()
            self.cellStates = self.simulation.getState()
        }
    }
}
