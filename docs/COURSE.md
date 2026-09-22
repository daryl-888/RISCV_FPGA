# Build a RISC-V CPU in six weeks

Build the single-cycle processor first, turn it into a five-stage pipeline, then run it on a Basys 3. Learn Verilog while writing each module. The tutor demonstrates one small change; the student types the next change, connects it, and runs the test.

Use two build labs per week, splitting each across meetings as needed. Install the tools from [SETUP.md](SETUP.md) before lab 1. `.sv` files use SystemVerilog constructs such as `logic`, `always_comb`, and `always_ff`; introduce each when it first appears.

| Week | Build labs | Working result |
|---|---|---|
| 1 | 1. Fetch; 2. Registers, ALU, decode | ADDI and register arithmetic execute |
| 2 | 3. Memory; 4. Branches and jumps | Single-cycle CPU runs the initial 14 instructions |
| 3 | 5. Complete and test the ISA; 6. Pipeline registers | Verified single-cycle baseline; pipeline runs independent instructions |
| 4 | 7. Forwarding; 8. Load-use stall | Dependent arithmetic and loads work |
| 5 | 9. Redirects and faults; 10. Compare implementations | Pipeline matches the single-cycle CPU |
| 6 | 11. Board wrapper; 12. Vivado and hardware | Switch-to-LED program runs on Basys 3 |

## Keep these design choices fixed

32-bit registers, x0 always zero, PC reset to 0, little-endian data. Separate instruction and data memories each hold 256 words. Both use byte addresses `0x000`–`0x3ff` on separate ports; only index with `[9:2]` after checking range and alignment. Reads are combinational; writes happen at the rising edge. Reset clears registers and pipeline validity, but retains memory contents.

Start with `ADD SUB AND OR XOR SLT ADDI LW SW BEQ JAL JALR LUI AUIPC`. Lab 5 expands to the 37 integer operations in [ARCHITECTURE.md](ARCHITECTURE.md). Unsupported instructions and invalid accesses fault without side effects. This is an educational RV32I subset.

## Week 1 — Fetch and execute arithmetic

### Lab 1: write the PC, instruction ROM, and first testbench

**Create:** `rtl/common/pc.sv`, `rtl/common/imem.sv`, `sim/fetch_tb.sv`.

Start by typing the PC:

```systemverilog
module pc (
    input logic clk, reset, enable,
    input logic [31:0] next_pc,
    output logic [31:0] value
);
    timeunit 1ns;
    timeprecision 1ps;
    always_ff @(posedge clk) begin
        if (reset) value <= 32'b0;
        else if (enable) value <= next_pc;
    end
endmodule
```

Explain ports while declaring them, `logic [31:0]` while choosing the width, and `<=` when storing the next PC. Connect `next_pc = value + 32'd4` in the fetch testbench. Add a 256-word ROM with a combinational output and `$readmemh` initialization. Give every module the same time unit/precision.

Load words `00500093`, `00700113`, `002081b3` at indices 0–2. The testbench generates a clock, holds reset for two rising edges, releases it at a falling edge, and checks PC/instruction pairs `(0,00500093)`, `(4,00700113)`, `(8,002081b3)`. Sample after updates settle, not in the same event region as the clocked assignments. Then hold `enable=0` and prove the PC stays fixed.

```sh
mkdir -p build/fetch
verilator --binary --timing --assert --trace -Wall \
  --top-module fetch_tb --Mdir build/fetch \
  rtl/common/pc.sv rtl/common/imem.sv sim/fetch_tb.sv
./build/fetch/Vfetch_tb
```

This command runs the files you create in this lab. Add `$dumpfile`, `$dumpvars`, a failing `$fatal` check, and a timeout by following the supplied `sim/alu_tb.sv` example.

### Lab 2: connect registers, ALU, and decode

**Create:** `regfile.sv`, `decode.sv` in `rtl/common/`; `cpu_single.sv` in `rtl/single_cycle/`; `sim/single_cycle_tb.sv`.

