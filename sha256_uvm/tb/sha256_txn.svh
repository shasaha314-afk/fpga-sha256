// =============================================================================
// sha256_txn.svh -- Monitor -> scoreboard/coverage transaction
// =============================================================================
// One transaction type carries every observable event on the interface.
// The scoreboard reacts to BLOCK/DIGEST/INIT/RESET; functional coverage
// samples protocol and data properties from the same stream.
// =============================================================================

typedef enum bit [1:0] {
    SHA256_EV_RESET  = 2'd0,
    SHA256_EV_INIT   = 2'd1,
    SHA256_EV_BLOCK  = 2'd2,
    SHA256_EV_DIGEST = 2'd3
} sha256_ev_e;

typedef enum bit [1:0] {
    SHA256_BLK_MIXED = 2'd0,
    SHA256_BLK_ZERO  = 2'd1,
    SHA256_BLK_ONES  = 2'd2,
    SHA256_BLK_ALT   = 2'd3
} sha256_blk_class_e;

class sha256_txn extends uvm_object;

    sha256_ev_e        kind;
    bit [511:0]        block;
    bit [255:0]        digest;
    int unsigned       cycle;
    int unsigned       msg_block_index;  // 1-based block number in this message
    int unsigned       latency;          // accept -> done, in clocks
    int unsigned       gap;              // clocks since previous done
    sha256_blk_class_e block_class;
    bit                digest_parity;
    bit                first_after_reset;

    `uvm_object_utils(sha256_txn)

    function new(string name = "sha256_txn");
        super.new(name);
    endfunction

    function string convert2string();
        case (kind)
            SHA256_EV_RESET:
                return $sformatf("RESET @%0d", cycle);
            SHA256_EV_INIT:
                return $sformatf("INIT @%0d", cycle);
            SHA256_EV_BLOCK:
                return $sformatf("BLOCK #%0d @%0d class=%s gap=%0d",
                                 msg_block_index, cycle, block_class.name(), gap);
            SHA256_EV_DIGEST:
                return $sformatf("DIGEST #%0d @%0d latency=%0d %064x",
                                 msg_block_index, cycle, latency, digest);
            default:
                return "UNKNOWN";
        endcase
    endfunction

endclass
