// =============================================================================
// sha256_agent.svh -- Driver + sequencer + monitor
// =============================================================================

class sha256_agent extends uvm_agent;

    `uvm_component_utils(sha256_agent)

    sha256_driver                  drv;
    uvm_sequencer #(sha256_seq_item) sqr;
    sha256_monitor                 mon;
    uvm_analysis_port #(sha256_txn) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        mon = sha256_monitor::type_id::create("mon", this);
        ap  = new("ap", this);

        if (get_is_active() == UVM_ACTIVE) begin
            drv = sha256_driver::type_id::create("drv", this);
            sqr = uvm_sequencer#(sha256_seq_item)::type_id::create("sqr", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
        mon.ap.connect(ap);
    endfunction

endclass
