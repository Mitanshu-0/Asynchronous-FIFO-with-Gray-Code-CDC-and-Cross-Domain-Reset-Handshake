⚡ Asynchronous FIFO — Gray-Code CDC & Reset Handshake

<div align="center">

<img src="https://img.shields.io/badge/HDL-Verilog-1E88E5?style=for-the-badge">
<img src="https://img.shields.io/badge/FIFO-Asynchronous-7B1FA2?style=for-the-badge">
<img src="https://img.shields.io/badge/CDC-Gray%20Code-F57C00?style=for-the-badge">
<img src="https://img.shields.io/badge/Verification-367%2F367%20Passed-2E7D32?style=for-the-badge">

</div>

📌 Overview

This project is a parameterized Asynchronous FIFO implemented using Verilog RTL.

The FIFO uses separate write and read clock domains, allowing the two sides to operate with independent clocks. Gray-coded pointers are used for transferring pointer information between the clock domains, with 2-flop synchronizers used for CDC.

The design also includes separate reset synchronizers and a cross-domain reset handshake to coordinate initialization of the two FIFO domains.

Main features

Independent write and read clock domains

Parameterized data width and FIFO depth

Binary and Gray-code read/write pointers

2-flop CDC synchronizers

Full and empty detection

Overflow and underflow detection

Asynchronous reset assertion

Synchronous reset de-assertion

Cross-domain reset initialization handshake

Dual-clock FIFO memory

🏗️ Architecture

The FIFO is divided into two main clock domains:

Write Domain and Read Domain

The complete architecture is shown below.

<p align="center">
  <img src="docs/async_fifo_full_architecture.svg" alt="Asynchronous FIFO Architecture" width="900">
</p>

The main blocks used in the design are:

Block

Function

reset_sync

Synchronizes reset release for each clock domain

reset_handshake

Coordinates initialization between the two domains

write_controller

Write pointer, full and overflow logic

read_controller

Read pointer, empty and underflow logic

cdc_sync

Synchronizes Gray-coded pointers between domains

fifo_memory

Stores FIFO data

async_fifo

Top-level module connecting all blocks

⚙️ Parameters

The FIFO can be configured using the following parameters:

Parameter

Default

Description

DATA_WIDTH

8

Width of FIFO data

ADDR_WIDTH

4

Address width

FIFO_DEPTH

16

FIFO depth = 2^ADDR_WIDTH

PTR_WIDTH

5

Pointer width = ADDR_WIDTH + 1

Default configuration

DATA_WIDTH = 8
ADDR_WIDTH = 4
FIFO_DEPTH = 16
PTR_WIDTH  = 5

The extra pointer bit is used to distinguish between full and empty conditions when the pointers wrap around.

🔌 Interface

Write Domain

Signal

Direction

Description

wr_clk

Input

Write clock

wr_rst_n

Input

Active-low write reset

wr_en

Input

Write request

wr_data

Input

Data to be written

full

Output

FIFO full indication

overflow

Output

Write attempted while FIFO was full

Read Domain

Signal

Direction

Description

rd_clk

Input

Read clock

rd_rst_n

Input

Active-low read reset

rd_en

Input

Read request

rd_data

Output

Data read from FIFO

empty

Output

FIFO empty indication

underflow

Output

Read attempted while FIFO was empty

🔄 FIFO Operation

Write Operation

A write is accepted only when the FIFO is enabled and not full:

wr_en && !full && wr_fifo_enable

When a write is accepted:

Data is written into FIFO memory.

The write pointer advances.

The binary pointer is converted to Gray code.

The Gray-coded write pointer is synchronized into the read domain.

Read Operation

A read is accepted only when the FIFO is enabled and not empty:

rd_en && !empty && rd_fifo_enable

When a read is accepted:

Data is read from FIFO memory.

The read pointer advances.

The binary pointer is converted to Gray code.

The Gray-coded read pointer is synchronized into the write domain.

