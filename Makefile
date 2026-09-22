VERILATOR ?= verilator
PYTHON ?= python3
CROSS ?= riscv64-unknown-elf-
PROGRAM ?= arithmetic

.PHONY: test lint waves test-tools program clean

test: test-tools build/alu/Valu_tb
	./build/alu/Valu_tb

lint:
	$(VERILATOR) --lint-only -Wall --top-module alu rtl/common/alu.sv

build/alu/Valu_tb: rtl/common/alu.sv sim/alu_tb.sv
	mkdir -p build/alu build/waves
	$(VERILATOR) --binary --timing --assert --trace -Wall --top-module alu_tb --Mdir build/alu rtl/common/alu.sv sim/alu_tb.sv

waves: build/alu/Valu_tb
	mkdir -p build/waves
	./build/alu/Valu_tb +trace

test-tools:
	$(PYTHON) -m unittest discover -s scripts -p 'test_*.py' -v

program: build/programs/$(PROGRAM).hex

build/programs/%.elf: programs/%.S programs/linker.ld
	mkdir -p build/programs
	$(CROSS)gcc -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -nostartfiles -Wl,--no-relax -Wl,-T,programs/linker.ld -o $@ $<
	$(CROSS)objdump -d -M no-aliases $@ > $(@:.elf=.dis)

build/programs/%.bin: build/programs/%.elf
	$(CROSS)objcopy -O binary -j .text $< $@

build/programs/%.hex: build/programs/%.bin scripts/bin_to_mem.py
	$(PYTHON) scripts/bin_to_mem.py $< $@ --format words --depth 256

.SECONDARY:

clean:
	$(PYTHON) -c "import pathlib, shutil; p=pathlib.Path('build'); shutil.rmtree(p) if p.exists() else None"
