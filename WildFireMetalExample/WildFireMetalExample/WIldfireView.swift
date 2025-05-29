//
//  WIldfireView.swift
//  WildFireMetalExample
//
//  Created by Dimitar Kyurtov on 27.05.25.
//

import SwiftUI

struct WildfireView: View {
    @ObservedObject var viewModel: WildfireViewModel

    var body: some View {
        VStack {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0..<viewModel.height, id: \.self) { y in
                    GridRow {
                        ForEach(0..<viewModel.width, id: \.self) { x in
                            Rectangle()
                                .fill(viewModel.colorForCell(x: x, y: y))
                                .frame(width: 2, height: 2)
                        }
                    }
                }
            }
            .drawingGroup()
            .frame(width: CGFloat(viewModel.width) * 2, height: CGFloat(viewModel.height) * 2)

            HStack {
                Color.red.frame(width: 20, height: 20)
                Text("Burning")
                Color.green.frame(width: 20, height: 20)
                Text("Burnable")
                Color.gray.frame(width: 20, height: 20)
                Text("Burned")
                Color.black.frame(width: 20, height: 20)
                Text("Not Burnable")
            }.padding()
        }
        .onAppear {
            viewModel.startSimulation()
        }
    }
}
