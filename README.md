# 🚀 Asynchronous FIFO — Gray-Code CDC & Reset Handshake

<p align="center">
  <img src="docs/async_fifo_full_architecture.svg" alt="Asynchronous FIFO Architecture" width="850">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/HDL-Verilog-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/Architecture-Asynchronous%20FIFO-purple?style=for-the-badge">
  <img src="https://img.shields.io/badge/CDC-Gray%20Code-orange?style=for-the-badge">
  <img src="https://img.shields.io/badge/Reset-Cross--Domain-green?style=for-the-badge">
</p>

## About

This project is a Verilog RTL implementation of an **Asynchronous FIFO**.

The FIFO has separate write and read clock domains, allowing data to be written and read using independent clocks. The design uses binary read/write pointers and converts them to Gray code before transferring pointer information between the two clock domains.

A 2-flop synchronizer is used for the Gray-coded pointers. The design also includes separate reset synchronizers and a cross-domain reset handshake to coordinate initialization of the two clock domains.

The current implementation contains the complete FIFO in a single Verilog source file.

---

## Architecture

The architecture contains two independent clock domains:

- **Write Clock Domain**
- **Read Clock Domain**

The main blocks are:

- Reset Synchronizer
- Reset Handshake
- Write Controller
- Read Controller
- CDC Synchronizers
- FIFO Memory

The complete architecture is shown in the diagram above.

---

## Main Features

- Asynchronous FIFO with independent write and read clocks
- Parameterized data width
- Parameterized FIFO depth
- Binary read/write pointers
- Gray-code pointer conversion
- 2-flop CDC synchronizers
- Full detection
- Empty detection
- Overflow detection
- Underflow detection
- Asynchronous reset assertion
- Synchronous reset de-assertion
- Cross-domain reset initialization handshake
- Dual-clock FIFO memory

---

## Parameters

| Parameter | Default | Description |
|---|---:|---|
| `DATA_WIDTH` | 8 | Width of FIFO data |
| `ADDR_WIDTH` | 4 | Address width |
| `FIFO_DEPTH` | 16 | FIFO depth = `2^ADDR_WIDTH` |
| `PTR_WIDTH` | 5 | Pointer width = `ADDR_WIDTH + 1` |

With the default values:

```text
DATA_WIDTH = 8
ADDR_WIDTH = 4
FIFO_DEPTH = 16
PTR_WIDTH  = 5
```

The extra pointer bit is used to distinguish the full and empty conditions when the pointers wrap around.

---

## Interface

### Write Side

| Signal | Description |
|---|---|
| `wr_clk` | Write clock |
| `wr_rst_n` | Active-low write reset |
| `wr_en` | Write enable |
| `wr_data` | Input data |
| `full` | Indicates FIFO is full |
| `overflow` | Indicates a write was attempted while FIFO was full |

### Read Side

| Signal | Description |
|---|---|
| `rd_clk` | Read clock |
| `rd_rst_n` | Active-low read reset |
| `rd_en` | Read enable |
| `rd_data` | Output data |
| `empty` | Indicates FIFO is empty |
| `underflow` | Indicates a read was attempted while FIFO was empty |

---

## Clock Domain Crossing

The write and read clocks are asynchronous to each other, so the pointer information cannot be transferred directly as normal binary values.

The design follows this flow:

```text
Binary Pointer
      ↓
Gray Code Conversion
      ↓
2-Flop Synchronizer
      ↓
Other Clock Domain
```

The write pointer is synchronized into the read clock domain, while the read pointer is synchronized into the write clock domain.

Gray code is used because only one bit changes between consecutive pointer values.

---

## Full and Empty Detection

### Full

The write controller checks the next write Gray pointer against the synchronized read pointer with the required MSB inversion.

This determines when the FIFO has reached its full condition.

### Empty

The read controller checks the next read Gray pointer against the synchronized write pointer.

When they match, the FIFO is considered empty.

---

## Overflow and Underflow

The design provides status signals for invalid FIFO operations.

### Overflow

If `wr_en` is asserted while `full` is already high:

```verilog
overflow <= wr_en && full;
```

The write is not accepted.

### Underflow

If `rd_en` is asserted while `empty` is high:

```verilog
underflow <= rd_en && empty;
```

The read is not accepted.

---

## Reset Design

Each clock domain has its own reset synchronizer.

The reset synchronizer provides:

- Asynchronous reset assertion
- Synchronous reset de-assertion

After local reset synchronization, the two domains exchange initialization information through the reset handshake.

FIFO operation is enabled only after the required local and remote initialization conditions are satisfied.

The reset/reinitialization resets the FIFO pointer and control state. The memory itself is not cleared, so previously stored data is not considered valid after reinitialization.

---

## RTL Modules

The current implementation contains the following modules in one Verilog file:

| Module | Purpose |
|---|---|
| `async_fifo` | Top-level FIFO |
| `reset_sync` | Reset synchronization |
| `reset_handshake` | Cross-domain initialization |
| `cdc_sync` | Gray-pointer synchronization |
| `fifo_memory` | FIFO storage |
| `write_controller` | Write pointer, full and overflow logic |
| `read_controller` | Read pointer, empty and underflow logic |

---


## Project Structure

```text
Async-FIFO/
│
├── README.md
│
├── rtl/
│   └── async_fifo.v
│
└── docs/
    └── async_fifo_full_architecture.svg
```

The current version keeps all RTL modules in one file. After verification, the modules will be separated into individual RTL files.

---

## Design Focus

The main focus of this project is the implementation of an asynchronous FIFO and the handling of communication between independent clock domains.

The important parts of the design are:

**Asynchronous FIFO → Gray-Code Pointers → CDC Synchronization → Full/Empty Detection → Reset Synchronization → Cross-Domain Reset Handshake**

---

## Tools

- Verilog HDL
- RTL Simulation
- GitHub

---




