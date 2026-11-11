// =============================================================================
// sha256_if.sv -- Testbench interface for the SHA-256 compression core
// =============================================================================
// The driver owns rst_n and all inputs. The monitor is read-only.
//
// Timing convention (no clocking block, so it works on every simulator):
//   * driver changes signals on negedge  -> stable before the next posedge
//   * monitor samples on posedge         -> sees the values the DUT samples
// This gives one clean handshake per clock without races.
// =============================================================================

interface sha256_if (input logic clk);

    logic         rst_n       = 1'b0;
    logic         init_i      = 1'b0;
    logic         block_valid_i = 1'b0;
    logic [511:0] block_i     = '0;
    logic         ready_o;
    logic         done_o;
    logic [255:0] digest_o;

    modport drv (
        input  clk,
        input  ready_o,
        input  done_o,
        output rst_n,
        output init_i,
        output block_valid_i,
        output block_i
    );

    modport mon (
        input clk,
        input rst_n,
        input init_i,
        input block_valid_i,
        input block_i,
        input ready_o,
        input done_o,
        input digest_o
    );

endinterface
