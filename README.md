# 🧠 TinyML Hardware Accelerator (Track A)
# IP Documentation: Tiny ML Accelerator

## Overview

This document outlines the MVP industrial implementation of our TinyML Accelerator IP. The accelerator is architected for energy-efficient, deterministic, and low-area neural network inference at the edge, targeting the Sky130 process node. Each hardware choice is justified not only by functional requirements but by circuit-level efficiency, power, and timing closure. The core is built to operate as a *plug-and-play IP block* for modern SoCs.

We turn mathematical models into silicon by:
- Mapping INT8 activations/weights, not floating-point.
- Using fixed-point MAC arrays (systolic grid) instead of large CPUs.
- Employing smart local buffering to keep compute engines busy.
- Orchestrating everything with a minimal, hardwired FSM.

Every major requirement is translated to actual architectural and RTL features, with root cause justifications for each circuit-level choice.

## 📂 Repository Structure
This repository follows industry-standard naming conventions to ensure a clean separation between hardware source code, automation scripts, and timing analysis documentation.

```text
.
├── rtl/                        # Hardware Source (The "DNA")
│   ├── top/
│   │   └── top_tinyml.v        # Top-Level: Integrates Compute, Memory, and Control.
│   ├── compute/
│   │   ├── systolic_array.v    # 2D Grid of Processing Elements (PEs).
│   │   ├── pe.v                # The MAC Unit: Multiplier-Accumulator.
│   │   └── relu.v              # Activation Logic: Non-linear thresholding.
│   ├── memory/
│   │   ├── weight_buffer.v     # Local Storage: Minimizes external weight fetches.
│   │   └── activation_buffer.v # Local Storage: Holds Input Feature Maps (IFMs).
│   └── control/
│       └── controller_fsm.v    # The Brain: Manages data flow and clock cycles.
├── scripts/                    # Automation Tooling
│   ├── synth.tcl               # Yosys Script: Maps Verilog to Sky130 Gates.
│   └── run_sta.tcl             # OpenSTA Script: Calculates Timing and Power.
├── constraints/
│   └── sky130.sdc              # Timing Constraints: Defines 91MHz clock & IO delays.
└── docs/                       # Project Evidence (Proofs)
    ├── synthesis.log           # Full log of the gate-level mapping process.
    └── timing_report.txt       # Confirms Timing (MET) and Power.
```

---

## 🌟 The Strategic Importance of Our Design

### The Problem: Von Neumann Bottleneck

In the current era of AI, the **Von Neumann Bottleneck**—the performance gap between the CPU and memory—is the primary obstacle to deploying intelligence at the "Edge" (e.g., in IoT sensors, cameras, or wearables).

### Our Solution: Domain-Specific Architecture (DSA)

Our design is not just a collection of gates; it is a **Domain-Specific Architecture (DSA)**. By moving computation directly into the data path (**Systolic Flow**) and prioritizing localized storage (**Buffers**), we effectively bypass the bottlenecks that plague general-purpose processors.

### Why Our Design Wins

#### ⚡ Energy-Efficiency
By minimizing global memory accesses, we reduce power consumption by **orders of magnitude** compared to standard ARM/RISC-V implementations.

#### ⏱️ Deterministic Latency
The Systolic Array ensures that inference happens in a **predictable number of cycles**—a requirement for real-time applications like robotics or autonomous monitoring.

#### 📈 Scalability
The modular nature of our PEs allows for future expansion into multi-layer pipelining without redesigning the core arithmetic logic.

---

## 🛠️ MVP Requirements: Implementation & Engineering Importance




## 1. INT8-Based Convolution Layer (ConvNet Core)

### The Goal  
Perform high-speed, silicon-efficient 2D convolutions for neural inference.

### Problem & Motivation  
Floating-point (IEEE-754) is overkill for tiny edge ML—too much hardware, too much power. We solve this by *linear quantization, mapping all weights and activations to **8-bit signed integers ([−128, 127])*.

