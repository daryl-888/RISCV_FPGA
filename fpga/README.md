# Basys3 project inputs

These files support the later board lab. They are not a completed processor or a prebuilt bitstream.

- `basys3_minimal.xdc`: the 100 MHz clock, center reset button, 16 switches, and 16 LEDs.
- `create_project.tcl`: creates a Vivado project for student-written RTL. It intentionally stops if `rtl/soc/basys3_top.sv` or `programs/boot.hex` is missing, and refuses to overwrite an existing output directory.
- `board_timing.xdc`: student-created, optional input for justified boundary constraints after the actual synchronizers exist. It is not supplied as a blanket timing waiver.

Required top-level interface:

```systemverilog
module basys3_top (
    input  logic        clk,
    input  logic        btnC,
    input  logic [15:0] sw,
    output logic [15:0] led
);
    // Student implementation: reset/input conditioning, CPU, memory, MMIO.
endmodule
```

The interface above is a declaration to follow, not functional starter RTL. Use `btnC` for reset; the baseline runs continuously. A physical single-step control is optional and requires an additional port, constraint, synchronizer, debouncer, and one-cycle enable circuit.

The target part is `xc7a35tcpg236-1`. Pin assignments come from the [Digilent master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc). Confirm your board revision before using them.

Read [tool setup](../docs/SETUP.md), then follow [the full FPGA lab](../docs/FPGA.md). From the Windows Vivado Tcl Console, substituting the actual checkout path:

```tcl
source {C:/fpga/RISCV_FPGA/fpga/create_project.tcl}
```

The created project is `build/vivado/basys3/basys3.xpr`. The script adds SystemVerilog files beneath `rtl/`, the boot image, and constraints. Keep testbenches out of `rtl/`; if using packages, inspect compilation order. Include files below nested directories and optional vendor IP may need explicit project additions. Source creation does not certify synthesis, timing, or hardware behavior.
