# Validation record

The course is a teaching package with an executable starter, not a completed processor.

## Checks performed

Environment: Ubuntu through WSL, Verilator **5.032**. Commands executed from the repository root:

| Check | Result |
|---|---|
| `make lint` | Passed; ALU lint completed without warnings |
| `make test` | Passed; 4 memory-image converter tests and 21 directed ALU checks |
| `make waves` | Passed; 21 ALU checks and `build/waves/alu.vcd` generated |

The ALU checks cover wraparound arithmetic, Boolean operations, signed/unsigned comparison, logical/arithmetic shifts, five-bit shift amounts, and a default control value. The converter checks word/byte endianness, padding and invalid inputs. These checks validate those supplied components only.

## Checks to run during the course

- `make program PROGRAM=arithmetic` and `make program PROGRAM=switches_leds` using the RISC-V GNU bare-metal toolchain.
- All student-created leaf and CPU testbenches, ordered trace comparison, hazard regression and fault handling.
- Basys 3 wrapper simulation, Vivado synthesis, implementation, setup/hold timing, DRC review and actual board execution.

Vivado and physical-board checks have not been performed for this starter because the course CPU and board wrapper are student deliverables. The project Tcl deliberately stops if that wrapper is missing. The reference processor was reviewed statically at the commit recorded in [REFERENCE_REPO.md](REFERENCE_REPO.md); it was not certified by the starter tests.

## Record your own evidence

For every milestone, append: date, source commit, simulator/compiler versions, exact command, pass/fail count, program image, waveform or report link, and one sentence explaining the result. Record limitations next to the result, not in a different document.
