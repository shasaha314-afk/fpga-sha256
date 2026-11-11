// =============================================================================
// sha256_sva.sv -- Protocol and latency assertions
// =============================================================================
// Latency from an accepted block to done_o is exactly 68 clocks:
//   1 (IDLE->LOAD) + 1 (LOAD->ROUND) + 64 (ROUND) + 1 (ACCUM) + 1 (DONE)
//
// Failure messages contain "SVA_FAIL" so the regression script can count them
// independently of the simulator's assertion-report format.
// =============================================================================

module sha256_sva (
    input logic         clk,
    input logic         rst_n,
    input logic         init_i,
    input logic         block_valid_i,
    input logic [511:0] block_i,
    input logic         ready_o,
    input logic         done_o,
    input logic [255:0] digest_o
);

    default clocking cb @(posedge clk);
    endclocking

    // default disable iff (!rst_n); // Vivado XSim does not support default disable iff

    // -------------------------------------------------------------------------
    // Handshake / latency
    // -------------------------------------------------------------------------
    property p_latency;
        disable iff (!rst_n)
        (block_valid_i && ready_o) |-> ##68 done_o;
    endproperty
    a_latency: assert property (p_latency)
        else $error("SVA_FAIL: done_o did not arrive 68 clocks after an accepted block");

    property p_ready_low;
        disable iff (!rst_n)
        (block_valid_i && ready_o) |-> ##[1:67] !ready_o;
    endproperty
    a_ready_low: assert property (p_ready_low)
        else $error("SVA_FAIL: ready_o re-asserted before the 68-cycle compression finished");

    property p_ready_return;
        disable iff (!rst_n)
        (block_valid_i && ready_o) |-> ##68 ready_o;
    endproperty
    a_ready_return: assert property (p_ready_return)
        else $error("SVA_FAIL: ready_o did not return with done_o");

    a_done_implies_ready: assert property (disable iff (!rst_n) done_o |-> ready_o)
        else $error("SVA_FAIL: done_o asserted while ready_o was low");

    a_done_pulse: assert property (disable iff (!rst_n) done_o |=> !done_o)
        else $error("SVA_FAIL: done_o was high for more than one clock");

    // -------------------------------------------------------------------------
    // Driver-side protocol (checks that the VIP itself obeys the contract)
    // -------------------------------------------------------------------------
    a_valid_needs_ready: assert property (disable iff (!rst_n) block_valid_i |-> ready_o)
        else $error("SVA_FAIL: block_valid_i asserted while the core was not ready");

    a_valid_single_cycle: assert property (disable iff (!rst_n) block_valid_i |=> !block_valid_i)
        else $error("SVA_FAIL: block_valid_i was high for more than one clock");

    // -------------------------------------------------------------------------
    // Payload must stay stable from acceptance until done
    // -------------------------------------------------------------------------
    property p_block_stable;
        disable iff (!rst_n)
        (block_valid_i && ready_o) |-> ##1 ((block_i == $past(block_i))[*67]);
    endproperty
    a_block_stable: assert property (p_block_stable)
        else $error("SVA_FAIL: block_i changed while the block was being compressed");

    // -------------------------------------------------------------------------
    // Cover properties: interesting protocol events
    // -------------------------------------------------------------------------
    c_single_block: cover property (disable iff (!rst_n) block_valid_i && ready_o);
    c_done:         cover property (disable iff (!rst_n) done_o);
    c_back_to_back: cover property (disable iff (!rst_n) (block_valid_i && ready_o) ##68 (block_valid_i && ready_o));
    c_init:         cover property (disable iff (!rst_n) init_i && ready_o);

endmodule
