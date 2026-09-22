# Learner workbook

Name: __________  Tutor: __________  Start date: __________

This workbook accompanies [COURSE.md](COURSE.md). Make a prediction before running a test. Record evidence after running it. Keep corrections visible so you can explain how your understanding changed. Solutions are in the separate tutor guide.

## Six-week planner

Plan four 90-minute meetings and 4–6 hours of guided independent work each week. Move dates when a mastery gate needs more time.

| Week | Sessions | Meeting dates | Practice hours planned/actual | Gate or remaining work |
|---|---|---|---|---|
| 1 | 1–4 | __________ | ____ / ____ | __________ |
| 2 | 5–8 | __________ | ____ / ____ | __________ |
| 3 | 9–12 | __________ | ____ / ____ | __________ |
| 4 | 13–16 | __________ | ____ / ____ | __________ |
| 5 | 17–20 | __________ | ____ / ____ | __________ |
| 6 | 21–24 | __________ | ____ / ____ | __________ |

## Before the first lab

| Item | Your record |
|---|---|
| Operating system and version | __________ |
| Verilator version and working example | __________ |
| C++ compiler/build tools | __________ |
| Waveform viewer and trace format | __________ |
| Vivado version and target device | __________ |
| Reference repository revision | __________ |
| Your implementation revision or dated snapshot | __________ |
| Board revision and programming connection | __________ |
| Program-image format and load procedure | __________ |

Explain in your own words what each contains:

- RTL: __________
- Simulation executable: __________
- Program image: __________
- FPGA bitstream: __________

## Session prediction sheets

For every row, fill the prediction first. Put the detailed trace or screenshot in a numbered lab log and reference it in the last column. “It works” is not an observation; include a value, an edge, or a specific report result.

| Session | Prompt | Prediction | Observation and lab-log ID |
|---|---|---|---|
| 1 | Interpret 0x80 as unsigned and signed 8-bit; add 0xFE and 3 at eight-bit width. | __________ | __________ |
| 2 | For a=0xA, b=0xC, predict AND, OR, XOR, ADD, and SUB. | __________ | __________ |
| 3 | From reset PC=0, predict four edges with enable 1,0,0,1. | __________ | __________ |
| 4 | Deliberately give a test one wrong expectation. What will establish that it actually failed? | __________ | __________ |
| 5 | Decode 0x00500093. Identify destination, source, immediate, and operation. | __________ | __________ |
| 6 | Compare 0x80000000 and 1 as signed values; then attempt to write x0. | __________ | __________ |
| 7 | Trace ADDI x1=5, ADDI x2=7, then ADD x3=x1+x2. | __________ | __________ |
| 8 | Store 42 at data byte address 12, load it, then attempt a word store at 13. | __________ | __________ |
| 9 | A BEQ at PC=0x20 has offset −8. Predict taken and not-taken next PCs. | __________ | __________ |
| 10 | A JAL at PC=0x20 jumps by 16 and writes x1. Distinguish target and link. | __________ | __________ |
| 11 | Place an invalid instruction before a store. Which effects are forbidden? | __________ | __________ |
| 12 | Choose five instructions and hand-calculate every register/memory effect before running them. | __________ | __________ |
| 13 | Chart five independent instructions through IF, ID, EX, MEM, WB. | __________ | __________ |
| 14 | Give an invalid slot stale store control bits. Predict its effective write enable. | __________ | __________ |
| 15 | Write x1 twice, then read it. Identify the youngest eligible forwarding source. | __________ | __________ |
| 16 | Load 9 into x1 and immediately double it with ADD. Predict the stalled stages and result. | __________ | __________ |
| 17 | Put a store and register write after a taken branch. Mark every killed slot. | __________ | __________ |
| 18 | Separate a producer and consumer by two independent instructions. Explain the WB→ID case. | __________ | __________ |
| 19 | Right-shift 0x80000000 by one logically and arithmetically; compare −1 and 1 signed/unsigned. | __________ | __________ |
| 20 | Use 0x80FF7F01 to predict LB/LBU at byte 2 and LH/LHU at byte 2. | __________ | __________ |
| 21 | Change switches during a run. Predict which value the processor may observe and where synchronization appears. | __________ | __________ |
| 22 | Identify the real active clock, required period, worst path, and inferred RAM type. | __________ | __________ |
| 23 | Predict three board outputs for chosen switch patterns and record the build used. | __________ | __________ |
| 24 | Explain a changed dependency sequence and the redesign needed for synchronous-read memories. | __________ | __________ |

