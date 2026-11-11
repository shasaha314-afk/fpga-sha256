// =============================================================================
// sha256_scoreboard.svh -- Self-checking reference-model scoreboard
// =============================================================================
// The scoreboard mirrors the DUT's hash chaining state:
//   * every accepted block updates the golden model and queues the digest it
//     must produce 68 cycles later
//   * every done_o pops one prediction and compares the full 256-bit digest
//   * init_i and reset both return the model to the NIST IV and flush the
//     prediction queue
//
// Because the model processes blocks in order, this checks EVERY intermediate
// digest of a multi-block message, not only the final one.
//
// +ERROR_INJECT=N flips bit 0 of the Nth prediction, to prove the checker is
// actually watching (the regression script runs this as a negative self-test).
// =============================================================================

class sha256_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(sha256_scoreboard)

    uvm_analysis_imp #(sha256_txn, sha256_scoreboard) imp;

    sha256_ref_model model;

    bit [255:0] exp_q[$];
    bit [511:0] blk_q[$];
    bit [255:0] last_digest;

    int unsigned n_blocks;
    int unsigned n_checked;
    int unsigned n_passed;
    int unsigned n_failed;
    int unsigned n_inits;
    int unsigned n_resets;
    int unsigned n_unexpected;
    int unsigned error_inject;
    int unsigned inject_at;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        imp   = new("imp", this);
        model = new();
        error_inject = 0;
        inject_at    = 0;
        void'($value$plusargs("ERROR_INJECT=%d", error_inject));
        if (sha256_model_pkg::sha256_selftest() != 0)
            `uvm_error("MODEL", "golden model self-test failed -- scoreboard results are not trustworthy")
    endfunction

    function void flush_sb(string why);
        model.reset();
        if (exp_q.size() != 0)
            `uvm_info("SB", $sformatf("%s discarded %0d in-flight prediction(s)",
                      why, exp_q.size()), UVM_MEDIUM)
        exp_q.delete();
        blk_q.delete();
    endfunction

    virtual function void write(sha256_txn t);

        case (t.kind)

            // ---------------------------------------------------------------
            SHA256_EV_RESET: begin
                flush_sb("reset");
                n_resets++;
            end

            // ---------------------------------------------------------------
            SHA256_EV_INIT: begin
                flush_sb("init");
                n_inits++;
            end

            // ---------------------------------------------------------------
            SHA256_EV_BLOCK: begin
                bit [255:0] predicted;
                predicted = model.update(t.block);
                exp_q.push_back(predicted);
                blk_q.push_back(t.block);
                n_blocks++;
            end

            // ---------------------------------------------------------------
            SHA256_EV_DIGEST: begin
                bit [255:0] expected;
                bit [511:0] block;
                bit         injected;

                if (exp_q.size() == 0) begin
                    n_unexpected++;
                    `uvm_error("SB", $sformatf(
                               "done_o with no outstanding block (digest=%064x cycle=%0d)",
                               t.digest, t.cycle))
                end
                else begin
                    expected = exp_q.pop_front();
                    block    = blk_q.pop_front();
                    injected = 1'b0;

                    if (error_inject != 0 && (n_checked + 1) == error_inject) begin
                        expected[0] = ~expected[0];
                        injected    = 1'b1;
                        `uvm_info("SB", "ERROR INJECTION: corrupted one expected digest", UVM_LOW)
                    end

                    n_checked++;

                    if (t.digest !== expected) begin
                        n_failed++;
                        `uvm_error("SB", $sformatf(
                            "DIGEST MISMATCH at cycle %0d (block #%0d)\n  input    = %0128x\n  got      = %064x\n  expected = %064x%s",
                            t.cycle, t.msg_block_index, block, t.digest, expected,
                            injected ? "\n  (expected value was intentionally corrupted)" : ""))
                    end
                    else begin
                        n_passed++;
                        last_digest = t.digest;
                        `uvm_info("SB", $sformatf(
                            "PASS  %064x  (block #%0d, latency %0d)",
                            t.digest, t.msg_block_index, t.latency), UVM_HIGH)
                    end
                end
            end

            default:
                `uvm_error("SB", "unknown transaction kind")

        endcase

    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf(
                  "blocks=%0d checked=%0d passed=%0d failed=%0d inits=%0d resets=%0d unexpected=%0d",
                  n_blocks, n_checked, n_passed, n_failed, n_inits, n_resets, n_unexpected),
                  UVM_LOW)

        $display("SHA256_SCOREBOARD blocks=%0d checked=%0d passed=%0d failed=%0d inits=%0d resets=%0d",
                 n_blocks, n_checked, n_passed, n_failed, n_inits, n_resets);

        if (n_checked == 0)
            `uvm_error("SB", "no digests were checked")
        if (exp_q.size() != 0)
            `uvm_error("SB", $sformatf("%0d prediction(s) left un-checked at end of test", exp_q.size()))
        if (n_failed != 0)
            `uvm_error("SB", $sformatf("%0d digest mismatch(es)", n_failed))
    endfunction

endclass
