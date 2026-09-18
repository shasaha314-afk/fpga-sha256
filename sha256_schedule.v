module sha256_schedule (
    input         clk,
    input         rst_n,
    input         load_i,
    input [511:0] block_i,
    input         advance_i,
    output [31:0] Wt_o
);
    reg [31:0] buf0,  buf1,  buf2,  buf3,
               buf4,  buf5,  buf6,  buf7,
               buf8,  buf9,  buf10, buf11,
               buf12, buf13, buf14, buf15;

    wire [31:0] sig1;
    assign sig1 = {buf14[16:0], buf14[31:17]} ^
                  {buf14[18:0], buf14[31:19]} ^
                  {10'b0, buf14[31:10]};

    wire [31:0] sig0;
    assign sig0 = {buf1[6:0],  buf1[31:7]}  ^
                  {buf1[17:0], buf1[31:18]} ^
                  {3'b0, buf1[31:3]};

    wire [31:0] W_new;
    assign W_new = sig1 + buf9 + sig0 + buf0;

    assign Wt_o = buf0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buf0<=0; buf1<=0; buf2<=0;  buf3<=0;
            buf4<=0; buf5<=0; buf6<=0;  buf7<=0;
            buf8<=0; buf9<=0; buf10<=0; buf11<=0;
            buf12<=0; buf13<=0; buf14<=0; buf15<=0;
        end
        else if (load_i) begin
            buf0  <= block_i[511:480]; buf1  <= block_i[479:448];
            buf2  <= block_i[447:416]; buf3  <= block_i[415:384];
            buf4  <= block_i[383:352]; buf5  <= block_i[351:320];
            buf6  <= block_i[319:288]; buf7  <= block_i[287:256];
            buf8  <= block_i[255:224]; buf9  <= block_i[223:192];
            buf10 <= block_i[191:160]; buf11 <= block_i[159:128];
            buf12 <= block_i[127:96];  buf13 <= block_i[95:64];
            buf14 <= block_i[63:32];   buf15 <= block_i[31:0];
        end
        else if (advance_i) begin
            buf0<=buf1; buf1<=buf2; buf2<=buf3;   buf3<=buf4;
            buf4<=buf5; buf5<=buf6; buf6<=buf7;   buf7<=buf8;
            buf8<=buf9; buf9<=buf10; buf10<=buf11; buf11<=buf12;
            buf12<=buf13; buf13<=buf14; buf14<=buf15; buf15<=W_new;
        end
    end

endmodule
