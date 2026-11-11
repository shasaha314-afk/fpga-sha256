// =============================================================================
// sha256_coverage.svh -- Functional coverage model
// =============================================================================
// Three covergroups:
//   * sha256_block_cg  : payload class, position in message, gap
//   * sha256_digest_cg : message length, latency, digest parity
//   * sha256_event_cg  : reset / init / block / digest events
//
// report_phase prints machine-readable SHA256_COVERAGE lines that
// scripts/run_regression.py parses into the regression summary.
// =============================================================================

class sha256_coverage extends uvm_subscriber #(sha256_txn);

    `uvm_component_utils(sha256_coverage)

    // Sampled variables (covergroups capture these on sample())
    sha256_ev_e        cov_kind;
    sha256_blk_class_e cov_block_class;
    int unsigned       cov_block_index;
    int unsigned       cov_gap;
    int unsigned       cov_latency;
    int unsigned       cov_msg_blocks;
    bit                cov_digest_parity;

    covergroup cg_event;
        option.per_instance = 1;
        cp_kind: coverpoint cov_kind {
            bins reset  = {SHA256_EV_RESET};
            bins init   = {SHA256_EV_INIT};
            bins block  = {SHA256_EV_BLOCK};
            bins digest = {SHA256_EV_DIGEST};
        }
    endgroup

    covergroup cg_block;
        option.per_instance = 1;
        cp_class: coverpoint cov_block_class {
            bins mixed       = {SHA256_BLK_MIXED};
            bins all_zero    = {SHA256_BLK_ZERO};
            bins all_ones    = {SHA256_BLK_ONES};
            bins alternating = {SHA256_BLK_ALT};
        }
        cp_index: coverpoint cov_block_index {
            bins first       = {1};
            bins second      = {2};
            bins third       = {3};
            bins four_to_8   = {[4:8]};
            bins nine_to_32  = {[9:32]};
            bins thirty_plus = {[33:100000]};
        }
        cp_gap: coverpoint cov_gap {
            bins back_to_back = {0};
            bins short_gap    = {[1:5]};
            bins medium_gap   = {[6:20]};
            bins long_gap     = {[21:100000]};
        }
        cross cp_class, cp_index;
    endgroup

    covergroup cg_digest;
        option.per_instance = 1;
        // Only the architecturally correct latency is a legal bin. A wrong
        // latency is caught by SVA and simply leaves this bin un-hit.
        cp_latency: coverpoint cov_latency {
            bins exact = {68};
        }
        cp_msg_blocks: coverpoint cov_msg_blocks {
            bins one         = {1};
            bins two         = {2};
            bins three       = {3};
            bins four_to_8   = {[4:8]};
            bins nine_to_32  = {[9:32]};
            bins thirty_plus = {[33:100000]};
        }
        cp_parity: coverpoint cov_digest_parity {
            bins even = {0};
            bins odd  = {1};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_event  = new();
        cg_block  = new();
        cg_digest = new();
    endfunction

    virtual function void write(sha256_txn t);
        cov_kind = t.kind;
        cg_event.sample();

        case (t.kind)
            SHA256_EV_BLOCK: begin
                cov_block_class = t.block_class;
                cov_block_index = t.msg_block_index;
                cov_gap         = t.gap;
                cg_block.sample();
            end

            SHA256_EV_DIGEST: begin
                cov_latency     = t.latency;
                cov_msg_blocks  = t.msg_block_index;
                cov_digest_parity = t.digest_parity;
                cg_digest.sample();
            end

            default: ;
        endcase
    endfunction

    function void report_phase(uvm_phase phase);
        real block_cov;
        real digest_cov;
        real event_cov;
        real overall;

        block_cov  = cg_block.get_coverage();
        digest_cov = cg_digest.get_coverage();
        event_cov  = cg_event.get_coverage();
        overall    = (block_cov + digest_cov + event_cov) / 3.0;

        $display("SHA256_COVERAGE block=%.2f digest=%.2f event=%.2f overall=%.2f",
                 block_cov, digest_cov, event_cov, overall);
        `uvm_info("COV", $sformatf(
                  "block=%.2f%% digest=%.2f%% event=%.2f%% overall=%.2f%%",
                  block_cov, digest_cov, event_cov, overall), UVM_LOW)
    endfunction

endclass
