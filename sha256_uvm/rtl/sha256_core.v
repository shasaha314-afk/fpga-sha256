// =============================================================================
// sha256_core.v  —  SHA-256 Compression Core
//
// Implements the full SHA-256 block compression as described in NIST FIPS 180-4,
// directly mirroring the hardware architecture of Fig. 7.
//
// STATE MACHINE (68 cycles per 512-bit block):
//   IDLE  (1 cy) : wait for block_valid_i
//   LOAD  (1 cy) : latch a-h = H0-H7, drive sched_load (combinational)
//   ROUND (64 cy): 64-round compression loop, drive sched_advance (combinational)
//   ACCUM (1 cy) : H' = H + [a..h]  (right-side adders in Fig. 7)
//   DONE  (1 cy) : pulse done_o, return to IDLE
//
// KEY TIMING DESIGN:
//   sched_load    is a COMBINATIONAL wire = (state == ST_LOAD)
//   sched_advance is a COMBINATIONAL wire = (state == ST_ROUND)
//   This guarantees sha256_schedule latches W[0..15] at the posedge that
//   transitions LOAD->ROUND, so Wt_o = W[0] is valid at the very first
//   ST_ROUND cycle with round_cnt = 0.  Each subsequent posedge in ST_ROUND
//   shifts the schedule and presents W[round_cnt] correctly.
// =============================================================================

