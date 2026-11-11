// =============================================================================
// sha256_functions.v
// Pure combinational SHA-256 sub-functions (Fig. 7 building blocks)
//
// Implements:
//   Sigma0, Sigma1  : big-sigma compression functions (on a and e)
//   sigma0, sigma1  : small-sigma message schedule functions
//   Ch, Maj         : choice and majority functions
// All operate on 32-bit words with 32-bit XOR/AND/OR (bitwise).
// =============================================================================

// -----------------------------------------------------------------------------
// Big-Sigma-0: used on working variable 'a' (upper path, Fig. 7)
//   Sigma0(a) = ROTR2(a) XOR ROTR13(a) XOR ROTR22(a)
// -----------------------------------------------------------------------------
module sha256_Sigma0 (
    input  [31:0] x,
    output [31:0] y
);
    assign y = {x[1:0],  x[31:2]}  ^   // ROTR2
               {x[12:0], x[31:13]} ^   // ROTR13
               {x[21:0], x[31:22]};    // ROTR22
endmodule

// -----------------------------------------------------------------------------
// Big-Sigma-1: used on working variable 'e' (lower path, Fig. 7)
//   Sigma1(e) = ROTR6(e) XOR ROTR11(e) XOR ROTR25(e)
// -----------------------------------------------------------------------------
module sha256_Sigma1 (
    input  [31:0] x,
    output [31:0] y
);
    assign y = {x[5:0],  x[31:6]}  ^   // ROTR6
               {x[10:0], x[31:11]} ^   // ROTR11
               {x[24:0], x[31:25]};    // ROTR25
endmodule

// -----------------------------------------------------------------------------
// Small-sigma-0: used in message schedule
//   sigma0(x) = ROTR7(x) XOR ROTR18(x) XOR SHR3(x)
// -----------------------------------------------------------------------------
module sha256_sigma0 (
    input  [31:0] x,
    output [31:0] y
);
    assign y = {x[6:0],  x[31:7]}  ^   // ROTR7
               {x[17:0], x[31:18]} ^   // ROTR18
               {3'b000,  x[31:3]};     // SHR3 (logical, zero-fill)
endmodule

// -----------------------------------------------------------------------------
// Small-sigma-1: used in message schedule
//   sigma1(x) = ROTR17(x) XOR ROTR19(x) XOR SHR10(x)
// -----------------------------------------------------------------------------
module sha256_sigma1 (
    input  [31:0] x,
    output [31:0] y
);
    assign y = {x[16:0], x[31:17]} ^   // ROTR17
               {x[18:0], x[31:19]} ^   // ROTR19
               {10'b0,   x[31:10]};    // SHR10 (logical, zero-fill)
endmodule

// -----------------------------------------------------------------------------
// Ch (Choice): lower-path function on e, f, g (Fig. 7)
//   Ch(e,f,g) = (e AND f) XOR (NOT_e AND g)
// -----------------------------------------------------------------------------
module sha256_Ch (
    input  [31:0] e,
    input  [31:0] f,
    input  [31:0] g,
    output [31:0] y
);
    assign y = (e & f) ^ (~e & g);
endmodule

// -----------------------------------------------------------------------------
// Maj (Majority): upper-path function on a, b, c (Fig. 7)
//   Maj(a,b,c) = (a AND b) XOR (a AND c) XOR (b AND c)
// -----------------------------------------------------------------------------
module sha256_Maj (
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] c,
    output [31:0] y
);
    assign y = (a & b) ^ (a & c) ^ (b & c);
endmodule
