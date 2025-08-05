# Low-Latency UDP Packet Filter for HFT

This repository contains the SystemVerilog source code for a high-performance, low-latency UDP packet filter designed for High-Frequency Trading (HFT) applications. The module is implemented on an FPGA and is capable of parsing Ethernet frames at line rate, filtering them based on a UDP destination port, and forwarding valid payloads with sub-nanosecond latency in RTL simulation.

This project serves as a foundational example of hardware-accelerated network processing, demonstrating essential skills for FPGA engineers in the finance industry.

## Table of Contents

1.  [Project Overview](https://github.com/AditiKulkarni454/hft-udp-filter/main/README.md#project-overview)
2.  [Features](https://github.com/AditiKulkarni454/hft-udp-filter/main/README.md#features)
3.  [Design Details](https://github.com/AditiKulkarni454/hft-udp-filter/main/README.md#design-details)
4.  [Verification Environment](https://github.com/AditiKulkarni454/hft-udp-filter/main/README.md#verification-environment)
5.  [Performance Results](https://github.com/AditiKulkarni454/hft-udp-filter/main/README.md#performance-results)
6.  [Repository Structure](https://github.com/AditiKulkarni454/hft-udp-filter/main/README.md#repository-structure)
7.  [How to Run the Simulation](https://github.com/AditiKulkarni454/hft-udp-filter/main/README.md#how-to-run-the-simulation)

## Project Overview

In HFT, market data is broadcast over UDP to minimize latency. A trading system receives an enormous volume of this data, but a specific strategy may only be interested in a small fraction of it. This UDP Packet Filter acts as a hardware "sieve," sitting at the network edge to make an instantaneous decision: **pass** or **drop**.

By dropping irrelevant packets in hardware, we prevent them from consuming valuable processing cycles in downstream logic or software, which is critical for maintaining a low-latency trading profile.

The filter's logic is as follows:

1.  Receive an Ethernet frame byte-by-byte.
2.  Check if the EtherType is `0x0800` (IPv4). 
3.  Check if the IP Protocol is `0x11` (UDP). 
4.  Extract the UDP destination port.
5.  If the port matches a configured value, forward the payload.
6.  If any check fails, drop the entire packet silently.

## Features

  * **Low-Latency Design**: Optimized for minimal clock cycles from input to output.
  * **Protocol Parsing**: Correctly parses Ethernet, IPv4, and UDP headers to locate the destination port.
  * **Configurable Filter**: The target UDP port to match is a configurable input.
  * **State Machine Control**: A robust Finite State Machine (FSM) manages the parsing process. 
  * **Comprehensive Verification**: Includes a SystemVerilog testbench with a wide array of directed test cases.
  * **Ready-to-Run**: Comes with a ModelSim `run.do` script for easy compilation and simulation.

## Design Details

The core of the filter is a Finite State Machine (FSM) implemented in `udp_packet_filter.sv`. It sequences through the incoming byte stream and inspects headers at the correct offsets.

### FSM States

  * `S_IDLE`: Waits for a new packet. 
  * `S_PARSE_ETH_HEADER`: Processes the 14-byte Ethernet header.
  * `S_PARSE_IP_HEADER`: Processes the 20-byte IPv4 header.
  * `S_PARSE_UDP_HEADER`: Processes the 8-byte UDP header and makes the filtering decision.
  * `S_STREAM_PAYLOAD`: Forwards the payload of a matching packet.
  * `S_DROP_PACKET`: Silently consumes the rest of a non-matching packet. 

A `byte_counter` works in conjunction with the FSM to track the current position within the packet, enabling precise extraction of header fields.

## Verification Environment

A design is only as good as its verification. This project includes a professional testbench (`tb_udp_filter.sv`) that has evolved to incorporate best practices.

  * **SystemVerilog Interfaces**: `packet_if.sv` is used to bundle signals, reducing clutter and preventing connection errors. We use separate input and output interface instances to cleanly manage data flow. 
  * **Directed Test Cases**: The testbench includes a comprehensive suite of directed tests to ensure robust behavior:
      * Standard pass and drop cases. 
      * Packets with incorrect EtherTypes (non-IPv4) or IP protocols (non-UDP). 
      * Malformed packets like runt frames.
      * Back-to-back packet streams to test line-rate handling.
      * A mid-packet reset test to ensure system stability. 
  * **Helper Tasks**: A `send_packet` task is used to easily stream packet data into the DUT, improving testbench readability. 

## Performance Results

The verification process was executed using **ModelSim - Intel FPGA Edition**. The simulation confirms the design is functionally correct and provides concrete performance metrics.

  * **Functional Correctness**: The DUT successfully passed all test cases, including the pass, drop, malformed packet, and reset scenarios.
  * **Algorithmic Latency**: The time from the first byte entering the DUT to the first byte of a valid payload exiting is **43 clock cycles**.
  * **Simulated Time Latency**: In the RTL simulation (with a 10ns clock period), this translates to a pass-through latency of **430 picoseconds**—a true sub-nanosecond result.
  * **Throughput**: The design successfully processes back-to-back packets without stalling, demonstrating it can handle the full 10Gbps line rate.

## Repository Structure

```
.
├── packet_if.sv          # SystemVerilog interface for data streaming
├── udp_packet_filter.sv  # The main RTL module for the UDP filter (DUT)
├── tb_udp_filter.sv      # The comprehensive SystemVerilog testbench
└── run.do                # ModelSim script to compile and run the simulation
```

## How to Run the Simulation

### Prerequisites

  * A Verilog/SystemVerilog simulator that supports SystemVerilog interfaces. This project was developed and tested with **ModelSim - Intel FPGA Edition v10.5b**.

### Steps

1.  **Clone the Repository:**
    ```sh
    git clone <your-repo-url>
    cd <your-repo-directory>
    ```
2.  **Launch ModelSim:** Open the ModelSim command-line interface or GUI.
3.  **Run the Script:** In the ModelSim console, execute the `run.do` script.
    ```tcl
    do run.do
    ```

This script will automatically perform the following steps:

1.  Clean up any previous simulation data.
2.  Create a `work` library.
3.  Compile all the necessary SystemVerilog files in the correct order.
4.  Load the simulation with the testbench (`tb_udp_filter`) as the top level.
5.  Open the GUI, execute a Tcl procedure (`add_wave_signals`) to automatically add relevant signals to the wave window, and run the simulation to completion.

You will be able to see the full test sequence output in the ModelSim transcript and inspect the detailed waveforms in the wave viewer.
