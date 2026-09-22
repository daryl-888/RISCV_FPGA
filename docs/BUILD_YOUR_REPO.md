# Build and maintain the repository yourself

This guide starts from either the published course or a blank repository. Keep a history that makes the design's development understandable: one working idea, its tests, and its explanation per commit.

## Route A: follow this course in your own copy

Fork [daryl-888/RISCV_FPGA](https://github.com/daryl-888/RISCV_FPGA) using GitHub, then clone your fork. In the commands below, replace `YOUR_USERNAME` before running them.

```sh
git clone https://github.com/YOUR_USERNAME/RISCV_FPGA.git
cd RISCV_FPGA
make test
git switch -c week-01-foundations
```

Use [SETUP.md](SETUP.md) if `make` or `verilator` is missing. Do not paste shell prompts or run Linux installation commands in a PowerShell window.

## Route B: build the structure from a blank folder

Create a public empty repository on GitHub named `RISCV_FPGA`. Leave the initial README, license and gitignore unchecked if you will create them locally. In a Linux/WSL terminal:

```sh
mkdir RISCV_FPGA
cd RISCV_FPGA
git init -b main
mkdir -p docs rtl/common rtl/single_cycle rtl/pipeline rtl/soc sim programs scripts fpga .github/workflows
```

Write the README first: scope, supported instructions, commands and measured status. Then add `.gitignore` for build outputs. Copy or author the leaf testbench, ALU, Makefile, and tool checks before writing a whole CPU. Git tracks files, not empty directories; put a short README in each planned implementation directory.

Configure your own commit name and email with `git config user.name` and `git config user.email` if Git requests them. Use a GitHub-provided no-reply email if you prefer to keep your personal address out of public commits. Never paste a password or access token into a source file or remote URL.

```sh
git add README.md .gitignore .gitattributes docs rtl sim programs scripts fpga Makefile .github
git diff --cached --stat
git diff --cached
git commit -m "Add course structure and tested ALU example"
git remote add origin https://github.com/YOUR_USERNAME/RISCV_FPGA.git
git push -u origin main
```

For an existing nonempty remote, clone it first and add your files there. Do not use force-push to overcome an unrelated-history error.

## Development sequence

| Milestone | Suggested branch | Commit only after |
|---|---|---|
| Foundations | `week-01-foundations` | ALU and clocked-state exercises pass |
| Single-cycle skeleton | `week-02-single-cycle` | Minimal instruction subset and reset pass |
| Single-cycle expansion | `week-03-isa-tests` | ISA, boundary and fault tests pass |
| Pipeline | `week-04-pipeline` | Valid bits, independent instructions and forwarding pass |
| Pipeline verification | `week-05-hazards` | Stalls, flushes and ordered trace comparisons pass |
| Board system | `week-06-basys3` | Wrapper simulation, timing and hardware demonstration pass |

Use `git switch -c BRANCH_NAME` at each milestone. Commit short working steps rather than waiting until a week ends. A useful commit message says what became possible, such as “Forward latest ALU result into branch comparison.”

## Daily workflow for a student

1. Pull your current branch before starting work.
2. Write the expected behavior and a test for today's small change.
3. Run the test, make the change, rerun it and the existing relevant regression.
4. Save a brief report from the workbook: prediction, observation, explanation.
5. Review `git diff` and `git status`; add named files deliberately.
6. Commit, push, and ask your tutor to review the explanation and evidence.

Use an issue for a reproducible bug: expected behavior, observed behavior, program/input, tool versions, and the failing assertion. Use a pull request to explain the change and link the issue. The provided CI checks the starter only; extend it with actual CPU targets when those tests exist.

## Keep the public repository reproducible

Track SystemVerilog, testbenches, linker script, assembly, image conversion scripts, Tcl, XDC and concise reports. Include a tool-version record and exact build commands. Save small illustrative waveform screenshots when they teach something; leave raw waveforms and complete generated Vivado trees out of Git.

For a release, preserve the commit SHA, program-image checksum, test summary, FPGA part, clock frequency, utilization, setup/hold timing summary and board-demo instructions. A green simulation badge does not mean timing or physical hardware has passed.

## Attribution and licensing

Link the reference repository and official technical sources. The reference snapshot did not expose a license; public readability alone is not a reason to add a license over someone else's copied RTL. This course uses original teaching examples and links the reference for study. Choose your license for the material you own before advertising reuse or accepting copied contributions. Keep any third-party notices with material you intentionally reuse.

## A useful final README status table

Keep separate rows for unit simulation, single-cycle ISA tests, pipeline hazard tests, wrapper simulation, synthesis, timing and board execution. Each row should state the command or procedure, tool version, commit, outcome and evidence link. Use “not run” when evidence is missing. This lets another learner reproduce your results without guessing what “working” means.
