# Tutor guide and answer key

Use this beside [COURSE.md](COURSE.md). Keep the answers separate from [WORKBOOK.md](WORKBOOK.md) until the learner has made a prediction. You are the tutor; you do not need to remember an entire architecture course before beginning.

## Prepare one meeting ahead

The six-week intensive has four 90-minute meetings each week. The learner has another 4–6 hours of guided independent work weekly. Reserve your own preparation separately: initially 1–2 hours per meeting, more for first-time tool installation or board troubleshooting. If that preparation is unavailable, extend the calendar while keeping the twenty-four-session sequence.

For each meeting:

1. Spend 15 minutes on its prerequisite refresher and solve the exit ticket yourself.
2. Spend 20–40 minutes running the smallest example and saving one clear trace.
3. Spend 15–25 minutes inserting a plausible bug and locating its first observable consequence.
4. Spend 10 minutes checking that the learner's starter materials and expected evidence are ready.
5. Use remaining preparation time for unfamiliar tools, not extra lecture slides.

Ask the learner to predict before you reveal. If a prediction is wrong, ask which stored state, selector, or timing assumption produced it. A useful explanation points to a value and an edge. Avoid taking over the keyboard for an entire lab; demonstrate one correction and return control.

## Refresher for a returning tutor

**Combinational versus sequential:** a combinational block calculates outputs from present inputs. A clocked block stores state at an edge. Draw the storage boundary before discussing code. In clocked RTL, nonblocking assignments model simultaneous state updates; one register does not see another register's newly assigned value during that same edge merely because its assignment appears later in the source.

**Width versus signedness:** a 32-bit vector supplies a pattern. Signedness changes comparison and some expression behavior. Addition wraps to the chosen result width. Test signed comparison with opposite-sign operands so a mistaken unsigned comparison cannot hide.

**ISA versus implementation:** the ISA says what an instruction does architecturally. It does not require five stages, a particular ALU, or this course's memory map. Preserve the effects when changing implementation timing.

**Address versus index:** the processor uses byte addresses. A 256-word RAM has 256 entries, not 256 byte addresses. Validate address range and alignment before selecting an index. The instruction and data arrays are separate ports and separate contents.

**Hazard versus dependency:** a dependency is a relationship between instructions. It becomes a hazard when an implementation cannot provide the needed value at the required time. Forwarding removes many hazards while leaving the underlying dependencies intact.

**Availability versus matching:** a matching register number is insufficient for forwarding. The producing instruction must be valid, writing a nonzero destination, and have the result available on that route. An EX/MEM load has an address at that boundary, not its final loaded value.

**Simulation versus hardware:** a simulation checks the behaviors that its stimulus exercises. Synthesis describes inferred hardware, implementation produces placement/routing, and timing analysis evaluates constraints. Board execution is another evidence layer; an LED demonstration cannot substitute for an instruction test suite.

**Clocking:** the board baseline runs continuously and uses a synchronized user reset. A visible step mode is an optional later extension. A clock enable does not create a slower clock or automatically justify relaxed timing constraints. For a slower core clock, use a proper generated clock and review its constraints.

## Worked examples

### 1. Decode and execute an ADDI

For `addi x1,x0,5`, the instruction word is `0x00500093`:

| Field | Value | Meaning |
|---|---|---|
| opcode [6:0] | 0x13 | Immediate arithmetic family |
| rd [11:7] | 1 | Destination x1 |
| funct3 [14:12] | 0 | ADDI within this family |
| rs1 [19:15] | 0 | Read x0 |
| immediate [31:20] | 5 | Sign-extended operand 5 |

At PC=0, operands are 0 and 5; the ALU result is 5. At the completing edge, x1 becomes 5 and PC becomes 4. Memory does not change. For immediate −1, the twelve-bit field is 0xFFF and its 32-bit sign extension is 0xFFFFFFFF.

Ask the learner to change only `rd`, then only the immediate. This separates register identity from stored value without introducing another datapath.

### 2. A short architectural trace

Assume execution starts at PC=0 and data address 12 is writable.

```asm
addi x1,x0,5
addi x2,x0,7
add  x3,x1,x2
sw   x3,12(x0)
lw   x4,12(x0)
```

| Instruction PC | New architectural effect |
|---|---|
| 0x00 | x1 = 5 |
| 0x04 | x2 = 7 |
| 0x08 | x3 = 12 |
| 0x0C | Data word index 3 = 12 |
| 0x10 | x4 = 12 |

Next sequential PC is 0x14. Bound the test before it consumes unrelated/uninitialized instructions, or append EBREAK and expect the documented unsupported-instruction fault/halt. A pipeline must produce these same ordered effects, although stores act in MEM and register results in WB. An event logger must account for those different observation points rather than compare raw signal transitions indiscriminately.

### 3. Load-use timing

Initialize data word 0 to 9, then execute `lw x1,0(x0)` and `add x2,x1,x1`. Cycles below name the stage occupied during each interval.

| Instruction/slot | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| LW | IF | ID | EX | MEM | WB | — | — |
| ADD | — | IF | ID | ID held | EX | MEM | WB |
| Bubble | — | — | — | EX invalid | MEM invalid | WB invalid | — |

During cycle 3, the detector sees an EX load and an ID consumer. At the next edge it holds PC/IF/ID and inserts an invalid EX slot. The load proceeds. In cycle 5 the ADD consumes the load result through MEM/WB forwarding. x2 becomes 18. Holding the load itself would prevent progress.

This timing depends on asynchronous data-memory reads and the chosen forwarding boundaries. In this course, a load immediately followed by a dependent store also stalls once; store data is forwarded in EX and carried onward. Do not silently substitute a different late store-data path while retaining this expected table.

