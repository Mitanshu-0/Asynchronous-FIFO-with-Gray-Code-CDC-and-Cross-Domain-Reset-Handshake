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

<p align="center">
  <b>Parameterized Asynchronous FIFO RTL Design with Gray-Code Clock Domain Crossing and Cross-Domain Reset Initialization</b>
</p>

---

## 📌 Overview

This project implements a **parameterized Asynchronous FIFO (First-In, First-Out)** using Verilog RTL.

The FIFO operates between two independent clock domains:

- 🟦 **Write Clock Domain**
- 🟩 **Read Clock Domain**

The design uses **Gray-coded read/write pointers** to transfer FIFO pointer information between the two clock domains.

A **2-flop CDC synchronizer** is used for pointer synchronization, while separate reset synchronizers and a **cross-domain reset handshake** coordinate FIFO initialization.

The design also provides:

- Full detection
- Empty detection
- Overflow detection
- Underflow detection
- Independent write/read clocks
- Parameterized data width and FIFO depth

---

# 🏗️ Architecture

The complete FIFO architecture is divided into two clock domains.

```text
                         ASYNCHRONOUS FIFO
                                │
              ┌─────────────────┴─────────────────┐
              │                                   │
       WRITE CLOCK DOMAIN                  READ CLOCK DOMAIN
              │                                   │
        Reset Synchronizer                 Reset Synchronizer
              │                                   │
        Reset Handshake  ◄──── CDC ────►   Reset Handshake
              │                                   │
        FIFO Enable                          FIFO Enable
              │                                   │
        Write Controller                    Read Controller
              │                                   │
        Binary Write Pointer                Binary Read Pointer
              │                                   │
        Binary → Gray                       Binary → Gray
              │                                   │
              └────── Gray Pointer CDC ───────────┘
                              │
                              ▼
                       Dual-Port Memory
                              │
                              ▼
                           rd_data
```

Detailed architecture:

**`docs/async_fifo_full_architecture.svg`**

---

# 🔄 FIFO Data Flow

## ✍️ Write Operation

```text
wr_en
  │
  ▼
Check FULL
  │
  ├──────────────► FULL = 1
  │                    │
  │                    ▼
  │                overflow
  │
  ▼
FIFO Memory Write
  │
  ▼
Increment Binary Pointer
  │
  ▼
Binary → Gray Conversion
  │
  ▼
Gray Pointer Synchronization
  │
  ▼
Read Clock Domain
```

A write is accepted only when:

```verilog
wr_en && !full && wr_fifo_enable
```

---

## 📖 Read Operation

```text
rd_en
  │
  ▼
Check EMPTY
  │
  ├──────────────► EMPTY = 1
  │                    │
  │                    ▼
  │                underflow
  │
  ▼
FIFO Memory Read
  │
  ▼
Increment Binary Pointer
  │
  ▼
Binary → Gray Conversion
  │
  ▼
Gray Pointer Synchronization
  │
  ▼
Write Clock Domain
```

A read is accepted only when:

```verilog
rd_en && !empty && rd_fifo_enable
```

---

# 🔀 Clock Domain Crossing

The write and read sides operate using independent clocks.

The FIFO uses **Gray-coded pointers** and **2-flop synchronizers** to transfer pointer information between the two asynchronous clock domains.

```text
Binary Pointer
      │
      ▼
Gray Code Conversion
      │
      ▼
2-Flip-Flop Synchronizer
      │
      ▼
Destination Clock Domain
```

## ➡️ Write Pointer → Read Domain

```text
WRITE DOMAIN                         READ DOMAIN

wr_ptr_bin
    │
    ▼
Binary → Gray
    │
    ▼
wr_ptr_gray
    │
    ▼
┌──────────────┐
│  2-FF CDC    │
│ Synchronizer │
└──────┬───────┘
       │
       ▼
wr_ptr_gray_sync
       │
       ▼
Read Controller
```

## ⬅️ Read Pointer → Write Domain

```text
READ DOMAIN                          WRITE DOMAIN

rd_ptr_bin
    │
    ▼
Binary → Gray
    │
    ▼
rd_ptr_gray
    │
    ▼
┌──────────────┐
│  2-FF CDC    │
│ Synchronizer │
└──────┬───────┘
       │
       ▼
rd_ptr_gray_sync
       │
       ▼
Write Controller
```

---

# 🧮 Gray-Code Pointer

The binary pointer is converted to Gray code using:

```verilog
gray = binary ^ (binary >> 1);
```

The write pointer uses:

```verilog
wr_ptr_gray_next =
    wr_ptr_bin_next ^
    (wr_ptr_bin_next >> 1);
```

The read pointer uses:

```verilog
rd_ptr_gray_next =
    rd_ptr_bin_next ^
    (rd_ptr_bin_next >> 1);
```

Gray coding is used for the pointer transfer between the two asynchronous clock domains.

---

# 🚦 Full Detection

The write controller determines the FIFO full condition by comparing the next write Gray pointer with a modified synchronized read pointer.

The two most significant bits of the synchronized read pointer are inverted:

```verilog
full_compare_ptr = rd_ptr_gray_sync;

full_compare_ptr[ADDR_WIDTH] =
    ~rd_ptr_gray_sync[ADDR_WIDTH];

full_compare_ptr[ADDR_WIDTH-1] =
    ~rd_ptr_gray_sync[ADDR_WIDTH-1];
```

The full condition is then determined by:

```verilog
full_next =
    (wr_ptr_gray_next == full_compare_ptr);
```

---

# 🟢 Empty Detection

The FIFO is considered empty when the next read pointer matches the synchronized write pointer:

```verilog
empty_next =
    (rd_ptr_gray_next == wr_ptr_gray_sync);
```

---

# ⚠️ Overflow & Underflow

## Overflow

An overflow pulse is generated when a write request occurs while the FIFO is full:

```verilog
overflow <= wr_en && full;
```

The write pointer does not advance and the memory write is not performed.

## Underflow

An underflow pulse is generated when a read request occurs while the FIFO is empty:

```verilog
underflow <= rd_en && empty;
```

The read pointer does not advance and the memory read is not performed.

---

# 🔐 Reset Architecture

Each clock domain has its own reset synchronizer.

```text
                  External Reset
                       │
             ┌─────────┴─────────┐
             │                   │
          wr_rst_n            rd_rst_n
             │                   │
             ▼                   ▼
       Reset Synchronizer  Reset Synchronizer
             │                   │
             ▼                   ▼
      wr_local_rst_n       rd_local_rst_n
             │                   │
             └─────────┬─────────┘
                       │
                Reset Handshake
                       │
                       ▼
                  FIFO Enable
```

The reset synchronizer provides:

- Asynchronous reset assertion
- Synchronous reset de-assertion

for each clock domain.

---

# 🤝 Cross-Domain Reset Handshake

The design uses a reset handshake between the write and read clock domains.

Each domain generates:

```text
init_done
ready
remote_ready_sync
```

The FIFO operation is enabled only after both domains have completed their initialization sequence.

### Write side

```verilog
assign wr_fifo_enable =
    wr_ready &&
    wr_remote_ready_sync;
```

### Read side

```verilog
assign rd_fifo_enable =
    rd_ready &&
    rd_remote_ready_sync;
```

This prevents the FIFO controllers from starting pointer operations before both clock domains have completed initialization.

---

# 💾 FIFO Memory

The FIFO uses a dual-clock memory array:

```verilog
reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
```

### Write

```verilog
always @(posedge wr_clk) begin
    if (wr_en) begin
        mem[wr_addr] <= wr_data;
    end
end
```

### Read

```verilog
always @(posedge rd_clk) begin
    if (rd_en) begin
        rd_data <= mem[rd_addr];
    end
end
```

The memory itself is not reset. FIFO validity is controlled through the read/write pointers and FIFO status flags.

---

# 🔄 Reset / Reinitialization Behavior

During reset or while the cross-domain initialization handshake is incomplete:

- Write pointer is returned to its initial value.
- Read pointer is returned to its initial value.
- `full` is cleared.
- `empty` is asserted.
- FIFO operation is disabled.

The FIFO memory itself is not cleared.

Therefore, after reset/reinitialization, previously stored memory contents are not considered valid FIFO data.

---

# 🧩 Internal Module Structure

The current implementation contains all modules in a **single Verilog source file**.

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

### `async_fifo`

Top-level module connecting the complete FIFO architecture.

### `reset_sync`

Provides asynchronous reset assertion and synchronous reset de-assertion for each clock domain.

### `reset_handshake`

Coordinates initialization between the write and read clock domains.

### `cdc_sync`

Synchronizes Gray-coded FIFO pointers between the two clock domains using a 2-flop synchronizer.

### `fifo_memory`

Provides FIFO storage using independent write and read clocks.