module sha256_core (
    input         clk,
    input         rst_n,
    input         init_i,          // re-init hash state to IV (between messages)
    input         block_valid_i,   // pulse: new 512-bit block available
    input [511:0] block_i,
    output reg    ready_o,
    output reg    done_o,
    output [255:0] digest_o
);

    // -------------------------------------------------------------------------
    // NIST Initial Hash Values
    // -------------------------------------------------------------------------
    localparam [31:0]
        IV0=32'h6a09e667, IV1=32'hbb67ae85,
        IV2=32'h3c6ef372, IV3=32'ha54ff53a,
        IV4=32'h510e527f, IV5=32'h9b05688c,
        IV6=32'h1f83d9ab, IV7=32'h5be0cd19;

    // -------------------------------------------------------------------------
    // Round constants
    // -------------------------------------------------------------------------
    reg [31:0] K [0:63];
    initial begin
        K[ 0]=32'h428a2f98; K[ 1]=32'h71374491; K[ 2]=32'hb5c0fbcf; K[ 3]=32'he9b5dba5;
        K[ 4]=32'h3956c25b; K[ 5]=32'h59f111f1; K[ 6]=32'h923f82a4; K[ 7]=32'hab1c5ed5;
        K[ 8]=32'hd807aa98; K[ 9]=32'h12835b01; K[10]=32'h243185be; K[11]=32'h550c7dc3;
        K[12]=32'h72be5d74; K[13]=32'h80deb1fe; K[14]=32'h9bdc06a7; K[15]=32'hc19bf174;
        K[16]=32'he49b69c1; K[17]=32'hefbe4786; K[18]=32'h0fc19dc6; K[19]=32'h240ca1cc;
        K[20]=32'h2de92c6f; K[21]=32'h4a7484aa; K[22]=32'h5cb0a9dc; K[23]=32'h76f988da;
        K[24]=32'h983e5152; K[25]=32'ha831c66d; K[26]=32'hb00327c8; K[27]=32'hbf597fc7;
        K[28]=32'hc6e00bf3; K[29]=32'hd5a79147; K[30]=32'h06ca6351; K[31]=32'h14292967;
        K[32]=32'h27b70a85; K[33]=32'h2e1b2138; K[34]=32'h4d2c6dfc; K[35]=32'h53380d13;
        K[36]=32'h650a7354; K[37]=32'h766a0abb; K[38]=32'h81c2c92e; K[39]=32'h92722c85;
        K[40]=32'ha2bfe8a1; K[41]=32'ha81a664b; K[42]=32'hc24b8b70; K[43]=32'hc76c51a3;
        K[44]=32'hd192e819; K[45]=32'hd6990624; K[46]=32'hf40e3585; K[47]=32'h106aa070;
        K[48]=32'h19a4c116; K[49]=32'h1e376c08; K[50]=32'h2748774c; K[51]=32'h34b0bcb5;
        K[52]=32'h391c0cb3; K[53]=32'h4ed8aa4a; K[54]=32'h5b9cca4f; K[55]=32'h682e6ff3;
        K[56]=32'h748f82ee; K[57]=32'h78a5636f; K[58]=32'h84c87814; K[59]=32'h8cc70208;
        K[60]=32'h90befffa; K[61]=32'ha4506ceb; K[62]=32'hbef9a3f7; K[63]=32'hc67178f2;
    end

    // -------------------------------------------------------------------------
    // Hash state registers H0-H7
    // -------------------------------------------------------------------------
    reg [31:0] H0,H1,H2,H3,H4,H5,H6,H7;

    // -------------------------------------------------------------------------
    // Working variables a-h (Fig. 7 left registers)
    // -------------------------------------------------------------------------
    reg [31:0] a,b,c,d,e,f,g,h_r;   // h_r to avoid keyword clash

    // -------------------------------------------------------------------------
    // Round counter
    // -------------------------------------------------------------------------
    reg [5:0] round_cnt;

    // -------------------------------------------------------------------------
    // FSM state encoding
    // -------------------------------------------------------------------------
    localparam [2:0] ST_IDLE=3'd0, ST_LOAD=3'd1,
                     ST_ROUND=3'd2, ST_ACCUM=3'd3, ST_DONE=3'd4;
    reg [2:0] state;

    // -------------------------------------------------------------------------
    // Combinational schedule control (WIRES, not regs)
    // This is the key timing fix: schedule sees load/advance in the SAME cycle.
    // -------------------------------------------------------------------------
    wire sched_load    = (state == ST_LOAD);
    wire sched_advance = (state == ST_ROUND);

    // -------------------------------------------------------------------------
    // Message schedule instantiation
    // -------------------------------------------------------------------------
    wire [31:0] Wt;
    sha256_schedule u_sched (
        .clk      (clk),
        .rst_n    (rst_n),
        .load_i   (sched_load),
        .block_i  (block_i),
        .advance_i(sched_advance),
        .Wt_o     (Wt)
    );

    // -------------------------------------------------------------------------
    // Round function instantiation (fully combinational, Fig. 7 center)
    // -------------------------------------------------------------------------
    wire [31:0] a_new,b_new,c_new,d_new,e_new,f_new,g_new,h_new;
    sha256_round u_round (
        .a(a),.b(b),.c(c),.d(d),
        .e(e),.f(f),.g(g),.h(h_r),
        .Wt(Wt), .Kt(K[round_cnt]),
        .a_new(a_new),.b_new(b_new),.c_new(c_new),.d_new(d_new),
        .e_new(e_new),.f_new(f_new),.g_new(g_new),.h_new(h_new)
    );

    // -------------------------------------------------------------------------
    // Digest output: H0||H1||...||H7
    // -------------------------------------------------------------------------
    assign digest_o = {H0,H1,H2,H3,H4,H5,H6,H7};

    // -------------------------------------------------------------------------
    // FSM — clocked
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            ready_o   <= 1'b1;
            done_o    <= 1'b0;
            round_cnt <= 6'd0;
            H0<=IV0; H1<=IV1; H2<=IV2; H3<=IV3;
            H4<=IV4; H5<=IV5; H6<=IV6; H7<=IV7;
            a<=0; b<=0; c<=0; d<=0;
            e<=0; f<=0; g<=0; h_r<=0;
        end
        else begin
            done_o <= 1'b0;   // default

            if (init_i) begin
                // Re-initialise between messages (without full reset)
                H0<=IV0; H1<=IV1; H2<=IV2; H3<=IV3;
                H4<=IV4; H5<=IV5; H6<=IV6; H7<=IV7;
                state   <= ST_IDLE;
                ready_o <= 1'b1;
            end
            else case (state)

                // ----------------------------------------------------------
                ST_IDLE: begin
                    ready_o <= 1'b1;
                    if (block_valid_i) begin
                        ready_o <= 1'b0;
                        state   <= ST_LOAD;
                    end
                end

                // ----------------------------------------------------------
                // ST_LOAD:
                //   sched_load wire = 1 THIS CYCLE.
                //   At THIS posedge, schedule latches W[0..15] from block_i.
                //   After this posedge: Wt_o = W[0].
                //   We also latch a-h = H0-H7 and set round_cnt = 0.
                //   Next state = ST_ROUND.
                // ----------------------------------------------------------
                ST_LOAD: begin
                    a<=H0; b<=H1; c<=H2; d<=H3;
                    e<=H4; f<=H5; g<=H6; h_r<=H7;
                    round_cnt <= 6'd0;
                    state     <= ST_ROUND;
                end

                // ----------------------------------------------------------
                // ST_ROUND:
                //   sched_advance wire = 1 THIS CYCLE.
                //   sha256_round (combinational) computes using:
                //     Wt = buf[0] = W[round_cnt]   ← correct
                //     Kt = K[round_cnt]             ← correct
                //     a..h = previous round outputs
                //   At THIS posedge:
                //     a-h registers capture a_new..h_new
                //     round_cnt increments
                //     schedule shifts (buf[0]<-buf[1], buf[15]<-W_new)
                //     After posedge: Wt_o = W[round_cnt+1]  ← ready for next
                // ----------------------------------------------------------
                ST_ROUND: begin
                    a<=a_new; b<=b_new; c<=c_new; d<=d_new;
                    e<=e_new; f<=f_new; g<=g_new; h_r<=h_new;
                    round_cnt <= round_cnt + 1;
                    if (round_cnt == 6'd63)
                        state <= ST_ACCUM;
                end

                // ----------------------------------------------------------
                // ST_ACCUM: H' = H + [a..h]  (right-side adders, Fig. 7)
                // ----------------------------------------------------------
                ST_ACCUM: begin
                    H0<=H0+a; H1<=H1+b; H2<=H2+c; H3<=H3+d;
                    H4<=H4+e; H5<=H5+f; H6<=H6+g; H7<=H7+h_r;
                    state <= ST_DONE;
                end

                // ----------------------------------------------------------
                ST_DONE: begin
                    done_o  <= 1'b1;
                    ready_o <= 1'b1;
                    state   <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