1. Write `logic [31:0] regs [0:31]`: two combinational read ports, one clocked write port, reset loop, x0 reads forced to zero and writes discarded.
2. Read `rtl/common/alu.sv`; implement the operations while learning `case`, `always_comb`, `$signed`, and default assignments. Run `make test` after changes.
3. Decode opcode, rs1, rs2, rd and funct fields with bit slices. Form the I immediate by sign extension.
4. Use muxes to choose rs2 or the immediate. Connect ALU output to register writeback; leave PC advancing by four.
5. Add ADDI and `ADD SUB AND OR XOR SLT`, validating their encodings. Give every combinational output a default.

**Run:** `addi x1,x0,5; addi x2,x0,7; add x3,x1,x2`. Expect x1=5, x2=7, x3=12. Attempt a write to x0. Compare −1 with +1 using SLT. Stop the testbench after the intended instructions.

Copy the fetch build command into a new Makefile target, selecting `single_cycle_tb` and listing the CPU's sources. Existing `make test` still checks the supplied ALU/converter only.

## Week 2 — Make the single-cycle CPU useful

### Lab 3: implement LW and SW

**Create:** `rtl/common/dmem.sv`; update decode and `cpu_single.sv`.

Generate I/S immediates. Calculate `rs1 + immediate`; use a combinational read and a clocked write. Add writeback selection between ALU result and memory data. Validate the full address and word alignment before enabling a write. Gate writes during reset or faults.

**Verilog in use:** arrays, concatenation, muxes, write enables, and separation of read logic from stored state.

**Run:** store 12 at data address 0, then load it into x4. Expect x4=12 while instruction word 0 remains unchanged. Address 4 must select data word 1. LW/SW at byte addresses `0x400` or `0x2` must fault, without modifying RAM.

### Lab 4: implement branches, jumps, and upper immediates

**Update:** immediate decoder, control signals, next-PC selection and writeback.

Add BEQ, JAL, JALR, LUI and AUIPC. B/J immediate wiring includes the implicit low zero. Branch/JAL targets use the executing instruction's PC; JALR uses `(rs1 + imm) & ~1`. Jumps write PC+4; LUI writes the U immediate; AUIPC writes PC plus that immediate. Check target alignment.

**Verilog in use:** bit concatenation, comparison, priority selection and shared control signals.

**Run:** taken/not-taken branches, a backward loop, a call/return, and JALR with rs1=9/imm=0 yielding target 8. Build `programs/arithmetic.S` with `make program PROGRAM=arithmetic`, load its hex, and expect x3=x4=12, x5=7 and data word 0=12. Its final JAL is a loop; the testbench decides completion.

## Week 3 — Finish the baseline, then split the datapath

### Lab 5: complete the instruction set and freeze the baseline

**Update:** ALU/control, data-memory lanes and the single-cycle testbench.

Add shifts, unsigned comparisons, remaining immediate operations and branches, then LB/LBU/LH/LHU/SB/SH. Mask shift amounts to five bits; implement signed versus unsigned results explicitly. Generate byte write masks so a partial store preserves neighboring bytes.

**Run:** the compact programs and boundary tests in [VERIFICATION.md](VERIFICATION.md). For word `80ff7f01`, LB at address 2 gives `ffffffff`, LBU gives `000000ff`, and storing byte `aa` there gives `80aa7f01`. Reject unsupported encodings and invalid memory accesses before changing state.

Add an ordered result log: instruction PC/word, destination/value, memory access and fault. Keep this tested single-cycle version available for comparison.

### Lab 6: create IF/ID, ID/EX, EX/MEM and MEM/WB

**Create:** `rtl/pipeline/cpu_pipeline.sv`, `sim/pipeline_tb.sv`; reuse common modules.

Move the single-cycle combinational work into IF, ID, EX, MEM and WB. At each boundary, register the data **and its matching controls, PC and destination**. Add a valid bit to every slot. Invalid slots cannot write registers or memory. Keep the register file in ID with writeback from WB.

**Verilog in use:** grouped clocked assignments and the fact that all registers capture old input values at an edge.

**Run:** independent ADDI instructions writing different registers. Follow one PC through all stages. Use a bounded test before adding jumps; do not yet expect dependent programs to work. Preserve asynchronous memory reads for this pipeline.

## Week 4 — Make dependencies work

### Lab 7: add forwarding

