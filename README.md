# GPU-Accelerated Wildfire Simulation Model Using Cellular Automata and Metal

## Author

**Dimitar Kyurtov**  
Sofia University St. Kliment Ohridski  
Email: dimitarkiurtov@gmail.com  

## Abstract

This work presents a GPU-accelerated wildfire simulation model based on cellular automata, implemented using Apple's Metal framework. The primary component is a reusable Metal library that computes cellular automata iterations on the GPU. The library supports a parameterized number of simulation steps per invocation, allowing control over the simulation timeline. An example macOS application demonstrates the use of this library, leveraging SwiftUI to visualize the simulation and interactively display the evolving state of the terrain.

The simulation operates on a 2D grid where each cell represents a segment of forest with a discrete state—burnable, burning, burned, or non-burnable. The spread of fire follows a probabilistic cellular automaton, with ignition probabilities influenced by environmental factors such as wind direction, wind magnitude, and terrain slope derived from an altitude map. These effects are modeled using simplified, physically inspired formulas that reflect natural fire behavior, including wind-driven spread and increased ignition on uphill slopes. Randomness in state transitions is achieved through a GPU-resident XORWOW random number generator initialized per cell.
