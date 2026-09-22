# RISC-V: From Gates to FPGA

A six-week intensive course for a first-year engineering student, with a preparation path for the returning tutor.

**Route:** digital logic → a small single-cycle processor → a five-stage pipeline → execution on a Basys 3 FPGA.

**Pace:** four 90-minute meetings and 4–6 hours of guided independent work each week: six contact hours and ten to twelve total learner hours weekly. Budget the tutor's preparation separately, initially 1–2 hours per session. The same sequence works independently: repeat a lab until its mastery gate passes, then move on. Six weeks is an intensive planning estimate, not a deadline for understanding; extend the calendar when a gate needs more practice.

This is a curriculum and implementation specification. It does not contain a completed processor or claim that a processor has passed verification. The reference is [daryl-888/RISC_V](https://github.com/daryl-888/RISC_V), examined at commit `e0c2eaa4c1655d926f467a5b840f35d327e4ea81`; its README states that simulation and a testbench have not yet been added. Treat it as material to inspect, not a verified implementation. Waveform names below are conceptual aliases to map during repository orientation.

## Navigation

- [Starting point and learning contract](#starting-point-and-learning-contract)
- [The processor we will build](#the-processor-we-will-build)
- [Evidence and mastery gates](#evidence-and-mastery-gates)
- [Weeks 1–2: single-cycle foundations](#weeks-12-single-cycle-foundations)
- [Weeks 3–4: verification and pipelining](#weeks-34-verification-and-pipelining)
- [Weeks 5–6: complete the teaching subset and reach hardware](#weeks-56-complete-the-teaching-subset-and-reach-hardware)
- [Practice plan](#practice-plan)
- [Official references](#official-references)

Use [WORKBOOK.md](WORKBOOK.md) for predictions and evidence. Instructors should prepare with [INSTRUCTOR.md](INSTRUCTOR.md), which contains solutions and worked examples.

## Starting point and learning contract

You need ordinary algebra, comfort following a short procedure, and willingness to draw boxes and arrows. Prior assembly, electronics, Verilog, or computer architecture courses are not required. Sessions 1–4 explicitly teach the missing foundations. If hexadecimal and edge-triggered state are already comfortable, demonstrate their exit tickets and spend the recovered time testing.

By the end, you should be able to:

1. Predict an instruction's changes to registers, memory, and the program counter.
2. Explain those changes using actual datapath and control signals.
3. Build a small single-cycle design and test boundary cases.
4. Transform it into a pipeline with forwarding, stalls, and flushes.
5. Explain why two implementations can have identical results and different timing.
6. Distinguish simulated behavior from synthesis, timing closure, and board execution.
7. Demonstrate an MMIO program on the FPGA with reproducible evidence.

Every lab follows **predict → run → inspect → explain**. A green test alone is incomplete evidence. A waveform without an expected result is also incomplete. Keep the shortest program that reproduces a failure, record the first incorrect architectural event, and change one plausible cause at a time.

Verilator translates supported HDL into an executable simulation model. With tracing enabled, that model can produce waveform data. Compiling a simulation does not configure an FPGA. See the [official Verilator overview](https://verilator.org/guide/latest/overview.html).

Vivado synthesis maps RTL into hardware structures; implementation places and routes them; timing analysis checks the specified timing requirements. A bitstream configures the FPGA. A program image is instruction data for the processor inside that hardware. The bitstream and program image are different things, even when an initialized program image is packaged into the bitstream.

## The processor we will build

These are course choices. They deliberately limit scope so that each result is explainable.

| Item | Teaching contract |
|---|---|
| Architectural width | 32-bit registers, addresses, and instruction words; little-endian data |
| Registers | x0 reads as zero and ignores writes; x1–x31 are ordinary registers |
| Reset | CPU-facing synchronous active-high reset makes PC and x1–x31 zero; pipeline valid bits, fault/halt state, and LED latch clear |
| Initial state | Instruction/data arrays retain contents across CPU reset; tests load their instruction image and initialize any RAM location before reading it |
| Instruction memory | Separate 256 × 32 read-only array; byte addresses 0x00000000–0x000003FF; aligned words through 0x000003FC |
| Data memory | Separate 256 × 32 array on the data port; same byte-address range; writes occur on a clock edge |
| Instruction/data relationship | The arrays are distinct even when their numeric addresses match; a store cannot modify instruction memory |
| Memory timing | Asynchronous reads, synchronous writes for the single-cycle and first pipeline designs |
| LED MMIO | Aligned LW/SW at 0x10000000; low 16 bits drive LEDs; reads zero-extend the stored bits |
| Switch MMIO | Aligned LW at 0x10000004 reads zero-extended synchronized switches; stores and subword accesses fault |
| Pipeline | IF, ID, EX, MEM, WB; branch/jump redirection in EX; valid bits distinguish instructions from bubbles |
| Hazards | Forward from EX/MEM except loads, and from MEM/WB; WB→ID bypass; one immediate load-use bubble under this memory model |
| Excluded | Caches, virtual memory, operating systems, interrupts, privilege modes, compressed instructions, multiply/divide, atomics |

The first instruction set is **ADD, SUB, AND, OR, XOR, SLT, ADDI, LW, SW, BEQ, JAL, JALR, LUI, AUIPC**. Build these fourteen first. Later add the remaining twenty-three integer compute, load, store, branch, and jump instructions, making thirty-seven:

| Family | Final instruction set |
|---|---|
| Register arithmetic/logic | ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND |
| Immediate arithmetic/logic | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI |
| Loads | LB, LH, LW, LBU, LHU |
| Stores | SB, SH, SW |
| Branches | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| Control transfer | JAL, JALR |
| Upper immediate | LUI, AUIPC |

FENCE, ECALL, and EBREAK all produce the course's `UNSUPPORTED_INSTRUCTION` fault and halt; none is silently accepted or treated as a no-op. Invalid encodings, unsupported operations, out-of-range accesses, and misalignment produce a documented fault/halt event without the invalid operation changing state. In the final pipeline, fault tokens drain in order: detected faults travel with the instruction, MEM selects the surviving stop boundary and suppresses younger work, older WB work completes, and the stop is published at WB. An EX redirect squashes younger fetch/decode faults; an older MEM fault outranks an EX redirect. Teach basic side-effect suppression first and finish this age ordering at the final gate. These are course debug events, not privileged traps or a claim of full platform compliance. [ARCHITECTURE.md](ARCHITECTURE.md) defines the complete contract.

Do not silently alias invalid addresses by dropping their high bits. For aligned word access, validate the full address and then use bits [9:2] to index 256 words. Later subword accesses select lanes with bits [1:0]. A four-byte instruction requires four-byte alignment in this course. Check a branch target when the branch is taken. JALR clears target bit 0; that does not guarantee four-byte alignment. Attribute a misaligned target to its branch/jump; an aligned out-of-range target faults on the subsequent fetch.

The tiny asynchronous-read memories are intended for distributed ROM/RAM or logic in this first FPGA version. Replacing them with synchronous-read block RAM changes the timing contract and requires redesign. Do not treat it as a harmless synthesis option.

### Waveform vocabulary

Use aliases such as `pc`, `instr`, `rs1`, `rs2`, `rd`, `alu_result`, `reg_write`, `mem_write`, `mem_addr`, `mem_rdata`, `mem_wdata`, and `halted`. Pipeline aliases add `if_id_valid`, `id_ex_valid`, `ex_mem_valid`, `mem_wb_valid`, stage PCs, `stall`, `redirect`, `forward_a`, and `forward_b`.

Names do not imply that signals already exist. Before tracing, map each alias to the design or add an observation port. Interpret a cycle as the interval between active rising edges; state captured at an edge becomes visible just afterward. Label screenshots with edge numbers so pre-edge and post-edge values cannot be confused.

## Evidence and mastery gates

| Gate | After | Required demonstration |
|---|---|---|
| G0: bits and state | Session 4 | Explain signed/unsigned values, predict a mux and register, read a clocked waveform |
| G1: one instruction | Session 8 | Trace ADDI, ADD, and LW through the single-cycle datapath; prove x0 stays zero |
| G2: single-cycle baseline | Session 12 | Fourteen-instruction directed suite, wrong-path prevention, invalid-access test, reproducible program image |
| G3: pipeline correctness | Session 18 | Dependency, load-use, branch-flush, store-data, x0, and WB→ID tests with matching architectural results |
| G4: extended instruction set | Session 20 | Thirty-seven-instruction coverage matrix, byte-lane tests, signed boundaries, stop/fault tests |
| G5: hardware | Session 24 | Reproducible build, passing constraints/timing review, live MMIO demonstration, individual explanation |

A gate passes when another person can repeat the result from the recorded inputs. If it fails, preserve the failure and repeat only the missing skill. Do not compensate for a broken dependency test with a more elaborate demonstration program.

## Weeks 1–2: single-cycle foundations

### Session 1 — Bits are patterns before they are numbers

**Objective:** convert between 8-bit binary and hexadecimal and interpret one pattern as signed and unsigned without guessing.

- **0–10, refresher:** place value and powers of two; build the values 1, 2, 4, 8, 16, 32, 64, 128.
- **10–25, explain:** group bits into nibbles; show two's-complement negation and fixed-width wraparound using an 8-bit number line.
- **25–40, demonstrate:** work 0x7F + 1 and 0xFF + 1; separate the stored pattern from its mathematical interpretation.
- **40–75, build:** complete six conversion exercises, then a small combinational addition experiment with fixed-width inputs.
- **75–85, check:** observe `a=0x7F`, `b=1`, and an 8-bit result of 0x80; reinterpret the same trace as unsigned and signed.
- **85–90, exit:** explain why 0xFF can mean 255 or −1.

**Exercise and success:** predict 0xFE + 3 before running; the stored 8-bit result is 0x01 and the explanation mentions discarded carry. **Common misunderstanding:** a leading 1 always means a negative number; it does only under a signed interpretation.

### Session 2 — Gates, muxes, and a first ALU

**Objective:** construct a truth table and make a selector choose between two 32-bit operations.

- **0–10, refresher:** bitwise AND, OR, and XOR on four-bit patterns.
- **10–25, explain:** contrast bitwise operations with Boolean decisions; draw a mux as “choose this complete bus.”
- **25–40, demonstrate:** change a mux input without changing its select, then change the select.
- **40–75, build:** implement AND, OR, XOR, and ADD in a combinational ALU; define defaults for every output.
- **75–85, check:** hold `a=0xA`, `b=0xC`; observe operation-dependent results and immediate combinational response between clock edges.
- **85–90, exit:** identify which signal determines the chosen operation.

**Exercise and success:** add SUB and test equal operands, zero, and wraparound; explain all results without clocking the ALU. **Common misunderstanding:** combinational logic “runs once per clock.” Its outputs follow inputs after propagation delay; state elements provide the clock boundary.

### Session 3 — Registers, reset, and synchronous state

**Objective:** distinguish combinational next-state logic from edge-triggered stored state and predict enabled-register behavior.

- **0–10, refresher:** review the mux and the idea of remembering a value.
- **10–25, explain:** draw `q_next → register → q`; discuss clock, enable, reset priority, and nonblocking assignments for clocked RTL.
- **25–40, demonstrate:** change `d` between edges and show that `q` remains fixed.
- **40–75, build:** make a 32-bit enabled register and a PC that resets to zero and increments by four when enabled.
- **75–85, check:** record `clk`, `reset`, `enable`, `pc`, and next PC for reset, advance, hold, and resume.
- **85–90, exit:** predict the next three PC values from an enable sequence.

**Exercise and success:** hold enable low for two edges and prove the PC is unchanged; releasing it advances exactly once per enabled edge. **Common misunderstanding:** reset is initialization of every design resource. Each state element needs its own documented reset or initialization policy.

### Session 4 — Make a simulation tell the truth

**Objective:** run a repeatable Verilator test with explicit expected values, a timeout, and a useful waveform.

- **0–10, refresher:** distinguish source code, executable program, and observed output.
- **10–25, explain:** model time, clock stimulus, evaluation, trace recording, assertions, and successful versus failed test exit status.
- **25–40, demonstrate:** run an intentionally incorrect PC expectation; locate the first failing edge.
- **40–75, build:** test reset, increment, and hold; initialize every driven input; make the test fail if it never finishes.
- **75–85, check:** show the failing assertion, then repair the expectation or design for a stated reason and rerun.
- **85–90, exit:** say what the simulation proves and what it cannot prove about an FPGA.

**Exercise and success:** a deliberate one-cycle error causes a non-success result and a trace that identifies it. **Common misunderstanding:** no error messages means a design is correct; a test that never checks a result can pass uselessly. Complete G0 and save the smallest working simulation as a known-good example.

### Session 5 — Instructions are structured bit patterns

**Objective:** identify opcode, register fields, and immediate fields in an instruction word and distinguish encoding from execution.

- **0–10, refresher:** slice a 32-bit bus into numbered fields.
- **10–25, explain:** introduce assembly notation and R, I, S, B, U, and J layouts; distinguish a register number from its contents.
- **25–40, demonstrate:** decode `addi x1,x0,5`; trace its immediate through sign extension.
- **40–75, build:** make a field decoder and immediate generator, first for I and S, then B, U, and J forms.
- **75–85, check:** observe an ADDI immediate of −1 become 0xFFFFFFFF; inspect a negative branch offset and its implicit low zero bit.
- **85–90, exit:** explain why an instruction's `rd=5` does not mean “write the number five.”

**Exercise and success:** hand-decode two instructions and independently compare with an assembler/disassembly listing. **Common misunderstanding:** the immediate is always one contiguous signed field; the layouts rearrange bits, and U-type construction differs from sign-extending twelve bits.

### Session 6 — A register file and exact ALU behavior

**Objective:** read two registers, write one, preserve x0, and distinguish signed comparison from subtraction's sign bit.

- **0–10, refresher:** revisit 0xFFFFFFFF as signed −1 and unsigned 4,294,967,295.
- **10–25, explain:** draw the two-read, one-write register file and its x0 override; explain signed casts at comparison points.
- **25–40, demonstrate:** attempt a write to x0, then read it alongside an ordinary register.
- **40–75, build:** add register-file tests and SLT tests with opposite-sign operands; connect register reads to the ALU.
- **75–85, check:** see writes take effect after the edge, x0 remain zero, and SLT report a full 32-bit 0 or 1.
- **85–90, exit:** explain why “take subtraction's top bit” is insufficient for every signed comparison.

**Exercise and success:** compare 0x80000000 against 1 and reverse the operands; both results match signed arithmetic. **Common misunderstanding:** every bit vector carries the intended signedness automatically; expression rules must be deliberate.

### Session 7 — The first complete single-cycle datapath

**Objective:** execute ADDI and register ALU instructions from PC=0 with exactly one intended register update per instruction.

- **0–10, refresher:** identify state and combinational blocks on a diagram.
- **10–25, explain:** connect PC, instruction memory, decoder, register file, ALU, and writeback mux.
- **25–40, demonstrate:** follow an ADDI's values before the edge and its PC/register changes afterward.
- **40–75, build:** load a short program that writes x1=5, x2=7, and x3=x1+x2; run with reset and a bounded cycle count.
- **75–85, check:** observe PCs 0, 4, 8, register destination numbers, ALU operands, and writeback data 5, 7, 12.
- **85–90, exit:** name every state element changed by the ADD at PC=8.

**Exercise and success:** replace ADD with SUB and predict the changed result before rerunning. **Common misunderstanding:** a single-cycle processor completes combinational work instantaneously; it needs a clock period long enough for its longest path.

### Session 8 — Loads, stores, and byte addresses

**Objective:** execute aligned LW/SW and explain why byte address 12 selects word index 3.

- **0–10, refresher:** divide a byte address into word index and byte offset.
- **10–25, explain:** calculate the effective address as register plus signed immediate; distinguish data-memory address from instruction PC.
- **25–40, demonstrate:** store 42 to data byte address 12 and then load it; show separate instruction/data arrays.
- **40–75, build:** add load writeback and store write enable, full address validation, and misaligned-word rejection.
- **75–85, check:** `mem_addr=12`, word index 3, store enable at its edge, and later load/writeback data 42; inspect a rejected address of 13.
- **85–90, exit:** explain why a store to data address 0 does not replace the instruction at PC=0.

**Exercise and success:** verify adjacent words retain different values and a rejected store changes neither. **Common misunderstanding:** masking an address creates a valid address; it can instead hide an out-of-range access. Complete G1.

## Weeks 3–4: verification and pipelining

### Session 9 — Branches change the next instruction

**Objective:** implement BEQ and demonstrate both a taken and a not-taken branch.

- **0–10, refresher:** distinguish the current PC from PC+4.
- **10–25, explain:** compute a branch target from the branch instruction's PC and signed offset; select it only when the condition holds.
- **25–40, demonstrate:** use one branch to skip a register write, then change an operand to make it fall through.
- **40–75, build:** implement equality comparison and next-PC control; add forward and backward branch tests.
- **75–85, check:** observe `branch_taken`, target, and PC; the skipped instruction must produce no register or memory write.
- **85–90, exit:** identify the base address for the branch offset.

**Exercise and success:** a bounded countdown loop executes the expected iteration count and terminates. **Common misunderstanding:** every branch jumps, or the offset is added to PC+4. Also test a not-taken branch whose computed target is misaligned; its unused target must not itself stop execution.

### Session 10 — Calls, returns, and upper immediates

**Objective:** execute JAL, JALR, LUI, and AUIPC and explain the link address separately from the jump target.

- **0–10, refresher:** binary concatenation and the purpose of a return address.
- **10–25, explain:** JAL/JALR write PC+4 to `rd`; LUI constructs an upper immediate and AUIPC adds one to the instruction PC.
- **25–40, demonstrate:** call a tiny routine and return using `jalr x0,0(x1)`.
- **40–75, build:** add link writeback, JALR target masking, and upper-immediate datapath selections.
- **75–85, check:** inspect `rd`, link data, target before/after bit-0 clearing, and the PC belonging to AUIPC.
- **85–90, exit:** distinguish `jal x0,label` from a call that retains a return address.

**Exercise and success:** the routine returns to the instruction after the call and preserves x0. **Common misunderstanding:** JALR clearing bit 0 ensures a valid instruction address; target bit 1 must still satisfy this course's alignment rule.

### Session 11 — Test the contract, including failure

**Objective:** build a coverage table for the first fourteen instructions and prove that invalid work cannot cause a side effect.

- **0–10, refresher:** separate an expected value, stimulus, and observation.
- **10–25, explain:** tests for ordinary inputs, boundaries, dependencies, unused sources, x0, and unsupported encodings.
- **25–40, demonstrate:** an incorrect decoder that accepts a neighboring encoding; show why one happy-path test misses it.
- **40–75, build:** add directed positive and negative tests plus a stop/fault test with an attempted later store.
- **75–85, check:** capture fault reason/PC and prove register and memory enables remain suppressed for invalid work.
- **85–90, exit:** name a failure that an arithmetic-result-only test would miss.

**Exercise and success:** a deliberately introduced decode bug fails at least one test; restoring the implementation passes the same test. **Common misunderstanding:** implementing an opcode means accepting every function-field combination under that opcode. A teaching halt is documented behavior, not a privileged trap implementation.

### Session 12 — Freeze a trustworthy baseline

**Objective:** reproduce a single-cycle run from source and program image, and explain every architectural update in one short program.

- **0–10, refresher:** define architectural state versus temporary combinational values.
- **10–25, explain:** keep an instruction listing, expected-state table, tool versions, and bounded stopping condition together.
- **25–40, demonstrate:** compare a hand trace with a machine-readable event log containing instruction PC and register/memory effects.
- **40–75, build:** run the fourteen-instruction suite and a sum-of-array program; independently calculate the sum.
- **75–85, check:** find the first mismatch, if any, using event order; rerun from a clean reset and image.
- **85–90, exit:** explain the longest likely combinational path and why cycle count alone is not performance.

**Exercise and success:** a peer repeats the result without verbal setup instructions. **Common misunderstanding:** a sophisticated reference model is automatically correct; retain hand-computed cases. Complete G2 and preserve the baseline before pipeline edits.

### Session 13 — Five stages, one architectural story

**Objective:** place five independent instructions on a cycle chart and carry each instruction's metadata through the pipeline.

- **0–10, refresher:** distinguish latency, throughput, and clock period.
- **10–25, explain:** divide work into IF, ID, EX, MEM, WB; list data and control needed at each boundary.
- **25–40, demonstrate:** move instruction cards through five rows; add a valid bit to each card.
- **40–75, build:** define pipeline registers, stage PCs, destination numbers, operands, and side-effect controls; run independent instructions only.
- **75–85, check:** follow one instruction's PC and `rd` from IF to WB; the first architectural write comes after pipeline fill.
- **85–90, exit:** explain how an older WB instruction can coexist with a younger IF instruction.

**Exercise and success:** five independent ALU instructions retire in order with correct destinations. **Common misunderstanding:** every stage should use the current fetch PC or current decoder outputs; instructions must carry their own metadata.

### Session 14 — Valid bits, reset, and clean bubbles

**Objective:** make invalid pipeline slots unable to write architectural state and implement explicit next-state priorities.

- **0–10, refresher:** review enable versus reset behavior in a register.
- **10–25, explain:** a bubble is an invalid slot, not a mysterious opcode; attach validity to all register, RAM, and MMIO writes.
- **25–40, demonstrate:** put nonzero stale control/data in an invalid slot and show that it cannot commit.
- **40–75, build:** reset stage valid bits, implement hold and bubble operations, and document priority among reset, stop, redirect, and stall.
- **75–85, check:** inspect valid bits alongside write enables during reset, fill, and an injected bubble.
- **85–90, exit:** explain why clearing just an instruction word is weaker than explicit validity.

**Exercise and success:** an invalid slot containing a store-like control pattern causes no memory write. **Common misunderstanding:** clearing every pipeline data bit is required for correctness; invalid data may remain if every effect is correctly gated. Explicitly resolve collisions according to instruction age and the project's stop policy.

### Session 15 — Forward the newest available value

**Objective:** resolve ALU dependencies with correct forwarding priority and without forwarding a load's address as its result.

- **0–10, refresher:** identify producer `rd` and consumer source registers.
- **10–25, explain:** compare EX inputs against valid writers in EX/MEM and MEM/WB; exclude x0 and unavailable load results.
- **25–40, demonstrate:** two consecutive writes to x1 followed by a read; the consumer must choose the newer value.
- **40–75, build:** operand forwarding and separate store-data forwarding; include branch comparisons and JALR's base operand.
- **75–85, check:** inspect `forward_a/b`, unforwarded values, selected values, and final results for one- and two-instruction gaps.
- **85–90, exit:** explain why a matching EX/MEM load cannot supply its address as loaded data.

**Exercise and success:** a three-ADD chain and an ALU-to-store pair produce expected results with no bubbles. **Common misunderstanding:** forwarding is only for ADD; every consumed register operand needs a defined route, including a store's data and a branch's comparison inputs.

### Session 16 — One load-use stall, explained edge by edge

**Objective:** insert exactly one bubble for an immediate load dependency under the asynchronous-memory contract.

- **0–10, refresher:** mark when a load's data becomes available and when its consumer needs it.
- **10–25, explain:** if an ID consumer needs an EX load's nonzero destination, hold PC and IF/ID and invalidate the next ID/EX slot.
- **25–40, demonstrate:** walk `lw x1,0(x0)` followed by `add x2,x1,x1` through a cycle table.
- **40–75, build:** source-use flags and load-use detection; conservatively include store data so load-to-store also stalls once in this version.
- **75–85, check:** see PC/IF/ID hold for one edge, a bubble enter EX, the load continue, and MEM/WB forwarding satisfy the delayed consumer.
- **85–90, exit:** explain why freezing every stage would prevent the load from making progress.

**Exercise and success:** the loaded value 9 produces x2=18, with exactly one dependency stall. **Common misunderstanding:** one load-use stall is universal; a different memory interface or forwarding arrangement changes the schedule.

## Weeks 5–6: complete the teaching subset and reach hardware

### Session 17 — Redirect and discard the wrong path

**Objective:** resolve control transfer in EX and prevent the two younger slots from producing side effects.

- **0–10, refresher:** identify older and younger instructions in a pipeline diagram.
- **10–25, explain:** fetch sequentially until EX redirects; replace the next PC and invalidate the IF/ID and ID/EX younger work.
- **25–40, demonstrate:** place a store and a register write after a taken branch; both must disappear.
- **40–75, build:** BEQ/JAL/JALR redirection with forwarded operands; test a branch following a producer and a JALR following a load.
- **75–85, check:** observe EX's instruction PC, redirect target, flushed valid bits, and absence of wrong-path writes.
- **85–90, exit:** identify exactly which instructions are killed and which older ones continue.

**Exercise and success:** a taken branch skips a sentinel store; the not-taken version performs it. **Common misunderstanding:** flushing the branch itself is correct; the branch's own legitimate effect, including a jump link, must survive.

### Session 18 — Compare pipelines by effects, not identical cycles

**Objective:** establish architectural agreement with the baseline and close the WB→ID timing gap.

- **0–10, refresher:** distinguish instruction order from wall-clock position.
- **10–25, explain:** compare final state and ordered instruction events; allow differing fill, stalls, and flushes. Add an explicit WB→ID register-read bypass.
- **25–40, demonstrate:** a producer in WB while its consumer is in ID; show the stale-read failure without bypass.
- **40–75, build:** run dependency, load-use, store-data, branch, JALR, x0, and source-use tests on both implementations.
- **75–85, check:** inspect matching retired PCs and values plus differing cycle counts; verify the WB→ID selected value at the capture edge.
- **85–90, exit:** explain why matching fetch PCs on every cycle is the wrong comparison.

**Exercise and success:** both cores produce the same sum and side effects, including a producer separated from its consumer by two independent instructions. **Common misunderstanding:** EX forwarding alone fixes all register-file timing cases. Complete G3.

### Session 19 — Signedness, shifts, and the remaining branches

**Objective:** complete integer arithmetic and branch families using boundary tests that separate similar operations.

- **0–10, refresher:** revisit signed/unsigned comparisons and binary shifts.
- **10–25, explain:** arithmetic versus logical right shift, register shift count width, immediate shift encodings, and signed versus unsigned predicates.
- **25–40, demonstrate:** shift 0x80000000 right by one in both modes; compare 0xFFFFFFFF and 1 both ways.
- **40–75, build:** add missing register/immediate ALU operations and BNE/BLT/BGE/BLTU/BGEU; test decoder legality.
- **75–85, check:** observe results 0x40000000 versus 0xC0000000 for right shifts and different branch decisions on identical bit patterns.
- **85–90, exit:** explain why a single less-than flag cannot represent both signed and unsigned order.

**Exercise and success:** boundary cases, zero shift, and maximum defined shift amount pass in both cores. **Common misunderstanding:** a right-shift operator automatically preserves the sign bit; operand type and operator both matter. Keep each new operation tied to a coverage row.

### Session 20 — Byte lanes and an explicit stop boundary

**Objective:** implement subword loads/stores and demonstrate deterministic fault/stop behavior without claiming a complete privileged machine.

- **0–10, refresher:** map four bytes to a little-endian word.
- **10–25, explain:** lane selection, byte write masks, sign/zero extension, natural alignment, and preservation of untouched lanes.
- **25–40, demonstrate:** load individual bytes from 0x80FF7F01 and overwrite only its third byte.
- **40–75, build:** add LB/LBU/LH/LHU/SB/SH; complete the thirty-seven-instruction matrix and documented FENCE/ECALL/EBREAK behavior.
- **75–85, check:** inspect byte masks, loaded extensions, untouched bytes, fault PC/reason, and suppression of younger side effects.
- **85–90, exit:** explain why correctly adding byte loads still does not prove full RISC-V platform compliance.

**Exercise and success:** an unaligned halfword and an out-of-range word fail deterministically; aligned subword cases preserve neighbors. **Common misunderstanding:** writing one byte permits replacing the entire word. Complete G4 before adding board complications.

### Session 21 — Memory-mapped I/O and real inputs

**Objective:** make a program read synchronized switches and update LEDs through the data-memory interface.

- **0–10, refresher:** distinguish a memory address from a physical pin.
- **10–25, explain:** full address decoding, RAM versus MMIO selection, registered LED state, and asynchronous inputs crossing into a clock domain.
- **25–40, demonstrate:** a switch-to-LED program in simulation; show raw and synchronized switch signals separately.
- **40–75, build:** word MMIO access at 0x10000000 and 0x10000004, switch synchronization, and a test proving MMIO writes do not also modify RAM.
- **75–85, check:** see synchronization delay, a load of the synchronized value, and an LED-latch change only at a valid store edge.
- **85–90, exit:** explain why software polling does not replace synchronization.

**Exercise and success:** several switch patterns are reflected in the expected LED bits. **Common misunderstanding:** two synchronizer stages guarantee a coherent snapshot of a simultaneously changing multi-bit bus. Independent switches can settle separately; debounce any button used to create a one-shot step.

### Session 22 — Synthesis, clocks, and timing evidence

**Objective:** synthesize the actual top-level design and explain its clock, inferred memories, utilization, and timing status.

- **0–10, refresher:** distinguish RTL, simulation executable, netlist, and bitstream.
- **10–25, explain:** choose the exact board/device, connect an appropriate constraint file, define clock timing, and inspect inferred hardware.
- **25–40, demonstrate:** find a clock report, a memory inference report, and the worst timing path in Vivado.
- **40–75, build:** synthesize and implement a free-running board wrapper with `clk`, synchronized `btnC` reset, 16 switches, and 16 LEDs; verify asynchronous memory remains compatible with the design. Use a properly generated/constrained clock when a lower core frequency is required. Physical stepping is an optional later extension using a debounced clock enable.
- **75–85, check:** record utilization, timing slack, clock constraints, and unresolved warnings with dispositions.
- **85–90, exit:** explain why successful synthesis does not establish that the design meets its clock period.

**Exercise and success:** every used port has reviewed pin/voltage constraints and all intended timing paths are constrained. **Common misunderstanding:** a slow enable automatically relaxes static timing; the active clock still governs paths unless valid, justified constraints say otherwise.

### Session 23 — Program the board and diagnose one layer at a time

**Objective:** reproduce the simulated MMIO demonstration on the Basys 3 and isolate a failure to a specific layer.

- **0–10, refresher:** identify board power, programming connection, user reset, and configuration reset.
- **10–25, explain:** establish a known-good clock/reset/I/O wrapper before interpreting processor behavior; retain a build identifier.
- **25–40, demonstrate:** program a constrained I/O check, then the processor image; show reset returning software execution to PC=0.
- **40–75, build:** run the switch-to-LED program and a computed-result program; record switch patterns, expected outputs, observed outputs, and reset behavior.
- **75–85, check:** correlate a visible result with the simulated architectural trace and the exact bitstream/program image used.
- **85–90, exit:** propose the next observation if simulation passes but every LED remains off.

**Exercise and success:** an instructor can repeat the demonstration after reset using the written procedure. **Common misunderstanding:** LEDs prove every instruction works. They provide end-to-end evidence for the exercised paths; directed simulation remains necessary.

### Session 24 — Demonstrate, defend, and hand off

**Objective:** present a reproducible processor experiment and explain a new instruction sequence without relying on memorized screenshots.

- **0–10, refresher:** restate the memory timing and instruction-support boundaries.
- **10–25, explain:** construct a concise evidence narrative: expected behavior, tests, waveform, timing report, board result, limitations.
- **25–40, demonstrate:** the instructor changes one dependency or branch outcome; predict the new timing and final state before running.
- **40–75, build:** complete the final report and demonstration package, fix only evidence gaps, and rerun affected checks.
- **75–85, check:** a peer rebuilds or repeats the documented run; individually explain one hazard, one byte-lane case, and one timing constraint.
- **85–90, exit:** identify the first redesign needed to adopt synchronous-read block RAM.

**Exercise and success:** complete G5 with a documented supported instruction set, reproducible tests, reviewed timing, and observable hardware behavior. **Common misunderstanding:** a more impressive feature excuses unclear correctness evidence. A small well-explained processor is a successful final project.

## Practice plan

Use the first hour after each week's meetings to redraw the new datapath or timing chart from memory. Use the next two hours to predict and run additional tests. Spend the fourth hour diagnosing one deliberately inserted bug or explaining the design to the tutor. Reserve up to two additional hours for unfinished gate evidence. Do not spend the entire practice period changing RTL without checking an expected result.

| Week | Practice artifact |
|---|---|
| 1: sessions 1–4 | Number-pattern sheet, ALU truth table, clocked-state trace, repeatable simulation |
| 2: sessions 5–8 | Instruction field sheet, register-file evidence, three-instruction trace, RAM addressing tests |
| 3: sessions 9–12 | Loop and call/return traces, immediate tests, fourteen-instruction coverage matrix, baseline report |
| 4: sessions 13–16 | Pipeline boundary table, invalid-slot test, forwarding and load-use cycle tables |
| 5: sessions 17–20 | Flush evidence, two-core comparison, thirty-seven-instruction matrix, byte-lane tests |
| 6: sessions 21–24 | MMIO simulation, implementation report, board evidence, final explanation |

For self-paced study, stop at each gate and take a day away from the implementation. On return, explain the evidence without the source code open. If that is difficult, repeat the conceptual example before adding the next feature.

## Official references

The [RISC-V RV32I specification](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html) is the authoritative reference for instruction semantics and encodings. Use it to resolve exact instruction behavior; use this course's explicit contract for the deliberately restricted environment and stop mechanism.

The [Verilator user guide](https://verilator.org/guide/latest/overview.html) describes the simulation tool and links to supported examples. Record the installed version; adapt invocation details to that version and the repository's harness.

The [Basys 3 reference manual](https://digilent.com/reference/_media/reference/programmable-logic/basys-3/basys3_rm.pdf) describes the board, its 100 MHz input oscillator, 16 switches, 16 LEDs, and configuration connections. Verify the physical board revision and use its official pin constraints. The manual's historical software-edition names are not a current installation guide.

For synthesis and implementation, consult the installed Vivado release's AMD documentation and the reports generated for this design. Device capacity or an example's successful build is not evidence that this design closes timing.
