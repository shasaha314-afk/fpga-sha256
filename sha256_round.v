module sha256_round (
    input  [31:0] a, b, c, d, e, f, g, h,
    input  [31:0] Wt,
    input  [31:0] Kt,
    output [31:0] a_new, b_new, c_new, d_new,
    output [31:0] e_new, f_new, g_new, h_new
);
    wire [31:0] S0_out;   // Sigma0(a)
    wire [31:0] S1_out;   // Sigma1(e)
    wire [31:0] maj_out;  // Maj(a,b,c)
    wire [31:0] ch_out;   // Ch(e,f,g)

    sha256_Sigma0 u_S0  (.x(a),         .y(S0_out));
    sha256_Sigma1 u_S1  (.x(e),         .y(S1_out));
    sha256_Maj    u_Maj (.a(a), .b(b), .c(c), .y(maj_out));
    sha256_Ch     u_Ch  (.e(e), .f(f), .g(g), .y(ch_out));

    wire [31:0] T2;
    assign T2 = S0_out + maj_out;      

    wire [31:0] WK;                    
    assign WK = Wt + Kt;

    wire [31:0] T1;
    assign T1 = h + S1_out + ch_out + WK;

    assign a_new = T1 + T2;            
    assign b_new = a;                  
    assign c_new = b;
    assign d_new = c;
    assign e_new = d + T1;             
    assign f_new = e;
    assign g_new = f;
    assign h_new = g;

endmodule
