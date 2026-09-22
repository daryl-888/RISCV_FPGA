# Reference processor lookup

Read [daryl-888/RISC_V at e0c2eaa4c1655d926f467a5b840f35d327e4ea81](https://github.com/daryl-888/RISC_V/tree/e0c2eaa4c1655d926f467a5b840f35d327e4ea81) after building the single-cycle baseline. Its README says it has not been simulated and has no testbench. Findings below come from source inspection, not a successful CPU simulation. No reference RTL is copied into this course.

## Files to inspect

Paths are relative to the reference repository. Stage modules own its pipeline registers.

| Topic | File(s) |
|---|---|
| Datapath | `src/riscv_top.v` |
| Fields/immediates | `src/pipeline/decode/DECODER.v` |
| Control/ALU | `src/core/CONTROL.v`, `ALU_CONTROL.v`, `ALU.v` |
| Register file/bypass | `src/pipeline/decode/REGISTER.v` |
| PC/decode stages | `src/pipeline/fetch/IF.v`, `src/pipeline/decode/ID.v` |
| Execute/redirect | `src/pipeline/execute/EX.v`, `BRANCH_JUMP.v` |
| Dependencies | `src/forward/F.v`, `src/hazard/HAZARD.v` |
| Memory | `src/memory/INSTRUCTION_MEMORY.v`, `DATA_MEMORY.v` |
| MEM/WB | `src/pipeline/memory/MEM.v`, `src/pipeline/writeback/WB.v` |
| Build | `.github/workflows/verilator-ci.yml` |

## Four concrete findings

**B/J immediates omit the low zero.** [DECODER.v](https://github.com/daryl-888/RISC_V/blob/e0c2eaa4c1655d926f467a5b840f35d327e4ea81/src/pipeline/decode/DECODER.v) produces half the intended byte displacement; the target unit adds it directly. Correct constructions:

```systemverilog
imm_b = {{19{instr[31]}}, instr[31], instr[7],
         instr[30:25], instr[11:8], 1'b0};
imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
         instr[20], instr[30:21], 1'b0};
```

`00000463` (BEQ x0,x0,+8) and `0080006f` (JAL x0,+8) must both decode to 8. Test backward/boundary offsets and the full redirect PC too.

**SLT compares unsigned vectors.** The [ALU expression](https://github.com/daryl-888/RISC_V/blob/e0c2eaa4c1655d926f467a5b840f35d327e4ea81/src/core/ALU.v) needs explicit signed operands for SLT/SLTI. With A=ffffffff and B=00000001, SLT=1 but SLTU=0. The supplied course ALU test includes this contrast.

**JALR leaves bit zero set.** [BRANCH_JUMP.v](https://github.com/daryl-888/RISC_V/blob/e0c2eaa4c1655d926f467a5b840f35d327e4ea81/src/pipeline/execute/BRANCH_JUMP.v) returns the unmasked sum; its caller does not mask it. Use `(rs1+imm_i)&32'hfffffffe`: sum 9 targets 8. Link remains instruction-local PC+4. A remaining bit one means misalignment; do not clear it. These three checks follow [RV32I semantics](https://docs.riscv.org/reference/isa/unpriv/rv32.html).

**CI references missing files.** The [workflow](https://github.com/daryl-888/RISC_V/blob/e0c2eaa4c1655d926f467a5b840f35d327e4ea81/.github/workflows/verilator-ci.yml) invokes absent `top.v`/`sim_main.cpp`; the actual top is `src/riscv_top.v`, module `RISCV_TOP`. No testbench exists. Referenced `instr.txt`/`data.txt` are also absent. Add real images and a self-checking testbench with timeout. Nested includes require `-Isrc`; do not additionally compile included leaves. Select `--top-module RISCV_TOP` for lint. Course `alu_tb` does not test this processor.

## Additional tests before reuse

- **Source use:** `lw x5,0(x0); addi x6,x0,5` has no rs2 dependency. Raw-field comparisons can add false stalls.
- **Forwarding:** require valid, RegWrite, rd≠0; exclude EX/MEM load addresses. The current interlock may mask that path, so establish a failing sequence before claiming another functional failure.
- **Encodings:** check all fixed/funct bits, including reserved shifts and R-type patterns.
- **Memory:** enforce bounds/alignment before writes; gate writes during reset and for invalid/faulted/flushed slots. Reset with a store in flight.
- **Retirement:** explicit validity must distinguish bubbles from real NOPs.
- **Board:** the inspected tree supplies no Basys 3 wrapper, pin constraints, or successful timing evidence.

The reference has 1 KiB instruction memory and 4 KiB data memory, organized as bytes. This course uses separate 1 KiB memories and defaults to 32-bit word images. Select converter `--format bytes` for byte arrays; verify the loader. Course MMIO/fault/validity/test contracts are additional design choices.

For each correction: predict a minimal test's result, demonstrate failure, fix it, and add one adjacent regression. Record measured evidence separately from source-review findings.
