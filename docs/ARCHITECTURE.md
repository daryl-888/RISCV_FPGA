# Architecture lookup

Build the initial 14-instruction single-cycle CPU, extend it to 37 instructions, then pipeline the same behavior. This is an RV32I subset: no compressed instructions, multiply/divide, CSRs, interrupts, privilege modes, caches, or OS. `FENCE`, `ECALL`, and `EBREAK` fault. [RV32I specification, version 2.1](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html)

## State and memory

| Item | Contract |
|---|---|
| Instructions/registers | 32 bits; x0 always reads zero and ignores writes |
| PC | 32-bit byte address; starts at zero; sequential successor PC+4 |
| Arithmetic | Low 32 bits; overflow does not fault |
| Instruction memory | Separate 256×32-bit array; legal fetch starts `0x000`–`0x3fc`, four-byte aligned |
| Data RAM | Separate 256×32-bit array; byte addresses `0x000`–`0x3ff`; little endian |
| Memory timing | Asynchronous reads; writes on rising edges |
| Register file | Two combinational reads; one rising-edge write, gated by `reg_write && rd != 0` |
| Fault | Failing instruction has no register/RAM/peripheral effect; terminal halt; reset recovers |

The instruction and data ports select independent address spaces. Data stores cannot modify instructions. Supply separate images. Validate the **entire 32-bit address** before indexing with `address[9:2]`; `0x400` must not alias zero.

Reset is active high and sampled on rising edges. While asserted: PC=0; x1–x31=0; LED/synchronizer state=0; pipeline valid bits=0; halt/fault state cleared; register/memory writes disabled. **Neither memory is cleared or reloaded.** Initialize simulation RAM explicitly; board programs initialize RAM they use. Later resets retain RAM. Assert reset for at least two edges and release between edges; condition the board button in the wrapper.

## Decode and immediates

Fixed fields: opcode=`instruction[6:0]`, rd=`[11:7]`, funct3=`[14:12]`, rs1=`[19:15]`, rs2=`[24:20]`, funct7=`[31:25]`. Decode actual source-use flags; immediate bits occupying rs fields are not dependencies.

`sext` extends the sign to 32 bits:

```text
I = sext(instruction[31:20])
S = sext({instruction[31:25], instruction[11:7]})
B = sext({instruction[31], instruction[7], instruction[30:25],
          instruction[11:8], 1'b0})
U = {instruction[31:12], 12'b0}
J = sext({instruction[31], instruction[19:12], instruction[20],
          instruction[30:21], 1'b0})
```

