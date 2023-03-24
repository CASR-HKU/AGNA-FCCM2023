`timescale 1ns / 1ps

`include "def.sv"

(* keep_hierarchy = "yes" *) module delay_chain_onecyc #(
    parameter DW = 8
) (
    input  wire               clk,
    rst,
    en,
    input  wire  [DW - 1 : 0] in,
    output logic [DW - 1 : 0] out
);

    always_ff @(posedge clk) begin
        if (~rst) out <= 0;
        else if (en) out <= in;
    end

endmodule