My hardest unresolved question this week: __________

My explanation after discussing it with the tutor: __________

## Repeatable lab-log form

Copy this form for each substantial experiment.

**Log ID / date / session:** __________

**Question being tested:** __________

**Design revision and program image:** __________

**Initial state:** reset sequence __________; initialized registers __________; initialized RAM __________; driven inputs __________.

**Prediction:** final architectural state __________; expected cycle/stall/flush behavior __________; expected stop condition __________.

**Reproduction steps:**

1. __________
2. __________
3. __________

| Evidence | Exact result or file/reference |
|---|---|
| Test command or documented run action | __________ |
| Exit status and assertion summary | __________ |
| Timeout/cycle bound | __________ |
| Trace format and trace file | __________ |
| Signal aliases and corresponding actual names | __________ |
| Screenshot edge numbers and interpretation | __________ |
| Expected versus observed state | __________ |

**First mismatch, if any:** instruction PC __________; edge __________; expected __________; observed __________.

**Hypothesis:** __________

**One change made and why:** __________

**Retest and affected regression results:** __________

**Conclusion in two sentences:** __________

## Architectural trace sheet

Record instruction effects in program order. For the pipeline, also record the stage where you observed the effect. Do not mistake a repeated stalled slot for another completed instruction.

| Order | Instruction PC | Assembly | Source values | Destination/value | Memory effect | Next PC | Observation stage/edge |
|---|---|---|---|---|---|---|---|
| 1 | ____ | ____ | ____ | ____ | ____ | ____ | ____ |
| 2 | ____ | ____ | ____ | ____ | ____ | ____ | ____ |
| 3 | ____ | ____ | ____ | ____ | ____ | ____ | ____ |
| 4 | ____ | ____ | ____ | ____ | ____ | ____ | ____ |
| 5 | ____ | ____ | ____ | ____ | ____ | ____ | ____ |

## Hazard timing worksheet

Program and initial values: __________

Mark IF/ID/EX/MEM/WB, held stages, and invalid bubbles. Add columns if needed. A dash means the instruction is absent; it does not mean stalled.

| Instruction | C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 | C9 |
|---|---|---|---|---|---|---|---|---|---|
| I1: __________ | ____ | ____ | ____ | ____ | ____ | ____ | ____ | ____ | ____ |
| I2: __________ | ____ | ____ | ____ | ____ | ____ | ____ | ____ | ____ | ____ |
| I3: __________ | ____ | ____ | ____ | ____ | ____ | ____ | ____ | ____ | ____ |
| I4: __________ | ____ | ____ | ____ | ____ | ____ | ____ | ____ | ____ | ____ |

| Consumer source | Producer | Needed stage/cycle | Available stage/cycle | Forwarding route or stall |
|---|---|---|---|---|
| ____ | ____ | ____ | ____ | ____ |
| ____ | ____ | ____ | ____ | ____ |

At a stall, these registers hold: __________. This slot becomes invalid: __________. These older instructions advance: __________.

At a redirect, the redirecting PC is __________, target is __________, and killed instruction PCs are __________.

Could this test falsely stall because an instruction field resembles an unused source? Explain: __________.

## Instruction and behavior coverage

For each listed mnemonic, record at least one test ID; separate names with semicolons. A family is incomplete if any mnemonic lacks evidence. Add signed boundary, immediate boundary, x0, and dependency cases where applicable.

