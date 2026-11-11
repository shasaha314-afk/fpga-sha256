// =============================================================================
// sha256_sequences.svh -- Directed and constrained-random stimulus
// =============================================================================

// -----------------------------------------------------------------------------
// KAT sequence: NIST FIPS 180-4 vectors plus padding-boundary lengths
// -----------------------------------------------------------------------------
class sha256_kat_seq extends uvm_sequence #(sha256_seq_item);

    `uvm_object_utils(sha256_kat_seq)

    function new(string name = "sha256_kat_seq");
        super.new(name);
    endfunction

    task send_msg(string s, string lbl);
        sha256_seq_item item;
        byte unsigned msg[];
        item = sha256_seq_item::type_id::create("item");
        start_item(item);
        string_to_bytes(s, msg);
        item.set_message(msg);
        item.do_init  = 1'b1;
        item.label    = lbl;
        finish_item(item);
        `uvm_info("KAT", $sformatf("sent \"%s\" (%0d bytes -> %0d block(s))",
                  lbl, msg.size(), item.blocks.size()), UVM_LOW)
    endtask

    task body();
        send_msg("", "empty");
        send_msg("abc", "abc");
        send_msg("hello", "hello");
        send_msg("The quick brown fox jumps over the lazy dog", "fox");
        send_msg("The quick brown fox jumps over the lazy dog.", "fox-period");
        send_msg("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                 "NIST 56-byte 2-block vector");
        send_msg(repeat_char(8'h71, 55), "55 bytes (largest 1-block message)");
        send_msg(repeat_char(8'h7a, 64), "64 bytes (exactly 2 blocks)");
        send_msg(repeat_char(8'h78, 130), "130 bytes (3 blocks)");
    endtask

endclass

// -----------------------------------------------------------------------------
// General constrained-random sequence
// -----------------------------------------------------------------------------
class sha256_random_seq extends uvm_sequence #(sha256_seq_item);

    `uvm_object_utils(sha256_random_seq)

    int unsigned num_items = 100;

    function new(string name = "sha256_random_seq");
        super.new(name);
    endfunction

    virtual task body();
        sha256_seq_item item;
        for (int unsigned i = 0; i < num_items; i++) begin
            item = sha256_seq_item::type_id::create("item");
            start_item(item);
            if (item.randomize() == 0)
                `uvm_fatal("RAND", "sha256_seq_item randomization failed")
            finish_item(item);
        end
    endtask

endclass

// -----------------------------------------------------------------------------
// Longer messages + more back-pressure, for coverage closure
// -----------------------------------------------------------------------------
class sha256_stress_seq extends sha256_random_seq;

    `uvm_object_utils(sha256_stress_seq)

    function new(string name = "sha256_stress_seq");
        super.new(name);
        num_items = 300;
    endfunction

    virtual task body();
        sha256_seq_item item;
        for (int unsigned i = 0; i < num_items; i++) begin
            int unsigned rand_ok;
            item = sha256_seq_item::type_id::create("item");
            start_item(item);
            rand_ok = item.randomize() with {
                n_blocks inside {[4:8]};
                gap_cycles dist { 0 := 60, [1:12] := 40 };
            };
            if (rand_ok == 0)
                `uvm_fatal("RAND", "stress item randomization failed")
            finish_item(item);
        end
    endtask

endclass

// -----------------------------------------------------------------------------
// Reset-during-operation, then prove the core recovers
// -----------------------------------------------------------------------------
class sha256_reset_seq extends uvm_sequence #(sha256_seq_item);

    `uvm_object_utils(sha256_reset_seq)

    function new(string name = "sha256_reset_seq");
        super.new(name);
    endfunction

    task send_abc();
        sha256_seq_item item;
        byte unsigned msg[];
        item = sha256_seq_item::type_id::create("item");
        start_item(item);
        string_to_bytes("abc", msg);
        item.set_message(msg);
        item.do_init = 1'b1;
        item.label   = "post-reset abc";
        finish_item(item);
    endtask

    task body();
        sha256_seq_item item;
        bit [511:0] b;

        // 1. Start a block, then hit reset halfway through the 68-cycle job.
        item = sha256_seq_item::type_id::create("reset_item");
        start_item(item);
        b = '0;
        for (int unsigned w = 0; w < 16; w++)
            b[32*w +: 32] = $urandom();
        item.blocks.push_back(b);
        item.n_blocks    = 1;
        item.do_init     = 1'b1;
        item.reset_mid   = 1'b1;
        item.reset_after = 20;
        item.label       = "interrupted by reset";
        finish_item(item);

        // 2. The very next message must be correct.
        send_abc();

        // 3. ...and so must ordinary random traffic afterwards.
        repeat (5) begin
            int unsigned rand_ok;
            item = sha256_seq_item::type_id::create("item");
            start_item(item);
            rand_ok = item.randomize() with { n_blocks inside {[1:4]}; };
            if (rand_ok == 0)
                `uvm_fatal("RAND", "reset-sequence randomization failed")
            finish_item(item);
        end
    endtask

endclass

// -----------------------------------------------------------------------------
// Coverage-closure sequence: legal corner cases the random run may not hit
// -----------------------------------------------------------------------------
// Four 40-block messages (one per payload class) cover every block position
// and the class x position cross. Short messages cover the remaining message
// length bins, and explicit gaps cover the gap distribution.
// -----------------------------------------------------------------------------
class sha256_closure_seq extends uvm_sequence #(sha256_seq_item);

    `uvm_object_utils(sha256_closure_seq)

    function new(string name = "sha256_closure_seq");
        super.new(name);
    endfunction

    function bit [511:0] make_block(sha256_blk_class_e cls);
        bit [511:0] b;
        for (int unsigned w = 0; w < 16; w++)
            b[32*w +: 32] = $urandom();
        case (cls)
            SHA256_BLK_ZERO: b = '0;
            SHA256_BLK_ONES: b = '1;
            SHA256_BLK_ALT:  b = {256{2'b10}};
            default:         ;
        endcase
        return b;
    endfunction

    task send_blocks(int unsigned n, sha256_blk_class_e cls,
                     int unsigned gap, bit do_init, string lbl);
        sha256_seq_item item;
        item = sha256_seq_item::type_id::create("item");
        start_item(item);
        item.blocks.delete();
        for (int unsigned i = 0; i < n; i++)
            item.blocks.push_back(make_block(cls));
        item.n_blocks    = n;
        item.do_init     = do_init;
        item.gap_cycles  = gap;
        item.label       = lbl;
        finish_item(item);
    endtask

    task body();
        // Every block position for every payload class (1, 2, 3, 4-8, 9-32, 33+)
        send_blocks(40, SHA256_BLK_MIXED, 0, 1, "40 mixed blocks");
        send_blocks(40, SHA256_BLK_ZERO,  0, 1, "40 all-zero blocks");
        send_blocks(40, SHA256_BLK_ONES,  0, 1, "40 all-ones blocks");
        send_blocks(40, SHA256_BLK_ALT,   0, 1, "40 alternating blocks");

        // Gap bins
        send_blocks(2, SHA256_BLK_MIXED,  1, 1, "2 blocks, short gap");
        send_blocks(2, SHA256_BLK_MIXED,  3, 1, "2 blocks, gap 3");
        send_blocks(2, SHA256_BLK_MIXED, 10, 1, "2 blocks, gap 10");
        send_blocks(2, SHA256_BLK_MIXED, 25, 1, "2 blocks, long gap");

        // Message-length bins and digest parity
        send_blocks(1, SHA256_BLK_MIXED, 0, 1, "1 block");
        send_blocks(2, SHA256_BLK_MIXED, 0, 1, "2 blocks");
        send_blocks(3, SHA256_BLK_MIXED, 0, 1, "3 blocks");
        send_blocks(4, SHA256_BLK_MIXED, 0, 1, "4 blocks");
        send_blocks(9, SHA256_BLK_MIXED, 0, 1, "9 blocks");
        send_blocks(1, SHA256_BLK_MIXED, 0, 1, "extra random 1-block");
        send_blocks(1, SHA256_BLK_MIXED, 0, 1, "extra random 1-block");
        send_blocks(1, SHA256_BLK_MIXED, 0, 1, "extra random 1-block");
    endtask

endclass

// -----------------------------------------------------------------------------
// NIST 1,000,000 x 'a' vector (slow; not in the default regression)
// -----------------------------------------------------------------------------
class sha256_million_a_seq extends uvm_sequence #(sha256_seq_item);

    `uvm_object_utils(sha256_million_a_seq)

    function new(string name = "sha256_million_a_seq");
        super.new(name);
    endfunction

    task body();
        sha256_seq_item item;
        bit [511:0] b;
        int unsigned nblocks;

        nblocks = 15626; // ceil((1000000 + 9) / 64)
        item = sha256_seq_item::type_id::create("item");
        start_item(item);
        item.blocks.delete();
        b = {64{8'h61}};
        for (int unsigned i = 0; i < 15625; i++)
            item.blocks.push_back(b);
        b = '0;
        b[511 -: 8] = 8'h80;
        b[63:0]     = 64'd8000000; // message length in bits
        item.blocks.push_back(b);
        item.n_blocks = nblocks;
        item.do_init  = 1'b1;
        item.label    = "1,000,000 x 'a'";
        finish_item(item);
    endtask

endclass
