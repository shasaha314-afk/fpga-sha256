// =============================================================================
// sha256_env.svh -- Agent + scoreboard + coverage
// =============================================================================

class sha256_env extends uvm_env;

    `uvm_component_utils(sha256_env)

    sha256_agent      agent;
    sha256_scoreboard sb;
    sha256_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent = sha256_agent::type_id::create("agent", this);
        sb    = sha256_scoreboard::type_id::create("sb", this);
        cov   = sha256_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.ap.connect(sb.imp);
        agent.ap.connect(cov.analysis_export);
    endfunction

endclass