| Family | Mnemonics to cover | Test IDs and missing cases |
|---|---|---|
| Register | ADD; SUB; SLL; SLT; SLTU; XOR; SRL; SRA; OR; AND | __________ |
| Immediate | ADDI; SLTI; SLTIU; XORI; ORI; ANDI; SLLI; SRLI; SRAI | __________ |
| Load | LB; LH; LW; LBU; LHU | __________ |
| Store | SB; SH; SW | __________ |
| Branch | BEQ; BNE; BLT; BGE; BLTU; BGEU | __________ |
| Jump | JAL; JALR | __________ |
| Upper immediate | LUI; AUIPC | __________ |

| Required behavior | Test ID | Expected outcome | Observed outcome |
|---|---|---|---|
| Reset and x0 | ____ | ____ | ____ |
| ALU dependency and newest-writer priority | ____ | ____ | ____ |
| Load-use and load-to-store dependency | ____ | ____ | ____ |
| WB→ID bypass | ____ | ____ | ____ |
| Forwarded branch/JALR operand | ____ | ____ | ____ |
| Wrong-path RAM/MMIO writes suppressed | ____ | ____ | ____ |
| Byte/halfword lane preservation | ____ | ____ | ____ |
| Full address validation and misalignment | ____ | ____ | ____ |
| FENCE, ECALL, EBREAK teaching behavior | ____ | ____ | ____ |
| Older fault versus younger redirect | ____ | ____ | ____ |
| Older redirect versus younger fault | ____ | ____ | ____ |
| MMIO address separation and reset | ____ | ____ | ____ |

## Hardware evidence sheet

| Item | Record |
|---|---|
| Board/device and constraint-file revision | __________ |
| Top-level ports and reviewed pin assignments | __________ |
| Active clock and period | __________ |
| Reset synchronization and polarity | __________ |
| Memory inference matches asynchronous-read contract | __________ |
| LUT/register/distributed-memory utilization | __________ |
| Setup/hold timing results and unconstrained paths | __________ |
| Warnings and individual dispositions | __________ |
| Bitstream, program image, and implementation revision | __________ |
| Programming and reset procedure | __________ |

| Test | Switch input | Predicted LEDs | Observed LEDs | Evidence reference |
|---|---|---|---|---|
| 1 | ____ | ____ | ____ | ____ |
| 2 | ____ | ____ | ____ | ____ |
| 3 | ____ | ____ | ____ | ____ |
| After reset | ____ | ____ | ____ | ____ |

One behavior this board demonstration does **not** establish: __________.

## Final report and assessment

Complete these paragraphs with concise evidence references.

**Implemented design and supported instruction set:** __________

**Memory map, timing assumptions, and deliberate limitations:** __________

**A complete single-cycle instruction explanation:** __________

**A pipeline hazard, its correction, and timing evidence:** __________

**Test coverage and the hardest bug found:** __________

**Synthesis, timing, and board results:** __________

**How someone else repeats the result:** __________

**Remaining work and next experiment:** __________

Score each category 0–3: **0** absent, **1** result claimed with weak explanation, **2** correct with reproducible evidence, **3** correct with a new-case prediction and clear limits.

| Category | Score | Evidence / improvement |
|---|---|---|
| Bits, state, and instruction semantics | ____ / 3 | __________ |
| Single-cycle datapath and control | ____ / 3 | __________ |
| Pipeline timing and hazards | ____ / 3 | __________ |
| Directed tests and fault/side-effect handling | ____ / 3 | __________ |
| FPGA constraints, timing, and demonstration | ____ / 3 | __________ |
| Reproduction and independent explanation | ____ / 3 | __________ |

Target: at least 2 in every category. A total score cannot compensate for missing required gate evidence.

| Gate | Date attempted | Evidence IDs | Pass / revisit | Tutor initials |
|---|---|---|---|---|
| G0 | ____ | ____ | ____ | ____ |
| G1 | ____ | ____ | ____ | ____ |
| G2 | ____ | ____ | ____ | ____ |
| G3 | ____ | ____ | ____ | ____ |
| G4 | ____ | ____ | ____ | ____ |
| G5 | ____ | ____ | ____ | ____ |
