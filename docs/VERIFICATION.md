# Verification lookup

These are acceptance tests to implement; they are not claims that a complete CPU exists or has passed. Starter CPU simulation covers only the supplied ALU; `make test` also checks image-conversion tools. Both CPUs must meet [ARCHITECTURE.md](ARCHITECTURE.md).

## Testbench setup

Initialize both memories; unused instruction words=`00000000`, data RAM normally zero. Reset for two rising edges; change inputs/release reset between edges; sample after registered updates settle. Reset retains RAM. Stop on the specified retirement marker, not EBREAK, and add a cycle watchdog.

For a future `cpu_tb`, create `sim/cpu.f` listing actual source paths:

```text
verilator --lint-only --timing --Wall --top-module cpu_tb -f sim/cpu.f
verilator --binary --timing --assert --trace-vcd --Wall --top-module cpu_tb -f sim/cpu.f
```

Add `$dumpfile`/`$dumpvars` or equivalent harness tracing; run the executable reported by the build. [Binary example](https://verilator.org/guide/latest/example_binary.html), [options](https://verilator.org/guide/latest/exe_verilator.html), [tracing](https://verilator.org/guide/latest/faq.html#how-do-i-generate-waveforms-traces-in-c).

## Unit checks

| Inputs/operation | Expected |
|---|---|
| ADD ffffffff,1; SUB 0,1 | 00000000; ffffffff |
| SLT/SLTU 80000000,7fffffff | 1/0 |
| SLT/SLTU ffffffff,0 | 1/0 |
| SRA/SRL 80000000,1 | c0000000/40000000 |
| SLL 1,register shift 32/31 | 1/80000000 |
| AND/OR/XOR a5a5a5a5,5a5a5a5a | 0/ffffffff/ffffffff |

Also test shifts 0/31, equal comparisons, and signed-zero boundaries.

Immediate boundaries: I/S=`0,1,2047,-1,-2048`; B=`+4,-4,+4094,-4096`; J=`+4,-4,+1048574,-1048576`; U fields=`0,12345,80000` (hex). Large offsets test decoding, not legal fetches. Check encodings independently against [base opcodes](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i) and [RV32 shifts](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv32_i). Check each instruction's controls/source-use flags; reject invalid funct fields, RV64 shifts, MUL, CSR, and malformed JALR with writes/redirect disabled.

Write/read every register through both ports; protect x0; test WB-to-ID bypass. Test all SB lanes/SH positions/SW masks. Legal RAM boundaries: word `0x3fc`, halfword `0x3fe`, byte `0x3ff`; `0x400` must fault. Fetch/load different contents at address zero to prove separate memories. Reset must clear registers/LED/PC/valid/fault state while retaining RAM.

## Reproducible programs

Each block starts at PC=0, with zeroed data RAM and reset registers. Instructions are four bytes; RAM[n] denotes word n. Stop at the stated marker's retirement.

**A: arithmetic, forwarding, load-use, x0.**

```asm
addi x1,x0,7
addi x2,x0,-3
add  x3,x1,x2
sub  x4,x1,x2
slt  x5,x2,x1
sw   x4,0(x0)
lw   x6,0(x0)
add  x7,x6,x3
addi x0,x0,123
done: jal x0,done
```

Marker `0x20`: x0=0, x1=7, x2=0xfffffffd, x3=4, x4=10, x5=1, x6=10, x7=14; RAM[0]=10. Exactly one load-use stall before the marker.

**B: wrong-path store.**

```asm
addi x1,x0,99
beq  x0,x0,taken
sw   x1,0(x0)
addi x2,x0,1
taken: addi x2,x0,2
done:  jal x0,done
```

Marker `0x10`: x1=99, x2=2, RAM[0]=0; no physical write from PC `0x08`. At the extended milestone, substitute BNE: RAM[0]=99.

**C: instruction-local PC, links, JALR bit zero.**

```asm
auipc x5,0
jal   x1,target
addi  x2,x0,99
target: auipc x6,0
addi  x3,x0,29
jalr  x4,0(x3)
sw    x2,0(x0)
land: addi x7,x0,5
done: jal x0,done
```

Marker `0x1c`: x1=8, x2=0, x3=29, x4=24, x5=0, x6=12, x7=5; RAM unchanged. Separately test `jalr x3,0(x3)`: target uses the old/forwarded source before writing the link.

**D: extended byte/halfword operations.**

```asm
lui  x1,0x80ff8
addi x1,x1,-255
sw   x1,0(x0)
lb   x2,3(x0)
lbu  x3,3(x0)
lh   x4,2(x0)
lhu  x5,2(x0)
addi x6,x0,0x55
sb   x6,1(x0)
sh   x6,2(x0)
lw   x7,0(x0)
done: jal x0,done
```

Marker `0x28`: x1=80ff7f01, x2=ffffff80, x3=80, x4=ffff80ff, x5=80ff, x6=55, x7=00555501 (hex). Store words must successively equal `80ff7f01,80ff5501,00555501`. Repeat every legal lane. Also check `sltiu x8,x0,-1`→1 and `slti x9,x0,-1`→0.

**E: MMIO.**

```asm
lui  x10,0x10000
lui  x11,0x12345
addi x11,x11,0x678
sw   x11,0(x10)
lw   x12,0(x10)
lw   x13,4(x10)
done: jal x0,done
```

Hold switches=`a55a` for two complete synchronizer edges before sampling. Marker `0x14`: LEDs=5678, x12=00005678, x13=0000a55a (hex).

## Hazard checks

Exercise both sources at producer distances 1/2/3: EX/MEM, MEM/WB, WB-to-ID. Test newest matching producer, rs1=rs2, rd=source, and rd=x0. ALU→store/JALR needs zero stalls; load→ALU/store-data/store-address/branch needs exactly one. Load→x0 causes none. `lw x5,0(x0); lui x6,0x28` must not falsely stall. A load immediately after a store sees its accepted bytes.

Taken redirects flush two younger slots; untaken branches flush none. Test redirect-over-stall priority in a controller unit test: an ordinary EX branch cannot simultaneously be the EX load required by load-use detection.

## Fault checks

Every case needs exact fault PC/code, unchanged failing/younger state, surviving older retirements, and one terminal fault record.

| Stimulus | Expected fault/behavior |
|---|---|
| LW/SW at 2; LH/SH at 1 | LOAD_MISALIGNED/STORE_MISALIGNED; no partial access |
| LW/SW at 1024, including LW x0 | LOAD_ACCESS/STORE_ACCESS; no alias |
| LW/SW at 0x10000002 | LOAD_MISALIGNED/STORE_MISALIGNED before region checks |
| SW at 0x10000004 | STORE_ACCESS |
| Subword MMIO | LOAD_ACCESS/STORE_ACCESS |
| Taken/untaken BEQ offset +2 | INSTRUCTION_MISALIGNED / no target fault |
| JALR sum 7/5 | Target 6 faults without link / target 4 succeeds |
| Jump to aligned 0x400 | Jump/link completes; fetch INSTRUCTION_ACCESS |
| 00000000; malformed encoding | ILLEGAL_INSTRUCTION |
| FENCE 0000000f; ECALL 00000073; EBREAK 00100073; later-milestone operation on initial CPU | UNSUPPORTED_INSTRUCTION |

```asm
addi x1,x0,9
sw   x1,0(x0)
.word 0x00000000
sw   x1,4(x0)
addi x2,x0,77
```

At halt: x1=9, x2=0, RAM[0]=9, RAM[1]=0; fault PC=`0x08`; successful PCs exactly `0x00,0x04`. Substitute faulting `lw x2,1024(x0)` and put a taken branch directly after it: older MEM fault defeats EX redirect. Wrong-path illegal/fetch faults must be discarded. Taken branch at `0x3fc` targeting valid earlier code kills fetch fault `0x400`; untaken branch retires then reports it.

## Trace checking and waves

Check each CPU against the expected results above, then compare their ordered retirements. Keep hand-checked [ISA semantics](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html) as a check against bugs shared by both implementations. Include stores, branches, and writes to x0. Record:

```text
retire_order, token_id, pc, instruction, next_pc,
rd_we, rd, rd_value,
mem_kind, mem_address, mem_size, mem_wmask, mem_wdata, mem_rdata, mmio
```

Use original effective addresses, lane-shifted store data, extended load data, and instruction-local next_pc. Normalize irrelevant fields to zero; rd_we is false for x0. Compare CPUs without cycle/token IDs. Fault records are separate: code, PC, available instruction bits, address.

**Stores write in MEM and retire one cycle later in WB.** Queue physical `{cycle,token_id,pc,address,mask,data}` writes; each retiring store must match exactly one. Update interpreter memory in retirement order; never compare live RAM at every retirement. Killed/faulted tokens cannot write. At drained boundaries all writes must match. Reset begins a new epoch: retain accepted RAM writes even when pending pre-reset retirement is canceled. Keep switch inputs fixed or supply sampled MMIO values to the interpreter.

Capture clock/reset/halted; each stage's valid/PC/instruction/token/fault; source-use/indices/immediate/controls; operands/forwarding; ALU; condition/redirect/target/flush/stall; memory address/size/data/mask/accepted-write; WB/retirement; pending/terminal fault; switch synchronizers/LEDs. Assert x0=0, invalid slots cause no effects, EX/MEM load addresses never forward, faults never write, and halt ends retirement.

## Program and board evidence

Inspect RV32I linked disassembly, disable compressed instructions, and fit each image within 1 KiB. Pseudoinstructions/relaxation can change instructions. [Assembly manual](https://github.com/riscv-non-isa/riscv-asm-manual/blob/main/src/asm-manual.adoc). After directed tests, save generated-program seeds/disassembly; cover every instruction, dependency path, branch outcome, mask, and fault ordering.

Board loop: `lui x10,0x10000; loop: lw x11,4(x10); sw x11,0(x10); jal x0,loop`. Check stable zero/all-one/alternating/walking-bit patterns, reset while held, and a documented RAM signature. Tie unused switches low. Save part/pins/electrical standard, tool versions, constraints, resource/timing reports, memory latency, tests/seeds/counts, and observations. Separate simulation evidence from hardware results.
