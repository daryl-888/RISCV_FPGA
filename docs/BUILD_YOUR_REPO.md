# Build your repository

Keep each commit small: one working CPU change and the test that proves it.

## Start from the course

Fork [daryl-888/RISCV_FPGA](https://github.com/daryl-888/RISCV_FPGA), replace `YOUR_USERNAME`, then run in **Ubuntu/WSL**:

```sh
git clone https://github.com/YOUR_USERNAME/RISCV_FPGA.git
cd RISCV_FPGA
make test
git switch -c week-01-parts
```

Follow [SETUP.md](SETUP.md) first if tools are missing. The supplied tests and CI cover the ALU; add CPU targets as you implement them.

## Or start blank

Create an empty GitHub repository, then:

```sh
mkdir RISCV_FPGA
cd RISCV_FPGA
git init -b main
mkdir -p docs rtl/common rtl/single_cycle rtl/pipeline rtl/soc sim programs scripts fpga .github/workflows
```

Write a README with scope, commands, and measured status. Add `.gitignore`, `.gitattributes`, ALU, testbench, Makefile, and tool checks. Git tracks files, so add a short README to planned directories. After those files exist:

```sh
git add README.md .gitignore .gitattributes docs rtl sim programs scripts fpga Makefile .github
git diff --cached
git commit -m "Add structure and tested ALU"
git remote add origin https://github.com/YOUR_USERNAME/RISCV_FPGA.git
git push -u origin main
```

If Git requests identity, configure `user.name` and `user.email`; GitHub's no-reply address is an option. Never commit tokens. Clone an existing nonempty remote instead of force-pushing over it.

## Build in 12 labs

| Week | Labs | Commit working pieces |
|---|---|---|
| 1 | 1–2 | Single-cycle parts |
| 2 | 3–4 | Remaining single-cycle parts |
| 3 | 5–6 | Full 37-instruction baseline; pipeline registers |
| 4 | 7–8 | Forwarding; load-use stalls |
| 5 | 9–10 | Redirects/faults; equivalence regression |
| 6 | 11–12 | Board-wrapper simulation; Vivado and board |

Use `git switch -c BRANCH_NAME` for a new milestone. Each session: pull, write expected behavior, code a small change, run its test and relevant regression, inspect `git diff`, then commit named files and push. Record a short explanation of any failing waveform. A useful bug report includes the program/input, expected result, actual result, and failing assertion.

Track RTL, tests, assembly, linker/conversion scripts, Tcl/XDC, and concise results. Ignore generated build trees and raw waveforms. For each simulation, synthesis, timing, and board result, record the command, tool version, commit, outcome, and evidence. Mark unrun checks “not run.” Record actual clock frequency when comparing performance.

Link original references and retain third-party notices. The reference snapshot exposed no license; public visibility does not grant reuse rights. Choose a license only for material you own or are authorized to license.
