// =============================================================================
// sha256_tests.svh -- UVM tests
// =============================================================================
// Run one with:  +UVM_TESTNAME=sha256_kat_test
// =============================================================================

// -----------------------------------------------------------------------------
// Base test: builds the environment and owns the phase objection
// -----------------------------------------------------------------------------
class sha256_base_test extends uvm_test;

    `uvm_component_utils(sha256_base_test)

    sha256_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = sha256_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        run_test_sequence();
        phase.drop_objection(this);
    endtask

    // Derived tests override this
    virtual task run_test_sequence();
    endtask

    function void final_phase(uvm_phase phase);
        uvm_report_server svr;
        int unsigned errs;
        int unsigned fats;

        svr  = uvm_report_server::get_server();
        errs = svr.get_severity_count(UVM_ERROR);
        fats = svr.get_severity_count(UVM_FATAL);

        if (errs == 0 && fats == 0)
            $display("SHA256_TEST_RESULT: PASS");
        else
            $display("SHA256_TEST_RESULT: FAIL (uvm_errors=%0d uvm_fatals=%0d)", errs, fats);
    endfunction

endclass

// -----------------------------------------------------------------------------
// Directed NIST known-answer tests
// -----------------------------------------------------------------------------
class sha256_kat_test extends sha256_base_test;

    `uvm_component_utils(sha256_kat_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_sequence();
        sha256_kat_seq seq = sha256_kat_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
    endtask

endclass

// -----------------------------------------------------------------------------
// Constrained-random messages
// -----------------------------------------------------------------------------
class sha256_random_test extends sha256_base_test;

    `uvm_component_utils(sha256_random_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_sequence();
        sha256_random_seq seq = sha256_random_seq::type_id::create("seq");
        int unsigned n = 100;
        void'($value$plusargs("NUM_ITEMS=%d", n));
        seq.num_items = n;
        `uvm_info("TEST", $sformatf("running %0d random messages", n), UVM_LOW)
        seq.start(env.agent.sqr);
    endtask

endclass

// -----------------------------------------------------------------------------
// Longer random messages, more back-pressure
// -----------------------------------------------------------------------------
class sha256_stress_test extends sha256_base_test;

    `uvm_component_utils(sha256_stress_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_sequence();
        sha256_stress_seq seq = sha256_stress_seq::type_id::create("seq");
        int unsigned n = 300;
        void'($value$plusargs("NUM_ITEMS=%d", n));
        seq.num_items = n;
        `uvm_info("TEST", $sformatf("running %0d stress messages", n), UVM_LOW)
        seq.start(env.agent.sqr);
    endtask

endclass

// -----------------------------------------------------------------------------
// Reset in the middle of a compression, then verify recovery
// -----------------------------------------------------------------------------
class sha256_reset_test extends sha256_base_test;

    `uvm_component_utils(sha256_reset_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_sequence();
        sha256_reset_seq seq = sha256_reset_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
    endtask

endclass

// -----------------------------------------------------------------------------
// Directed coverage closure
// -----------------------------------------------------------------------------
class sha256_closure_test extends sha256_base_test;

    `uvm_component_utils(sha256_closure_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_sequence();
        sha256_closure_seq seq = sha256_closure_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
    endtask

endclass

// -----------------------------------------------------------------------------
// NIST 1,000,000 x 'a' (slow, opt-in)
// -----------------------------------------------------------------------------
class sha256_million_a_test extends sha256_base_test;

    `uvm_component_utils(sha256_million_a_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_test_sequence();
        sha256_million_a_seq seq = sha256_million_a_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
    endtask

endclass
