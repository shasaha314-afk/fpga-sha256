# =============================================================================
# add_sim_uvm.tcl
# Helper script to add and configure the UVM testbench in an open Vivado project
# Usage in Vivado Tcl Console: source add_sim_uvm.tcl
# =============================================================================

set script_dir [file dirname [file normalize [info script]]]

# Create sim_uvm simulation fileset if it does not already exist
if {[get_filesets -quiet sim_uvm] eq ""} {
    puts "Creating simulation fileset 'sim_uvm'..."
    create_fileset -simset sim_uvm
} else {
    puts "Fileset 'sim_uvm' already exists."
}

# Define UVM testbench files
set tb_files [list \
    [file normalize [file join $script_dir "sha256_uvm/tb/sha256_if.sv"]] \
    [file normalize [file join $script_dir "sha256_uvm/tb/sha256_model_pkg.sv"]] \
    [file normalize [file join $script_dir "sha256_uvm/tb/sha256_uvm_pkg.sv"]] \
    [file normalize [file join $script_dir "sha256_uvm/tb/sha256_sva.sv"]] \
    [file normalize [file join $script_dir "sha256_uvm/tb/tb_top.sv"]] \
]

puts "Adding UVM testbench files to sim_uvm..."
add_files -fileset sim_uvm -norecurse $tb_files

# Explicitly ensure SystemVerilog file type
foreach f $tb_files {
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_uvm] $f]
}

# Set include path so `include finds .svh components
set tb_inc [file normalize [file join $script_dir "sha256_uvm/tb"]]
set_property include_dirs $tb_inc [get_filesets sim_uvm]

# Configure XSim compilation, elaboration, and simulation options
set_property -name {xsim.compile.xvlog.more_options} -value {-L uvm} -objects [get_filesets sim_uvm]
set_property -name {xsim.elaborate.xelab.more_options} -value {-L uvm} -objects [get_filesets sim_uvm]
set_property -name {xsim.simulate.xsim.more_options} -value {-testplusarg UVM_TESTNAME=sha256_kat_test} -objects [get_filesets sim_uvm]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_uvm]

# Configure simulation top
set_property top tb_top [get_filesets sim_uvm]
set_property top_lib xil_defaultlib [get_filesets sim_uvm]

# Set sim_uvm as active simulation fileset
current_fileset -simset [get_filesets sim_uvm]
update_compile_order -fileset sim_uvm

puts "sim_uvm successfully configured as the active simulation set!"
