// =============================================================================
// sha256_model_pkg.sv -- Software golden model + message padding helpers
// =============================================================================
// This is an independent, behavioural SystemVerilog implementation of SHA-256
// used by the UVM scoreboard. It is NOT the DUT: it is a straightforward
// software-style model (arrays + loops) so that the RTL and the model share
// no code and cannot hide each other's bugs.
//
// sha256_selftest() hashes the fixed padded blocks from the NIST FIPS 180-4
// known-answer tests and checks the message-padding helper against the same
// vectors. The scoreboard calls it at time zero and reports an error if it
// fails, so the checks below are trustworthy.
// =============================================================================

package sha256_model_pkg;

    // -------------------------------------------------------------------------
    // Round constants: first 32 bits of the fractional parts of the cube roots
    // of the first 64 primes (FIPS 180-4 section 4.2.2)
    // -------------------------------------------------------------------------
    localparam bit [31:0] K[64] = '{
        32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5,
        32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
        32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3,
        32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
        32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc,
        32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
        32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7,
        32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
        32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13,
        32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
        32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3,
        32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
        32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5,
        32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
        32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208,
        32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2
    };

    // -------------------------------------------------------------------------
    // Padded test vectors from the original directed testbench
    // -------------------------------------------------------------------------
    localparam bit [511:0] BLOCK_EMPTY = 512'h80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;

    localparam bit [511:0] BLOCK_ABC = 512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018;

    localparam bit [511:0] BLOCK_HELLO = 512'h68656c6c6f8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000028;

    localparam bit [511:0] BLOCK_FOX = 512'h54686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f67800000000000000000000000000000000000000158;

    localparam bit [511:0] BLOCK_NIST2_1 = 512'h6162636462636465636465666465666765666768666768696768696a68696a6b696a6b6c6a6b6c6d6b6c6d6e6c6d6e6f6d6e6f706e6f70718000000000000000;

    localparam bit [511:0] BLOCK_NIST2_2 = 512'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c0;

    // -------------------------------------------------------------------------
    // Golden reference model
    // -------------------------------------------------------------------------
    class sha256_ref_model;

        bit [31:0] H[8];

        function new();
            reset();
        endfunction

        function void reset();
            H[0] = 32'h6a09e667;
            H[1] = 32'hbb67ae85;
            H[2] = 32'h3c6ef372;
            H[3] = 32'ha54ff53a;
            H[4] = 32'h510e527f;
            H[5] = 32'h9b05688c;
            H[6] = 32'h1f83d9ab;
            H[7] = 32'h5be0cd19;
        endfunction

        function bit [255:0] digest();
            digest = {H[0], H[1], H[2], H[3], H[4], H[5], H[6], H[7]};
        endfunction

        // --- SHA-256 sub-functions -----------------------------------------
        function automatic bit [31:0] rotr32(input bit [31:0] x, input int unsigned n);
            rotr32 = (x >> n) | (x << (32 - n));
        endfunction

        function automatic bit [31:0] big_sigma0(input bit [31:0] x);
            big_sigma0 = rotr32(x, 2) ^ rotr32(x, 13) ^ rotr32(x, 22);
        endfunction

        function automatic bit [31:0] big_sigma1(input bit [31:0] x);
            big_sigma1 = rotr32(x, 6) ^ rotr32(x, 11) ^ rotr32(x, 25);
        endfunction

        function automatic bit [31:0] small_sigma0(input bit [31:0] x);
            small_sigma0 = rotr32(x, 7) ^ rotr32(x, 18) ^ (x >> 3);
        endfunction

        function automatic bit [31:0] small_sigma1(input bit [31:0] x);
            small_sigma1 = rotr32(x, 17) ^ rotr32(x, 19) ^ (x >> 10);
        endfunction

        function automatic bit [31:0] ch(input bit [31:0] e, f, g);
            ch = (e & f) ^ (~e & g);
        endfunction

        function automatic bit [31:0] maj(input bit [31:0] a, b, c);
            maj = (a & b) ^ (a & c) ^ (b & c);
        endfunction

        // --- Compress one 512-bit block; returns the updated digest ---------
        function bit [255:0] update(input bit [511:0] block_i);
            bit [31:0] w[64];
            bit [31:0] a, b, c, d, e, f, g, h;
            bit [31:0] t1, t2;

            for (int t = 0; t < 16; t++)
                w[t] = block_i[511 - 32*t -: 32];

            for (int t = 16; t < 64; t++)
                w[t] = small_sigma1(w[t-2]) + w[t-7] + small_sigma0(w[t-15]) + w[t-16];

            a = H[0]; b = H[1]; c = H[2]; d = H[3];
            e = H[4]; f = H[5]; g = H[6]; h = H[7];

            for (int t = 0; t < 64; t++) begin
                t1 = h + big_sigma1(e) + ch(e, f, g) + K[t] + w[t];
                t2 = big_sigma0(a) + maj(a, b, c);
                h = g;
                g = f;
                f = e;
                e = d + t1;
                d = c;
                c = b;
                b = a;
                a = t1 + t2;
            end

            H[0] = H[0] + a;
            H[1] = H[1] + b;
            H[2] = H[2] + c;
            H[3] = H[3] + d;
            H[4] = H[4] + e;
            H[5] = H[5] + f;
            H[6] = H[6] + g;
            H[7] = H[7] + h;

            update = digest();
        endfunction

    endclass

    // -------------------------------------------------------------------------
    // String / byte-array helpers
    // -------------------------------------------------------------------------
    function automatic void string_to_bytes(input string s, output byte unsigned b[]);
        b = new[s.len()];
        for (int i = 0; i < s.len(); i++)
            b[i] = s[i];
    endfunction

    function automatic string repeat_char(input byte unsigned ch, input int unsigned n);
        string s = "";
        string one = $sformatf("%c", ch);
        for (int i = 0; i < n; i++)
            s = {s, one};
        return s;
    endfunction

    // -------------------------------------------------------------------------
    // FIPS 180-4 message padding. A message of n bytes becomes
    //   ((n + 9 + 63) / 64) * 64 bytes
    // laid out as: message | 8'h80 | zeros | 64-bit big-endian bit length.
    // -------------------------------------------------------------------------
    function automatic void pad_message(input byte unsigned msg[], output bit [511:0] blocks[$]);
        int unsigned n;
        int unsigned total;
        bit [63:0]   nbits;

        n     = msg.size();
        total = ((n + 9 + 63) / 64) * 64;

        nbits = {32'd0, n};
        nbits = nbits << 3;

        blocks.delete();
        for (int unsigned blk = 0; blk < total/64; blk++) begin
            bit [511:0] b;
            b = '0;
            for (int j = 0; j < 64; j++) begin
                int unsigned g;
                byte unsigned v;
                g = blk*64 + j;
                v = 8'h00;
                if (g < n)
                    v = msg[g];
                else if (g == n)
                    v = 8'h80;
                else if (g >= total - 8)
                    v = nbits[8*(total - 1 - g) +: 8];
                b[511 - 8*j -: 8] = v;
            end
            blocks.push_back(b);
        end
    endfunction

    // -------------------------------------------------------------------------
    // Self-test of the model and the padding helper against NIST vectors.
    // Returns 0 on success, otherwise the number of failures.
    // -------------------------------------------------------------------------
    function automatic int unsigned sha256_selftest();
        int unsigned fails = 0;
        sha256_ref_model m = new();
        bit [511:0] blocks[$];
        byte unsigned msg[];
        bit [255:0] d;

        // --- Fixed padded-block KATs (independent of pad_message) -----------
        m.reset();
        d = m.update(BLOCK_EMPTY);
        if (d !== 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855) begin
            $display("[MODEL FAIL] empty-string digest");
            fails++;
        end

        m.reset();
        d = m.update(BLOCK_ABC);
        if (d !== 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad) begin
            $display("[MODEL FAIL] abc digest");
            fails++;
        end

        m.reset();
        d = m.update(BLOCK_HELLO);
        if (d !== 256'h2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824) begin
            $display("[MODEL FAIL] hello digest");
            fails++;
        end

        m.reset();
        d = m.update(BLOCK_FOX);
        if (d !== 256'hd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592) begin
            $display("[MODEL FAIL] fox digest");
            fails++;
        end

        m.reset();
        d = m.update(BLOCK_NIST2_1);
        d = m.update(BLOCK_NIST2_2);
        if (d !== 256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1) begin
            $display("[MODEL FAIL] 56-byte / 2-block digest");
            fails++;
        end

        // --- Padding helper KATs (fixed expected blocks) --------------------
        string_to_bytes("", msg);
        pad_message(msg, blocks);
        if (blocks.size() != 1 || blocks[0] !== BLOCK_EMPTY) begin
            $display("[MODEL FAIL] padding: empty message");
            fails++;
        end

        string_to_bytes("abc", msg);
        pad_message(msg, blocks);
        if (blocks.size() != 1 || blocks[0] !== BLOCK_ABC) begin
            $display("[MODEL FAIL] padding: abc");
            fails++;
        end

        string_to_bytes("hello", msg);
        pad_message(msg, blocks);
        if (blocks.size() != 1 || blocks[0] !== BLOCK_HELLO) begin
            $display("[MODEL FAIL] padding: hello");
            fails++;
        end

        string_to_bytes("The quick brown fox jumps over the lazy dog", msg);
        pad_message(msg, blocks);
        if (blocks.size() != 1 || blocks[0] !== BLOCK_FOX) begin
            $display("[MODEL FAIL] padding: fox");
            fails++;
        end

        string_to_bytes("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", msg);
        pad_message(msg, blocks);
        if (blocks.size() != 2 ||
            blocks[0] !== BLOCK_NIST2_1 ||
            blocks[1] !== BLOCK_NIST2_2) begin
            $display("[MODEL FAIL] padding: 56-byte NIST message");
            fails++;
        end

        // 55 bytes = largest single-block message, 64 bytes = two blocks
        string_to_bytes(repeat_char(8'h71, 55), msg);
        pad_message(msg, blocks);
        if (blocks.size() != 1) begin
            $display("[MODEL FAIL] padding: 55 bytes should be 1 block, got %0d", blocks.size());
            fails++;
        end

        string_to_bytes(repeat_char(8'h7a, 64), msg);
        pad_message(msg, blocks);
        if (blocks.size() != 2) begin
            $display("[MODEL FAIL] padding: 64 bytes should be 2 blocks, got %0d", blocks.size());
            fails++;
        end

        if (fails == 0)
            $display("[MODEL PASS] reference model and padding helper match NIST FIPS 180-4 vectors");
        else
            $display("[MODEL FAIL] %0d model/padding self-test failure(s)", fails);

        return fails;
    endfunction

endpackage
