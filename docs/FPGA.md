# Labs 11–12: run your CPU on Basys3

Implement `rtl/soc/basys3_top.sv`, memories, synchronizers, and MMIO around your tested CPU. The supplied Tcl/XDC files are templates; they do not contain a finished CPU or establish a hardware result.

## 1. Wire the wrapper

Use part `xc7a35tcpg236-1`, `clk` on W5 at **100 MHz / 10 ns**, active-high `btnC` on U18, `sw[15:0]`, and `led[15:0]`. Check your board revision against the [Basys3 manual](https://www.amd.com/content/dam/amd/en/documents/university/aup-boards/XUPBasys3/documentation/Basys3_rm_8_22_2014.pdf) and supplied pins against [Digilent's master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc).

| Resource | Address | Behavior |
|---|---|---|
| Instruction ROM | `0x00000000–0x000003ff` | 256 × 32; asynchronous read; reset PC=0 |
| Separate data RAM | `0x00000000–0x000003ff` | 256 × 32; asynchronous read, rising-edge write |
| LEDs | `0x10000000` | Word store updates low 16 bits; word load zero-extends LEDs |
| Switches | `0x10000004` | Word load zero-extends synchronized inputs; stores fault `STORE_ACCESS` |

MMIO accepts aligned words only. Validate full addresses, widths, and alignment before selecting RAM index `[9:2]`; `0x3fc` is the last word. MMIO must never also write RAM. Invalid accesses follow [the architecture contract](ARCHITECTURE.md): suppress faulting/younger effects, finish older instructions, then halt until reset.

Use distributed LUT memories for the asynchronous baseline; request `rom_style`/`ram_style` and inspect synthesis inference. See [UG474 applications](https://docs.amd.com/r/en-US/ug474_7Series_CLB/Distributed-RAM-Applications), [timing](https://docs.amd.com/r/en-US/ug474_7Series_CLB/Distributed-RAM-Timing-Characteristics), and [UG901 inference examples](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Distributed-RAM-Examples).

Reset PC, x1–x31, valid bits, fault/halt state, synchronizers, and LEDs; keep x0 zero. Retain memories; programs initialize RAM before reading. Reset loops can defeat memory inference. A button reset does not rerun `$readmemh`.

Keep asynchronous IF/MEM reads in the five-stage pipeline. **BRAM is not a drop-in replacement**: clocked reads require fetch/load response tracking, redirect cancellation, revised stalls/forwarding, and exactly-once stores. A single-cycle CPU needs additional cycles or another interface. See [UG473 memory timing](https://docs.amd.com/v/u/en-US/ug473_7Series_Memory_Resources).

## 2. Synchronize inputs and reset

Pass each switch through two flops in the CPU clock domain, mark them `ASYNC_REG`, and put no logic between stages. MMIO reads only stage two. Independent bits are not an atomic snapshot; check settled patterns.

Synchronize `btnC`, then apply synchronous CPU reset; require a reset press after programming. Reset overrides enables, stalls, and writes and clears pipeline valid bits. If asserting reset asynchronously, synchronize release in the actual CPU domain; see [AMD's reset synchronizer](https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/XPM_CDC_ASYNC_RST).

Optional stepping needs a verified extra pin, synchronization, debounce, and a one-cycle **enable**. Gate PC, pipeline state, register/RAM/MMIO writes together; synchronizers continue running. A paused store must not repeat. One step advances a pipeline cycle, not necessarily one retired instruction.

## 3. Simulate the wrapper

Add your own CPU/SoC targets; the supplied targets check the ALU and image converter. Check:

- Pipeline results match the single-cycle baseline, including dependencies and faults.
- A taken redirect kills a younger LED store.
- Reset clears PC/LEDs and discards in-flight writes; disabled CPU state produces no writes.
- `switches_leds` loads `0x10000004`, then stores the loaded value to `0x10000000`.
- ROM word zero matches disassembly and `boot.hex`.

Build/copy `programs/boot.hex` using [SETUP.md](SETUP.md); use `$readmemh("boot.hex", imem)`. Rebuild the bitstream whenever the image changes.

## 4. Create and inspect the project

Close existing projects. In **Windows Vivado's Tcl Console**, substitute your checkout path:

```tcl
source {C:/fpga/RISCV_FPGA/fpga/create_project.tcl}
```

The template fails clearly for missing student top/boot image, unavailable part, wrong Tcl environment, open project, or existing output directory. It refuses overwrite: open `build/vivado/basys3/basys3.xpr` if already created. It adds `rtl/` SystemVerilog, boot image, minimal XDC, and optional `board_timing.xdc`; add vendor IP explicitly.

Open Elaborated Design; check top ports/hierarchy. Run Synthesis; inspect latches, drivers, ROM loading, memory inference, clock network, synchronizers, and utilization. Resolve functional warnings. Keep testbenches outside `rtl/`.

Run Implementation, open the implemented design, then:

```tcl
set course_reports {C:/fpga/RISCV_FPGA/build/reports}
file mkdir $course_reports
report_clocks -file [file join $course_reports clocks.rpt]
report_utilization -file [file join $course_reports utilization.rpt]
report_timing_summary -delay_type min_max -report_unconstrained \
    -file [file join $course_reports timing.rpt]
report_drc -file [file join $course_reports drc.rpt]
report_cdc -file [file join $course_reports cdc.rpt]
check_timing -verbose -file [file join $course_reports check_timing.rpt]
```

Require nonnegative setup/hold slack, zero negative totals, and resolved clock/pulse-width failures. Read [timing summaries](https://docs.amd.com/r/2023.1-English/ug949-vivado-design-methodology/Understanding-Timing-Reports) and [worst paths](https://docs.amd.com/r/2022.2-English/ug906-vivado-design-analysis/Reading-a-Timing-Path-Report).

The minimal XDC is not complete signoff. In `fpga/board_timing.xdc`, justify asynchronous input exceptions only to actual first synchronizer stages; keep interstage paths timed. Document LED observation boundaries. Review every unconstrained endpoint and [CDC report](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Report-Clock-Domain-Crossings). Never hide internal CPU paths or waive missing pin/I/O standards.

A slow enable **does not fix 100 MHz timing**; see [multicycle constraints](https://docs.amd.com/r/2025.1-English/ug903-vivado-using-constraints/Multicycle-Paths?contentId=LiIB~TADBSYbch~YkyhjqA). If needed, fix long paths or use [Clocking Wizard](https://docs.amd.com/r/en-US/pg065-clk-wiz/Core-Architecture) for a genuinely slower buffered clock. Add its `.xci`, generate products, retain constraints, hold reset until locked, synchronize release, and verify [generated clocks](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Generated-Clocks). Keep the oscillator constraint at 10 ns; changing it to 40 ns does not slow hardware.

## 5. Program and test

After checks pass, Generate Bitstream. Connect powered USB-JTAG with a data cable. Use **Hardware Manager → Open Target → Auto Connect → Program Device** and the fresh `basys3_top.bit`, normally under `build/vivado/basys3/basys3.runs/impl_1/`. See [AMD's connection workflow](https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/Connect-to-the-Hardware-Target-in-Vivado?contentId=B7OnJ_38fxwgmppGSiOq~A).

Hold center reset: LEDs clear. Release; test settled switch patterns `0001`, `8000`, `5555`, `aaaa`, `ffff`, `0000`. Repeat reset with nonzero switches: LEDs clear, then recover. Test both CPUs. JTAG configuration disappears on power loss; center reset restarts the CPU.

Save revision, versions, disassembly, logs/waveform, constraints, reports, actual clock, and board observations/video. Compare elapsed time as well as cycles. Without hardware, record “simulation completed; physical-board validation pending.” For failures, inspect reset, ROM/bitstream timestamp, store address/data/enable, then timing and synchronization.
