# RISCV_FPGA

A six-week, tutor-led course in building and verifying a RISC-V processor: digital logic → single-cycle CPU → five-stage pipeline → Digilent Basys 3.

Designed for an incoming college freshman and a tutor refreshing computer architecture. Start with explanations, predict behavior on paper, implement a small piece, and prove it with an automated test and a waveform.

## Start here

1. Tutor: read [the teaching plan](docs/COURSE.md) and [instructor preparation and answers](docs/INSTRUCTOR.md).
2. Student: copy [the workbook](docs/WORKBOOK.md) into your own learning journal.
3. Follow [setup](docs/SETUP.md), then run `make test` in a Linux/WSL terminal at this repository's root.
4. Learn the [CPU contract](docs/ARCHITECTURE.md) before implementing instructions.
5. Use [verification](docs/VERIFICATION.md) at every milestone and [the FPGA guide](docs/FPGA.md) before programming a board.

## What is included

- 24 guided sessions: four 90-minute meetings each week for six weeks, plus independent practice.
- Tutor refreshers, worked examples, student worksheets, mastery gates, and debugging exercises.
- An executable 32-bit ALU example with directed tests, waveform generation, and continuous integration.
- Assembly examples, a checked binary-to-memory-image converter, and a minimal Basys 3 constraints/project template.
- A [reading map and technical review](docs/REFERENCE_REPO.md) of [daryl-888/RISC_V](https://github.com/daryl-888/RISC_V).
- Instructions to [build and publish your own repository](docs/BUILD_YOUR_REPO.md).

**This is a curriculum and starter repository.** The complete single-cycle CPU, pipelined CPU, board wrapper, and their testbenches are student deliverables developed during the course. The supplied ALU simulation does not certify either CPU. See [validation status](docs/VALIDATION.md) for checks actually performed.

## Six-week route

| Week | Build | Evidence needed to advance |
|---|---|---|
| 1 | Binary arithmetic, combinational logic, clocked state, ALU | Explain a waveform and pass ALU tests |
| 2 | ISA decode, register file, single-cycle datapath, word memory | Trace arithmetic and load/store instructions |
| 3 | Branches, jumps, initial subset, single-cycle verification | Directed program results and memory-boundary tests |
| 4 | Pipeline registers, forwarding and load-use stalls | Correct results for independent and dependent programs |
| 5 | Flushes, trace comparison, expanded ISA, faults | Hazard regression, 37-instruction coverage and wrong-path side-effect suppression |
| 6 | Board integration, synthesis, timing, demonstration | Passing simulation, timing report, and repeatable board demo |

Treat weeks as a suggested pace; mastery gates control progression. A beginner who needs more repetition should extend a week instead of skipping a verification gate.

## Reproducible commands

```sh
make test       # ALU checks plus memory-image converter tests
make lint       # Verilator checks the supplied ALU
make waves      # runs ALU test; writes build/waves/alu.vcd
make program PROGRAM=arithmetic
make program PROGRAM=switches_leds
```

`make program` additionally requires the RISC-V GNU bare-metal toolchain; it produces `.elf`, disassembly, `.bin`, and a 256-word `.hex` in `build/programs/`. CPU simulation commands are added by the student when the CPU exists. The [setup guide](docs/SETUP.md) explains prerequisites and command locations.

## Repository layout

```text
docs/                 course, tutor notes, worksheets, specifications and guides
rtl/common/alu.sv     supplied combinational teaching example
rtl/single_cycle/     student single-cycle implementation
rtl/pipeline/         student pipeline implementation
rtl/soc/              student memory/I/O and Basys 3 wrapper
sim/                  supplied ALU testbench; future CPU tests
programs/             assembly programs and linker layout
scripts/              memory-image converter and converter checks
fpga/                 constraints and a project creation template
.github/workflows/    starter checks on pushes and pull requests
```

## Scope

The course targets a little-endian RV32I **educational subset**: 37 integer arithmetic, load/store, branch and jump instructions, with a smaller initial subset. FENCE, ECALL, EBREAK, privileged instructions and extensions are outside this contract and stop execution through the documented fault mechanism. It is not a claim of complete ISA or platform compliance.

The baseline uses small asynchronous-read instruction/data memories so the single-cycle and classic five-stage models agree with their timing diagrams. FPGA block RAM has different read timing and is a later design extension. No operating system, cache, interrupts or external DRAM are required.

## Publishing and reuse

Keep source, tests, memory images used for reproducible examples, and learning reports under version control. Generated binaries, waveforms and Vivado project outputs stay in `build/`. The reference repository is linked for study; its RTL is not bundled here. Choose a license before inviting redistribution; see [publishing instructions](docs/BUILD_YOUR_REPO.md).
