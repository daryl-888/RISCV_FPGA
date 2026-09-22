.option norvc
.option norelax
.section .text
.globl _start
_start:
    lui  x1, 0x10000
loop:
    lw   x2, 4(x1)
    sw   x2, 0(x1)
    jal  x0, loop
# LED MMIO 0x10000000, synchronized switch MMIO 0x10000004.
# This deliberately exercises load-to-store data dependence.
