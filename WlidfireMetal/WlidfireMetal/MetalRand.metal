//
//  MetalRand.metal
//  WildfireMetal
//
//  Created by Dimitar Kyurtov on 29.05.25.
//

#include <metal_stdlib>
using namespace metal;

namespace metalrand {
    struct XORWOWState {
        uint32_t x, y, z, w, v, d;
    };
    
    /// Returns a random uint.
    inline uint metalRand(thread XORWOWState &state) {
        uint t = state.x ^ (state.x >> 2);
        state.x = state.y;
        state.y = state.z;
        state.z = state.w;
        state.w = state.v;
        state.v = (state.v ^ (state.v << 4)) ^ (t ^ (t << 1));
        state.d += 362437;
        return state.v + state.d;
    }

    /// Initializes a state with seed and sequence.
    inline void metalRandInit(uint seed, uint sequence, thread XORWOWState &state) {
        state.x = seed ^ 0xA341316C ^ sequence;
        state.y = seed ^ 0xC8013EA4 ^ (sequence << 1);
        state.z = seed ^ 0xAD90777D ^ (sequence >> 1);
        state.w = seed ^ 0x7E95761E ^ (~sequence);
        state.v = seed ^ 0xBA77B11E;
        state.d = 362437;
        
        for (int i = 0; i < 10; i ++) {
            metalrand::metalRand(state);
        }
    }
}
