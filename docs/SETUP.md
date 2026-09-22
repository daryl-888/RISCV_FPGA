# Setup: simulation first

Use Ubuntu/WSL 2 for simulation and Windows Vivado for Basys3. The supplied targets check the ALU and image converter. Add CPU and SoC targets during the labs.

## 1. Install tools

In **PowerShell**:

```powershell
wsl --list --verbose
```

If Ubuntu is missing, run as administrator, then restart and complete its account setup:

```powershell
wsl --install -d Ubuntu-24.04
```

For an existing version-1 distribution, use `wsl --set-version Ubuntu-24.04 2`, substituting its listed name. See [Microsoft's WSL instructions](https://learn.microsoft.com/en-us/windows/wsl/install).

Keep the checkout at a short shared path, such as `C:\fpga\RISCV_FPGA` (`/mnt/c/fpga/RISCV_FPGA` in Ubuntu). WSL's own filesystem builds faster, but separate checkouts must stay synchronized. See [filesystem guidance](https://learn.microsoft.com/en-us/windows/wsl/setup/environment).

In **Ubuntu**:

```bash
sudo apt update
sudo apt install -y build-essential make git python3 verilator gtkwave \
  gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
cd /mnt/c/fpga/RISCV_FPGA
mkdir -p build
verilator --version > build/tool-versions.txt
g++ --version >> build/tool-versions.txt
python3 --version >> build/tool-versions.txt
riscv64-unknown-elf-gcc --version >> build/tool-versions.txt
make test
make lint
make waves
gtkwave build/waves/alu.vcd
```

Use Verilator 5.x for the starter's `--binary`/`--timing` options. See [Verilator installation](https://verilator.org/guide/latest/install.html), [Ubuntu 24.04 Verilator](https://packages.ubuntu.com/noble/verilator), and [bare-metal GCC](https://packages.ubuntu.com/noble/gcc-riscv64-unknown-elf). Missing packages: enable Ubuntu's `universe` repository and update. Stop at the first build error. If GTKWave cannot open, use another VCD viewer; tests still run without a GUI.

## 2. Check one instruction

In **Ubuntu**:

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

Expect words `00500093`, `0000006f`; little-endian bytes `93 00 50 00 6f 00 00 00`. A word-wide `$readmemh` file contains `00500093`, not reversed bytes.

The `riscv64` tool prefix can produce RV32I using these explicit [GCC ISA/ABI options](https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html). [Objdump's numeric/no-aliases options](https://www.sourceware.org/binutils/docs/binutils/objdump.html) expose canonical instructions. This assembly runs without an OS or C runtime; later C needs startup code, a stack, and a deliberate linker layout.

## 3. Build a program

```bash
make program PROGRAM=arithmetic
make program PROGRAM=switches_leds
riscv64-unknown-elf-objdump -d -M numeric,no-aliases \
  build/programs/switches_leds.elf
cp build/programs/switches_leds.hex programs/boot.hex
```

`programs/linker.ld` sets addresses; `scripts/bin_to_mem.py` converts `.bin` bytes into `.hex` words. The `.elf` retains addresses for disassembly. Inspect `python3 scripts/bin_to_mem.py --help` when changing formats.

Check entry address zero, supported instructions, and size ≤1 KiB. Instruction ROM and data RAM are **separate** 256-word memories, each addressed at `0x00000000–0x000003ff`. Validate the full address and alignment before taking index `[9:2]`; otherwise invalid addresses wrap. NOP padding does not excuse a runaway PC.

In your ROM use `$readmemh("boot.hex", imem)` and the same image in simulation. Vivado must include `programs/boot.hex`; rebuild the bitstream after changing it.

## 4. Install Windows Vivado

Include Artix-7 support and cable drivers. Check your release's [AMD device/edition support](https://docs.amd.com/r/2025.1-English/ug973-vivado-release-notes-install-license/Supported-Devices). In the **Vivado Tcl Console**:

```tcl
version -short
get_parts xc7a35tcpg236-1
```

Record the version; the second command must return the part. Use Windows Hardware Manager for USB/JTAG. No board-file package is needed when selecting the part directly. Continue with [FPGA.md](FPGA.md) in labs 11–12.

Before lab 1, verify ALU tests/lint pass, the VCD exists, and the known instruction matches. For confusing failures, check the shell, working directory, LF line endings, ROM word order, selected top, and output timestamp first.
