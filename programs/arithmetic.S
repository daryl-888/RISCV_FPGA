.option norvc
.option norelax
.section .text
.globl _start
_start:
    addi x1, x0, 5
    addi x2, x0, 7
    add  x3, x1, x2
    sw   x3, 0(x0)
    lw   x4, 0(x0)
    sub  x5, x4, x1
done:
    jal  x0, done
# Expected: x1=5, x2=7, x3=12, x4=12, x5=7; dmem word 0=12.
# The backward jump is a stop loop. The testbench detects completion by PC
# or signature and enforces a cycle timeout; the CPU has no HALT instruction.
