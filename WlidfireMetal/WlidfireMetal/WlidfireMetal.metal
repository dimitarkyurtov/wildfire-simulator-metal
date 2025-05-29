#include <metal_stdlib>
#include "MetalRand.metal"
using namespace metal;

#define WIDTH 256
#define HEIGHT 256

enum CellState {
    NotBurnable = 0,
    Burnable = 1,
    Burning = 2,
    Burned = 3
};

struct SimulationParams {
    float baseProbability;
    int iterations;
};
    
kernel void setup_rng(device metalrand::XORWOWState *states [[buffer(0)]],
                         constant uint &seed [[buffer(1)]],
                         constant uint &width [[buffer(2)]],
                         uint2 gid [[thread_position_in_grid]]) {
    
    uint thread_id = gid.y * width + gid.x;
    metalrand::XORWOWState localState = states[thread_id];

    metalRandInit(seed, thread_id, localState);

    states[thread_id] = localState;
}

kernel void wildfireSimulation(
    device uint8_t* currentState [[ buffer(0) ]],
    device uint8_t* nextState [[ buffer(1) ]],
    device float2* windField [[ buffer(2) ]],
    device float* altitude [[ buffer(3) ]],
    constant SimulationParams& params [[ buffer(4) ]],
    device metalrand::XORWOWState *states [[buffer(5)]],
    uint2 gid [[ thread_position_in_grid ]]
) {
    if (gid.x >= WIDTH || gid.y >= HEIGHT) return;

    int idx = gid.y * WIDTH + gid.x;
    uint8_t state = currentState[idx];

    if (state == NotBurnable || state == Burned) {
        nextState[idx] = state;
        return;
    }

    bool willIgnite = false;
    float ignitionProb = 0.0;

    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            int nx = gid.x + dx;
            int ny = gid.y + dy;
            if (nx < 0 || nx >= WIDTH || ny < 0 || ny >= HEIGHT) continue;

            int nIdx = ny * WIDTH + nx;
            if (currentState[nIdx] == Burning) {
                float2 wind = windField[idx];
                float slope = (altitude[idx] - altitude[nIdx]);

                float windEffect = clamp(1.0 + 0.5 * dot(normalize(float2(dx, dy)), normalize(wind)), 0.5, 2.0);
                float slopeEffect = clamp(1.0 + 0.1 * slope, 0.5, 2.0);
                float prob = params.baseProbability * windEffect * slopeEffect;
                ignitionProb += prob;

                ignitionProb = 0.1;
            }
        }
    }

//    ignitionProb = clamp(ignitionProb, 0.0f, 1.0f);
//    ignitionProb = 0.5;

//    float seed = float(idx * 73856093 ^ params.iterations);
//    float randVal = fract(sin(seed) * 43758.5453);
    metalrand::XORWOWState localState = states[idx];
    float randVal = float(metalrand::metalRand(localState)) / UINT_MAX;
    states[idx] = localState;

//    float randVal = 0.4;
    willIgnite = (state == Burnable && ignitionProb > randVal);
//    randVal = 0.6;

    if (state == Burning) {
//        nextState[idx] = (randVal > 0.5f) ? Burned : Burning;
        // TODO: Update this
        nextState[idx] = (randVal > 0.5f) ? Burning : Burning;
    } else {
        nextState[idx] = willIgnite ? Burning : state;
    }
}
