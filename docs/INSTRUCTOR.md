# Tutor coding guide

Use two labs weekly with [COURSE.md](COURSE.md). Write the CPU immediately; explain Verilog as each construct appears. The starter uses SystemVerilog syntax. Follow [ARCHITECTURE.md](ARCHITECTURE.md) and its educational RV32I subset.

Each lab adds hardware and checks. Introduce the listed bug to confirm a check fails. Create CPU testbenches as the design grows; the supplied `make test` checks the ALU and image converter.

## Week 1

**1. Fetch.** Write the 32-bit PC, 256-word instruction array, and clock/reset testbench. Explain `logic`, `assign`, arrays, and nonblocking `<=` in `always_ff`. Validate addresses before indexing `[9:2]`. Catch incrementing by one or aliasing `0x400`. Expect reset PC=0, then fetch PCs 0, 4, 8; invalid fetches fault.

**2. Arithmetic.** Add register file, decoder, immediate generation, ALU connections, and writeback for ADDI and the six initial register operations. Explain slices, concatenation, `always_comb`, blocking assignments, and defaulted `case` controls. Catch unsigned SLT or writable x0. Expect ADDI 5, ADDI 7, ADD to produce x3=12; x0 stays zero.

## Week 2

**3. LW/SW.** Add separate data RAM and load/store paths. Explain combinational reads and rising-edge writes. Catch byte addresses used as word indices or CPU reset clearing RAM. Expect storing 42 at byte address 12 then loading it to return 42; address 13 faults without writing.

**4. Complete fourteen.** Add BEQ, JAL, JALR, LUI, and AUIPC. Explain immediate concatenation and next-PC selection. Catch shifting assembled B/J immediates twice. Expect BEQ at `0x20`, offset −8, to select `0x18` when taken or `0x24` otherwise; JAL at `0x20`, offset 16, selects `0x30` and writes link `0x24`.

## Week 3

**5. Extend to thirty-seven.** Add remaining operations, byte masks, and faults; run single-cycle regression. Explain `$signed`, `>>>`, and lane enables. Catch accepting MUL through incomplete decode. Expect LB/LBU at byte 2 of `0x80ff7f01` to return `0xffffffff`/`0x000000ff`. FENCE, ECALL, and EBREAK fault without side effects.

**6. Pipeline registers.** Carry PC, instruction, controls, operands, and valid bits through all four stage boundaries. Explain simultaneous nonblocking updates. Start with independent instructions. Catch invalid slots retaining effective write enables. Expect identical architectural results and N+4 cycles for N independent instructions from an empty pipeline.

## Week 4

**7. Forwarding.** Write prioritized multiplexers and explicit WB→ID bypass. Include store address/data, branch operands, and JALR. Explain qualified comparisons and priority. Catch forwarding load addresses or selecting older writers. Expect `addi x1,x0,1; addi x1,x1,1; add x2,x1,x0` to produce x2=2.

**8. Load-use stall.** Write source-use checks, PC/IF/ID holds, and invalid ID/EX bubbles. Explain enables versus bubbles. Catch freezing the producing load. Expect load 9 followed by doubling ADD to produce 18 with one stall; a dependent store also stalls once.

## Week 5

**9. Redirects/faults.** Add EX flushes and ordered fault tokens. Explain control priority. Catch wrong-path writes and premature halts. Expect EX redirects to squash younger faults; an older MEM fault overrides EX, preserves older WB work, and publishes its stop at WB.

**10. Compare results.** Compare the two CPUs' ordered retirement records and stores. Explain assertions and bounded testbench loops. Catch comparing raw cycle numbers or counting held instructions twice. Expect both CPUs to match architectural results across directed and generated regressions.

## Week 6

**11. Board simulation.** Add MMIO, switch synchronizers, and conditioned reset. Explain ports and two-stage synchronizers. Catch accepted subword peripheral accesses or switch writes. Expect the switches-to-LED program to copy stable patterns; forbidden peripheral accesses fault.

**12. Vivado and Basys 3.** Connect top-level ports and constraints; inspect memory inference and implemented timing, then program the board. Explain ports, pins, and clock constraints. Catch wrong pins, wrong images, or negative slack. Expect timing to pass at the selected clock and three matching switch/LED patterns.

