# RISCV_FPGA

Build a single-cycle RISC-V CPU, convert it to a five-stage pipeline, and run it on a Basys 3. Learn Verilog by writing and testing the actual processor modules.

**[Follow the build guide](docs/COURSE.md)** — 12 build labs across six weeks. Start with the PC and instruction memory, then add each working piece.

| Week | Build |
|---|---|
| 1 | PC, instruction memory, register file, ALU and arithmetic execution |
| 2 | Data memory, branches, jumps and the initial 14-instruction CPU |
| 3 | Complete the 37-instruction subset; add pipeline registers |
| 4 | Forwarding and load-use stalls |
| 5 | Redirects, faults and comparison against the single-cycle CPU |
| 6 | MMIO, board-wrapper simulation, Vivado timing and Basys 3 execution |

## Start coding

Install tools with [SETUP.md](docs/SETUP.md), then run the supplied example:

```sh
make test
make waves
```

Continue with **lab 1** in the build guide. The repository supplies a tested ALU, assembly examples, memory-image conversion, and FPGA templates. You build the full CPUs and board wrapper during the labs. See [validation results](docs/VALIDATION.md).

## Use when needed

- [Tutor coding notes](docs/INSTRUCTOR.md) and [build log](docs/WORKBOOK.md)
- [Architecture reference](docs/ARCHITECTURE.md) and [test programs/results](docs/VERIFICATION.md)
- [Basys 3 build steps](docs/FPGA.md)
- [Existing RISC_V repository: files and corrections](docs/REFERENCE_REPO.md)
- [Build and publish your own repository](docs/BUILD_YOUR_REPO.md)

The CPU targets an educational RV32I subset with small separate instruction/data memories and no operating system. Source goes in `rtl/`, tests in `sim/`, assembly in `programs/`, and generated files in `build/`. The technical references specify the exact memory, reset, instruction and fault behavior.
