Asynchronous FIFO

A parameterized Asynchronous FIFO (First-In-First-Out) implemented
in Verilog/SystemVerilog for transferring data between two independent
clock domains.

The project includes:

Gray-coded read/write pointers

2-flop clock-domain-crossing synchronizers

Independent reset synchronization

Cross-domain reset handshake

Full and empty detection

Overflow and underflow indication

Dual-clock FIFO memory

Self-checking verification testbench

Directed, corner-case, and randomized stress testing

Project Structure

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
    └── tb_async_fifo

The testbench filename can be kept with the extension used in the
repository.

Architecture



The design has two independent clock domains:

Write domain: wr_clk

Read domain: rd_clk

The write and read pointers are maintained locally and transferred to
the opposite clock domain using Gray coding and 2-flop synchronizers.

Main data flow

                    +----------------------+
                    |     async_fifo       |
                    |      top level       |
                    +----------+-----------+
                               |
              +----------------+----------------+
              |                                 |
              v                                 v
     +------------------+              +------------------+
     | Write Controller |              | Read Controller  |
     +--------+---------+              +--------+---------+
              |                                 |
        Write Pointer                      Read Pointer
        Binary + Gray                      Binary + Gray
              |                                 |
              |       2-FF CDC Synchronizers    |
              +--------------+------------------+
                             |
                             v
                    +----------------+
                    |  FIFO Memory   |
                    +----------------+

FIFO Configuration

The default parameters are:

Parameter                   Value

Data width                 8 bits
Address width              4 bits
FIFO depth             16 entries
Pointer width              5 bits
Write clock period          10 ns
Read clock period           16 ns

The FIFO depth is calculated as:

DEPTH = 2^ADDR_WIDTH
      = 2^4
      = 16

The pointer width is one bit wider than the address width:

PTR_WIDTH = ADDR_WIDTH + 1
           = 5 bits

The additional pointer bit is used to distinguish the full and empty
conditions after pointer wraparound.

RTL Modules

async_fifo.v

Top-level FIFO module.

It connects the reset logic, reset handshake, write controller, read
controller, CDC synchronizers, and FIFO memory.

reset_sync.v

Provides asynchronous reset assertion and synchronous reset de-assertion
for each clock domain.

reset_handshake.v

Coordinates initialization between the write and read domains.

Each side waits for the other domain to complete initialization before
normal FIFO operation begins.

cdc_sync.v

A 2-flop synchronizer used to transfer Gray-coded FIFO pointers between
asynchronous clock domains.

There are two CDC paths:

Read pointer  → Write clock domain
Write pointer → Read clock domain

fifo_memory.v

Implements the FIFO storage.

Writes occur on wr_clk

Reads occur on rd_clk

Write and read accesses are qualified by the FIFO control logic

write_controller.v

Handles the write side:

Write pointer generation

Binary-to-Gray conversion

Full detection

Overflow generation

Write address generation

A write is accepted only when:

wr_en = 1
full = 0
fifo_enable = 1

read_controller.v

Handles the read side:

Read pointer generation

Binary-to-Gray conversion

Empty detection

Underflow generation

Read address generation

A read is accepted only when:

rd_en = 1
empty = 0
fifo_enable = 1

Clock Domain Crossing

The FIFO does not directly pass binary pointers between clock domains.

Instead:

Binary Pointer
      |
      v
Gray Code
      |
      v
2-FF Synchronizer
      |
      v
Other Clock Domain

Gray code is used because only one bit changes between consecutive
Gray-code values. This reduces the risk of an asynchronous receiver
observing multiple pointer bits changing at the same time.

The synchronized pointers are then used for full and empty generation.

Full Detection

The write controller calculates the next write pointer.

The FIFO becomes full when the next Gray-coded write pointer matches the
synchronized read pointer with the required wrap bits inverted.

Conceptually:

next write pointer
        |
        v
   Gray conversion
        |
        v
compare with synchronized
read pointer
        |
        v
      FULL

When full is asserted, further write requests are rejected.

Empty Detection

The read controller calculates the next read pointer.

The FIFO becomes empty when:

