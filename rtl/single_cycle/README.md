# Single-cycle implementation workspace

Add your CPU here during weeks 2–3. Keep reusable leaf modules in `rtl/common/`.
Follow the interface and behavior in [the architecture contract](../../docs/ARCHITECTURE.md).
Add `sim/single_cycle_tb.sv` and a dedicated simulation target before claiming this stage works.

Suggested construction order: register file → immediate decoder → control decoder → PC and operand muxes → ALU integration → instruction memory → data memory → jump/branch logic → faults → retirement trace.
