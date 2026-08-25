<div align="center">

⚡ Asynchronous FIFO

Gray-Code CDC & Cross-Domain Reset Handshake

<p>
  <img src="https://img.shields.io/badge/HDL-Verilog-1e88e5?style=for-the-badge">
  <img src="https://img.shields.io/badge/Design-Asynchronous%20FIFO-7b1fa2?style=for-the-badge">
  <img src="https://img.shields.io/badge/CDC-2--FF%20Synchronizer-f57c00?style=for-the-badge">
  <img src="https://img.shields.io/badge/Verification-367%2F367%20Passed-2e7d32?style=for-the-badge">
</p>

<p>
  <b>A parameterized Verilog RTL implementation of an asynchronous FIFO with independent clock domains, Gray-coded pointer synchronization, and coordinated reset initialization.</b>
</p>

</div>

🏗️ Architecture

The FIFO is divided into two independent clock domains:

Write clock domain

Read clock domain

The complete architecture is shown below.

<p align="center">
  <img src="docs/async_fifo_full_architecture.svg" alt="Asynchronous FIFO Architecture" width="900">
</p>

📌 About the Design

This project implements an Asynchronous FIFO (First-In, First-Out) using Verilog RTL.

The write and read sides operate with independent clocks. The FIFO uses binary pointers internally and converts them to Gray code before transferring pointer information across the clock domains.

A 2-flop synchronizer is used for pointer CDC. Each clock domain also has its own reset synchronizer, and a cross-domain reset handshake coordinates FIFO initialization before normal FIFO operation begins.

The design provides:

Full and empty detection

Overflow and underflow indication

Parameterized data width

Parameterized FIFO depth

Independent write and read clocks

Dual-clock FIFO memory

⚙️ Parameters

Parameter

Default

Description

DATA_WIDTH

8

Width of each FIFO data word

ADDR_WIDTH

4

Address width

FIFO_DEPTH

16

FIFO depth (2^ADDR_WIDTH)

PTR_WIDTH

5

Pointer width (ADDR_WIDTH + 1)

Default configuration

Data width   : 8 bits
FIFO depth   : 16 entries
Address      : 4 bits
Pointer      : 5 bits

The additional pointer bit is used to distinguish full and empty conditions when the pointers wrap around.

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

Write enable

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

Read enable

rd_data

Output

Data read from FIFO

empty

Output

FIFO empty indication

underflow

Output

Read attempted while FIFO was empty

🔄 How the FIFO Works

Write path

A write is accepted when:

wr_en && !full && wr_fifo_enable

When accepted, data is written into the FIFO memory and the write pointer advances.

The write pointer is maintained in binary and Gray-code form. The Gray-coded pointer is then synchronized into the read clock domain.

Read path

A read is accepted when:

rd_en && !empty && rd_fifo_enable

When accepted, data is read from the FIFO memory and the read pointer advances.

The Gray-coded read pointer is synchronized into the write clock domain.

🔀 Clock Domain Crossing

The two clocks are asynchronous, so the pointer values are not transferred directly as binary counters.

The pointer transfer follows:

Binary Pointer
      ↓
Gray Code
      ↓
2-FF Synchronizer
      ↓
Destination Clock Domain

Write pointer → Read domain

wr_ptr_bin → wr_ptr_gray → 2-FF synchronizer → wr_ptr_gray_sync

Read pointer → Write domain

rd_ptr_bin → rd_ptr_gray → 2-FF synchronizer → rd_ptr_gray_sync

Gray code is used so that consecutive pointer values differ by one bit during normal pointer movement.

🚦 Full & Empty Detection

Full

The write controller compares the next write Gray pointer with the synchronized read pointer after inverting the two most significant bits.

full_compare_ptr = rd_ptr_gray_sync;

full_compare_ptr[ADDR_WIDTH] =
    ~rd_ptr_gray_sync[ADDR_WIDTH];

full_compare_ptr[ADDR_WIDTH-1] =
    ~rd_ptr_gray_sync[ADDR_WIDTH-1];

full_next =
    (wr_ptr_gray_next == full_compare_ptr);

Empty

The read controller compares the next read Gray pointer with the synchronized write pointer.

empty_next =
    (rd_ptr_gray_next == wr_ptr_gray_sync);

⚠️ Overflow & Underflow

Overflow

An overflow pulse is generated when a write is requested while the FIFO is full:

overflow <= wr_en && full;

The write is not accepted.

Underflow

An underflow pulse is generated when a read is requested while the FIFO is empty:

underflow <= rd_en && empty;

The read is not accepted.

🔐 Reset & Initialization

Each clock domain has its own reset synchronizer implementing:

Asynchronous reset assertion

Synchronous reset de-assertion

After the local reset is synchronized, the two domains exchange initialization and ready information through the reset handshake.

FIFO operation is enabled only after the required local and remote initialization conditions are satisfied.

During reset/reinitialization:

Write pointer returns to its initial value

Read pointer returns to its initial value

full is cleared

empty is asserted

FIFO operation is disabled

The FIFO memory itself is not reset. Therefore, previously stored memory contents are not considered valid FIFO data after reinitialization.

🧩 RTL Modules

The current implementation keeps the complete design in one Verilog source file.

Module

Purpose

async_fifo

Top-level FIFO and module interconnection

reset_sync

Reset synchronization for each clock domain

reset_handshake

Cross-domain initialization handshake

cdc_sync

2-flop synchronization of Gray-coded pointers

fifo_memory

Dual-clock FIFO storage

write_controller

Write pointer, full and overflow logic

read_controller

Read pointer, empty and underflow logic

🧪 Verification

The FIFO was verified using directed checks and data-integrity checking.

Final simulation result

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

Result Summary

Check

Result

Directed checks

80 / 80 passed

Data integrity

287 / 287 passed

Overflow event mismatches

0

Underflow event mismatches

0

Total checks

367 / 367 passed

Verification result: ALL CHECKS PASSED ✅

📁 Repository Structure

Async-FIFO/
│
├── README.md
│
├── rtl/
│   └── async_fifo.v
│
└── docs/
    └── async_fifo_full_architecture.svg

The current version keeps all RTL modules in a single source file. The modules can be separated into individual files later for easier maintenance and reuse.

🛠️ Tools

Verilog HDL

RTL Simulation

GitHub

🎯 Project Focus

The main focus of this project is implementing and verifying an asynchronous FIFO while handling the important issues that come with independent clock domains:

Gray-code pointer transfer → CDC synchronization → Full/empty detection → Overflow/underflow handling → Reset synchronization → Cross-domain initialization

<div align="center">

⚡ Asynchronous FIFO • Verilog RTL • CDC • Gray Code

</div>
