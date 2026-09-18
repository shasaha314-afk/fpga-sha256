`timescale 1ns/1ps

module sha256_tb;

    reg          clk, rst_n, init_i, block_valid_i;
    reg  [511:0] block_i;
    wire         ready_o, done_o;
    wire [255:0] digest_o;

    sha256_core dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .init_i        (init_i),
        .block_valid_i (block_valid_i),
        .block_i       (block_i),
        .ready_o       (ready_o),
        .done_o        (done_o),
        .digest_o      (digest_o)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    localparam [511:0] BLOCK_EMPTY = 512'h80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;

    localparam [511:0] BLOCK_ABC = 512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018;

    localparam [511:0] BLOCK_HELLO = 512'h68656c6c6f8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000028;

    localparam [511:0] BLOCK_FOX = 512'h54686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f67800000000000000000000000000000000000000158;

    localparam [511:0] BLOCK_NIST2_1 = 512'h6162636462636465636465666465666765666768666768696768696a68696a6b696a6b6c6a6b6c6d6b6c6d6e6c6d6e6f6d6e6f706e6f70718000000000000000;

    localparam [511:0] BLOCK_NIST2_2 = 512'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c0;

    integer pass_cnt, fail_cnt, test_num;

    task reset_core;
    begin
        rst_n         = 0;
        init_i        = 0;
        block_valid_i = 0;
        block_i       = 512'h0;
        repeat(3) @(posedge clk); #1;
        rst_n = 1;
        @(posedge clk); #1;
    end
    endtask

    task reinit_core;
    begin
        @(posedge clk); #1;
        init_i = 1;
        @(posedge clk); #1;
        init_i = 0;
        @(posedge clk); #1;
    end
    endtask

    task feed_block;
        input [511:0] blk;
    begin
        wait (ready_o === 1'b1);
        @(posedge clk); #1;
        block_valid_i = 1;
        block_i       = blk;
        @(posedge clk); #1;
        block_valid_i = 0;
        wait (done_o === 1'b1);
        @(posedge clk); #1;
    end
    endtask

    task check_result;
        input [255:0] expected;
        input [511:0] label;
    begin
        if (digest_o === expected) begin
            $display("[PASS] Test %0d: %0s", test_num, label);
            $display("       %064x", digest_o);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] Test %0d: %0s", test_num, label);
            $display("       Got     : %064x", digest_o);
            $display("       Expected: %064x", expected);
            fail_cnt = fail_cnt + 1;
        end
        $display("");
        test_num = test_num + 1;
    end
    endtask

    initial begin
        $display("  SHA-256 Verilog Testbench  (NIST FIPS 180-4)  ");
        $display("");

        pass_cnt = 0; fail_cnt = 0; test_num = 1;

        reset_core;

        $display("--- Test 1: sha256(\"\") ---");
        feed_block(BLOCK_EMPTY);
        check_result(256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855,
                     "empty string");

        reinit_core;
        $display("--- Test 2: sha256(\"abc\") ---");
        feed_block(BLOCK_ABC);
        check_result(256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad,
                     "abc");

        reinit_core;
        $display("--- Test 3: sha256(\"hello\") ---");
        feed_block(BLOCK_HELLO);
        check_result(256'h2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824,
                     "hello");

        reinit_core;
        $display("--- Test 4: sha256(\"The quick brown fox...\") ---");
        feed_block(BLOCK_FOX);
        check_result(256'hd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592,
                     "fox");

        reinit_core;
        $display("--- Test 5: sha256(\"abcdbcdecdef...nopq\") -- 2 blocks ---");
        feed_block(BLOCK_NIST2_1);
        feed_block(BLOCK_NIST2_2);
        check_result(256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1,
                     "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");

       
        $display("Results: %0d passed, %0d failed", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("ALL TESTS PASSED -- RTL matches NIST FIPS 180-4");
        else
            $display("FAILURES -- check waveforms with gtkwave");
      

        $finish;
    end

    // Watchdog
    initial begin
        #5000000;
        $display("[ERROR] Watchdog timeout!");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("sha256_wave.vcd");
        $dumpvars(0, sha256_tb);
    end

endmodule
