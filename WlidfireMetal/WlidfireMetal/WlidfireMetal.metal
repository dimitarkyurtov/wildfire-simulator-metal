//
//  WlidfireMetal.metal
//  WlidfireMetal
//
//  Created by Dimitar Kyurtov on 27.05.25.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
    float4 positions[3] = {
        float4( 0.0,  0.5, 0.0, 1.0),
        float4(-0.5, -0.5, 0.0, 1.0),
        float4( 0.5, -0.5, 0.0, 1.0)
    };
    
    VertexOut out;
    out.position = positions[vertexID];
    return out;
}

fragment float4 fragment_main() {
    return float4(1.0, 0.0, 0.0, 1.0); // Red
}


