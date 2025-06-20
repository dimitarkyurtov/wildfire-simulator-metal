#include <metal_stdlib>
#include "MetalRand.metal"
using namespace metal;

enum CellState {
    NotBurnable = 0,
    Burnable = 1,
    Burning = 2,
    Burned = 3
};

struct SimulationParams {
    float baseProbability;
    int iterations;
    int width;
    int height;
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
    device metalrand::XORWOWState *states [[buffer(4)]],
    device SimulationParams& params [[ buffer(5) ]],
    uint2 gid [[ thread_position_in_grid ]]
) {
    int WIDTH = params.width;
    int HEIGHT = params.height;
    
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
            }
        }
    }

    metalrand::XORWOWState localState = states[idx];
    float randVal = float(metalrand::metalRand(localState)) / UINT_MAX;
    states[idx] = localState;

    willIgnite = (state == Burnable && ignitionProb > randVal);

    if (state == Burning) {
        nextState[idx] = (randVal > 0.2f) ? Burning : Burned;
    } else {
        nextState[idx] = willIgnite ? Burning : state;
    }
}
