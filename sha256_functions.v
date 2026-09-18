module sha256_Sigma0 (
    input  [31:0] x,
    output [31:0] y
);
    assign y = {x[1:0],  x[31:2]}  ^   // ROTR2
               {x[12:0], x[31:13]} ^   // ROTR13
               {x[21:0], x[31:22]};    // ROTR22
endmodule

module sha256_Sigma1 (
    input  [31:0] x,
    output [31:0] y
);
    assign y = {x[5:0],  x[31:6]}  ^   // ROTR6
               {x[10:0], x[31:11]} ^   // ROTR11
               {x[24:0], x[31:25]};    // ROTR25
endmodule

module sha256_sigma0 (
    input  [31:0] x,
    output [31:0] y
);
    assign y = {x[6:0],  x[31:7]}  ^   // ROTR7
               {x[17:0], x[31:18]} ^   // ROTR18
               {3'b000,  x[31:3]};     // SHR3 
endmodule

module sha256_sigma1 (
    input  [31:0] x,
    output [31:0] y
);
    assign y = {x[16:0], x[31:17]} ^   // ROTR17
               {x[18:0], x[31:19]} ^   // ROTR19
               {10'b0,   x[31:10]};    // SHR10 
endmodule

module sha256_Ch (
    input  [31:0] e,
    input  [31:0] f,
    input  [31:0] g,
    output [31:0] y
);
    assign y = (e & f) ^ (~e & g);
endmodule

module sha256_Maj (
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] c,
    output [31:0] y
);
    assign y = (a & b) ^ (a & c) ^ (b & c);
endmodule
