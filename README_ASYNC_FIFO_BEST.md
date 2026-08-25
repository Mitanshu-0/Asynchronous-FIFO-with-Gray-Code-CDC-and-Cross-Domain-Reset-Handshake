<div align="center">

# 🚀 Asynchronous FIFO

### Gray-Code Clock Domain Crossing & Cross-Domain Reset Handshake

<p>
  <img src="https://img.shields.io/badge/HDL-Verilog-1565C0?style=for-the-badge&logo=verilog&logoColor=white">
  <img src="https://img.shields.io/badge/Design-Asynchronous%20FIFO-6A1B9A?style=for-the-badge">
  <img src="https://img.shields.io/badge/CDC-2FF%20Synchronizer-EF6C00?style=for-the-badge">
  <img src="https://img.shields.io/badge/Verification-367%2F367%20Passed-2E7D32?style=for-the-badge">
</p>

<p>
  <b>A parameterized Verilog RTL implementation of an asynchronous FIFO designed for reliable data transfer between independent clock domains.</b>
</p>

</div>

---

## 📖 Overview

An asynchronous FIFO is used when data needs to pass between two clock domains that do not share the same clock.

This project implements the FIFO completely in **Verilog RTL** with separate write and read clock domains. The design uses binary pointers internally and Gray-coded pointers for clock-domain crossing. The transferred pointers are passed through 2-flop synchronizers before being used by the opposite clock domain.

The design also includes a reset synchronizer for each clock domain and a cross-domain reset handshake. This allows FIFO operation to begin only after the required initialization conditions are satisfied.

### What is implemented

- Independent write and read clock domains
- Parameterized data width
- Parameterized FIFO depth
- Binary and Gray-code pointers
- 2-flop CDC synchronization
- Full and empty detection
- Overflow and underflow detection
- Asynchronous reset assertion
- Synchronous reset de-assertion
- Cross-domain reset initialization
- Dual-clock FIFO memory

---

## 🏗️ Architecture

The design is organized around two independent domains:

**Write Domain** → controls data insertion and the write pointer

**Read Domain** → controls data removal and the read pointer

The complete architecture is shown below.

<p align="center">
  <img src="docs/async_fifo_full_architecture.svg" alt="Asynchronous FIFO Architecture" width="900">
</p>

### Main blocks

| Block | Responsibility |
|:--|:--|
| `async_fifo` | Top-level module and interconnection |
| `reset_sync` | Local reset synchronization |
| `reset_handshake` | Cross-domain initialization |
| `write_controller` | Write pointer, full and overflow logic |
| `read_controller` | Read pointer, empty and underflow logic |
| `cdc_sync` | Gray-pointer synchronization |
| `fifo_memory` | FIFO data storage |

---

## ⚙️ Configuration

The FIFO is parameterized so its data width and depth can be changed without changing the basic architecture.

| Parameter | Default | Meaning |
|:--|--:|:--|
| `DATA_WIDTH` | `8` | Number of bits in each data word |
| `ADDR_WIDTH` | `4` | Number of address bits |
| `FIFO_DEPTH` | `16` | Number of FIFO entries |
| `PTR_WIDTH` | `5` | Pointer width |

The FIFO depth is:

```text
FIFO_DEPTH = 2^ADDR_WIDTH
```

For the current default configuration:

```text
Data width  = 8 bits
FIFO depth  = 16 entries
Pointer     = 5 bits
```

The extra pointer bit is used to distinguish between full and empty after pointer wrap-around.

---

## 🔌 Interface

### Write Side

| Signal | Direction | Description |
|:--|:--:|:--|
| `wr_clk` | Input | Write clock |
| `wr_rst_n` | Input | Active-low write reset |
| `wr_en` | Input | Write request |
| `wr_data` | Input | Data written into the FIFO |
| `full` | Output | Indicates that the FIFO is full |
| `overflow` | Output | Indicates a write attempt while full |

### Read Side

| Signal | Direction | Description |
|:--|:--:|:--|
| `rd_clk` | Input | Read clock |
| `rd_rst_n` | Input | Active-low read reset |
| `rd_en` | Input | Read request |
| `rd_data` | Output | Data read from the FIFO |
| `empty` | Output | Indicates that the FIFO is empty |
| `underflow` | Output | Indicates a read attempt while empty |

---

## ✍️ Write and Read Operation

### Write

A write is accepted only when:

```verilog
wr_en && !full && wr_fifo_enable
```

When accepted, the input data is written into memory and the write pointer advances.

The write pointer is maintained in binary and Gray-code form. The Gray-coded write pointer is then synchronized into the read clock domain.

### Read

A read is accepted only when:

```verilog
rd_en && !empty && rd_fifo_enable
```

When accepted, the data at the current read address is read from memory and the read pointer advances.

The Gray-coded read pointer is synchronized into the write clock domain.

---

## 🔀 Clock Domain Crossing

The write and read clocks are asynchronous, so the binary pointers are not transferred directly between the domains.

The pointer transfer works as follows:

