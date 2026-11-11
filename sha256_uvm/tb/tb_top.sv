// =============================================================================
// tb_top.sv -- UVM top level
// =============================================================================
// `+UVM_TESTNAME=<test>` selects the test.
// The driver owns rst_n; the testbench only generates the clock, wires the
// interface to the DUT, registers the virtual interface and runs UVM.
// =============================================================================

`timescale 1ns/1ps

module tb_top;

    import uvm_pkg::*;
    import sha256_uvm_pkg::*;

    logic clk;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    sha256_if vif (.clk(clk));

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    sha256_core dut (
        .clk           (clk),
        .rst_n         (vif.rst_n),
        .init_i        (vif.init_i),
        .block_valid_i (vif.block_valid_i),
        .block_i       (vif.block_i),
        .ready_o       (vif.ready_o),
        .done_o        (vif.done_o),
        .digest_o      (vif.digest_o)
    );

    // -------------------------------------------------------------------------
    // Protocol assertions
    // -------------------------------------------------------------------------
    sha256_sva u_sva (
        .clk           (clk),
        .rst_n         (vif.rst_n),
        .init_i        (vif.init_i),
        .block_valid_i (vif.block_valid_i),
        .block_i       (vif.block_i),
        .ready_o       (vif.ready_o),
        .done_o        (vif.done_o),
        .digest_o      (vif.digest_o)
    );

    // -------------------------------------------------------------------------
    // UVM start
    // -------------------------------------------------------------------------
    initial begin
        $display("");
        $display("================================================================");
        $display("  SHA-256 UVM testbench  (NIST FIPS 180-4)");
        $display("  driver / monitor / scoreboard / sequences / SVA / coverage");
        $display("================================================================");
        uvm_config_db#(virtual sha256_if)::set(null, "*", "vif", vif);
        run_test();
    end

    // -------------------------------------------------------------------------
    // Watchdog: catches a hung sequence or a missing objection drop
    // -------------------------------------------------------------------------
    initial begin
        int unsigned wd_ms = 5;
        void'($value$plusargs("WATCHDOG_MS=%d", wd_ms));
        #(wd_ms * 1ms);
        $display("SHA256_TEST_RESULT: FAIL (watchdog timeout after %0d ms)", wd_ms);
        $fatal(1, "WATCHDOG: simulation exceeded %0d ms", wd_ms);
    end

    // -------------------------------------------------------------------------
    // Optional waves: +define+DUMP_WAVES
    // -------------------------------------------------------------------------
    `ifdef DUMP_WAVES
    initial begin
        $dumpfile("sha256_uvm.vcd");
        $dumpvars(0, tb_top);
    end
    `endif

endmodule
