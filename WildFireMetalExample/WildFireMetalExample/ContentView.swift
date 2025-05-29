//
//  ContentView.swift
//  WildFireMetalExample
//
//  Created by Dimitar Kyurtov on 27.05.25.
//

import SwiftUI
import MetalKit

struct ContentView: View {
    var body: some View {
        WildfireView(viewModel: WildfireViewModel())
    }
}
