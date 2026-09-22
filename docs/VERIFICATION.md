# Verification: earn confidence one observable result at a time

The purpose of a test is to show a specific behavior is correct and to expose a plausible mistake. A waveform that looks busy is not a passing test. A test should state its inputs, expected outputs, stopping condition, and timeout; it should fail automatically when an expectation is broken.

This guide is a test plan and acceptance specification. It does not claim that a completed CPU exists or that these tests have already run. Both implementations must meet [ARCHITECTURE.md](ARCHITECTURE.md), including its Harvard memory map, reset rules, supported-instruction milestones, and ordered fault behavior.

## 1. Build confidence in layers

| Layer | What to test | Evidence required before moving on |
|---|---|---|
| Combinational building blocks | Multiplexers, ALU, immediate generator, decoder | Self-checking boundary cases; no unintended latches; illegal encodings leave writes disabled |
| Clocked building blocks | Register file, PC enable/reset, RAM byte writes, I/O register | Checks immediately after the defined edge; masked bytes and `x0` preserved |
| Single-cycle ISA | Each enabled instruction in isolation, then short programs | Expected register/RAM state and ordered instruction trace |
| Pipeline timing | Forwarding, load-use stalls, redirects, flushes, faults | Same architectural answers plus expected cycle behavior |
| Differential execution | Single-cycle and pipeline against an independent instruction model | Matching retirement streams and store-event checks across directed and generated programs |
| FPGA implementation | Constraints, synthesized memory type, timing, reset, switch-to-LED program | Saved reports and reproducible board observations |

Do not diagnose a branch failure by rewriting the entire CPU. First check the immediate generator, comparator, forwarded operands, selected target, and flush signals. A failing small test is a useful result: it narrows the search.

## 2. Testbench conventions

Initialize all instruction and data words explicitly for deterministic simulation. Fill unused instruction locations with `0x00000000`, which this course decoder rejects, so falling off the test program fails visibly. Load data through the data-memory interface or initialization image; instruction word zero and data word zero are unrelated storage.

Drive inputs away from the active clock edge. After a rising edge, sample only after registered updates settle. Assert reset across at least two rising edges, then release it between edges. Treat data RAM as retained across reset; clear it in the test fixture only when starting a new test.

End a positive program at a known retired marker PC or with a final `jal x0, done` loop. Stop the testbench after observing the intended retirement, not after guessing a fixed delay. `EBREAK` is an unsupported-instruction fault on this platform; it is not a successful finish instruction. Every test also needs a generous cycle limit so a hung CPU fails instead of running forever.

The starter's existing `make test` command checks the supplied ALU; see [SETUP.md](SETUP.md). Later, Verilator can build a runnable CPU simulation from a SystemVerilog testbench using `--binary`; use `--timing` for a testbench that contains clock delays. For the following future CPU commands, create a testbench with top module `cpu_tb` and a `sim/cpu.f` file listing the actual testbench and RTL source paths, one per line. This avoids assuming all modules live in one directory.

```text
verilator --lint-only --timing --Wall --top-module cpu_tb -f sim/cpu.f
verilator --binary --timing --assert --trace-vcd --Wall --top-module cpu_tb -f sim/cpu.f
```

