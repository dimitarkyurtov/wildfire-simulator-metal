//
//  ContentView.swift
//  WildFireMetalExample
//
//  Created by Dimitar Kyurtov on 27.05.25.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> MetalRenderer {
        MetalRenderer(metalView: view)
    }

    let view = MTKView()

    func makeNSView(context: Context) -> MTKView {
        context.coordinator
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        MetalView()
            .frame(minWidth: 400, minHeight: 300)
    }
}
