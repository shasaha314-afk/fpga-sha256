// =============================================================================
// sha256_driver.svh -- Drives the core's simple block interface
// =============================================================================
// Protocol implemented:
//   * wait for ready_o (sampled on negedge)
//   * assert block_valid_i + block_i for exactly one clock
//   * wait for done_o before ending the item
//   * optional init_i pulse before an item re-initialises the hash state
//
// Signals change on negedge so they are stable at the posedge where the DUT
// samples them, and so the monitor's posedge sampling is race-free.
// =============================================================================

class sha256_driver extends uvm_driver #(sha256_seq_item);

    `uvm_component_utils(sha256_driver)

    virtual sha256_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sha256_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "sha256_driver: virtual interface not configured")
    endfunction

    task run_phase(uvm_phase phase);
        // Safe idle values, then a power-on reset.
        vif.init_i        = 1'b0;
        vif.block_valid_i = 1'b0;
        vif.block_i       = '0;
        do_reset(5);

        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    // -------------------------------------------------------------------------
    // Reset (also used by the reset-recovery test)
    // -------------------------------------------------------------------------
    task do_reset(int unsigned cycles);
        vif.rst_n         = 1'b0;
        vif.init_i        = 1'b0;
        vif.block_valid_i = 1'b0;
        vif.block_i       = '0;
        repeat (cycles) @(negedge vif.clk);
        vif.rst_n = 1'b1;
        @(negedge vif.clk);
        `uvm_info("DRV", "reset released", UVM_HIGH)
    endtask

    // -------------------------------------------------------------------------
    // Wait until the core can accept a block.
    // -------------------------------------------------------------------------
    task wait_ready();
        do @(negedge vif.clk);
        while (!(vif.rst_n === 1'b1 && vif.ready_o === 1'b1));
    endtask

    task wait_done();
        do @(negedge vif.clk);
        while (!(vif.rst_n === 1'b1 && vif.done_o === 1'b1));
        // done_o is sampled by the monitor at the following posedge; let it
        // run before the item completes so the last digest is never lost.
        @(negedge vif.clk);
    endtask

    // -------------------------------------------------------------------------
    // Drive one 512-bit block.
    // -------------------------------------------------------------------------
    task drive_one_block(bit [511:0] blk);
        wait_ready();
        vif.block_i       = blk;
        vif.block_valid_i = 1'b1;
        @(negedge vif.clk);          // valid is high across exactly one posedge
        vif.block_valid_i = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Drive a whole item.
    // -------------------------------------------------------------------------
    task drive_item(sha256_seq_item item);
        `uvm_info("DRV", $sformatf("driving %s", item.convert2string()), UVM_HIGH)

        if (item.blocks.size() == 0) begin
            `uvm_warning("DRV", "item contains no blocks -- nothing to drive")
            return;
        end

        if (item.do_init) begin
            wait_ready();
            vif.init_i = 1'b1;
            @(negedge vif.clk);
            vif.init_i = 1'b0;
        end

        if (item.reset_mid) begin
            if (item.blocks.size() > 0)
                drive_one_block(item.blocks[0]);
            repeat (item.reset_after) @(negedge vif.clk);
            `uvm_info("DRV", "injecting mid-computation reset", UVM_LOW)
            do_reset(3);
            return;
        end

        for (int unsigned i = 0; i < item.blocks.size(); i++) begin
            drive_one_block(item.blocks[i]);
            if (i != item.blocks.size() - 1) begin
                if (item.gap_cycles > 0) begin
                    wait_done();
                    repeat (item.gap_cycles) @(negedge vif.clk);
                end
                // gap_cycles == 0: immediately wait for ready, giving
                // back-to-back blocks at the core's maximum throughput.
            end
        end

        wait_done();
    endtask

endclass