B/J already contain the low zero; do not shift again. Targets must still be four-byte aligned. [Immediate layouts](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html#_immediate_encoding_variants)

| Group | Initial 14 | Add for 37 |
|---|---|---|
| Register ALU | ADD SUB AND OR XOR SLT | SLL SRL SRA SLTU |
| Immediate ALU | ADDI | SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI |
| Loads | LW | LB LH LBU LHU |
| Stores | SW | SB SH |
| Branches | BEQ | BNE BLT BGE BLTU BGEU |
| Jumps | JAL JALR | — |
| Upper immediate | LUI AUIPC | — |

Validate opcode, funct3, funct7, and fixed fields, including RV32 shift-immediate restrictions. Start combinational decode with writes/redirect disabled and an illegal marker; enable controls only for a legal, supported encoding. See official [base encodings](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i) and [RV32 shift encodings](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv32_i).

Use signed comparisons for SLT/SLTI/BLT/BGE and unsigned comparisons for U variants. Register shifts use rs2[4:0]; SRA replicates bit 31. Logical immediates and SLTIU use the sign-extended I immediate. [Integer operations](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html#_integer_computational_instructions)

## Datapath controls

All `pc` values below belong to the executing instruction, carried with it through the pipeline.

| Class/opcode | Sources | Calculation | Register result | Other action |
|---|---|---|---|---|
| Register ALU/0x33 | rs1,rs2 | selected operation | ALU | — |
| Immediate ALU/0x13 | rs1 | rs1 op I/shift | ALU | — |
| Load/0x03 | rs1 | rs1+I | extended memory data | read |
| Store/0x23 | rs1,rs2 | rs1+S | none | masked write of rs2 |
| Branch/0x63 | rs1,rs2 | compare sources; target=pc+B | none | redirect if taken |
| JAL/0x6f | none | target=pc+J | pc+4 | redirect |
| JALR/0x67 | rs1 | target=(rs1+I)&0xfffffffe | pc+4 | redirect |
| LUI/0x37 | none | U | U | — |
| AUIPC/0x17 | none | pc+U | ALU | — |

Default next PC is pc+4. Check selected target alignment **after** JALR clears bit zero; never clear bit one. An untaken branch does not validate its unused target. [Control transfers](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html#_control_transfer_instructions)

Single-cycle path: PC → instruction memory → decode/register reads → operand muxes → ALU → data memory → writeback mux → register file. At the edge, apply valid, fault-free writes and next PC. On fault, suppress writes, hold the failing PC, capture the fault, and halt. Measure the complete path, especially loads, for timing.

## Data accesses and MMIO

For address `a`, offset=`a[1:0]`. Bytes allow any RAM address; halfwords require `a[0]==0`; words require `a[1:0]==0`. The entire access must fit. Reject misalignment; never split an access.

| Store | Offsets | Byte mask | Write bus |
|---|---|---|---|
| SB | 0–3 | `0001 << offset` | `(rs2 & 0xff) << (8*offset)` |
| SH | 0,2 | `0011 << offset` | `(rs2 & 0xffff) << (8*offset)` |
| SW | 0 | `1111` | rs2 |

Only masked bytes change. Set `shifted = read_word >> (8*offset)`. LB/LH sign-extend its low 8/16 bits; LBU/LHU zero-extend them; LW returns the word. [Load/store rules](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html#_load_and_store_instructions)

| Data address | Accepted access | Meaning |
|---|---|---|
| `0x00000000`–`0x000003ff` | Implemented RAM sizes | Data RAM |
| `0x10000000` | Aligned LW/SW | LED register: store low 16 bits; read zero-extended |
| `0x10000004` | Aligned LW | Synchronized switches: low 16 bits; upper bits zero |
| Other addresses | None | Access fault |

Subword MMIO accesses and switch writes fault. Loads to x0 still validate accesses. Synchronize each switch through two clocked stages; expose stage two. This neither debounces nor makes multi-bit changes atomic; hold test patterns stable.

Infer distributed/LUT memory where supported and inspect synthesis. Registered-read block RAM changes this timing contract and requires stages or wait states.

## Five-stage pipeline

| Stage | Work / outgoing state |
|---|---|
| IF | Sequential fetch; IF/ID: valid, PC, instruction, fetch fault, token ID |
| ID | Decode/read/WB bypass; ID/EX: metadata, controls, source indices/values, rd |
| EX | Forward/ALU/compare/redirect; EX/MEM: result/address, forwarded store data, next_pc, controls/fault |
| MEM | Validate/access RAM or MMIO; MEM/WB: final value, memory metadata, controls/fault |
| WB | Register write and ordered retirement |

An invalid slot is a bubble: no write, redirect, retirement, or fault. Carry instruction identity and controls with every valid token.

**Forwarding:** independently select every used EX source from (1) valid, fault-free EX/MEM non-load producer, (2) valid, fault-free MEM/WB final value, (3) captured ID value. Producers must write matching nonzero rd. Newest wins. Never forward a load's effective address. Jumps forward pc+4; LUI/AUIPC forward their register results. Forward branch operands, JALR base, store address, and store data; choosing an immediate ALU input must preserve forwarded store data. Add explicit WB-to-ID bypass for simultaneous reads/writes.

**Load-use:** all source operands, including store data, are consumed in EX.

```text
load_use = ID.valid && EX.valid && EX.is_load && EX.rd != 0 &&
           ((ID.uses_rs1 && ID.rs1 == EX.rd) ||
            (ID.uses_rs2 && ID.rs2 == EX.rd))
```

On this condition, hold PC/IF-ID for one edge, insert an invalid ID/EX slot, and advance older stages. Exactly one stall precedes the consumer's MEM/WB forwarding, including `lw; sw` dependencies. Adjacent ALU→store uses forwarding with zero stalls.

**Redirect:** resolve branches/JAL/JALR in EX. A taken redirect installs its target and invalidates next IF/ID and ID/EX, discarding two younger instructions. The target fetch starts next cycle. Untaken branches have no penalty. Preserve the redirecting and older tokens.

## Ordered faults

Carry early faults with their tokens, suppressing ordinary side effects. At a surviving MEM fault: suppress its writes; kill younger tokens/redirects; stop fetch; allow older WB to retire; move the fault to WB. At the next edge emit one terminal fault record, assert halted, and leave the pipeline empty.

An older EX redirect kills IF/ID faults. An older MEM fault defeats an EX redirect. Front-end priority:

```text
reset > halted/draining fault > MEM fault > fault-free EX redirect
      > load-use stall > advance
```

Front-end stopping must not freeze fault advancement or older-stage draining. Aligned out-of-range jumps complete, including links; target fetch then faults. Selected misaligned targets fault the branch/jump and suppress its link.

Fault names: `ILLEGAL_INSTRUCTION`, `UNSUPPORTED_INSTRUCTION`, `INSTRUCTION_MISALIGNED`, `INSTRUCTION_ACCESS`, `LOAD_MISALIGNED`, `LOAD_ACCESS`, `STORE_MISALIGNED`, `STORE_ACCESS`. Illegal means no accepted encoding; unsupported means recognized but excluded, including FENCE/ECALL/EBREAK. Numeric codes are unspecified. Data misalignment takes precedence over region/access failure. Capture code, PC, instruction, and relevant address; mark instruction unavailable for fetch faults.

Stores physically write at the end of MEM, then retire at the end of WB. Queue physical writes and match them to retirement; comparing live RAM after each retirement is insufficient. Reset starts a new trace epoch while retaining already accepted RAM writes. See [verification](VERIFICATION.md).

## Performance and completion

For N successful instructions from an empty pipeline: ideal cycles=N+4; add one per load-use stall and two per taken redirect, counting actual nonoverlapping penalties. Exclude reset/fault tails. Execution time=instruction count×CPI×clock period. Report measured cycles, retirement count, constraints, and timing slack; these documents contain no FPGA performance result.

Both CPUs must pass the same architectural checks. Memory sizes, reset, MMIO, pipeline timing, and fault draining are course platform choices, not prescribed RISC-V implementations.
