# Single-cycle implementation workspace

Build your CPU here in labs 1–5. Keep reusable leaf modules in `rtl/common/`.
Follow the interface and behavior in [the architecture contract](../../docs/ARCHITECTURE.md).
Add `sim/single_cycle_tb.sv` and a dedicated simulation target before claiming this stage works.

Construction order: PC and instruction memory → register file, ALU and decode → arithmetic execution → data memory → branches/jumps → remaining instructions and faults → result trace.
