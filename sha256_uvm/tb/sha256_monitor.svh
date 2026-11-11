// =============================================================================
// sha256_monitor.svh -- Passive protocol observer
// =============================================================================
// Samples on posedge (the same instant the DUT samples), so it sees exactly
// the handshake the hardware sees. Every event is broadcast on ap and consumed
// by the scoreboard and the functional coverage subscriber.
//
// It also measures:
//   * latency: block accepted -> done
//   * gap:     previous done -> next block accepted (0 = back-to-back)
//   * blocks in the current message (between init/reset events)
// =============================================================================

class sha256_monitor extends uvm_monitor;

    `uvm_component_utils(sha256_monitor)

    virtual sha256_if vif;
    uvm_analysis_port #(sha256_txn) ap;

    int unsigned cycle;
    int unsigned msg_block_index;
    int unsigned last_accept_cycle;
    int unsigned last_done_cycle;
    int unsigned n_blocks_seen;
    int unsigned n_digests_seen;
    int unsigned n_inits_seen;
    int unsigned n_resets_seen;
    bit          have_last_accept;
    bit          have_last_done;
    bit          in_reset;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sha256_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "sha256_monitor: virtual interface not configured")
    endfunction

    function automatic sha256_blk_class_e classify(bit [511:0] b);
        if (b === '0)               return SHA256_BLK_ZERO;
        if (b === '1)               return SHA256_BLK_ONES;
        if (b === {256{2'b10}})     return SHA256_BLK_ALT;
        return SHA256_BLK_MIXED;
    endfunction

    task run_phase(uvm_phase phase);
        cycle            = 0;
        msg_block_index  = 0;
        last_accept_cycle = 0;
        last_done_cycle  = 0;
        n_blocks_seen    = 0;
        n_digests_seen   = 0;
        n_inits_seen     = 0;
        n_resets_seen    = 0;
        have_last_accept = 1'b0;
        have_last_done   = 1'b0;
        in_reset         = 1'b0;

        forever begin
            sha256_txn t;
            @(posedge vif.clk);
            cycle++;

            // ---------------------------------------------------------------
            // Reset is asynchronous and dominant
            // ---------------------------------------------------------------
            if (vif.rst_n !== 1'b1) begin
                if (!in_reset) begin
                    t = sha256_txn::type_id::create("t_reset");
                    t.kind  = SHA256_EV_RESET;
                    t.cycle = cycle;
                    ap.write(t);
                    n_resets_seen++;
                end
                in_reset         = 1'b1;
                msg_block_index  = 0;
                have_last_accept = 1'b0;
                have_last_done   = 1'b0;
                continue;
            end
            in_reset = 1'b0;

            // ---------------------------------------------------------------
            // init_i starts a new message (new IV)
            // ---------------------------------------------------------------
            if (vif.init_i === 1'b1) begin
                t = sha256_txn::type_id::create("t_init");
                t.kind  = SHA256_EV_INIT;
                t.cycle = cycle;
                ap.write(t);
                n_inits_seen++;
                msg_block_index  = 0;
                have_last_accept = 1'b0;
                have_last_done   = 1'b0;
            end

            // ---------------------------------------------------------------
            // done_o: digest is valid this cycle
            // ---------------------------------------------------------------
            if (vif.done_o === 1'b1) begin
                t = sha256_txn::type_id::create("t_digest");
                t.kind             = SHA256_EV_DIGEST;
                t.cycle            = cycle;
                t.digest           = vif.digest_o;
                t.msg_block_index  = msg_block_index;
                t.latency          = have_last_accept ? (cycle - last_accept_cycle) : 0;
                t.gap              = have_last_done   ? (cycle - last_done_cycle)   : 0;
                t.digest_parity    = ^vif.digest_o;
                ap.write(t);
                n_digests_seen++;
                last_done_cycle = cycle;
                have_last_done  = 1'b1;
            end

            // ---------------------------------------------------------------
            // Block handshake. Published after DIGEST so that, when done and
            // the next block coincide (back-to-back), the scoreboard compares
            // the old digest before queueing the next prediction.
            // ---------------------------------------------------------------
            if (vif.block_valid_i === 1'b1 && vif.ready_o === 1'b1) begin
                msg_block_index++;
                t = sha256_txn::type_id::create("t_block");
                t.kind              = SHA256_EV_BLOCK;
                t.cycle             = cycle;
                t.block             = vif.block_i;
                t.msg_block_index   = msg_block_index;
                t.block_class       = classify(vif.block_i);
                t.gap               = have_last_done ? (cycle - last_done_cycle) : 0;
                t.first_after_reset = (msg_block_index == 1);
                ap.write(t);
                n_blocks_seen++;
                last_accept_cycle = cycle;
                have_last_accept  = 1'b1;
            end
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("MON", $sformatf(
                  "observed blocks=%0d digests=%0d inits=%0d resets=%0d cycles=%0d",
                  n_blocks_seen, n_digests_seen, n_inits_seen, n_resets_seen, cycle),
                  UVM_LOW)
    endfunction

endclass
