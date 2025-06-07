# GPU-Accelerated Wildfire Simulation Model Using Cellular Automata and Metal

## Author

**Dimitar Kyurtov**  
Sofia University St. Kliment Ohridski  
Email: dimitarkiurtov@gmail.com  

## Abstract

This work presents a GPU-accelerated wildfire simulation model based on cellular automata, implemented using Apple's Metal framework. The primary component is a reusable Metal library that computes cellular automata iterations on the GPU. The library supports a parameterized number of simulation steps per invocation, allowing control over the simulation timeline. An example macOS application demonstrates the use of this library, leveraging SwiftUI to visualize the simulation and interactively display the evolving state of the terrain.

The simulation operates on a 2D grid where each cell represents a segment of forest with a discrete state—burnable, burning, burned, or non-burnable. The spread of fire follows a probabilistic cellular automaton, with ignition probabilities influenced by environmental factors such as wind direction, wind magnitude, and terrain slope derived from an altitude map. These effects are modeled using simplified, physically inspired formulas that reflect natural fire behavior, including wind-driven spread and increased ignition on uphill slopes. Randomness in state transitions is achieved through a GPU-resident XORWOW random number generator initialized per cell.


## Introduction

Wildfires are natural disasters with profound ecological, economic, and social impacts. Their increasing frequency and intensity, often linked to climate change, make accurate modeling and simulation more critical than ever. Effective wildfire simulation can support environmental research, improve emergency preparedness, and aid in planning fire mitigation strategies. It is particularly valuable in training scenarios, risk forecasting, and optimizing resource deployment during wildfire events.

The goal of this project is to develop a GPU-accelerated wildfire simulation model, specifically targeted at Apple platforms using the Metal framework. The aim of this project is to simulate fire spread in near real-time while providing the ability to add visual interactivity. The simulation is based on a cellular automata model that captures fire propagation dynamics through probabilistic rules influenced by wind and terrain slope.

Unlike large-scale supercomputing models used in operational forecasting, this project assumes a smaller problem domain suitable for execution on end-user devices such as laptops, tablets, or smartphones. This assumption enables deployment in educational, exploratory, or even mobile emergency planning tools. The assumption is based on the fact the problem space for most terrains is small enough to be computed on an end user device in real time.

## Background

Wildfire simulation has been the focus of significant research across environmental science, computer graphics, and high-performance computing. Models range from physical-based approaches that solve partial differential equations to empirical and stochastic models such as cellular automata. Among these, cellular automata are particularly appealing for real-time and GPU-accelerated implementations due to their spatial locality and parallelism. Previous studies[1][2] have demonstrated the use of cellular automata to approximate the spread of fire with sufficient realism for planning and education purposes.

This project builds on that foundation by implementing a GPU-accelerated version using Apple’s Metal framework, targeting consumer-grade devices like MacBooks and iPhones. The simulation operates over a 2D grid representing a forest terrain where cells transition between vegetation states based on probabilistic rules. Environmental factors—specifically wind and slope—are used to make the model more realistic, following the pattern of simplified fire spread models found in the literature.

The work is structured in two parts. The first part involves developing a reusable Metal compute library that encapsulates the logic for cellular automata iteration, random number generation, and environmental influence computation. This library is designed to be efficient, configurable, and portable across Apple devices. The second part involves creating a macOS application using SwiftUI, which uses the library to perform simulations and visualize the results in real-time.

The approach taken in this project reflects a practical, user-focused application of GPU computing to ecological modeling. It demonstrates that even with limited hardware resources, meaningful and interactive wildfire simulation is feasible. References to relevant literature and prior work are provided in the References section.

## Methodology

The implementation of the wildfire simulation is based on a probabilistic cellular automata model executed on the GPU using Metal. This section outlines the main components of the simulation, including environmental modeling, probability computation, parallel execution, and platform-specific design decisions.

### 1. Cellular Automata Structure

The simulation uses a 2D grid to model a forest environment, where each cell represents a portion of terrain and can be in one of four discrete states: Not Burnable, Burnable, Burning, or Burned. The state transitions are governed by rules based on the states of neighboring cells and influenced by environmental factors such as wind and terrain slope. The update of the entire grid is performed in parallel using GPU compute shaders.