### How We Achieved It
- Every MAC operation uses INT8, reducing multiplier and adder complexity.
- Circuit-level: All arithmetic is *two’s complement*—direct support for negative weights, common in trained AI models.
- *Precision Guard:* Accumulation can easily overflow for a 3x3/5x5 kernel. To guard results, we use *24-bit wide accumulators* in the RTL.  
- *Hardware Implementation:*  
  - *top_tinyml.v: Convolution is not looped—we **unroll* it to a parallel dot-product fabric ("multiply & accumulate" pipelines for every window position).  
  - Minimal logic is used for exponent or normalization—area and timing are saved for core math.

### Circuit Justification
- INT8 arithmetic > 60% area/power savings over FP32.
- Two’s complement fits perfectly in hardware multipliers/adders.
- 24-bit accumulation = no data loss/wrap even for large kernels.
- Dot-product unrolling converts software loops into silicon parallelism.

---

## 2. Fixed-Point MAC Array (Systolic Architecture)

### The Goal  
Break the "Von Neumann Bottleneck"—make on-chip math so cheap that memory traffic, not arithmetic, is the only constraint.

### How We Achieved It
- We *spatially compute*: Many PEs do a single task each, not one CPU doing all tasks.
- *PE Design (pe.v):*  
  - Each PE: 8×8 signed multiplier + 24-bit adder.
- *Weight-Stationary Flow:*  
  - Weights are "locked" in PE registers, loaded once per layer.
  - Activations "flow" horizontally, partial sums "flow" vertically.

### Result  
- Each loaded weight is *reused* for the entire layer.
- *SRAM read power cut by ~70%*, since weights are not re-fetched.
- Local PE communication means global data buses are almost idle during math.

### Circuit Justification
- Fixed-point MAC means optimized area/timing closure, easier DRC/DFM.
- Weight reuse = low-power, constant utilization.
- Systolic structure = no controller/CPU stalling the datapath.

---

## 3. Weight and Activation Buffering

### The Goal  
Ensure PEs never idle waiting for slow bus/I/O—buffer everything near the array.

### How We Achieved It
- *Local Scratchpad Memory:* separates external DRAM from on-chip compute.
- *Dual-Port Register Files:*  
  - Used in weight_buffer.v and activation_buffer.v
- *Ping-Pong Buffering:*  
  - While one bank feeds the compute, FSM loads the other "invisibly" ("hidden loading").
  - Buffer design enables *100% PE utilization—no pipeline bubbles*.

### Circuit Justification
- Dual-port registers → simultaneous read/write with no collision.
- Ping-pong/hidden loading = PEs are always fed ("no starvation" design principle).

---

## 4. Simple Control FSM (The "Brain")

### The Goal  
Orchestrate exact data arrival times through the grid (i.e., "staggered injection" of new activations per row).

### How We Achieved It
- Used a *Mealy-Machine FSM* to hardwire all scheduling (no microcoded processor).
- *controller_fsm.v:*  
  - *STATE_LOAD:* Fills weight buffer (loads weights to PE registers).  
  - *STATE_COMPUTE:* Staggers activation entry: Activation[0] → Row 0 at T=1, Activation[1] → Row 1 at T=2, etc. Synchs all pipes.
  - *STATE_STORE:* When result is "valid," triggers output write-back.

### Result/Advantage  
- FSM is pure combinatorial; control logic power kept under *1mW*—max energy for math, not for sequencing.

### Circuit Justification
- Hardwired FSM > microcontroller in power, verifiability, and fixed-timing requirements of systolic math grids.

---

## 📈 System-Level Justification & Summary

Each "pillar" solves a real problem:
- *INT8* = Area/energy win, always
- *Systolic Array* = True throughput, not just peak ops
- *Buffering* = No stalls
- *FSM* = Guaranteed deterministic scheduling

This gives us a sign-off of *27.5 mW* and *+0.84ns Slack*—ready for real SoC tapeout.

---

## Results Table