### 4. Newest writer and same-edge register reads

Use `addi x1,x0,1; addi x1,x1,1; add x2,x1,x0`. The third instruction needs the second instruction's value, 2. When both forwarding candidates match x1, eligible EX/MEM wins over MEM/WB.

For WB→ID, place two independent instructions between a producer and consumer. The producer occupies WB while the consumer occupies ID. An explicit WB→ID bypass supplies the value captured by ID/EX. Do not depend on an accidental simulation ordering or an unspecified register-file read-during-write behavior.

### 5. Byte lanes and signed loads

For a word `0x80FF7F01` at byte address 0:

| Byte address | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| Stored byte | 0x01 | 0x7F | 0xFF | 0x80 |

`LB` at 2 yields 0xFFFFFFFF; `LBU` yields 0x000000FF. `LH` at 2 yields 0xFFFF80FF; `LHU` yields 0x000080FF. Storing byte 0xAA at address 2 changes the word to 0x80AA7F01. A halfword access at address 1 is rejected under this course's alignment contract.

### 6. Redirects and faults have ages

A branch in EX has younger instructions in ID and IF. On a taken branch, invalidate both younger slots and fetch the target next. The branch and older work survive. A wrong-path store must never assert an effective memory write.

For the advanced stop tests, a younger illegal instruction in ID is squashed by an older taken branch in EX. Conversely, a faulting older memory access in MEM outranks a younger EX redirect. Fault tokens move toward retirement; older WB work completes, the surviving fault suppresses younger effects, and its stop is published at WB. A misaligned jump target belongs to the jump; an aligned target outside instruction memory fails on the next fetch. These rules need directed tests, not just an informal `halted` flag.

## Exit-ticket answer key

For the workbook's numerical predictions: session 1 gives unsigned 128, signed −128, and sum 0x01. Session 2 gives AND 0x8, OR 0xE, XOR 0x6, ADD 0x16, and 32-bit SUB 0xFFFFFFFE. Session 3 gives PCs 4, 4, 4, 8 after reset is released. Session 9 gives target 0x18 when taken and 0x24 otherwise. Session 10 gives target 0x30 and link 0x24. Session 19 gives logical shift 0x40000000, arithmetic shift 0xC0000000, signed −1 < 1 true, and unsigned 0xFFFFFFFF < 1 false. Other numerical predictions appear in the worked examples above.

FENCE, ECALL, and EBREAK all fault with `UNSUPPORTED_INSTRUCTION` in this course. They do not implement architectural fences, service calls, or privileged traps. CPU reset clears x1–x31; RAM contents are retained and must be initialized by the test fixture or program. Subword peripheral accesses and writes to the switch register fault. Use [ARCHITECTURE.md](ARCHITECTURE.md) for exact priorities and event fields.

| Session | Minimum acceptable answer |
|---|---|
| 1 | The bits are identical; unsigned 0xFF is 255 and signed 8-bit two's-complement is −1. |
| 2 | The ALU operation/select input chooses the result bus. |
| 3 | PC advances by four only at enabled active edges, except reset takes its defined priority. |
| 4 | The test checks simulated behavior; it does not prove pin mapping, physical timing, or board operation. |
| 5 | `rd` identifies a register; writeback data supplies its new value. |
| 6 | Subtraction can overflow; its sign bit alone is not a complete signed less-than predicate. |
| 7 | ADD changes its nonzero destination register and next PC; it does not change data memory. |
| 8 | Instruction and data memories are different arrays on separate ports. |
| 9 | The branch's own PC is the target base. |
| 10 | x0 discards the link; another destination can retain PC+4 for return. |
| 11 | Examples include wrong-path stores, illegal encodings, x0 writes, and address aliasing. |
| 12 | A load path crosses fetch, decode/read, address ALU, data read, and writeback; performance also depends on period. |
| 13 | Different instructions occupy different stages concurrently, each carrying its own PC/control. |
| 14 | An invalid slot suppresses all effects even when stale bits resemble a valid instruction. |
| 15 | A load's effective address is not its loaded value. |
| 16 | The producer must advance while the consumer waits. |
| 17 | Kill younger ID/IF instructions; preserve the redirecting instruction and older work. |
| 18 | Correct cores can fetch at different times; compare architectural effects in order. |
| 19 | Signed and unsigned order differ for values with the high bit set. |
| 20 | Platform behavior includes more than integer data operations; this design deliberately restricts the environment. |
| 21 | Polling is software behavior; synchronization addresses clock-domain sampling. |
| 22 | Synthesis can succeed while implemented paths violate the specified period. |
| 23 | Check the known-good I/O wrapper, actual bitstream, clock/reset, then program image and MMIO trace. |
| 24 | Redesign instruction/data response timing, stage boundaries, and hazard assumptions for registered reads. |

## Assess explanations and recover efficiently

Use the rubric in the workbook; grade demonstrated understanding, not the length of a report. Do not average away a failure to suppress wrong-path writes or a lack of timing evidence for hardware operation. Treat those as incomplete gate evidence.

If a learner is stuck, reduce the problem: one instruction, one register, one word, one expected edge. If the result is right but the explanation is weak, change an input and ask for a new prediction. If simulation passes but hardware fails, preserve the passing simulation and inspect the wrapper, initialization, constraints, reset, and inferred memory behavior before rewriting the processor.

The intensive schedule is ambitious. Extend a week when necessary. Keep byte-lane completion and the final stop-order tests visible on the remaining-work list. Optional physical stepping, UART, block RAM migration, branch prediction, and caches should begin only after the required gates pass.
