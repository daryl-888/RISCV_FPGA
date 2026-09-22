# Minimal Basys3 rev B pin map for the course top-level ports.
# Pin facts verified against Digilent's board constraints:
# https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc
# This is an original compact mapping; unused board peripherals are omitted.

set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -name board_clk -period 10.000 [get_ports clk]

set_property PACKAGE_PIN U18 [get_ports btnC]
set_property IOSTANDARD LVCMOS33 [get_ports btnC]

set course_switch_pins {V17 V16 W16 W17 W15 V15 W14 W13 V2 T3 T2 R3 W2 U1 T1 R2}
set course_led_pins {U16 E19 U19 V19 W18 U15 U14 V14 V13 V3 W3 U3 P3 N3 P1 L1}
for {set bit 0} {$bit < 16} {incr bit} {
    set switch_port [get_ports [format {sw[%d]} $bit]]
    set led_port [get_ports [format {led[%d]} $bit]]
    set_property PACKAGE_PIN [lindex $course_switch_pins $bit] $switch_port
    set_property IOSTANDARD LVCMOS33 $switch_port
    set_property PACKAGE_PIN [lindex $course_led_pins $bit] $led_port
    set_property IOSTANDARD LVCMOS33 $led_port
}

# Deliberately no broad false paths or multicycle paths.
# After implementing synchronizers, document only the justified asynchronous
# boundary exceptions in board_timing.xdc. See ../docs/FPGA.md.
