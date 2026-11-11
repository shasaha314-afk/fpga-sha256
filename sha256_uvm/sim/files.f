// SHA-256 UVM compile order
// Paths are relative to the project root (sha256_uvm/).

// RTL
rtl/sha256_functions.v
rtl/sha256_round.v
rtl/sha256_schedule.v
rtl/sha256_core.v

// Testbench
tb/sha256_if.sv
tb/sha256_model_pkg.sv
tb/sha256_uvm_pkg.sv
tb/sha256_sva.sv
tb/tb_top.sv
