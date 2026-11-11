// =============================================================================
// sha256_seq_item.svh -- One message / burst of 512-bit blocks
// =============================================================================
// n_blocks, block pattern, inter-block gap and init behaviour are randomized
// under constraints. The actual 512-bit payload is filled in post_randomize
// with $urandom (the constraints are on the properties that matter for
// verification: message length, data class, back-pressure and chaining).
// =============================================================================

class sha256_seq_item extends uvm_sequence_item;

    rand int unsigned       n_blocks;     // blocks in this item: 1..8
    rand sha256_blk_class_e pattern;      // payload data class
    rand int unsigned       gap_cycles;   // idle clocks between blocks
    rand bit                do_init;      // re-init hash state before item

    // Not randomized: set by directed sequences
    bit [511:0] blocks[$];
    bit         reset_mid;                // reset the core mid-computation
    int unsigned reset_after;             // clocks after first block
    string      label;

    constraint c_n_blocks {
        n_blocks inside {[1:8]};
    }

    constraint c_pattern {
        pattern dist {
            SHA256_BLK_MIXED := 70,
            SHA256_BLK_ZERO  := 8,
            SHA256_BLK_ONES  := 8,
            SHA256_BLK_ALT   := 14
        };
    }

    constraint c_gap {
        gap_cycles dist {
            0        := 80,
            [1:3]    := 15,
            [4:12]   := 5
        };
    }

    constraint c_init {
        do_init dist {
            1 := 90,
            0 := 10
        };
    }

    `uvm_object_utils(sha256_seq_item)

    function new(string name = "sha256_seq_item");
        super.new(name);
        reset_mid  = 1'b0;
        reset_after = 0;
        label      = "";
    endfunction

    // Fill the payload after the constrained properties are chosen.
    function void post_randomize();
        bit [511:0] b;
        blocks.delete();
        for (int unsigned i = 0; i < n_blocks; i++) begin
            for (int unsigned w = 0; w < 16; w++)
                b[32*w +: 32] = $urandom();
            case (pattern)
                SHA256_BLK_ZERO: b = '0;
                SHA256_BLK_ONES: b = '1;
                SHA256_BLK_ALT:  b = {256{2'b10}};
                default:         ; // keep random payload
            endcase
            blocks.push_back(b);
        end
    endfunction

    function void set_blocks(bit [511:0] b[$]);
        blocks.delete();
        foreach (b[i])
            blocks.push_back(b[i]);
    endfunction

    function void set_message(byte unsigned msg[]);
        bit [511:0] b[$];
        pad_message(msg, b);
        set_blocks(b);
        n_blocks = b.size();
    endfunction

    function string convert2string();
        return $sformatf("n_blocks=%0d pattern=%s gap=%0d init=%0d label=\"%s\"",
                         blocks.size(), pattern.name(), gap_cycles, do_init, label);
    endfunction

endclass
