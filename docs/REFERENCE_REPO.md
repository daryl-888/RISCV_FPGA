# Reading the reference processor

Reference: [daryl-888/RISC_V](https://github.com/daryl-888/RISC_V), inspected at [commit e0c2eaa4c1655d926f467a5b840f35d327e4ea81](https://github.com/daryl-888/RISC_V/tree/e0c2eaa4c1655d926f467a5b840f35d327e4ea81).

Use this as a concrete design to read and question after building your own single-cycle baseline. The reference README explicitly says it has not been simulated and has no testbench. That honesty is useful: students should learn to separate an intended design from measured evidence. This reading review is based on source inspection, not a successful simulation of the reference CPU.

## Read in this order

| Lesson topic | Reference file | What to draw or explain |
|---|---|---|
| Whole datapath | `src/riscv_top.v` | Mark IF/ID, ID/EX, EX/MEM, MEM/WB and feedback paths |
| Instruction fields | `src/pipeline/decode/DECODER.v` | Reconstruct each immediate from instruction bits |
| Control | `src/core/CONTROL.v`, `ALU_CONTROL.v` | Follow one ADD, LW, SW, BEQ and JALR |
| Arithmetic | `src/core/ALU.v` | Explain signed versus unsigned comparisons and shifts |
| Register state | `src/pipeline/decode/REGISTER.v` | Show x0 protection and WB-to-ID bypass |
| PC and fetch | `src/pipeline/fetch/IF.v` | Explain reset, hold and redirect priority |
| Decode register | `src/pipeline/decode/ID.v` | Identify every control field that becomes a bubble |
| Execute and redirect | `src/pipeline/execute/EX.v`, `BRANCH_JUMP.v` | Separate target address from link value PC+4 |
| Dependencies | `src/forward/F.v`, `src/hazard/HAZARD.v` | Trace forwarding priority and one load-use stall |
| Memory | `src/memory/INSTRUCTION_MEMORY.v`, `DATA_MEMORY.v` | Explain byte addressing, little endian and async reads |
| Final result | `src/pipeline/memory/MEM.v`, `writeback/WB.v` | Follow load data into register-file writeback |
| Automation | `.github/workflows/verilator-ci.yml` | Check that every referenced file actually exists |

Paths above are relative to the reference repository, not this course repository. Its stage modules own the pipeline registers. Other organizations are valid if the timing and control contract stay explicit.

## Concrete corrections to investigate

### 1. B/J immediates need their implicit low zero

In [DECODER.v](https://github.com/daryl-888/RISC_V/blob/e0c2eaa4c1655d926f467a5b840f35d327e4ea81/src/pipeline/decode/DECODER.v), the B and J concatenations omit the low `1'b0`. The target unit then adds that value directly, so a +8-byte branch displacement is decoded as +4. A +8-byte JAL has the same problem. The correct byte-displacement constructions are:

```systemverilog
imm_b = {{19{instr[31]}}, instr[31], instr[7],
         instr[30:25], instr[11:8], 1'b0};
imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
         instr[20], instr[30:21], 1'b0};
```

Exercise: decode `00000463` (BEQ x0,x0,+8) and `0080006f` (JAL x0,+8); both must produce immediate 8. Add backward displacements and boundary values. Verify the full redirect PC in a CPU test, not only the decoder output. RISC-V describes these as offsets in multiples of two bytes. [RV32I specification](https://docs.riscv.org/reference/isa/unpriv/rv32.html)

### 2. SLT must compare signed operands

The [ALU SLT expression](https://github.com/daryl-888/RISC_V/blob/e0c2eaa4c1655d926f467a5b840f35d327e4ea81/src/core/ALU.v) compares unsigned input vectors directly. With A=`ffffffff` and B=`00000001`, signed SLT must return 1, while unsigned SLTU must return 0. Use explicit signed casts for SLT/SLTI, and preserve the unsigned comparison for SLTU/SLTIU. The supplied course ALU test includes this exact contrast. [RV32I comparisons](https://docs.riscv.org/reference/isa/unpriv/rv32.html)

### 3. JALR clears target bit zero

[BRANCH_JUMP.v](https://github.com/daryl-888/RISC_V/blob/e0c2eaa4c1655d926f467a5b840f35d327e4ea81/src/pipeline/execute/BRANCH_JUMP.v) returns a direct base-plus-offset sum; the caller does not clear bit zero. For JALR, compute `(rs1 + imm_i) & 32'hfffffffe`. With rs1=9 and imm=0, target=8. The link result still uses that instruction's PC+4. Without compressed instructions, target bit 1 remaining set is a separate instruction-address-misalignment case; do not clear both low bits to hide it. [RV32I jumps](https://docs.riscv.org/reference/isa/unpriv/rv32.html)

### 4. The simulation workflow cannot run as written

The [workflow](https://github.com/daryl-888/RISC_V/blob/e0c2eaa4c1655d926f467a5b840f35d327e4ea81/.github/workflows/verilator-ci.yml) invokes `top.v` and `sim_main.cpp`, but neither file exists in the inspected tree. The actual top file is `src/riscv_top.v`, module `RISCV_TOP`. There is no testbench in the tree. The memory modules also reference `instr.txt` and `data.txt`, which are absent.

First make a standalone leaf test pass. Then add real program images and a self-checking top testbench with a timeout. The reference uses nested Verilog includes: compile its top with `-Isrc` and avoid also listing all included leaves, which could define modules twice. Explicitly select `--top-module RISCV_TOP` when linting that design. Do not assume the course's `alu_tb` target tests the reference processor.

## Design gaps to cover with tests

- **Source-use flags:** the hazard unit compares raw rs1/rs2 fields without opcode-specific use flags. For example, `lw x5,0(x0); addi x6,x0,5` should not stall for an rs2 dependency: those five bits belong to the immediate. Spurious stalls affect performance even if arithmetic results remain correct.
- **Forwarding validity:** explicitly require `RegWrite`, rd≠0 and a valid slot. A load in EX/MEM holds an effective address, not its completed load result; forbid that address as a completed result. The current interlock may mask that path for ordinary true dependencies, so demonstrate the interaction before calling it a separate observed functional failure.
- **Illegal encodings:** decoding only an opcode or a subset of funct bits can admit unsupported instructions. Test the entire accepted encoding, including reserved shift and R-type patterns.
- **Bounds/alignment:** reference memory arrays use computed indices without the course's documented bounds/alignment fault contract. Check accesses before any write.
- **Reset and side effects:** memory writes must be gated during reset and for invalid/faulted/flushed slots. Assert reset with a store in flight and prove no accidental write occurs.
- **Trace validity:** cleared controls and an architectural NOP are different concepts. Add explicit validity for counting and comparing real instruction retirement.
- **FPGA integration:** the inspected tree has no Basys 3 I/O wrapper, pin constraints or successful timing evidence. Those are independent deliverables.

## Differences chosen for this course

The reference instruction memory holds 1 KiB of bytes; its data memory holds 4 KiB. This course deliberately starts with separate 1 KiB instruction and 1 KiB data memories. The reference reads byte arrays; the starter image converter defaults to **32-bit word lines** for the course word arrays. Use `--format bytes` for an 8-bit array and verify the loader. Never reuse a memory image based only on its filename.

The course also adds a defined MMIO map, explicit faults, validity, self-checking tests and tutor/student materials. Those are teaching choices, not claims about features already present in the reference. No reference RTL is copied into this repository.

## Tutor debugging exercise

Ask the student to choose one finding and submit:

1. The architectural rule in their own words.
2. A minimal input or program that distinguishes correct from incorrect behavior.
3. A predicted waveform and expected result before running it.
4. A failing assertion on the original behavior.
5. A small correction and the passing result.
6. One adjacent regression test and a short explanation of what it protects.

Keep fixes in your own learning branch. Do not replace a source review with untested assertions that the whole CPU works.
