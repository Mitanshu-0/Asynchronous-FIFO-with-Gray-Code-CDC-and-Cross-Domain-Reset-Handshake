# Asynchronous-FIFO-with-Gray-Code-CDC-and-Cross-Domain-Reset-Handshake
A parameterized asynchronous FIFO RTL design with independent read/write clock domains, Gray-code pointer synchronization for safe clock-domain crossing (CDC), full/empty detection, overflow/underflow protection, and coordinated cross-domain reset initialization using reset synchronizers and a reset handshake.

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

The design uses **Gray-coded read/write pointers** to safely transfer FIFO pointer information between the two clock domains.

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
