`timescale 1ns / 1ps

`include "def.sv"

(* keep_hierarchy = "yes" *) module rf (
    clk,
    rst,
    error,
    updt_en,
    updt_sel,
    updt_addr,
    updt_data,
    exec_sel,
    exec_addr,
    exec_data
);

    input wire clk;
    input wire rst;
    output wire error;
    input wire updt_en;
    input wire updt_sel;
    input wire [`PARAM_RF_ADDR_WIDTH-1:0] updt_addr;
    input wire [`PARAM_RF_DATA_WIDTH-1:0] updt_data;
    input wire exec_sel;
    input wire [`PARAM_RF_ADDR_WIDTH-1:0] exec_addr;
    output wire [`PARAM_RF_DATA_WIDTH-1:0] exec_data;

    assign error = 1'b0;

    genvar bit_cnt;

    generate
        for (bit_cnt = 0; bit_cnt < `PARAM_RF_DATA_WIDTH; bit_cnt++) begin : b
            (* keep_hierarchy = "yes" *) RAM64X1D #(
                .INIT            (64'h0000000000000000),  // Initial contents of RAM
                .IS_WCLK_INVERTED(1'b0)                   // Specifies active high/low WCLK
            ) RAM64X1D_inst (
                .DPO  (exec_data[bit_cnt]),  // Read-only 1-bit data output
                // .SPO(SPO),     // Rw/ 1-bit data output
                .A0   (updt_sel),            // Rw/ address[0] input bit
                .A1   (updt_addr[0]),        // Rw/ address[1] input bit
                .A2   (updt_addr[1]),        // Rw/ address[2] input bit
                .A3   (updt_addr[2]),        // Rw/ address[3] input bit
                .A4   (updt_addr[3]),        // Rw/ address[4] input bit
                .A5   (updt_addr[4]),        // Rw/ address[5] input bit
                .D    (updt_data[bit_cnt]),  // Write 1-bit data input
                .DPRA0(exec_sel),            // Read-only address[0] input bit
                .DPRA1(exec_addr[0]),        // Read-only address[1] input bit
                .DPRA2(exec_addr[1]),        // Read-only address[2] input bit
                .DPRA3(exec_addr[2]),        // Read-only address[3] input bit
                .DPRA4(exec_addr[3]),        // Read-only address[4] input bit
                .DPRA5(exec_addr[4]),        // Read-only address[5] input bit
                .WCLK (clk),                 // Write clock input
                .WE   (updt_en)              // Write enable input
            );
        end
    endgenerate

endmodule