On a Linux/WSL build, the default generated executable is normally under `obj_dir/`; select the actual path reported by your build. Tool installation, shell wildcard handling, and C++ compiler setup depend on the environment. Record the installed Verilator version in the test report. The options are documented in the official [binary example](https://verilator.org/guide/latest/example_binary.html) and [command-line reference](https://verilator.org/guide/latest/exe_verilator.html).

For a VCD waveform, the testbench also needs a dump-file name and dump variables, or equivalent tracing setup in a C++ harness. Start with a small failing test to avoid an enormous trace. [Verilator tracing FAQ](https://verilator.org/guide/latest/faq.html#how-do-i-generate-waveforms-traces-in-c)

## 3. Unit tests that expose common mistakes

### ALU and comparison

| Operation and inputs | Expected 32-bit result | Mistake this detects |
|---|---|---|
| ADD `0xffffffff`, `1` | `0x00000000` | Accidental overflow fault or wrong width |
| SUB `0`, `1` | `0xffffffff` | Subtraction order or borrow handling |
| SLT `0x80000000`, `0x7fffffff` | `1` | Signed comparison implemented as unsigned |
| SLTU same inputs | `0` | Unsigned comparison implemented as signed |
| SLT `0xffffffff`, `0` | `1` | Negative-value handling |
| SLTU same inputs | `0` | Signed/unsigned confusion |
| SRA `0x80000000`, shift 1 | `0xc0000000` | Logical shift used for arithmetic shift |
| SRL same inputs | `0x40000000` | Arithmetic shift used for logical shift |
| SLL `1`, register shift 32 | `1` | Failure to mask shift amount to five bits |
| SLL `1`, register shift 31 | `0x80000000` | Highest legal shift |
| AND / OR / XOR `0xa5a5a5a5`, `0x5a5a5a5a` | `0`, `0xffffffff`, `0xffffffff` | Bitwise operation selection |

Also exercise shift counts 0 and 31, both equal operands in every comparator, and values immediately below/above signed zero. Cast operands deliberately in HDL: the bit pattern alone does not force an expression to use signed comparison.

### Immediate generator and decoder

Check I and S immediates `0`, `1`, `2047`, `-1`, and `-2048`. Check B offsets `+4`, `-4`, `+4094`, and `-4096`; check J offsets `+4`, `-4`, `+1048574`, and `-1048576`. Large offsets here test the immediate unit, not a legal fetch inside the small instruction memory. Check U fields zero, `0x12345`, and `0x80000`.

Use independently hand-checked instruction words or an assembler plus disassembly to test those fields. An encoder and decoder that share the same mistaken bit arrangement can agree with each other while both are wrong. Compare fixed fields with the [official base opcode definitions](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i) and [RV32-specific shift definitions](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv32_i).

For each supported operation, check its controls and `uses_rs1/uses_rs2`. For each rejected encoding, check the fault marker, no register write, no memory write, and no redirect. Include invalid `funct3`, invalid `funct7`, RV64-style shift encodings, `MUL`, a CSR instruction, and malformed JALR.

### Register file and memory

- Write every nonzero register and read it through both ports. Write `x0` repeatedly and confirm every read of `x0` remains zero.
- Test simultaneous WB write and ID read of the same register; ID must capture the new value via bypass.
- For each SB byte lane, change exactly one byte of a known word. For each SH position, change exactly two. Confirm SW changes all four.
- Check RAM addresses zero and `0x3fc`, byte address `0x3ff`, and halfword address `0x3fe`. Check that `0x400` faults rather than aliasing zero.
- Fetch at instruction address zero while loading data address zero with different contents. Confirm each port sees its own memory.
- Reset after changing a register, an LED, and RAM: register and LED clear, RAM remains, and PC restarts at zero.

## 4. Short programs with exact expected results

Each block is a separate program beginning at instruction address zero. Data RAM starts at zero unless stated otherwise. Numeric comments give byte PCs; all shown instructions occupy four bytes. Registers not written remain zero after reset.

### A. Arithmetic, a load-use dependency, and `x0`

```asm
# PC
addi x1, x0, 7       # 0x00
addi x2, x0, -3      # 0x04
add  x3, x1, x2      # 0x08: 4
sub  x4, x1, x2      # 0x0c: 10
slt  x5, x2, x1      # 0x10: 1
sw   x4, 0(x0)       # 0x14: data RAM word 0 = 10
lw   x6, 0(x0)       # 0x18
add  x7, x6, x3      # 0x1c: 14; one load-use stall
addi x0, x0, 123     # 0x20: discarded register write
done:
jal  x0, done        # 0x24
```

After the instruction at `0x20` retires: `x0=0`, `x1=7`, `x2=0xfffffffd`, `x3=4`, `x4=10`, `x5=1`, `x6=10`, `x7=14`, and data word zero is 10. Exactly one load-use stall occurs before this marker in the baseline pipeline. The ADD at `0x08` and the store at `0x14` also exercise forwarding.

### B. A taken branch must suppress a wrong-path store

```asm
addi x1, x0, 99      # 0x00
beq  x0, x0, taken   # 0x04
sw   x1, 0(x0)       # 0x08: must be killed
addi x2, x0, 1       # 0x0c: must be killed
taken:
addi x2, x0, 2       # 0x10
done:
jal  x0, done        # 0x14
```

After `0x10` retires, `x1=99`, `x2=2`, and data word zero is still zero. No store-bus event may occur for PC `0x08`. With the branch in EX, the store is in ID and must be invalidated. Replacing the branch with `bne x0, x0, taken` exercises the opposite decision: the store executes, and word zero becomes 99.

### C. Link addresses, JALR bit zero, and instruction-local PC

```asm
auipc x5, 0          # 0x00: x5 = 0
jal   x1, target     # 0x04: x1 = 0x08
addi  x2, x0, 99     # 0x08: killed
target:
auipc x6, 0          # 0x0c: x6 = 0x0c
addi  x3, x0, 29     # 0x10: 0x1d
jalr  x4, 0(x3)      # 0x14: target 0x1c, x4 = 0x18
sw    x2, 0(x0)      # 0x18: killed
land:
addi  x7, x0, 5      # 0x1c
done:
jal   x0, done       # 0x20
```

After `0x1c` retires: `x1=8`, `x2=0`, `x3=29`, `x4=24`, `x5=0`, `x6=12`, `x7=5`, and RAM is unchanged. Also test `jalr x3, 0(x3)` separately: target calculation must use the old/forwarded source, then replace `x3` with the link address.

### D. Byte lanes and sign extension, extended milestone

```asm
lui   x1, 0x80ff8    # 0x00
addi  x1, x1, -255   # 0x04: 0x80ff7f01
sw    x1, 0(x0)      # 0x08
lb    x2, 3(x0)      # 0x0c: 0xffffff80
lbu   x3, 3(x0)      # 0x10: 0x00000080
lh    x4, 2(x0)      # 0x14: 0xffff80ff
lhu   x5, 2(x0)      # 0x18: 0x000080ff
addi  x6, x0, 0x55   # 0x1c
sb    x6, 1(x0)      # 0x20: RAM word 0 = 0x80ff5501
sh    x6, 2(x0)      # 0x24: RAM word 0 = 0x00555501
lw    x7, 0(x0)      # 0x28: 0x00555501
done:
jal   x0, done       # 0x2c
```

Check every intermediate store event, not just the final word. Repeat loads at all byte offsets and both aligned halfword offsets. For `SLTIU`, explicitly check `sltiu x8, x0, -1` gives 1: the immediate is sign-extended before its unsigned interpretation. Check `slti x9, x0, -1` gives 0. These distinctions follow the [RV32I instruction semantics](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html).

### E. MMIO read/write rules

```asm
lui   x10, 0x10000   # MMIO base = 0x10000000
lui   x11, 0x12345
addi  x11, x11, 0x678 # x11 = 0x12345678
sw    x11, 0(x10)    # LEDs retain 0x5678
lw    x12, 0(x10)    # x12 = 0x00005678
lw    x13, 4(x10)    # synchronized switches
done:
jal   x0, done
```

Hold raw switch inputs at `0xa55a` early enough for two complete synchronizer edges before the load samples them. Expect `x13=0x0000a55a`. A switch transition on a sampling edge has no deterministic simulation expectation; schedule testbench input changes between edges.

## 5. Hazard coverage beyond the example programs

For every source operand, vary the producer distance: immediately preceding instruction, one independent instruction between them, and two independent instructions between them. These target EX/MEM forwarding, MEM/WB forwarding, and WB-to-ID bypass. Repeat with `rs1 == rs2`, `rd == rs1`, `rd == rs2`, and `rd == x0`.

| Sequence | Expected baseline behavior |
|---|---|
| `add x5,x1,x2; sub x6,x5,x3` | EX/MEM forwarding; zero stalls |
| `add x5,x1,x2; add x5,x5,x3; sub x6,x5,x4` | Newest matching producer wins |
| `add x5,x1,x2; sw x5,0(x0)` | Forward store data; zero stalls |
| `lw x5,0(x0); add x6,x5,x5` | One stall; MEM/WB forwards both operands |
| `lw x5,0(x0); sw x5,4(x0)` | One stall in this course baseline |
| `lw x5,0(x0); sw x1,0(x5)` | One stall for store address dependency |
| `lw x5,0(x0); beq x5,x0,target` | One stall, then correct comparison; taken branch adds redirect flush |
| `addi x5,x0,target_address; jalr x1,0(x5)` | Forward JALR base; zero data stalls |
| `lw x0,0(x0); add x6,x0,x0` | No load-use stall; x6 becomes zero |
| `lw x5,0(x0); lui x6,0x28` | No stall from apparent source bits in a U immediate |
| Store followed immediately by load of the same address | Load observes accepted store bytes |

For the last false-dependency example, `lui x6,0x28` places a 5 in the instruction bits that would encode rs1 in an R instruction; LUI does not use rs1. This deliberately catches a hazard unit that compares raw fields without source-use controls.

Check control priority directly by driving a valid EX redirect and a hypothetical younger stall request in a controller unit test; redirect must win. In this specific five-stage pipeline, a classic load-use request requires a load in EX, so it cannot coincide with a branch in EX. Do not claim to have exercised that impossible combination through an ordinary instruction sequence.

## 6. Fault tests must prove the absence of side effects

Every negative test has an expected fault PC/code and a known pre-fault snapshot. Verify older instructions retire, the failing instruction does not update architectural state, and every younger instruction is suppressed. The fault record is terminal and is not a successful retirement.

| Stimulus | Expected result |
|---|---|
| `lw x1,2(x0)` | `LOAD_MISALIGNED`; x1 unchanged |
| `sw x1,2(x0)` | `STORE_MISALIGNED`; all RAM bytes unchanged |
| Extended `lh x1,1(x0)` / `sh x1,1(x0)` | Load/store misalignment; no partial access |
| `lw x1,1024(x0)` / `sw x1,1024(x0)` | Load/store access fault; word zero unchanged |
| `lw x0,1024(x0)` | Load access fault despite discarded destination |
| LW/SW at `0x10000002` | Misalignment, before region/size checks |
| SW to `0x10000004` | Store access fault; switch input and LED unchanged |
| LB or SB at `0x10000000` | Access fault; MMIO accepts word accesses only |
| Taken BEQ with encoded offset +2 | Instruction misalignment attributed to branch |
| Not-taken BEQ with encoded offset +2 | No target-alignment fault; sequential execution |
| JALR sum 7 | Bit zero clears to 6; still instruction-misaligned; link unchanged |
| JALR sum 5 | Target becomes 4; aligned, no alignment fault |
| Jump to aligned `0x400` | Jump/link completes, then fetch access fault at `0x400` |
| `0x00000000`, malformed funct fields | Illegal-instruction fault |
| `0x0000000f` (FENCE), `0x00000073` (ECALL), `0x00100073` (EBREAK) | Unsupported-instruction fault |
| A recognized later-milestone instruction on the initial CPU | Unsupported-instruction fault |

The chosen fatal halt is the course execution environment. Real RISC-V systems may provide trap handlers and other access policies; the relevant alignment and load-to-`x0` semantics are in the [official RV32I specification](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html).

Use these ordering tests in addition to isolated negative cases:

```asm
addi x1, x0, 9       # 0x00: older register update must survive
sw   x1, 0(x0)       # 0x04: older store must survive
.word 0x00000000     # 0x08: deliberate illegal instruction
sw   x1, 4(x0)       # 0x0c: younger store must never happen
addi x2, x0, 77      # 0x10: younger register update must never happen
```

At halt: `x1=9`, `x2=0`, data word zero is 9, data word one is zero, and fault PC is `0x08`. Successful retirement PCs are exactly `0x00, 0x04`; next comes one terminal fault record. A `.word` directive inserts bits; it is not a CPU instruction mnemonic.

Replace the illegal instruction with `lw x2,1024(x0)` to test a fault first discovered in MEM. Place a taken branch in EX while that load is in MEM; the older load fault must win. Conversely, put an illegal word on the wrong path immediately after a taken branch; the branch flush must discard its decode fault and execution must continue at the target.

Test a fetch fault on the wrong path too: put a taken branch at instruction address `0x3fc`, with a legal target below it. Fetching sequentially at `0x400` may create a fault token, but the older taken branch must kill it. A not-taken branch at `0x3fc` must instead retire and then report the fetch fault at `0x400`.

## 7. Compare architectural traces, not simultaneous cycles

The CPUs intentionally have different timing. Compare their **ordered successful retirement records** against a small independent instruction interpreter. Retirement means an instruction has completed successfully in program order. Record branches, stores, and writes to `x0` too, even when no register changes.

Suggested normalized record:

```text
retire_order         consecutive successful retirement number
token_id             unique ID allocated to a fetched instruction; gaps allowed after flushes
pc, instruction     instruction identity
next_pc             architectural successor (target or pc + 4)
rd_we, rd, rd_value  rd_we is false for rd = 0 or no destination
mem_kind            none / load / store
mem_address         original effective byte address
mem_size            1 / 2 / 4 bytes
mem_wmask           store byte lanes, otherwise zero
mem_wdata           lane-shifted store bus data, otherwise zero
mem_rdata           value returned to the instruction after extension, otherwise zero
mmio                whether this access uses a peripheral
```

Carry store/load metadata through MEM/WB so the retirement record describes the correct instruction. Compare only fields meaningful for that instruction and normalize the rest to zero. The `next_pc` is instruction-local; never copy the speculative fetch PC into it. Record a separate terminal fault event containing code, PC, valid instruction bits if available, and fault address.

### The store happens in MEM before its WB record

In this pipeline, RAM and LED writes occur at the edge ending MEM; the store's retirement record appears one cycle later at the edge ending WB. Therefore, comparing the live hardware RAM against the interpreter after every retirement can fail even when execution is correct: a younger store may have already changed hardware RAM at that same edge.

Use two coordinated checks:

1. **Physical write monitor:** record every accepted RAM/MMIO write as `{cycle, token_id, pc, address, mask, data}`. Check it is associated with a valid, fault-free store in MEM, and save it in a queue.
2. **Retirement checker:** when that store retires, require exactly one matching queued write. Apply its bytes to the interpreter's logical memory in retirement order, and compare the store record with the interpreter's expected event.

No killed or faulting token may generate a physical write. At a completed, drained test boundary, every accepted write must have a matching successful retirement. Assert this continuously where possible, not merely by looking at final RAM: an incorrect store could be overwritten later and hide the bug. Treat reset as a new trace epoch: a store accepted before reset remains in RAM even if reset cancels its still-pending WB record. Log that boundary and retain the physically accepted RAM changes when restarting the reference model; do not incorrectly require a canceled pre-reset token to retire afterward.

For a data load, the interpreter reads its own logical memory after all older stores have retired. This produces the right instruction-order expectation even though the physical memory ran ahead. For switch reads, hold a known input pattern or provide the interpreter the sampled MMIO read value from the device model; comparing CPUs at different cycle counts against a freely changing switch input is not a deterministic test.

Compare single-cycle and pipeline traces after dropping cycle numbers and implementation-specific token IDs. Both should match the reference sequence. A mismatch report should show the last few matching PCs, the first differing field, and the relevant register/memory values. This is much easier to diagnose than a final checksum mismatch alone.

The reference model should implement instructions directly from their specification, not reuse the RTL decoder or ALU. The [RISC-V ISA manual](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html) is the semantic reference; this course's memory map and fault rules supply the platform behavior. Matching two CPUs that share a decoder bug does not establish correctness.

## 8. Assembly, generated programs, and practical coverage

Use the selected milestone's instructions deliberately. `li`, `mv`, `j`, `ret`, and `nop` are assembler conveniences, and some expand to multiple real instructions. For example, `nop` encodes `addi x0,x0,0`; `ret` normally encodes `jalr x0,0(x1)`. `call`, symbol-address construction, and linker relaxation can also change the final instruction stream. Inspect the linked disassembly, not just the source file. The official [RISC-V assembly programmer's manual](https://github.com/riscv-non-isa/riscv-asm-manual/blob/main/src/asm-manual.adoc) describes these conventions.

Select an RV32I assembler target and disable compressed instructions, but remember that RV32I assemblers still accept base instructions deliberately excluded by this course. Program and data images must each fit their separate 1 KiB memory. An ABI selection alone does not make compiler startup code compatible with this machine's reset state, MMIO, or missing trap/CSR support.

After directed tests pass, generate short bounded programs containing only supported instructions and valid addresses. Bias toward dependencies, boundary values, taken/not-taken branches, and partial stores. Keep a seed and the full disassembly for every failure. Add controlled negative programs separately so that an expected fault is not confused with a generator mistake.

Track coverage by behavior: each instruction, operand boundaries, each forwarding source, each source operand, both branch decisions, every byte mask, each fault cause, and fault/redirect ordering. A large test count without those cases is weak evidence. Full RISC-V architectural certification is outside this subset's scope.

## 9. Signals worth capturing in the waveform

| Area | Signals | What they explain |
|---|---|---|
| Clock/reset | clock, reset, halted | Whether the CPU is allowed to advance |
| Fetch | PC, fetched instruction, fetch fault | Instruction identity and speculative path |
| Pipeline identity | valid, PC, instruction, token ID in every stage | Which instruction owns a result or fault |
| Decode | uses_rs1, uses_rs2, rs1, rs2, rd, immediate, controls | Whether a dependency is real |
| EX | operand values before/after forwarding, forwarding selectors, ALU result | Operand freshness and arithmetic |
| Control flow | branch condition, redirect, target, flush, load-use stall | Priority and wrong-path suppression |
| Memory | address, size, read data, write data, byte mask, accepted write | Whether a side effect actually happened |
| WB | register write enable/index/value, retirement valid/order | Architectural completion |
| Fault control | per-stage fault marker, pending fault, terminal fault record | Older drain and younger cancellation |
| I/O | raw switches, both synchronizer stages, LED register | External-input delay and output state |

Assertions should enforce `x0 == 0`, invalid stages causing no side effects, no forwarding from a load's EX/MEM address, no memory write on an access fault, and no retirement after terminal halt. Add a watchdog for every program.

## 10. Board acceptance and the evidence to save

Before programming the FPGA, check that the chosen top-level ports match the board pins and electrical standard, the intended clock is constrained, timing meets that constraint, and inferred memory read latency matches the architecture. Save the synthesis resource report and timing report. A successful bitstream build alone does not establish correct timing.

The first board program repeatedly loads the synchronized switch word and stores it to the LED register:

```asm
lui  x10, 0x10000
loop:
lw   x11, 4(x10)
sw   x11, 0(x10)
jal  x0, loop
```

For stable switch patterns zero, all available bits one, alternating bits, and a single walking bit, the corresponding LEDs should settle to the selected pattern. On boards with fewer than 16 inputs/outputs, tie unused switch bits to zero in the wrapper and document which low LED bits are connected. Check reset both at startup and while the program runs. A loop will quickly overwrite the reset LED value, so observe the reset state while reset remains asserted or through an internal probe.

Then run a RAM checksum/signature program and expose pass/fail through LEDs or a debug probe. State the expected signature in the test report. If the design works only at a much lower clock, investigate the timing report and constraints before calling it complete.

For each milestone, retain a compact record with tool versions, selected ISA milestone, test names/seeds, pass/fail counts, first failing trace if any, FPGA part, clock constraint, timing result, memory implementation, and observed board patterns. Label simulation results and hardware observations separately. The course is complete when the student can reproduce the evidence and explain one failure they diagnosed from it.

## Primary sources

- [RISC-V RV32I specification, version 2.1, pinned 2024 edition](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html): architectural behavior and exception rules.
- [Official RISC-V opcode definitions](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i) and [RV32 definitions](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv32_i): independent encoding checks.
- [RISC-V assembly programmer's manual](https://github.com/riscv-non-isa/riscv-asm-manual/blob/main/src/asm-manual.adoc): assembler syntax and pseudoinstructions.
- [Verilator executable example](https://verilator.org/guide/latest/example_binary.html): building a SystemVerilog testbench executable.
- [Verilator command-line reference](https://verilator.org/guide/latest/exe_verilator.html): lint, timing, assertions, and trace options.
- [Verilator tracing FAQ](https://verilator.org/guide/latest/faq.html): waveform setup.
