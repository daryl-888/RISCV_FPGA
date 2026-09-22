# Later-lab project creation template. This does not supply a completed CPU.
# In the Windows Vivado Tcl Console, source this file by its absolute path.
# Build, inspect reports, and program manually as described in docs/FPGA.md.

set course_root [file normalize [file join [file dirname [info script]] ..]]
set course_top [file join $course_root rtl soc basys3_top.sv]
set course_image [file join $course_root programs boot.hex]
set course_project_dir [file join $course_root build vivado basys3]

if {![file isfile $course_top]} {
    error "Student RTL is missing: $course_top. Complete the CPU and board-wrapper labs before creating this project. The supplied starter contains no finished Basys3 CPU."
}
if {![file isfile $course_image]} {
    error "Boot image is missing: $course_image. Build switches_leds, copy its word-format hex to programs/boot.hex, and match the RTL readmemh filename. See docs/SETUP.md."
}
if {[llength [info commands create_project]] == 0} {
    error "Run this script inside Vivado, not a general Tcl shell."
}
if {[llength [get_projects -quiet]] != 0} {
    error "Close the current Vivado project before sourcing this template."
}
if {[file exists $course_project_dir]} {
    error "Project output already exists: $course_project_dir. Open its .xpr, or choose a new output directory in this script; this template will not overwrite it."
}
if {[llength [get_parts -quiet xc7a35tcpg236-1]] != 1} {
    error "Artix-7 part xc7a35tcpg236-1 is unavailable. Install the Artix-7 device files."
}

proc course_collect_sv {directory} {
    set result {}
    foreach path [lsort [glob -nocomplain -directory $directory *]] {
        if {[file isdirectory $path]} {
            set result [concat $result [course_collect_sv $path]]
        } elseif {[file extension $path] eq ".sv"} {
            lappend result $path
        }
    }
    return $result
}

# Keep synthesis RTL in rtl/ and testbenches elsewhere. Give alternative CPU
# implementations distinct module names, and instantiate only the chosen one.
set course_rtl [course_collect_sv [file join $course_root rtl]]
create_project basys3 $course_project_dir -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]
add_files -norecurse $course_rtl
set_property top basys3_top [current_fileset]
set_property include_dirs [list [file join $course_root rtl]] [current_fileset]
add_files -norecurse $course_image
set_property file_type {Memory Initialization Files} [get_files $course_image]
add_files -fileset constrs_1 -norecurse [file join $course_root fpga basys3_minimal.xdc]

# Students add this only after identifying exact synchronizer boundary pins.
set course_boundary_xdc [file join $course_root fpga board_timing.xdc]
if {[file isfile $course_boundary_xdc]} {
    add_files -fileset constrs_1 -norecurse $course_boundary_xdc
}

# Optional MMCM/Clocking Wizard IP is a later extension. Add its .xci and
# generate output products explicitly when adapting this baseline template.
update_compile_order -fileset sources_1
puts "Created [file join $course_project_dir basys3.xpr]"
puts "Check top ports, ROM loading, synthesis, timing, and CDC before programming."
puts "No synthesis, timing closure, bitstream generation, or board test has been performed by this script."