### `write_controller`

Handles:

- Write pointer generation
- Binary-to-Gray conversion
- Full detection
- Overflow detection
- Write address generation

### `read_controller`

Handles:

- Read pointer generation
- Binary-to-Gray conversion
- Empty detection
- Underflow detection
- Read address generation

---

# 🎛️ Parameters

| Parameter | Default | Description |
|---|---:|---|
| `DATA_WIDTH` | `8` | Width of each FIFO data word |
| `ADDR_WIDTH` | `4` | Address width |
| `FIFO_DEPTH` | `16` | FIFO depth = `2^ADDR_WIDTH` |
| `PTR_WIDTH` | `5` | Pointer width = `ADDR_WIDTH + 1` |

For the default configuration:

```text
DATA_WIDTH = 8
ADDR_WIDTH = 4
FIFO_DEPTH = 16
PTR_WIDTH  = 5
```

---

# 🔌 Interface

## Write Clock Domain

| Signal | Direction | Description |
|---|---|---|
| `wr_clk` | Input | Write clock |
| `wr_rst_n` | Input | Active-low write-domain reset |
| `wr_en` | Input | Write enable |
| `wr_data` | Input | Data to be written |
| `full` | Output | FIFO full indication |
| `overflow` | Output | Write attempted while FIFO was full |

## Read Clock Domain

| Signal | Direction | Description |
|---|---|---|
| `rd_clk` | Input | Read clock |
| `rd_rst_n` | Input | Active-low read-domain reset |
| `rd_en` | Input | Read enable |
| `rd_data` | Output | Data read from FIFO |
| `empty` | Output | FIFO empty indication |
| `underflow` | Output | Read attempted while FIFO was empty |

---

# 📊 Current Implementation Status

| Component | Status |
|---|:---:|
| Asynchronous FIFO architecture | ✅ |
| Independent write/read clocks | ✅ |
| Parameterized data width | ✅ |
| Parameterized FIFO depth | ✅ |
| Binary read/write pointers | ✅ |
| Gray-code pointer conversion | ✅ |
| Write → Read CDC | ✅ |
| Read → Write CDC | ✅ |
| 2-flop CDC synchronizers | ✅ |
| Full detection | ✅ |
| Empty detection | ✅ |
| Overflow detection | ✅ |
| Underflow detection | ✅ |
| Reset synchronizers | ✅ |
| Cross-domain reset handshake | ✅ |
| Dual-clock FIFO memory | ✅ |
| Write controller | ✅ |
| Read controller | ✅ |
| Complete RTL implementation | ✅ |
| Functional verification | 🔄 In Progress |

---

# 📁 Project Structure

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

---

# 🛠️ Current RTL Status

> **RTL architecture:** Implemented  
> **Verification:** In progress  
> **Current RTL organization:** Single Verilog source file

The current version contains the complete FIFO implementation in one source file.

After verification, the individual modules can be separated into dedicated RTL files.

---

# 📐 Design Summary

```text
                    ┌─────────────────────┐
                    │  ASYNCHRONOUS FIFO  │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
     Dual Clock           Gray-Code              CDC
      Domains              Pointers         Synchronizers
          │                    │                    │
          └──────────────┬─────┴────────────────────┘
                         │
                         ▼
                 Full / Empty Logic
                         │
                         ▼
                  Reset Handshake
                         │
                         ▼
                    FIFO Memory
```

---

# 📚 Design Concepts

This implementation combines:

- Asynchronous FIFO architecture
- Independent clock domains
- Binary pointer generation
- Gray-code conversion
- Clock-domain crossing
- 2-flop synchronization
- Full and empty detection
- Overflow and underflow detection
- Asynchronous reset assertion
- Synchronous reset de-assertion
- Cross-domain reset initialization
- Dual-clock memory

---

# 🔄 Development Flow

```text
┌─────────────────────────────┐
│ Complete FIFO RTL           │
│ Implementation              │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Functional Verification     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Waveform Analysis           │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Module-by-Module RTL        │
│ Organization                │
└─────────────────────────────┘
```

---

# 📌 Project Focus

The main focus of this project is the RTL implementation of an asynchronous FIFO with particular emphasis on:

**Clock Domain Crossing → Gray-Code Pointers → Full/Empty Detection → Reset Synchronization → Cross-Domain Reset Initialization**

---

<p align="center">

### ⚡ Asynchronous FIFO • Verilog RTL • Gray Code • CDC • Reset Handshake

</p>
