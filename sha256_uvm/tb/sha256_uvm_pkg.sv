// =============================================================================
// sha256_uvm_pkg.sv -- All verification components
// =============================================================================
// Compile order (see sim/files.f):
//   1. sha256_if.sv
//   2. sha256_model_pkg.sv
//   3. sha256_uvm_pkg.sv   (this file)
//   4. sha256_sva.sv
//   5. tb_top.sv
// =============================================================================

`ifndef SHA256_UVM_PKG_SV
`define SHA256_UVM_PKG_SV

`include "uvm_macros.svh"

package sha256_uvm_pkg;

    import uvm_pkg::*;
    import sha256_model_pkg::*;

    `include "sha256_txn.svh"
    `include "sha256_seq_item.svh"
    `include "sha256_sequences.svh"
    `include "sha256_driver.svh"
    `include "sha256_monitor.svh"
    `include "sha256_scoreboard.svh"
    `include "sha256_coverage.svh"
    `include "sha256_agent.svh"
    `include "sha256_env.svh"
    `include "sha256_tests.svh"

endpackage

`endif