🔀 Clock Domain Crossing

Since wr_clk and rd_clk are independent, pointer information is transferred using Gray code and 2-flop synchronization.

Write pointer

Write Binary Pointer
        ↓
Binary → Gray
        ↓
Write Gray Pointer
        ↓
2-FF Synchronizer
        ↓
Read Clock Domain

Read pointer

Read Binary Pointer
        ↓
Binary → Gray
        ↓
Read Gray Pointer
        ↓
2-FF Synchronizer
        ↓
Write Clock Domain

The cdc_sync module contains the two flip-flop stages used for this synchronization.

🚦 Full and Empty Detection

Full Detection

The write controller compares the next write Gray pointer with a modified synchronized read pointer.

The two most significant bits of the synchronized read pointer are inverted for the full comparison.

full_compare_ptr = rd_ptr_gray_sync;

full_compare_ptr[ADDR_WIDTH] =
    ~rd_ptr_gray_sync[ADDR_WIDTH];

full_compare_ptr[ADDR_WIDTH-1] =
    ~rd_ptr_gray_sync[ADDR_WIDTH-1];

full_next =
    (wr_ptr_gray_next == full_compare_ptr);

Empty Detection

The FIFO is considered empty when the next read Gray pointer matches the synchronized write pointer:

empty_next =
    (rd_ptr_gray_next == wr_ptr_gray_sync);

⚠️ Overflow and Underflow

The FIFO provides one-cycle status pulses for invalid read/write requests.

Overflow

A write request while the FIFO is full generates:

overflow <= wr_en && full;

The write pointer does not advance and the memory write is not performed.

Underflow

A read request while the FIFO is empty generates:

underflow <= rd_en && empty;

The read pointer does not advance and the memory read is not performed.

🔐 Reset Design

Each clock domain has its own reset synchronizer.

The reset synchronizer provides:

Asynchronous reset assertion

Synchronous reset de-assertion

After local reset synchronization, the two domains exchange initialization information through the reset_handshake module.

FIFO operation is enabled only after the required local and remote initialization conditions are satisfied.

Reset behavior

During reset or initialization:

Write pointer is returned to its initial value.

Read pointer is returned to its initial value.

full is cleared.

empty is asserted.

FIFO operation is disabled.

The FIFO memory itself is not reset. Therefore, previously stored memory contents are not considered valid FIFO data after reinitialization.

🧩 RTL Modules

The current implementation contains all modules in a single Verilog source file.

Module

Description

async_fifo

Top-level FIFO

reset_sync

Reset synchronization

reset_handshake

Cross-domain reset initialization

cdc_sync

Gray-code pointer CDC synchronization

fifo_memory

Dual-clock FIFO memory

write_controller

Write pointer, full and overflow logic

read_controller

Read pointer, empty and underflow logic

🧪 Verification

The FIFO was tested using directed checks and data-integrity checking.

Final Results

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

Verification Summary

Check

Result

Directed checks

✅ 80 / 80

Data integrity

✅ 287 / 287

Overflow event mismatches

✅ 0

Underflow event mismatches

✅ 0

Total checks

✅ 367 / 367

Final verification result: ALL CHECKS PASSED.

📁 Project Structure

Async-FIFO/
│
├── README.md
│
├── rtl/
│   └── async_fifo.v
│
└── docs/
    └── async_fifo_full_architecture.svg

The current RTL is kept in a single source file. The individual modules can be separated into dedicated files later.

🛠️ Tools

Verilog HDL

RTL Simulation

GitHub

🎯 Project Focus

This project focuses on the practical RTL implementation of an asynchronous FIFO, with particular attention to:

Clock Domain Crossing → Gray-Code Pointers → Full/Empty Detection → Overflow/Underflow Handling → Reset Synchronization → Cross-Domain Reset Initialization

<div align="center">

⚡ Asynchronous FIFO • Verilog RTL • CDC • Gray Code

</div>
