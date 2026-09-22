# CPU build log

Name: __________  Repository: __________  Start date: __________

Work through two labs weekly in [COURSE.md](COURSE.md). Record changed files, the exact command or Vivado action, expected result, observed result, and commit. Link a short failing trace when debugging. Replace placeholders with actual paths and values. The starter's `make test` runs only the ALU test; add CPU tests as you add hardware.

Use [ARCHITECTURE.md](ARCHITECTURE.md) for the educational RV32I subset and [VERIFICATION.md](VERIFICATION.md) for test cases.

| Lab | Files | Command | Expected | Observed | Commit |
|---|---|---|---|---|---|
| 1: PC/fetch | ____ | ____ | Reset PC=0; fetch 0,4,8; reject invalid addresses. | ____ | ____ |
| 2: Registers/ALU/decode | ____ | ____ | ADDI/R-type gives x3=12; x0 stays zero. | ____ | ____ |
| 3: LW/SW | ____ | ____ | Store/load 42 at address 12; reject address 13. | ____ | ____ |
| 4: Complete fourteen | ____ | ____ | Branch targets, jump links, LUI, AUIPC pass. | ____ | ____ |
| 5: Extend thirty-seven | ____ | ____ | All operations and single-cycle fault cases pass. | ____ | ____ |
| 6: Pipeline registers | ____ | ____ | Independent instructions match; invalid slots have no effects. | ____ | ____ |
| 7: Forwarding | ____ | ____ | Newest writer wins; WB→ID/store/branch paths pass. | ____ | ____ |
| 8: Load-use stall | ____ | ____ | Load 9 then double gives 18; one bubble. | ____ | ____ |
| 9: Redirects/faults | ____ | ____ | Wrong-path writes disappear; fault ordering passes. | ____ | ____ |
| 10: Comparison regression | ____ | ____ | Both cores match architectural results and stores. | ____ | ____ |
| 11: MMIO/wrapper | ____ | ____ | Stable switches reach LEDs; forbidden accesses fault. | ____ | ____ |
| 12: Basys 3 | ____ | ____ | Timing passes; three switch/LED patterns match. | ____ | ____ |

## Evidence milestones

**Single-cycle — after lab 5:** commit ____; regression command/report ____; instruction/data images ____; thirty-seven-instruction and fault results ____.

**Pipeline — after lab 10:** commit ____; comparison report ____; forwarding, one-bubble load-use, flush, and fault-order traces ____.

**FPGA — after lab 12:** commit/bitstream ____; selected clock and timing report ____; inferred memory type ____; board/reset checks ____; three switch/LED observations ____.