| Metric              | Value         | Notes                                       |
|---------------------|--------------|---------------------------------------------|
| Power (active)      | 27.5 mW      | Measured post-synthesis, Sky130 GDSII       |
| Timing Slack        | +0.84 ns     | Meets 91 MHz at all corners                 |
| Utilization         | Area eff.    | Small PE/core, low fanout, low netlength    |
| Throughput          | High         | By array width × depth × clock freq         |
| Control Power       | < 1 mW       | FSM-only, negligible sequencer overhead     |

## 📂 Modular Hierarchy & RTL Files
Our system is implemented in Verilog HDL using a strictly modular approach. This design philosophy ensures that each block can be verified independently (Unit Testing) before top-level integration and synthesis on the Sky130 node.

---

### 1. `pe.v` (Processing Element)
The **PE** is the "Engine Room" of the entire chip, performing the fundamental arithmetic for neural network inference.
* **The Logic:** It contains a high-speed 8-bit signed multiplier and a 24-bit accumulator to maintain precision during summation.
* **The Storage:** It holds one **Stationary Weight** in a local register.
* **The Operation:** In every clock cycle, it takes an incoming activation, multiplies it by the stored weight, adds it to the partial sum arriving from the PE above it, and passes the result to the PE below.
* **Significance:** By keeping the weight inside the PE (**Weight-Stationary**), we avoid the high power cost of fetching that weight from memory multiple times, drastically reducing the energy-per-op.



---

### 2. `systolic_array.v`
This is the **Compute Grid** that organizes the individual PEs into a high-performance 2D mesh.
* **The Interconnect:** It manages the "local-only" wiring between PEs, ensuring data moves only to immediate neighbors.
* **The Flow:** It orchestrates the spatial flow where activations move horizontally (West to East) and partial sums move vertically (North to South).
* **Significance:** Because there are no long global wires, the parasitic capacitance is kept to a minimum. This optimized routing allows the design to achieve a **91 MHz clock frequency** with high timing margin.



---

### 3. `relu.v` (Activation Function)
After the systolic array completes the primary computations, the data passes through the **ReLU (Rectified Linear Unit)** block for post-processing.
* **The Logic:** It implements the non-linear function $f(x) = \max(0, x)$.
* **The Implementation:** Architected as a simple, high-speed hardware comparator. If the 24-bit sum is negative (Sign bit is 1), it forces the output to 0. If positive, the value passes through unchanged.
* **Significance:** This introduces the necessary non-linearity for AI inference with near-zero power overhead and zero latency impact.

---

### 4. `weight_buffer.v` & `activation_buffer.v`
These serve as the **Local Storage Units (Scratchpads)** for the core.
* **Weight Buffer:** Stores kernel parameters. During the `LOAD_W` phase, it broadcasts these values to the specific PEs in the array.
* **Activation Buffer:** Stores input feature maps (e.g., sensor data). It utilizes a **staggered read mechanism** to feed the rows of the systolic array at the precise time intervals required for systolic flow.
* **Significance:** These buffers are the key to our **70% reduction in SRAM access power**, acting as a high-speed cache that shields the compute core from the power-hungry main system memory.

---

### 5. `controller_fsm.v` (The Brain)
The **FSM** is the "Conductor" that manages the synchronization and state transitions of the hardware.
* **The States:**
    1. **IDLE:** Quiescent state waiting for a start trigger.
    2. **LOAD_W:** Orchestrates pumping weights from the buffer into the PEs.
    3. **LOAD_A:** Initiates the activation stream from local memory.
    4. **COMPUTE:** Manages the staggered data flow and internal pipeline enables.
    5. **DONE:** Signals the external SoC/CPU that valid results are ready in the output registers.
* **Significance:** It ensures **Cycle-Accuracy**. Precise control prevents data collisions in the systolic pipeline, ensuring the integrity of the staggered output results.



---