```text
Binary Pointer
      │
      ▼
Binary → Gray
      │
      ▼
2-FF Synchronizer
      │
      ▼
Destination Clock Domain
```

### Write pointer

```text
wr_ptr_bin
    ↓
wr_ptr_gray
    ↓
2-FF Synchronizer
    ↓
wr_ptr_gray_sync
    ↓
Read Controller
```

### Read pointer

```text
rd_ptr_bin
    ↓
rd_ptr_gray
    ↓
2-FF Synchronizer
    ↓
rd_ptr_gray_sync
    ↓
Write Controller
```

Gray code is used because consecutive pointer values differ by only one bit, making it suitable for this pointer transfer method.

---

## 🚦 Full and Empty Logic

### Full detection

The write controller checks the next write Gray pointer against a modified synchronized read pointer.

The two most significant bits of the synchronized read pointer are inverted:

```verilog
full_compare_ptr = rd_ptr_gray_sync;

full_compare_ptr[ADDR_WIDTH] =
    ~rd_ptr_gray_sync[ADDR_WIDTH];

full_compare_ptr[ADDR_WIDTH-1] =
    ~rd_ptr_gray_sync[ADDR_WIDTH-1];
```

The full condition is then:

```verilog
full_next =
    (wr_ptr_gray_next == full_compare_ptr);
```

### Empty detection

The FIFO is empty when the next read Gray pointer matches the synchronized write pointer:

```verilog
empty_next =
    (rd_ptr_gray_next == wr_ptr_gray_sync);
```

---

## ⚠️ Overflow and Underflow

The FIFO reports invalid access attempts through one-cycle pulses.

### Overflow

When a write is requested while the FIFO is full:

```verilog
overflow <= wr_en && full;
```

The write is not accepted.

### Underflow

When a read is requested while the FIFO is empty:

```verilog
underflow <= rd_en && empty;
```

The read is not accepted.

---

## 🔐 Reset Design

Each clock domain has its own reset synchronizer.

The reset synchronizer provides:

- **Asynchronous reset assertion**
- **Synchronous reset de-assertion**

After local reset synchronization, the write and read domains exchange initialization information through the reset handshake.

FIFO operation is enabled only after the required local and remote initialization conditions are satisfied.

### During reset / reinitialization

- Write pointer returns to its initial value
- Read pointer returns to its initial value
- `full` is cleared
- `empty` is asserted
- FIFO operation is disabled

The FIFO memory itself is not reset. Therefore, data that was present before reinitialization is not considered valid after the FIFO state is reinitialized.

---

## 🧩 RTL Organization

The current implementation keeps the complete design in a **single Verilog source file**.

```text
async_fifo.v
│
├── async_fifo
├── reset_sync
├── reset_handshake
├── cdc_sync
├── fifo_memory
├── write_controller
└── read_controller
```

### Module responsibilities

**`async_fifo`**  
Top-level module connecting the complete FIFO.

**`reset_sync`**  
Synchronizes reset release separately in the write and read clock domains.

**`reset_handshake`**  
Coordinates initialization between the two clock domains.

**`cdc_sync`**  
Synchronizes Gray-coded pointers using two flip-flop stages.

**`fifo_memory`**  
Stores FIFO data using separate write and read clocks.

**`write_controller`**  
Handles the write pointer, full flag, overflow pulse, and write address.

**`read_controller`**  
Handles the read pointer, empty flag, underflow pulse, and read address.

---

## 🧪 Verification

The design was verified using directed checks and data-integrity checking.

### Final Result

```text
# ================================================
# FINAL RESULTS
# ================================================
# Directed checks : 80 passed / 0 failed / 80 total
# Data integrity  : 287 passed / 0 failed / 287 total
# Overflow pulses : 111
# Underflow pulses: 104
# Overflow event mismatches : 0
# Underflow event mismatches: 0
# RESULT: ALL CHECKS PASSED (367/367)
# ================================================
```

### Verification Summary

| Test / Check | Result |
|:--|:--:|
| Directed checks | **80 / 80** ✅ |
| Data integrity | **287 / 287** ✅ |
| Overflow event mismatches | **0** ✅ |
| Underflow event mismatches | **0** ✅ |
| **Total checks** | **367 / 367** ✅ |

### Verification status

> **367 / 367 checks passed — no failures or event mismatches.**

---

## 📁 Repository Structure

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

The current version keeps all RTL modules in one file. The modules can be separated into individual files later for easier maintenance and reuse.

---

## 🛠️ Tools Used

- **Verilog HDL**
- **RTL Simulation**
- **GitHub**

---

## 🎯 Project Focus

The main focus of this project is the implementation and verification of an asynchronous FIFO with reliable communication between independent clock domains.

The key design areas are:

**Gray-Code Pointer Transfer · CDC Synchronization · Full/Empty Detection · Overflow/Underflow Handling · Reset Synchronization · Cross-Domain Reset Initialization**

---

<div align="center">

### ⚡ Built as an RTL design study of asynchronous FIFO and CDC techniques.

</div>