**Create:** `rtl/pipeline/forwarding.sv`; update operand selection and register-file bypass.

Compare EX source registers with older destination registers. An eligible EX/MEM ALU result wins over MEM/WB. Require valid, RegWrite and rd≠0; an EX/MEM load holds an address, so its result is unavailable there. Forward branch/JALR operands and store data too. Add WB→ID bypass for a writeback and decode reading the same register.

**Run:** `addi x1,x0,1; addi x1,x1,1; add x2,x1,x0`. Expect x2=2. Also test a producer followed by a store and a producer with two independent instructions before its consumer.

### Lab 8: add the load-use interlock

**Create:** `rtl/pipeline/hazard.sv`; add register enable/bubble controls.

When an EX load's nonzero rd matches a source actually used by ID, hold PC and IF/ID, clear ID/EX valid, and let older stages advance. Use decode's `uses_rs1/uses_rs2` flags. This baseline forwards store data in EX, so an immediately dependent store also waits once.

**Run:** initialize data word 0=9, then `lw x1,0(x0); add x2,x1,x1`. Expect one stall and x2=18. `lw x5,0(x0); addi x6,x0,5` must not stall for a false rs2 match. Check load-to-store address and data dependencies separately.

## Week 5 — Redirect safely and verify the pipeline

### Lab 9: add redirects, flushing, and ordered faults

**Update:** EX branch logic, fetch selection, pipeline validity and fault fields.

Resolve branches/jumps in EX. A taken redirect sets the next PC and invalidates both younger IF/ID and ID/EX slots. Preserve older work. Redirect wins over a younger dependency stall.

Carry faults with their instruction. A surviving MEM fault suppresses younger instructions and permits older WB to finish; report the fault in WB and halt. That older fault overrides a younger redirect. A redirect discards younger wrong-path faults. Use the exact rules in [ARCHITECTURE.md](ARCHITECTURE.md).

**Run:** a taken branch over `sw` and prove the store never writes. Repeat with a wrong-path illegal instruction. Then put an invalid older memory access before a younger jump and prove the fault wins.

### Lab 10: compare both CPUs with the same programs

**Update:** both CPU testbenches and the regression target.

Run arithmetic, memory, branches, jumps, forwarding, stalls, byte operations and faults on both CPUs. Compare ordered completed-instruction records; their cycle counts differ. Track actual MEM writes separately so a wrong-path store cannot disappear from the report. Start both with identical memory images and bound every test.

**Finish:** fix the first mismatching instruction, rerun the affected test and regression, then commit the passing pipeline. [VERIFICATION.md](VERIFICATION.md) supplies the expected values; [REFERENCE_REPO.md](REFERENCE_REPO.md) maps the existing design and its known corrections.

## Week 6 — Run the CPU on Basys 3

### Lab 11: add the board wrapper and simulate its I/O

**Create:** `rtl/soc/basys3_top.sv`, synchronizers, reset conditioning, MMIO decode and `sim/soc_tb.sv`.

Use ports `clk`, `btnC`, `sw[15:0]`, `led[15:0]`. Synchronize external inputs. Decode aligned LW/SW at `0x10000000` for the LED latch and aligned LW at `0x10000004` for synchronized switches. Gate every side effect with validity, reset and fault controls.

**Run:** build `switches_leds.S`, load the image, and change switches to `0001`, `8000`, `a55a`. The loop must eventually copy each stable value to LEDs. Reset must clear LEDs and restart the program. This also exercises load-to-store dependence.

### Lab 12: synthesize, check timing, and program

Follow [FPGA.md](FPGA.md): copy the program image to `programs/boot.hex`, source `fpga/create_project.tcl`, inspect inferred memories, synthesize, implement, check timing/constraints, generate the bitstream and program the board.

Use the 100 MHz board clock only if timing passes. If it does not, fix the path or use a properly constrained generated clock. A slow clock enable does not repair a failing 100 MHz path. Keep the first version's small memories asynchronous; block RAM requires a separate latency redesign.

**Finish:** repeat the switch patterns on the physical board, reset and repeat. Save the source commit, program image, test results, timing report and bitstream identifier in [WORKBOOK.md](WORKBOOK.md).
