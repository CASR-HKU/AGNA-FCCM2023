`timescale 1ns / 1ps

`include "def.sv"

(*use_dsp48 = "no" *) module abuf_exec_addr #(
    parameter ABUF_EXEC_ADDR_WIDTH = `PARAM_ABUF_ADDR_WIDTH
) (
    input                                   clk,
    rst_n,
    input  logic [                     9:0] abuf2rf_updt_idx  [2:0],
    input  logic [                     2:0] exec_pad_t,
    input  logic [                     2:0] exec_pad_l,
    input  logic [                     9:0] exec_r_iw,
    input  logic [                     9:0] exec_r_ih,
    output logic [ABUF_EXEC_ADDR_WIDTH-1:0] abuf_exec_addr_out
);

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            abuf_exec_addr_out <= 0;
        end else begin
            abuf_exec_addr_out <=   (abuf2rf_updt_idx[2] - exec_pad_l) + (abuf2rf_updt_idx[1] - exec_pad_t) * exec_r_iw + 
                                    abuf2rf_updt_idx[0] * exec_r_iw * exec_r_ih;
        end
    end

endmodule
