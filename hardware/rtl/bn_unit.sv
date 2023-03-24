`timescale 1ns / 1ps

`include "def.sv"

// y = (x + a) * b
(* keep_hierarchy = "yes" *)
module bn_unit #(
    parameter BN_DATA_WIDTH = `PARAM_BNBUF_DATA_WIDTH
) (
    input  logic                            clk,
    input  logic                            rst_n,
    // input and output data
    input  logic signed [BN_DATA_WIDTH-1:0] bn_param_data_a,
    input  logic signed [BN_DATA_WIDTH-1:0] bn_param_data_b,
    input  logic signed [BN_DATA_WIDTH-1:0] bn_input_data,
    output logic signed [BN_DATA_WIDTH-1:0] bn_output_data,
    // fout result valid
    input  logic                            fout_result_valid,
    // bn result valid
    // output logic                            bn_result_valid     ,
    // pass bn module for this layer
    input  logic                            bn_enable_layer
);

    logic signed [BN_DATA_WIDTH-1:0] bn_xa;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            bn_xa <= 0;
        end else if (fout_result_valid & bn_enable_layer) begin
            bn_xa <= bn_input_data + bn_param_data_a;
        end else if (fout_result_valid & (~bn_enable_layer)) begin
            bn_xa <= bn_input_data;
        end
    end

    logic fout_result_valid_r;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            fout_result_valid_r <= 1'b0;
        end else fout_result_valid_r <= fout_result_valid;
    end

    logic [BN_DATA_WIDTH*2-1:0] mul_result;
    always_comb begin
        mul_result = bn_xa * bn_param_data_b;
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            bn_output_data <= 0;
        end else if (fout_result_valid_r & bn_enable_layer) begin
            // bn_output_data <= mul_result[BN_DATA_WIDTH*2-1:BN_DATA_WIDTH];
            bn_output_data <= mul_result[BN_DATA_WIDTH-1:0];
        end else if (fout_result_valid_r & (~bn_enable_layer)) begin
            bn_output_data <= bn_xa;
        end
    end

    // logic fout_result_valid_t;
    // always_ff @( posedge clk ) begin
    //     if (~rst_n) begin
    //         fout_result_valid_t <= 1'b0;
    //     end
    //     else fout_result_valid_t <= fout_result_valid_r;
    // end

    // assign bn_result_valid = fout_result_valid_t;

endmodule
