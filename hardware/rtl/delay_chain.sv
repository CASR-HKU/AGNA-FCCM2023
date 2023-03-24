`timescale 1ns / 1ps

`include "def.sv"

(* keep_hierarchy = "yes" *) module delay_chain #(
    parameter DW  = 8,
    parameter LEN = 4
) (
    input  wire              clk,
    rst,
    en,
    input  wire [DW - 1 : 0] in,
    output wire [DW - 1 : 0] out
);
    wire [DW - 1 : 0] dly[LEN : 0];
    assign dly[0] = in;
    assign out = dly[LEN];
    genvar i, j;
    generate
        for (j = 0; j < DW; j = j + 1) begin
            for (i = 1; i <= LEN; i = i + 1) begin
                FDRE DeFF (
                    .Q (dly[i][j]),
                    .C (clk),
                    .CE(en),
                    .D (dly[i-1][j]),
                    .R (~rst)
                );
            end
        end
    endgenerate
endmodule
