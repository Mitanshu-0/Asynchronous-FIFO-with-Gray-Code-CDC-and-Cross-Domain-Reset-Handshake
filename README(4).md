# Asynchronous FIFO

A parameterized **Asynchronous FIFO (First-In-First-Out)** implemented
in Verilog/SystemVerilog for reliable data transfer between two
independent clock domains.

The design uses **Gray-coded read/write pointers**, **2-flop CDC
synchronizers**, independent reset synchronization, and a cross-domain
reset handshake. A self-checking testbench verifies functional behavior,
data integrity, reset corner cases, and overflow/underflow events.

------------------------------------------------------------------------

## Table of Contents

-   [Overview](#overview)
-   [Features](#features)
-   [Project Structure](#project-structure)
-   [Architecture](#architecture)
-   [FIFO Configuration](#fifo-configuration)
-   [RTL Modules](#rtl-modules)
-   [Clock-Domain Crossing](#clock-domain-crossing)
-   [FIFO Operation](#fifo-operation)
-   [Full and Empty Detection](#full-and-empty-detection)
-   [Reset Handling](#reset-handling)
-   [Overflow and Underflow](#overflow-and-underflow)
-   [Verification](#verification)
-   [Verification Tests](#verification-tests)
-   [Random Stress Test](#random-stress-test)
-   [Verification Results](#verification-results)
-   [Design Highlights](#design-highlights)
-   [Future Improvements](#future-improvements)
-   [Project Status](#project-status)

------------------------------------------------------------------------

## Overview

An asynchronous FIFO is used when data must be transferred between two
clock domains that operate independently.

This project implements a dual-clock FIFO with:

-   An independent **write clock domain**
-   An independent **read clock domain**
-   Local binary pointers for address generation
-   Gray-coded pointers for clock-domain crossing
-   2-stage synchronizers for transferred pointers
-   Full and empty status generation
-   Overflow and underflow event indication
-   Coordinated reset startup
-   A self-checking verification environment

The default implementation is an **8-bit × 16-entry FIFO**.

------------------------------------------------------------------------

## Features

  Feature                 Implementation
  ----------------------- ---------------------------------------
  FIFO type               Asynchronous / dual-clock
  Data width              8 bits
  FIFO depth              16 entries
  Write clock             `wr_clk`
  Read clock              `rd_clk`
  Pointer format          Binary + Gray
  CDC synchronization     2-flop synchronizers
  Full detection          Gray-code next-pointer comparison
  Empty detection         Gray-code next-pointer comparison
  Overflow                Registered event
  Underflow               Registered event
  Reset                   Async assertion / sync de-assertion
  Reset coordination      Cross-domain handshake
  Verification            Self-checking SystemVerilog testbench
  Final verified checks   **367 / 367 passed**

------------------------------------------------------------------------

## Project Structure

``` text
.
├── docs/
│   └── async_fifo_full_architecture.svg
│
├── rtl/
│   ├── async_fifo.v
│   ├── cdc_sync.v
│   ├── fifo_memory.v
│   ├── read_controller.v
│   ├── reset_handshake.v
│   ├── reset_sync.v
│   └── write_controller.v
│
└── tb/
    └── tb_async_fifo.sv
```

### Directory Description

  Directory   Purpose
  ----------- --------------------------------------
  `rtl/`      RTL design modules
  `tb/`       Self-checking verification testbench
  `docs/`     Project architecture documentation

------------------------------------------------------------------------

## Architecture

The project architecture is documented in the repository SVG:

![Asynchronous FIFO Architecture](docs/async_fifo_full_architecture.svg)

The FIFO is divided into two independent clock domains.

### Write Domain

The write side contains:

-   Write controller
-   Binary write pointer
-   Gray-coded write pointer
-   Write address generation
-   Full detection
-   Overflow generation

### Read Domain

The read side contains:

-   Read controller
-   Binary read pointer
-   Gray-coded read pointer
-   Read address generation
-   Empty detection
-   Underflow generation

### Cross-Domain Paths

Two pointer paths cross the clock-domain boundary:

``` text
Read Gray Pointer
       │
       ▼
2-FF Synchronizer
       │
       ▼
Write Clock Domain
```

``` text
Write Gray Pointer
       │
       ▼
2-FF Synchronizer
       │
       ▼
Read Clock Domain
```

The FIFO memory is shared between the two domains through independent
write and read clocked accesses.

------------------------------------------------------------------------

## FIFO Configuration

The top-level module is parameterized using:

``` verilog
parameter DATA_WIDTH = 8
parameter ADDR_WIDTH = 4
```

Therefore:

``` text
FIFO depth
= 2^ADDR_WIDTH
= 2^4
= 16 entries
```

The pointer width is:

``` text
PTR_WIDTH
= ADDR_WIDTH + 1
= 5 bits
```

The additional pointer bit allows the design to distinguish between full
and empty states after pointer wraparound.

### Default Parameters

  Parameter         Value
  --------------- -------
  `DATA_WIDTH`          8
  `ADDR_WIDTH`          4
  FIFO depth           16
  Pointer width         5

------------------------------------------------------------------------

## RTL Modules

### `async_fifo.v`

Top-level integration module.

It connects:

-   Reset synchronization
-   Reset handshake
-   Write controller
-   Read controller
-   Pointer CDC synchronizers
-   FIFO memory

### `reset_sync.v`

Provides asynchronous reset assertion and synchronous reset de-assertion
for an individual clock domain.

### `reset_handshake.v`

Coordinates initialization between the write and read domains.

Normal FIFO operation begins only after the required local and remote
initialization conditions are satisfied.

### `cdc_sync.v`

Implements the 2-flop synchronizer used to transfer Gray-coded pointers
between asynchronous clock domains.

Two instances are used:

``` text
Read pointer  → Write domain
Write pointer → Read domain
```

### `fifo_memory.v`

Implements the FIFO storage array.

-   Write access uses `wr_clk`
-   Read access uses `rd_clk`
-   Memory accesses are enabled only for accepted FIFO operations

### `write_controller.v`

Controls the write side of the FIFO.

Responsibilities:

-   Write pointer generation
-   Binary-to-Gray conversion
-   Write address generation
-   Full detection
-   Overflow generation

A write is accepted when:

``` text
wr_en = 1
full = 0
fifo_enable = 1
```

### `read_controller.v`

Controls the read side of the FIFO.

Responsibilities:

-   Read pointer generation
-   Binary-to-Gray conversion
-   Read address generation
-   Empty detection
-   Underflow generation

A read is accepted when:

``` text
rd_en = 1
empty = 0
fifo_enable = 1
```

------------------------------------------------------------------------

## Clock-Domain Crossing

The FIFO does not directly transfer binary pointers between clock
domains.

Instead, each pointer follows this path:

``` text
Binary Pointer
      │
      ▼
Gray Conversion
      │
      ▼
2-FF Synchronizer
      │
      ▼
Destination Clock Domain
```

### Why Gray Code?

A binary counter can change several bits during a single increment. Gray
code changes only one bit between adjacent values, making it better
suited for asynchronous pointer transfer.

The synchronized Gray pointer is then used by the destination-domain
FIFO controller for full or empty detection.

------------------------------------------------------------------------

## FIFO Operation

### Write Operation

A write request is accepted only when the FIFO is enabled and not full.

``` text
wr_en
  │
  ▼
FIFO enabled?
  │
  ├── No ──► Reject
  │
  ▼
full?
  │
  ├── Yes ─► Reject + overflow event
  │
  ▼
Write data to memory
  │
  ▼
Increment write pointer
  │
  ▼
Convert binary pointer to Gray code
  │
  ▼
Update full status
```

### Read Operation

A read request is accepted only when the FIFO is enabled and not empty.

``` text
rd_en
  │
  ▼
FIFO enabled?
  │
  ├── No ──► Reject
  │
  ▼
empty?
  │
  ├── Yes ─► Reject + underflow event
  │
  ▼
Read data from memory
  │
  ▼
Increment read pointer
  │
  ▼
Convert binary pointer to Gray code
  │
  ▼
Update empty status
```

------------------------------------------------------------------------

## Full and Empty Detection

### Full Detection

The write controller calculates the next write pointer and compares its
Gray-coded value with the synchronized read pointer.

The required wraparound bits are inverted for the full comparison.

Conceptually:

``` text
Next Write Pointer
        │
        ▼
   Gray Conversion
        │
        ▼
Compare with synchronized
Read Gray Pointer
        │
        ▼
       FULL
```

When `full` is asserted, additional write requests are rejected.

### Empty Detection

The read controller calculates the next read pointer.

The FIFO is empty when:

``` text
next_read_gray == synchronized_write_gray
```

When `empty` is asserted, additional read requests are rejected.

------------------------------------------------------------------------

## Reset Handling

Each clock domain has its own reset synchronization.

The reset sequence is:

``` text
External Reset
      │
      ▼
Reset Synchronizer
      │
      ▼
Local Initialization
      │
      ▼
Cross-Domain Reset Handshake
      │
      ▼
FIFO Enabled
```

The verification environment exercises:

-   Simultaneous reset
-   Independent write-side reset
-   Independent read-side reset
-   Skewed reset release
-   Reset while FIFO is full
-   Reset while enables are active
-   Reset with data in flight

A reset reinitializes the FIFO pointer and status state, so the FIFO is
logically flushed after recovery.

------------------------------------------------------------------------

## Overflow and Underflow

### Overflow

An overflow event occurs when a write is requested while the FIFO is
full:

``` text
wr_en && full
```

The rejected write does not advance the write pointer or enter the FIFO
memory.

### Underflow

An underflow event occurs when a read is requested while the FIFO is
empty:

``` text
rd_en && empty
```

The rejected read does not advance the read pointer.

------------------------------------------------------------------------

# Verification

The testbench is self-checking and uses a queue-based reference model to
verify FIFO ordering and data integrity.

The scoreboard:

1.  Tracks only writes accepted by the DUT.
2.  Stores accepted write data in a reference queue.
3.  Removes the oldest expected value when a read is accepted.
4.  Compares the expected value with the registered `rd_data`.
5.  Reports mismatches automatically.

The testbench also maintains independent shadow models for overflow and
underflow event verification.

------------------------------------------------------------------------

## Verification Tests

The testbench contains **18 major test sections**.

  ------------------------------------------------------------------------
                            \# Test                  Verification Purpose
  ---------------------------- --------------------- ---------------------
                             1 Simultaneous reset /  Verify initial FIFO
                               initialization        state

                             2 Single write / single Verify basic
                               read                  operation

                             3 Fill FIFO to full     Verify FIFO capacity
                                                     and `full`

                             4 DEPTH+1 write /       Verify rejected write
                               overflow              and overflow

                             5 Drain FIFO / empty    Verify complete FIFO
                                                     drain

                             6 DEPTH+1 read /        Verify rejected read
                               underflow             and underflow

                             7 Normal burst          Verify burst data
                                                     integrity

                             8 Pointer wraparound    Verify repeated
                                                     pointer wrapping

                             9 Writer faster /       Verify full behavior
                               reader stopped        under write pressure

                            10 Reader faster /       Verify empty behavior
                               writer stopped        under read pressure

                            11 Independent write     Verify write-side
                               reset at half-full    reset recovery

                            12 Independent read      Verify read-side
                               reset at half-full    reset recovery

                            13 Reset while FIFO is   Verify full-state
                               full                  recovery

                            14 Reset while enables   Verify reset during
                               are active            active traffic

                            15 Skewed reset release  Verify
                                                     non-simultaneous
                                                     reset release

                            16 Reset with data in    Verify mid-operation
                               flight                reset

                            17 Concurrent random     Verify asynchronous
                               stress                random traffic

                            18 Overflow/underflow    Verify event outputs
                               event summary         against shadow models
  ------------------------------------------------------------------------

------------------------------------------------------------------------

## Random Stress Test

The testbench includes concurrent randomized traffic in both clock
domains.

### Write-side stress

``` text
600 iterations
```

### Read-side stress

``` text
600 iterations
```

The two processes operate independently on their respective clocks.

After the random phase, the remaining reference-model data is drained
and the final data-integrity checks are performed.

------------------------------------------------------------------------

## Verification Results

The current verified simulation produced:

``` text
================================================
FINAL RESULTS
================================================
Directed checks : 80 passed / 0 failed / 80 total
Data integrity  : 287 passed / 0 failed / 287 total
Overflow pulses : 111
Underflow pulses: 104
Overflow event mismatches : 0
Underflow event mismatches: 0
RESULT: ALL CHECKS PASSED (367/367)
================================================
```

### Result Summary

  Verification Category      Passed   Failed     Total
  ----------------------- --------- -------- ---------
  Directed checks            **80**        0        80
  Data integrity            **287**        0       287
  **Combined checks**       **367**    **0**   **367**

### Event Verification

  Event         Observed   Mismatches
  ----------- ---------- ------------
  Overflow           111        **0**
  Underflow          104        **0**

### Final Result

> **ALL CHECKS PASSED --- 367/367**

The implemented verification suite completed with:

-   **0 directed-test failures**
-   **0 data-integrity failures**
-   **0 overflow event mismatches**
-   **0 underflow event mismatches**

------------------------------------------------------------------------

## Design Highlights

This project demonstrates the following RTL and digital-design concepts:

-   Asynchronous FIFO architecture
-   Independent clock domains
-   Clock-domain crossing
-   Gray-code pointer synchronization
-   2-flop synchronizers
-   Full and empty detection
-   Overflow and underflow handling
-   Asynchronous reset assertion
-   Synchronous reset de-assertion
-   Cross-domain reset coordination
-   Dual-clock FIFO memory
-   Queue-based self-checking verification
-   Directed corner-case verification
-   Concurrent randomized stress testing

------------------------------------------------------------------------

## Future Improvements

Possible extensions to the current implementation include:

-   SystemVerilog assertions
-   Functional coverage
-   Additional randomized clock ratios
-   Constrained-random verification
-   Dedicated CDC analysis
-   RTL synthesis
-   FPGA implementation
-   Timing and resource analysis
-   Post-synthesis simulation
-   Formal verification of FIFO properties

------------------------------------------------------------------------

## Project Status

  Area                          Status
  ----------------------------- ----------------------
  RTL implementation            **Complete**
  CDC pointer synchronization   **Implemented**
  Reset coordination            **Implemented**
  Full / empty detection        **Implemented**
  Overflow / underflow          **Implemented**
  Directed verification         **80 / 80 passed**
  Data-integrity verification   **287 / 287 passed**
  Total verification checks     **367 / 367 passed**
  Event mismatches              **0**
  Overall status                **PASS**

------------------------------------------------------------------------

## Summary

This project implements a parameterized **8-bit × 16-entry asynchronous
FIFO** designed for data transfer between independent clock domains.

The design combines:

``` text
Binary Pointers
      ↓
Gray-Code Conversion
      ↓
2-FF CDC Synchronization
      ↓
Full / Empty Detection
      ↓
FIFO Memory Control
```

The verification environment covers normal operation, boundary
conditions, pointer wraparound, reset scenarios, overflow/underflow
behavior, and concurrent randomized traffic.

**Final verified result: 367 / 367 checks passed.**