### 2. Environmental Modeling

#### Wind Representation

Wind is modeled as a 2D vector field, where each cell is assigned a wind direction and magnitude represented by a normalized `float2`. In the example application these vectors are slightly randomized around a dominant wind direction to simulate natural variation. Wind affects the fire spread by influencing the probability that a burnable cell ignites if it has a burning neighbor in the direction of the wind. The alignment between wind and the direction from a burning neighbor to a candidate cell is computed using the dot product, scaled and clamped to a factor between 0.5 and 2.0.

#### Slope Representation

Slope is derived from an altitude matrix representing elevation at each cell. The slope between a burnable cell and its burning neighbor is calculated as the difference in elevation. Fire tends to spread faster uphill due to preheating of vegetation, so slope effects are modeled as a multiplier: 
``` Metal
slopeEffect = clamp(1.0 + 0.1 * slope, 0.5, 2.0)
```
This simple linear model provides a realistic approximation of fire behavior over varying terrain without the complexity of full fluid dynamics.

### 3. Probability Computation

The ignition probability for a burnable cell is calculated by summing the weighted contributions of all burning neighbors. For each burning neighbor, the following formula is used: 
```
P_ignite += baseProbability * windEffect * slopeEffect
```
Where `baseProbability` is a tunable global constant, and `windEffect` and `slopeEffect` are derived as described above. The final probability is clamped to the range [0.0, 1.0]. A pseudo-random number is generated per cell to decide whether ignition occurs by comparing it to the computed probability.

To support stochastic transitions, each cell maintains its own state in a GPU-side random number generator based on the XORWOW algorithm. This ensures per-cell randomness that evolves over time.

### 4. GPU Execution Model

Each cell in the grid is processed independently by a GPU thread in a compute shader. The Metal kernel dispatches one thread per cell using a 2D thread grid that matches the simulation domain. Each thread:

- Reads its current state
- Iterates over the 8-connected neighborhood
- Calculates ignition probability from burning neighbors
- Generates a random number and determines state transition
- Writes the new state to a separate output buffer

Because each thread only reads from the current state buffer and writes to a separate next-state buffer, there is no need for synchronization between threads. This thread-local independence is ideal for GPU execution and ensures maximum parallel throughput without performance degradation from thread contention.

### 5. Platform-Specific Design Considerations

The decision to use Apple’s Metal framework was motivated not by raw performance but by the goal of providing native deployment on Apple devices. This design choice aligns with the assumption that the target problem space is modest in size and can be executed efficiently on consumer-grade hardware. It allows researchers, students, or emergency planners to run interactive wildfire simulations on personal devices without specialized hardware.

## Demo

There are 2 videos which demonstarate the example application with different visually appealing starting configurations:
* [demo-1](videos/demo-1.mov)
* [demo-2](videos/demo-2.mov)

## Conclusion

This project demonstrates that realistic wildfire spread can be simulated efficiently on consumer-grade Apple hardware using GPU acceleration with Metal. This is done by combining cellular automata with environmental factors such as wind and slope, and leveraging per-cell parallelism on the GPU.

## References

1. Alexandridis, A., Vakalis, D., Siettos, C. I., & Bafas, G. (2008). *A cellular automaton model for forest fire spread prediction: The case of the wildfire that swept through Spetses Island in 1990*. Applied Mathematics and Computation, 204(1), 191–201.  
   [https://doi.org/10.1016/j.amc.2008.06.040](https://doi.org/10.1016/j.amc.2008.06.040)

2. Karafyllidis, I., & Thanailakis, A. (1997). *A model for predicting forest fire spreading using cellular automata*. Ecological Modelling, 99(1), 87–97.  
   [https://doi.org/10.1016/S0304-3800(96)01942-4](https://doi.org/10.1016/S0304-3800(96)01942-4)

3. Rothermel, R. C. (1972). *A mathematical model for predicting fire spread in wildland fuels* (Research Paper INT-115). USDA Forest Service.  
   [https://www.fs.usda.gov/research/treesearch/38466](https://www.fs.usda.gov/research/treesearch/38466)