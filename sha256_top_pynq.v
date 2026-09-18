module sha256_top_pynq (
    input  wire       clk,             // 98 MHz clock from Clock Wizard
    input  wire       btn0,            // Reset button
    input  wire       btn1,            // Start button
    output wire [3:0] result_nibble    // LD0-LD3
);

    (* MARK_DEBUG = "TRUE" *)
    wire rst_n = ~btn0;

    wire [511:0] block_i =
        512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018;

    (* MARK_DEBUG = "TRUE" *)
    wire ready_o;

    (* MARK_DEBUG = "TRUE" *)
    wire done_o;

    (* MARK_DEBUG = "TRUE" *)
    wire [255:0] digest_o;

    localparam S_IDLE  = 2'd0;
    localparam S_INIT  = 2'd1;
    localparam S_START = 2'd2;

    reg [1:0] ctrl_state;

    reg init_r;
    reg block_valid_r;

    always @(posedge clk or posedge btn0)
    begin
        if (btn0) begin
            ctrl_state    <= S_IDLE;
            init_r        <= 1'b0;
            block_valid_r <= 1'b0;
        end
        else begin

            init_r        <= 1'b0;
            block_valid_r <= 1'b0;

            case (ctrl_state)

                S_IDLE:
                begin
                    if (btn1)
                        ctrl_state <= S_INIT;
                end

                S_INIT:
                begin
                    init_r <= 1'b1;
                    ctrl_state <= S_START;
                end

                S_START:
                begin
                    block_valid_r <= 1'b1;
                    ctrl_state <= S_IDLE;
                end

            endcase
        end
    end

    (* MARK_DEBUG = "TRUE" *)
    wire block_valid = block_valid_r;

    sha256_core u_core (
        .clk           (clk),
        .rst_n         (rst_n),
        .init_i        (init_r),
        .block_valid_i (block_valid),
        .block_i       (block_i),
        .ready_o       (ready_o),
        .done_o        (done_o),
        .digest_o      (digest_o)
    );

    assign result_nibble = digest_o[3:0];

endmodule