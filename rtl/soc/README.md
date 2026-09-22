# Board and memory integration workspace

Add memory wrappers, MMIO decode, synchronizers, reset conditioning and `basys3_top.sv` here in week 6. The minimal top-level ports are `clk`, `btnC`, `sw[15:0]` and `led[15:0]`.

First simulate this wrapper with changing switch values. Then create the Vivado project with [the FPGA guide](../../docs/FPGA.md). Keep board-specific details out of CPU decode and ALU logic.