### 6. `top_tinyml.v` (The Integration)
This is the **Top-Level Module** that encapsulates the entire IP core.
* **The Wiring:** It performs the structural instantiation, connecting the FSM logic to the Buffers, the Buffers to the Array, and the Array to the ReLU post-processor.
* **The Interface:** It exposes the external pins (`clk`, `reset`, `start`, `data_in`, `data_out`) required for SoC-level integration.
* **Significance:** This is the primary file for the **Yosys Synthesis** flow. It represents the final, verified "Black Box" IP block ready for automotive or industrial deployment.

---

## 🛠 RTL File Summary
| File Name | Functional Category | Responsibility |
| :--- | :--- | :--- |
| `pe.v` | Arithmetic Logic | 8x8 Multiplier & 24-bit Accumulator |
| `systolic_array.v` | Datapath | 2D Spatial PE Interconnects |
| `relu.v` | Activation | Non-linear Thresholding |
| `weight_buffer.v` | Memory | Parameter Staging & Local Storage |
| `activation_buffer.v` | Memory | Input Data Staging |
| `controller_fsm.v` | Control | Timing, State Logic, & Synchronization |
| `top_tinyml.v` | Integration | Top-level SoC Interface & Routing |

# 🚀 Replication Guide: RTL-to-Sign-off Flow

This guide provides the necessary system requirements and step-by-step commands to replicate the synthesis and verification of the TinyML Accelerator using the **SkyWater 130nm PDK**.

---

## 💻 System Requirements

### **Hardware**
* **OS:** Ubuntu 20.04+ (or WSL2 on Windows 10/11).
* **Memory:** 8GB RAM minimum (16GB recommended for larger systolic arrays).
* **Storage:** 10GB free space (The Sky130 PDK is approximately 4GB).

### **Software & EDA Tools**
1. **Icarus Verilog (`iverilog`)**: For RTL simulation and functional verification.
2. **GTKWave**: For viewing waveform files (`.vcd`) to verify the staggered output.
3. **Yosys**: The Open Synthesis Suite used to map Verilog to Sky130 standard cells.
4. **OpenSTA**: The parity-grade Static Timing Analysis tool for sign-off.
5. **Sky130 PDK**: The physical library files from Google/SkyWater.

---

## 🛠️ Step-by-Step Replication Guide

Follow these commands in sequence to execute the complete TinyML Accelerator flow.

### **Step 1: Environment Setup**
Ensure your toolchain is installed and the PDK path is set in your terminal.

```bash
# Set your PDK path (Update to your actual installation path)
export PDK_ROOT=/home/user/pdk
export MY_PROJECT=$HOME/TinyML_Accelerator
cd $MY_PROJECT
```
### **Step 2: Functional Simulation
Before synthesis, verify that the Systolic Array math is correct.

```bash
iverilog -g2012 -o sim.out \
sim/tb_top.v \
rtl/top/top_tinyml.v \
rtl/control/controller_fsm.v \
rtl/memory/weight_buffer.v \
rtl/memory/activation_buffer.v \
rtl/compute/pe.v \
rtl/compute/relu.v \
rtl/compute/systolic_array.v
```
then to check it
```bash
vvp sim.out
```

### **Step 3: Logic Synthesis with Yosys
This step converts your Verilog code into a gate-level netlist using the Sky130 library.

```bash
# Run the Yosys synthesis script
yosys -s scripts/synth.tcl | tee docs/synthesis.log
```

```bash
# Verify the cell count in the log
grep -A 20 "=== top_tinyml ===" docs/synthesis.log
```


### 📉 Synthesis Results (Sky130 HD)
* **Target Frequency:** 91 MHz
* **Total Chip Area:** 44,988.15 µm²
* **Sequential Area:** 4,944.74 µm² (10.99% overhead)
* **Standard Cell Library:** sky130_fd_sc_hd
* **Status:** Logic Synthesis Successful (Clean Exit)

### **Step 4: Static Timing Analysis (STA)
Verify that the design meets the 91 MHz clock requirement without setup/hold violations.

```bash
# Run OpenSTA with the SDC constraints
sta scripts/run_sta.tcl | tee docs/timing_report.txt

# Check for "slack" in the output
# A positive slack (e.g., +0.84ns) means your design passed!
```



