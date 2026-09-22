# Tool setup: simulation first, board later

This course uses an Ubuntu shell for Verilator and the RISC-V assembler, and Windows Vivado for the Basys3. Use Ubuntu 24.04 LTS or a later supported release with Verilator 5.x. Commands below name the shell in which they run. Do not paste Linux commands into PowerShell or Vivado Tcl commands into Ubuntu.

The supplied executable starter is an ALU exercise. `make test`, `make lint`, and `make waves` exercise that starter. You will add CPU simulation targets as you build the single-cycle and pipelined CPUs. A passing ALU test is not evidence that a CPU exists or works.

## 1. Prepare the two environments

In **PowerShell**, check whether Ubuntu is already installed:

```powershell
wsl --list --verbose
```

If needed, open PowerShell as administrator, install Ubuntu, restart when prompted, and complete the Ubuntu username/password setup:

```powershell
wsl --install -d Ubuntu-24.04
```

Use WSL version 2. If an existing Ubuntu installation reports version 1, convert that named distribution with `wsl --set-version Ubuntu-24.04 2`. Distribution names can differ; use the name from the list. See [Microsoft's WSL installation instructions](https://learn.microsoft.com/en-us/windows/wsl/install).

For this Windows/Ubuntu workflow, extract or clone the course into a short Windows path such as `C:\fpga\RISCV_FPGA`. Ubuntu sees it as `/mnt/c/fpga/RISCV_FPGA`. This makes the same source files available to both tools. Linux builds are usually faster in the WSL filesystem; an advanced alternative is separate synchronized Git checkouts. Never edit one checkout and accidentally build an older copy in the other. See [Microsoft's filesystem guidance](https://learn.microsoft.com/en-us/windows/wsl/setup/environment).

## 2. Install the simulation tools

Run in **Ubuntu**:

```bash
sudo apt update
sudo apt install -y build-essential make git python3 verilator gtkwave \
  gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
cd /mnt/c/fpga/RISCV_FPGA
mkdir -p build
verilator --version
g++ --version
python3 --version
riscv64-unknown-elf-gcc --version
riscv64-unknown-elf-objdump --version
```

The package manager route is documented by [Verilator](https://verilator.org/guide/latest/install.html). Ubuntu 24.04 provides [Verilator 5.x](https://packages.ubuntu.com/noble/verilator) and the [bare-metal RISC-V GCC package](https://packages.ubuntu.com/noble/gcc-riscv64-unknown-elf). If a package is unavailable, check that the `universe` repository is enabled and update the package index. Do not substitute a Linux-targeting compiler without understanding its defaults. An older Verilator may reject this starter's `--binary` or `--timing` options; install a supported 5.x release before continuing.

Record the actual versions in your lab notebook. Use the same installed versions throughout the six-week course when possible. Package versions vary by Ubuntu release; these commands are a setup procedure, not a claim that every version has been tested with this repository.

Run the supplied starter:

```bash
make test
make lint
make waves
gtkwave build/waves/alu.vcd
```

Stop on an error and read the first meaningful diagnostic. The commands should finish with success, and the waveform file should exist after `make waves`. If GTKWave cannot open a window, keep working with test output and open the VCD in a waveform viewer that works on your computer; waveform generation does not require a working GUI.

Save a short setup record:

```bash
verilator --version > build/tool-versions.txt
riscv64-unknown-elf-gcc --version >> build/tool-versions.txt
python3 --version >> build/tool-versions.txt
```

## 3. Understand the executable formats

Your laptop executes the simulator. The CPU you design executes RISC-V instructions stored in its instruction memory. These are different programs for different machines.

| File | Meaning | Who reads it? |
|---|---|---|
| `.S` | Assembly source | RISC-V assembler |
| `.elf` | Linked program plus addresses and metadata | Disassembler and development tools |
| `.bin` | Raw bytes, with no ELF header | Conversion script |
| `.hex` | Course text file, one eight-digit instruction word per line | `$readmemh` into a 32-bit-wide instruction array |
| `.bit` | FPGA configuration, including implemented logic and initial ROM contents | Vivado Hardware Manager |

An instruction word is not the same thing as the order of its bytes in a file. `addi x1, x0, 5` is the word `00500093`. In a little-endian binary its four bytes, from lowest to highest address, are `93 00 50 00`. A word-wide `$readmemh` file must contain `00500093`; a byte-wide memory would need four separate entries `93`, `00`, `50`, `00`.

The course baseline has 256 instruction words and 256 separate data words. Both use byte addresses `0x00000000` through `0x000003ff`; the memories are independent. The word index is `address[9:2]` only after checking that the whole address is in range and aligned. Taking those bits first would silently wrap an invalid address into valid RAM.

## 4. Check the compiler with one known instruction

Run this self-contained exercise in **Ubuntu**:

```bash
mkdir -p build/toolchain-check
cat > build/toolchain-check/check.S <<'EOF'
    .section .text
    .globl _start
_start:
    addi x1, x0, 5
1:  jal  x0, 1b
EOF
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax \
  -nostdlib -nostartfiles -Wl,--no-relax -Wl,-Ttext=0 -Wl,-e,_start \
  -o build/toolchain-check/check.elf build/toolchain-check/check.S
riscv64-unknown-elf-objdump -d -M numeric,no-aliases \
  build/toolchain-check/check.elf
riscv64-unknown-elf-objcopy -O binary -j .text \
  build/toolchain-check/check.elf build/toolchain-check/check.bin
od -An -tx1 build/toolchain-check/check.bin
```

Expected instruction words are `00500093` and `0000006f`. Expected bytes are `93 00 50 00 6f 00 00 00`. Verify both before debugging a CPU against this image.

The `riscv64` prefix names the installed toolchain; explicit `-march=rv32i -mabi=ilp32` requests 32-bit base integer instructions and a matching ABI. It does not add multiply, divide, compressed instructions, or floating point. [GCC documents the ISA and ABI options](https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html). `-M numeric,no-aliases` exposes register numbers and canonical instruction names instead of convenient assembly aliases; see [GNU objdump](https://www.sourceware.org/binutils/docs/binutils/objdump.html).

This is a bare-metal assembly exercise. There is no operating system, `printf`, default startup routine, initialized stack, or C runtime. Later C work requires a deliberate startup sequence, stack location, linker layout, data initialization, supported instruction set, and any required compiler helper routines. Successful compilation alone does not establish that the hardware can run the program.

## 5. Build the course programs

From the repository root in **Ubuntu**:

```bash
make program PROGRAM=arithmetic
make program PROGRAM=switches_leds
riscv64-unknown-elf-objdump -d -M numeric,no-aliases \
  build/programs/switches_leds.elf
```

The inputs live in `programs/`; outputs live in `build/programs/`. The Makefile uses `programs/linker.ld` and `scripts/bin_to_mem.py` to produce a word-format `.hex` image. The converter's `--format words` output is for a 32-bit array; `--format bytes` is a different representation. Inspect `python3 scripts/bin_to_mem.py --help` before using it outside the Makefile.

Check that each program fits the 1 KiB instruction memory, contains only instructions your current milestone implements, and has the expected entry address. Padding unused instruction words with `00000013` gives `addi x0,x0,0` (NOP). Padding does not make a runaway PC correct: tests must still detect unexpected execution and out-of-range fetches.

For Vivado, copy the chosen image to `programs/boot.hex` and use `$readmemh("boot.hex", imem)` in the student's instruction ROM. Add the same image to simulation. Rebuild the FPGA after changing this file; changing a file on the laptop cannot change a programmed ROM by itself.

```bash
cp build/programs/switches_leds.hex programs/boot.hex
```

## 6. Install Vivado on Windows

Install a Vivado release that supports your Windows version and the Artix-7 `xc7a35tcpg236-1` part. Include Artix-7 device support and the programming cable drivers. The course does not require Vitis or a separate commercial CPU core. Verify device and edition support in the [release-specific AMD installation guide](https://docs.amd.com/r/2025.1-English/ug973-vivado-release-notes-install-license/Supported-Devices); licensing and edition names can change between releases.

Use the Windows Vivado GUI for implementation and JTAG. This keeps USB programming in Windows and avoids making WSL USB forwarding an additional course prerequisite. In the Vivado Tcl Console, record:

```tcl
version -short
get_parts xc7a35tcpg236-1
```

The second command must return the target part. If it does not, install that device family before attempting a build. Choosing the FPGA part directly means no third-party board-file package is required.

Continue with [the Basys3 guide](FPGA.md) only after the simulation evidence for your current CPU milestone is ready.

## Setup acceptance checklist

- [ ] Ubuntu opens and reports WSL 2 from the Windows distribution list.
- [ ] Verilator, the C++ compiler, Python, and the bare-metal RISC-V tools report versions.
- [ ] `make test` and `make lint` succeed for the supplied ALU starter.
- [ ] `make waves` produces `build/waves/alu.vcd`; you can identify input and output changes.
- [ ] The known-instruction exercise produces the expected words and little-endian bytes.
- [ ] Course assembly builds; you can read its canonical disassembly.
- [ ] Vivado reports `xc7a35tcpg236-1`, and its version is recorded.

## Common setup failures

| Symptom | Check first |
|---|---|
| `make` or `verilator` not found | Are you in Ubuntu, and did installation finish? |
| RISC-V linker asks for startup files or libraries | Confirm the bare-metal tool prefix and the `-nostdlib -nostartfiles` flags. |
| Disassembly contains instructions the CPU cannot execute | Check `-march`, pseudo-instruction expansion, relaxation, and the actual output. |
| Simulation fetches reversed instruction values | Compare one known word with its four binary bytes and the ROM element width. |
| Vivado cannot find an image | Add `boot.hex` as a project source; check the synthesis log and `$readmemh` filename. |
| Linux scripts report unexpected characters | Save scripts with LF line endings; do not edit generated binaries as text. |
| Changes appear to have no effect | Check the current folder, chosen top module, program image, and rebuilt output timestamp. |
