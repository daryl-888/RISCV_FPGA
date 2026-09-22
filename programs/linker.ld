OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { IMEM (rx) : ORIGIN = 0, LENGTH = 1024 }
SECTIONS {
    .text : { *(.text .text.*) } > IMEM
    /DISCARD/ : { *(.comment) *(.riscv.attributes) }
}
ASSERT(SIZEOF(.text) <= LENGTH(IMEM), "program exceeds instruction memory")