next_read_gray == synchronized_write_gray

When empty is asserted, further read requests are rejected.

Overflow and Underflow

Overflow

An overflow event occurs when a write is requested while the FIFO is
full:

wr_en && full

The rejected write does not advance the write pointer or write new data
into the FIFO.

Underflow

An underflow event occurs when a read is requested while the FIFO is
empty:

rd_en && empty

The rejected read does not advance the read pointer.

Reset Handling

Each clock domain has its own reset synchronization.

The reset sequence is:

External Reset
      |
      v
Reset Synchronizer
      |
      v
Local Initialization
      |
      v
Cross-Domain Handshake
      |
      v
FIFO Enabled

The design supports:

simultaneous reset

independent write-side reset

independent read-side reset

skewed reset release

reset while FIFO is full

reset during active traffic

reset while data is in flight

A reset reinitializes the FIFO pointers and status so the FIFO is
logically flushed.

Verification

The testbench is self-checking and uses a queue-based reference model to
verify FIFO data ordering.

The scoreboard:

Adds a value only when the DUT actually accepts a write.

Removes the oldest expected value when the DUT accepts a read.

Compares the DUT's registered rd_data with the expected value.

Reports any data mismatch automatically.

The testbench also contains independent shadow models for overflow and
underflow event verification.

Verification Tests

The testbench contains 18 major test sections.

Test Description

   1 Simultaneous reset / initialization
   2 Single write / single read
   3 Fill FIFO to full
   4 DEPTH+1 write / overflow
   5 Drain FIFO / empty
   6 DEPTH+1 read / underflow
   7 Normal burst
   8 Pointer wraparound
   9 Writer faster / reader stopped
  10 Reader faster / writer stopped
  11 Independent write reset at half-full
  12 Independent read reset at half-full
  13 Reset while FIFO is full
  14 Reset while enables are active
  15 Skewed reset release
  16 Reset with data in flight
  17 Concurrent random stress
  18 Overflow/underflow event summary

Random Stress Test

The testbench includes concurrent randomized traffic.

The write-side stress process runs for:

600 iterations

The read-side stress process also runs for:

600 iterations

The two processes operate independently on their respective clocks.

After the random phase, the scoreboard is completely drained and the
remaining data is checked.

Verification Result

The current verified simulation produced:

===============================================
FINAL RESULTS
===============================================
Directed checks : 80 passed / 0 failed / 80 total
Data integrity  : 287 passed / 0 failed / 287 total
Overflow pulses : 111
Underflow pulses: 104
Overflow event mismatches : 0
Underflow event mismatches: 0
RESULT: ALL CHECKS PASSED (367/367)
===============================================

Summary

Category                                     Result

Directed checks                  80 / 80 passed
Data integrity checks          287 / 287 passed
Total checks                   367 / 367 passed
Data mismatches                               0
Overflow event mismatches                     0
Underflow event mismatches                    0
Overflow pulses observed                    111
Underflow pulses observed                   104

Result

ALL CHECKS PASSED --- 367/367

The implemented verification suite completed without directed-test
failures, data-integrity failures, or overflow/underflow event
mismatches.

Design Highlights

This project demonstrates several important RTL and digital-design
concepts:

Asynchronous FIFO design

Multiple independent clock domains

Clock-domain crossing

Gray-code pointer synchronization

2-flop synchronizers

FIFO full/empty detection

Overflow and underflow handling

Reset synchronization

Cross-domain reset coordination

Dual-clock memory access

Queue-based self-checking verification

Directed corner-case testing

Randomized concurrent stress testing

Future Improvements

Possible extensions to the current project include:

SystemVerilog assertions

Functional coverage

Additional randomized clock ratios

Additional constrained-random testing

CDC analysis

RTL synthesis

FPGA implementation

Timing and resource reports

Post-synthesis simulation

Formal verification of FIFO properties

Project Status

RTL: Complete

Verification: Complete for the implemented test suite

Final simulation result: 367 / 367 checks passed

Data integrity: 287 / 287 passed

Directed checks: 80 / 80 passed

Overflow/underflow event mismatches: 0

