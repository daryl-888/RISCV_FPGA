# From a simulated CPU to a Basys3

Your board milestone is a processor executing a program that reads switches and writes LEDs. The final demonstration must show that the CPU, memories, pipeline controls, and memory-mapped I/O work together. Connecting switches directly to LEDs is a useful first wiring test, but it does not meet the CPU milestone.

This guide is a later lab. You implement `rtl/soc/basys3_top.sv`, the processor, memories, input conditioning, and I/O decoder. The repository provides the project template and pin constraints; it does not provide a finished CPU or claim a successful hardware run.

## 1. Fix the hardware contract before coding

The Basys3 uses an Artix-7 `XC7A35T-1CPG236C`; Vivado's part identifier is `xc7a35tcpg236-1`. Its board oscillator is 100 MHz. The course uses these top-level ports:

| Port | Purpose | Board connection |
|---|---|---|
| `clk` | Real clock input | W5, 100 MHz, 10 ns period |
| `btnC` | Active-high reset request | U18, center button |
| `sw[15:0]` | Human-operated inputs | All 16 slide switches |
| `led[15:0]` | Registered MMIO output | All 16 individual LEDs |

These board facts are documented in the [Digilent Basys3 reference manual, hosted by AMD](https://www.amd.com/content/dam/amd/en/documents/university/aup-boards/XUPBasys3/documentation/Basys3_rm_8_22_2014.pdf). The exact switch and LED pins in `fpga/basys3_minimal.xdc` were checked against [Digilent's master constraints](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc). Check the board revision printed on your board against these references.

The baseline is one synchronous clock domain. First attempt the real 100 MHz clock. A design is acceptable at a lower, correctly generated and constrained clock if required by its measured timing. Do not promise a frequency before implementation.

| Resource | Capacity/address | Required baseline behavior |
|---|---|---|
| Instruction ROM | 256 × 32 bits; instruction byte addresses `0x00000000–0x000003ff` | Combinational read; reset PC is zero |
| Data RAM | 256 × 32 bits; data byte addresses `0x00000000–0x000003ff` | Combinational read, rising-edge write |
| LED register | Data address `0x10000000` | Aligned word store updates bits 15:0; aligned load returns zero-extended LED value |
| Switch register | Data address `0x10000004` | Aligned word load returns zero-extended synchronized switches; stores raise `STORE_ACCESS` with no write |

The two memories are independent Harvard memories: instruction address zero and data address zero select different storage. Word operations require `address[1:0] == 0`; the last valid word begins at `0x3fc`. Decode the full address before selecting RAM index bits `[9:2]`. An MMIO access must never also write RAM. MMIO supports only aligned word accesses; byte/halfword peripheral accesses fault. Unsupported and misaligned accesses raise the course fault, suppress their side effects and younger instructions, allow older instructions to finish, then halt until reset. Follow the architecture contract for fault classification and ordering; this baseline does not implement privileged RISC-V trap handling.

## 2. Preserve memory timing when moving to the FPGA

The single-cycle design needs instruction and load data before the next active clock edge. Small ROM/RAM arrays with asynchronous reads are therefore the baseline. On Artix-7, distributed memory uses LUT resources and supports this read behavior. See [AMD UG474: distributed RAM applications](https://docs.amd.com/r/en-US/ug474_7Series_CLB/Distributed-RAM-Applications) and [distributed RAM timing](https://docs.amd.com/r/en-US/ug474_7Series_CLB/Distributed-RAM-Timing-Characteristics).

For synthesis, request distributed implementation with suitable `rom_style`/`ram_style` attributes and write an appropriate memory inference pattern. Attributes are requests; inspect the synthesized result. A conceptual RAM pattern is:

```systemverilog
(* ram_style = "distributed" *) logic [31:0] words [0:255];
assign read_data = words[word_index];
always_ff @(posedge cpu_clk) begin
    if (cpu_enable && valid_store)
        words[word_index] <= write_data;
end
```

This fragment omits address validation, reset policy, byte enables, and the MMIO mux. It illustrates memory timing only. Compare your complete implementation with [AMD UG901 distributed RAM examples](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Distributed-RAM-Examples).

Do not clear the entire RAM in a reset loop and assume inference will be unchanged. Reset PC, integer registers `x1–x31`, pipeline valid bits, fault/halt state, synchronizer state, and the LED register; keep `x0` fixed at zero. Retain the memories, and have programs initialize the RAM locations they read. A synthesizable initialization file can supply initial ROM contents, but a push-button reset does not rerun `$readmemh`. Check synthesis messages and the implemented ROM data.

The five-stage baseline is still **IF → ID → EX → MEM → WB with asynchronous instruction and data reads**. IF reads instruction ROM into IF/ID; MEM reads data RAM into MEM/WB. Pipeline registers separate the combinational work. This gives a clear baseline for forwarding, load-use stalls, branch flushing, and performance comparison.

Artix-7 block RAM has clocked read behavior. Replacing the arrays with BRAM changes when instruction or load data becomes available, even if the port widths match. It is an optional redesign: specify request/response timing, hold or tag outstanding fetches, cancel stale responses after redirects, revise load-use stalls and forwarding, and carry PC/control/valid metadata with the matching response. Recheck stores for exactly-once effects while stalled. The single-cycle design would need additional cycles or a different memory interface. Follow [AMD UG473: 7 Series memory resources](https://docs.amd.com/v/u/en-US/ug473_7Series_Memory_Resources) for the primitive timing. BRAM is not a drop-in area optimization for this lab.

## 3. Condition external inputs

Mechanical inputs are not synchronized to the clock. Build and test the board wrapper separately from the CPU.

1. Pass each switch through a two-flop synchronizer in the CPU clock domain. Mark the synchronizer registers appropriately, for example with `ASYNC_REG`, and allow no logic between their stages.
2. Use only the second-stage switch values in MMIO. Synchronizing each bit reduces metastability risk; it does not make a changing 16-bit bus an atomic snapshot. For this demo, set a pattern and allow it to settle before checking it.
3. Synchronize the reset request. A simple baseline uses two-flop synchronization followed by a synchronous CPU reset. Hold the center button long enough to be sampled. Document startup behavior and require a reset press after programming.
4. If using asynchronous reset assertion, synchronize its release in the actual CPU clock domain. AMD provides an [asynchronous reset synchronizer macro](https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/XPM_CDC_ASYNC_RST). Do not send an unsynchronized button directly to every architectural register.
5. Give reset priority over CPU enables, stalls, writes, and pipeline advances. Reset must empty all pipeline valid bits so stale instructions cannot write a register, RAM, or MMIO.

The minimum constraints do not expose a step button. To add one, introduce `btnU` and its verified T18/LVCMOS33 constraint. Synchronize it, require a stable level for a chosen debounce interval, then detect a rising edge to create a one-clock `step_pulse`. At 100 MHz, a 10 ms debounce interval is 1,000,000 clock cycles; recalculate after a real clock-frequency change. Test press, bounce, hold, and release.

Use that pulse as a **clock enable**, not a clock. All state that represents CPU progress must agree on the enable: PC, pipeline registers, register-file writes, RAM writes, and MMIO writes. Input synchronizers and the debounce counter keep running every real clock. A paused pipeline must not repeatedly execute a pending store. In a pipeline, one step advances one clock cycle; it does not necessarily retire one instruction.

## 4. Separate observation speed from timing closure

A slow enable makes activity easy to observe. It does not automatically change Vivado's timing requirements. Logic connected to a 100 MHz clock remains subject to that clock's constraints unless a correctly justified timing exception changes the relationship. The baseline course does not use multicycle exceptions to hide a long CPU path; see [AMD's multicycle-path explanation](https://docs.amd.com/r/2025.1-English/ug903-vivado-using-constraints/Multicycle-Paths?contentId=LiIB~TADBSYbch~YkyhjqA).

If a correct single-cycle datapath misses 10 ns:

1. Read the worst path. Identify launch register, combinational logic, and capture register.
2. Remove accidental long logic or incorrect inference and rerun implementation.
3. If needed, add Clocking Wizard configured for the real 100 MHz input and a lower output frequency, such as 25 MHz if the IP accepts that configuration. Use its clock buffer output to clock the entire CPU and board-conditioning domain.
4. Hold that domain in reset until the clock is locked, and synchronize reset release to the output clock. Keep the input pin constrained at 10 ns; verify the derived output clock period in `report_clocks`.
5. Add the IP `.xci`, generate its output products, retain its constraints, and rerun all implementation reports. Extend the project-creation template so another student can reproduce this configuration.

Clocking Wizard creates an appropriate clock network; a fabric counter bit used as a clock is a different design requiring additional clocking analysis. See [PG065 core architecture](https://docs.amd.com/r/en-US/pg065-clk-wiz/Core-Architecture) and [UG903 generated clocks](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/Generated-Clocks). Merely changing `create_clock` to 40 ns while leaving the CPU on the 100 MHz oscillator misdescribes the hardware.

## 5. Complete simulation evidence before synthesis

Keep the same CPU RTL and memory semantics in simulation and synthesis. Put testbenches outside `rtl/`.

- [ ] Unit tests cover the ALU, register file including `x0`, immediate construction, decoder, and memory address checks.
- [ ] Single-cycle programs produce expected architectural results and terminate or reach a defined loop within a bounded cycle count.
- [ ] Pipeline traces match the single-cycle architectural results, with valid bits determining which instructions have effects.
- [ ] Directed tests cover EX/MEM and MEM/WB forwarding, load-use dependencies, store data dependencies, branches, jumps, flushes, and reset with instructions in flight.
- [ ] A taken branch kills a younger store to the LED address; the LED register remains unchanged.
- [ ] Reset clears LEDs and PC; holding a CPU enable low prevents repeated architectural writes.
- [ ] The switch-to-LED program passes against the wrapper's synchronized switch/MMIO model.
- [ ] The simulated ROM word at address zero matches the disassembly and `boot.hex`.

The provided `make test` and `make lint` cover the starter ALU. Add and document separate CPU and SoC targets as you implement them. Keep a test log and one annotated waveform that explains a real dependency or redirect; a waveform without expected results is weak evidence.

## 6. Create and inspect the Vivado project

Build the program and create `programs/boot.hex` as described in [SETUP.md](SETUP.md). In **Windows Vivado**, close any existing project and use the Tcl Console:

```tcl
source {C:/fpga/RISCV_FPGA/fpga/create_project.tcl}
```

Replace the path with your checkout. The script creates `build/vivado/basys3/basys3.xpr` only after the student top and boot image exist. It adds `.sv` files under `rtl/`, selects `basys3_top`, adds the memory file, and adds the minimal constraints. Review the Sources panel and package/include order. Optional vendor IP requires explicit additions. If the project already exists, open its `.xpr`; the script intentionally refuses to overwrite it.

Before synthesis, **Open Elaborated Design** and inspect the top ports and hierarchy. Ensure the selected CPU is instantiated and unused alternative modules are not accidentally driving outputs. Then use **Run Synthesis**. Open the synthesized design and examine:

- Inferred latches, undriven signals, multiple drivers, missing files, and unexpected constant outputs.
- Whether the instruction ROM and data RAM use the intended distributed resources.
- Register and LUT usage, including whether a reset loop prevented memory inference.
- The clock network and synchronizer structure.

Resolve warnings that affect behavior; document narrowly justified warnings. Do not waive unconstrained pins or unspecified I/O standards to force bitstream generation.

## 7. Implement and judge the result

Run **Implementation**, then **Open Implemented Design**. In its Tcl Console, with this checkout path substituted:

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

Require nonnegative setup and hold slack, zero negative totals, and no unresolved clock/pulse-width failures for the intended operating conditions. Read the failing paths when these conditions are not met; a produced `.bit` file alone is not timing signoff. [AMD explains the timing-summary checks](https://docs.amd.com/r/2023.1-English/ug949-vivado-design-methodology/Understanding-Timing-Reports) and [individual timing paths](https://docs.amd.com/r/2022.2-English/ug906-vivado-design-analysis/Reading-a-Timing-Path-Report).

The supplied XDC is a **pin-and-clock starting point**, not a complete timing signoff file. Human switches and buttons have no synchronous relationship to the CPU clock, and LEDs have no external receiving clock. After locating your actual synchronizer pins, document narrowly scoped asynchronous-input exceptions up to only their first receiving stages in `fpga/board_timing.xdc`. Keep the path between synchronizer stages timed. Treat LED output boundaries explicitly as asynchronous observation endpoints, with a stated rationale. Review all unconstrained endpoints: no internal CPU path may be left unconstrained or hidden behind a broad exception. Never add a false path through the datapath merely to improve the report.

Review CDC results and the actual external-input circuitry, even if only one internal clock is present. A tool report does not replace checking that every physical input enters through the intended synchronizer. See [AMD UG906 CDC reporting](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Report-Clock-Domain-Crossings). Have the tutor review the exceptions, clock report, and worst path before board acceptance.

## 8. Program and test the physical board

After timing and design-rule checks pass, choose **Generate Bitstream**. Use a data-capable USB cable in the board's USB-JTAG connector, power the board, and open **Hardware Manager → Open Target → Auto Connect**. Select the detected Artix-7 device and **Program Device** with the newly generated `basys3_top.bit`. The project run normally places it under `build/vivado/basys3/basys3.runs/impl_1/`; verify the actual run path and timestamp. AMD documents the [hardware-target connection workflow](https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/Connect-to-the-Hardware-Target-in-Vivado?contentId=B7OnJ_38fxwgmppGSiOq~A).

JTAG loads the current FPGA configuration; power loss removes it. The board's configuration/PROG control and the course's center-button CPU reset serve different purposes. Use center reset to restart the CPU without loading a new bitstream. See the [Basys3 programming description](https://www.amd.com/content/dam/amd/en/documents/university/aup-boards/XUPBasys3/documentation/Basys3_rm_8_22_2014.pdf).

Run this acceptance sequence and record actual observations:

| Test | Procedure | Required result |
|---|---|---|
| Reset | Set switches to zero; press and hold center reset | LED register clears; CPU remains reset |
| Known pattern | Release reset; set `0x0001`, then `0x8000` | The corresponding endpoint LED lights after input synchronization and loop execution |
| Bit order | Set `0x5555`, `0xaaaa`, `0xffff`, `0x0000` | Each stable pattern appears exactly on LEDs |
| Live loop | Change several switches while the program runs | Output follows the final stable pattern without reprogramming |
| Restart | Hold center reset while switches are nonzero; release | LEDs clear while reset is held, then return to the sampled pattern |
| Pipeline equivalence | Build the same program for the pipelined implementation | Same stable visible results; simulation trace accounts for different cycle counts |

A switch transition may briefly pass through intermediate patterns because the inputs are independent. Check the settled result. The acceptance program should repeatedly load address `0x10000004` and store address `0x10000000`. In the pipeline, this sequence is also a useful test of load-to-store data handling. Confirm the store value comes from the load result rather than a stale register operand.

For a stronger demonstration, use a second program that writes arithmetic-derived patterns or delayed counter values. Keep its disassembly and simulation results so an observer can distinguish CPU execution from a direct switch-to-LED wire.

## 9. Submit evidence, not an unsupported success claim

Save the source revision, tool versions, program source and disassembly, simulation logs, one annotated waveform, constraints, synthesis/implementation reports, actual clock frequency, and a short photo/video of the board acceptance sequence. Record the FPGA resource usage and compare single-cycle versus pipelined cycles for the same program. Do not compare performance using cycle count alone when their clock periods differ.

If no board was available, report **simulation completed; physical-board validation pending**. If timing failed, report the failing slack and path and continue fixing the design. A checked-in constraints file or successful simulation does not establish that the board works.

## Troubleshooting by evidence

| Symptom | First useful evidence |
|---|---|
| Device not found | USB data cable, board power, Windows cable driver, and Hardware Manager target list |
| All LEDs remain zero | Reset state, ROM loading messages, PC activity, decoded store address and write enable |
| LEDs show reversed bit order | XDC mapping and the top-level bus declaration |
| Single-cycle works; pipeline fails | Valid bits, load-use handling, store-data forwarding, and branch-killed writes |
| Simulation works; hardware is intermittent | Implemented timing, reset release, input synchronization, and unintended generated clocks |
| Step repeats a store while paused | Whether RAM/MMIO writes are gated with CPU progress |
| RAM unexpectedly uses many flip-flops | Read/write/reset coding pattern and synthesis inference report |
| Program edits have no effect | `boot.hex` contents, new synthesis/bitstream timestamp, and the selected programming file |
