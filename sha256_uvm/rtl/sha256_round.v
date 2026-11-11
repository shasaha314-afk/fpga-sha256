// =============================================================================
// sha256_round.v
// One iteration of the SHA-256 round function — DIRECT hardware map of Fig. 7.
//
// DATAPATH (combinational, matches Fig. 7 left-to-right):
//
//   UPPER PATH  (computes new 'a'):
//     Sigma0(a)  --> |
//     Maj(a,b,c) --> [+] --> T2
//
//   LOWER PATH  (computes new 'e'):
//     Sigma1(e)    -->|
//     Ch(e,f,g)    -->|
//     h            -->|
//     Wt + Kt ----->[+]--> [+] --> T1
//
//   OUTPUT WIRES (a' through h', Fig. 7 right side):
//     a' = T1 + T2
//     b' = a
//     c' = b
//     d' = c
//     e' = d + T1
//     f' = e
//     g' = f
//     h' = g
//
// All adders are mod-2^32 (carry truncated), matching ⊞ in the diagram.
// =============================================================================

module sha256_round (
    // Current working variables (left side of Fig. 7)
    input  [31:0] a, b, c, d, e, f, g, h,
    // Round word and constant
    input  [31:0] Wt,
    input  [31:0] Kt,
    // Updated working variables (right side of Fig. 7, one iteration)
    output [31:0] a_new, b_new, c_new, d_new,
    output [31:0] e_new, f_new, g_new, h_new
);
    // -------------------------------------------------------------------------
    // Instantiate sub-functions (Fig. 7 blocks)
    // -------------------------------------------------------------------------
    wire [31:0] S0_out;   // Sigma0(a)
    wire [31:0] S1_out;   // Sigma1(e)
    wire [31:0] maj_out;  // Maj(a,b,c)
    wire [31:0] ch_out;   // Ch(e,f,g)

    sha256_Sigma0 u_S0  (.x(a),         .y(S0_out));
    sha256_Sigma1 u_S1  (.x(e),         .y(S1_out));
    sha256_Maj    u_Maj (.a(a), .b(b), .c(c), .y(maj_out));
    sha256_Ch     u_Ch  (.e(e), .f(f), .g(g), .y(ch_out));

    // -------------------------------------------------------------------------
    // T2 = Sigma0(a) + Maj(a,b,c)   [upper adder in Fig. 7]
    // -------------------------------------------------------------------------
    wire [31:0] T2;
    assign T2 = S0_out + maj_out;      // mod 2^32 implicit in Verilog

    // -------------------------------------------------------------------------
    // T1 = h + Sigma1(e) + Ch(e,f,g) + Wt + Kt
    // Fig. 7 shows the bottom adder first combines Wt+Kt,
    // then feeds into the chain with Ch, Sigma1, h.
    // -------------------------------------------------------------------------
    wire [31:0] WK;                    // Wt + Kt  (bottom adder box, Fig. 7)
    assign WK = Wt + Kt;

    wire [31:0] T1;
    assign T1 = h + S1_out + ch_out + WK;

    // -------------------------------------------------------------------------
    // Output: rotated working variables  a'–h'  (right side of Fig. 7)
    // -------------------------------------------------------------------------
    assign a_new = T1 + T2;            // new a = T1 + T2
    assign b_new = a;                  // new b = old a  (wire passthrough)
    assign c_new = b;
    assign d_new = c;
    assign e_new = d + T1;             // new e = d + T1
    assign f_new = e;
    assign g_new = f;
    assign h_new = g;

endmodule
