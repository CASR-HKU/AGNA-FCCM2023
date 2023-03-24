`timescale 1ns / 1ps

`include "def.sv"

(* keep_hierarchy = "yes" *) module bn #(
    parameter BN_DATA_WIDTH      = `PARAM_BNBUF_DATA_WIDTH,
    parameter BN_ADDR_WIDTH      = `PARAM_BNBUF_ADDR_WIDTH,
    parameter BN_UPDT_DATA_WIDTH = `DFLT_BN_UPDT_DATA_WIDTH,
    parameter MM2S_TAG_WIDTH     = `DFLT_MEM_TAG_WIDTH,

    parameter PBUF_DATA_WIDTH = `PARAM_PBUF_DATA_WIDTH,
    parameter PBUF_DATA_NUM   = `PARAM_PBUF_DATA_NUM
) (
    // common signals
    input  logic                                   clk,
    input  logic                                   rst_n,
    // input axis bn data
    output logic                                   s_axis_int2bn_tready,
    input  logic                                   s_axis_int2bn_tvalid,
    input  logic        [  BN_UPDT_DATA_WIDTH-1:0] s_axis_int2bn_tdata,
    input  logic        [BN_UPDT_DATA_WIDTH/8-1:0] s_axis_int2bn_tkeep,
    input  logic                                   s_axis_int2bn_tlast,
    // input axis bn tag
    output logic                                   s_axis_int2bn_tag_tready,
    input  logic                                   s_axis_int2bn_tag_tvalid,
    input  logic        [      MM2S_TAG_WIDTH-1:0] s_axis_int2bn_tag_tdata,
    input  logic        [    MM2S_TAG_WIDTH/8-1:0] s_axis_int2bn_tag_tkeep,
    input  logic                                   s_axis_int2bn_tag_tlast,
    // fout channel number (for execution address)
    input  logic        [                    15:0] fout_channel,
    // input data
    input  logic signed [     PBUF_DATA_WIDTH-1:0] bn_input_data           [PBUF_DATA_NUM-1:0],
    // output data
    output logic signed [     PBUF_DATA_WIDTH-1:0] bn_output_data          [PBUF_DATA_NUM-1:0],
    // control signals
    input  logic                                   fout_result_valid,
    output logic                                   bn_result_valid,
    input  logic                                   bn_enable_layer
);

    // update bn buffer
    logic bn_buf_updt_state, bn_buf_updt_end;

    always_comb begin
        s_axis_int2bn_tready = 1'b1;
        bn_buf_updt_end = s_axis_int2bn_tready & s_axis_int2bn_tvalid & s_axis_int2bn_tlast;
        s_axis_int2bn_tag_tready = 1'b1;
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            bn_buf_updt_state <= 1'b0;
        end else if (bn_buf_updt_end) begin
            bn_buf_updt_state <= 1'b0;
        end else if (s_axis_int2bn_tag_tvalid & s_axis_int2bn_tag_tready) begin
            bn_buf_updt_state <= 1'b1;
        end
    end

    // batch norm param buffer
    logic [BN_ADDR_WIDTH-1:0] a_updt_addr;
    logic [BN_ADDR_WIDTH-1:0] b_updt_addr;
    logic [BN_DATA_WIDTH-1:0] a_updt_data;
    logic [BN_DATA_WIDTH-1:0] b_updt_data;

    logic [BN_ADDR_WIDTH-1:0] a_exec_addr;
    logic [BN_ADDR_WIDTH-1:0] b_exec_addr;
    logic [BN_DATA_WIDTH-1:0] a_exec_data;
    logic [BN_DATA_WIDTH-1:0] b_exec_data;

    // may need to insert 0 here
    assign a_exec_addr[9:0] = fout_channel[9:0];
    assign b_exec_addr[9:0] = fout_channel[9:0];
    assign a_exec_addr[10]  = 1'b0;
    assign b_exec_addr[10]  = 1'b0;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            a_updt_addr <= 0;
        end else if (bn_buf_updt_end) begin
            a_updt_addr <= 0;
        end else if (s_axis_int2bn_tready & s_axis_int2bn_tvalid) begin
            a_updt_addr <= a_updt_addr + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            b_updt_addr <= 0;
        end else if (bn_buf_updt_end) begin
            b_updt_addr <= 0;
        end else if (s_axis_int2bn_tready & s_axis_int2bn_tvalid) begin
            b_updt_addr <= b_updt_addr + 1;
        end
    end

    buf_bn #(
        .BUF_UPDT_ADDR_WIDTH(BN_ADDR_WIDTH),
        .BUF_UPDT_DATA_WIDTH(BN_DATA_WIDTH),
        .BUF_EXEC_ADDR_WIDTH(BN_ADDR_WIDTH),
        .BUF_EXEC_DATA_WIDTH(BN_DATA_WIDTH)
    ) bnbuf_a_inst (
        .clk(clk),
        .buf_updt_wr_en(s_axis_int2bn_tready & s_axis_int2bn_tvalid),
        .buf_updt_addr(a_updt_addr),
        .buf_updt_data(a_updt_data),
        .buf_exec_addr(a_exec_addr),
        .buf_exec_data(a_exec_data)
    );

    buf_bn #(
        .BUF_UPDT_ADDR_WIDTH(BN_ADDR_WIDTH),
        .BUF_UPDT_DATA_WIDTH(BN_DATA_WIDTH),
        .BUF_EXEC_ADDR_WIDTH(BN_ADDR_WIDTH),
        .BUF_EXEC_DATA_WIDTH(BN_DATA_WIDTH)
    ) bnbuf_b_inst (
        .clk(clk),
        .buf_updt_wr_en(s_axis_int2bn_tready & s_axis_int2bn_tvalid),
        .buf_updt_addr(b_updt_addr),
        .buf_updt_data(b_updt_data),
        .buf_exec_addr(b_exec_addr),
        .buf_exec_data(b_exec_data)
    );

    always_comb begin
        a_updt_data = s_axis_int2bn_tdata[BN_DATA_WIDTH-1:0];
        b_updt_data = s_axis_int2bn_tdata[BN_UPDT_DATA_WIDTH-1:BN_DATA_WIDTH];
    end

    genvar pbuf_wb_num_idx;
    generate
        for (pbuf_wb_num_idx = 0; pbuf_wb_num_idx < PBUF_DATA_NUM; pbuf_wb_num_idx++) begin
            bn_unit bn_unit_inst (
                .clk(clk),
                .rst_n(rst_n),
                // input and output data
                .bn_param_data_a(a_exec_data),
                .bn_param_data_b(b_exec_data),
                .bn_input_data(bn_input_data[pbuf_wb_num_idx]),
                .bn_output_data(bn_output_data[pbuf_wb_num_idx]),
                // fout result valid
                .fout_result_valid(fout_result_valid),
                // bn result valid
                // .bn_result_valid(bn_result_valid),
                // pass bn module for this layer
                .bn_enable_layer(bn_enable_layer)
            );
        end
    endgenerate

    logic fout_result_valid_r;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            fout_result_valid_r <= 1'b0;
        end else fout_result_valid_r <= fout_result_valid;
    end

    logic fout_result_valid_t;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            fout_result_valid_t <= 1'b0;
        end else fout_result_valid_t <= fout_result_valid_r;
    end

    assign bn_result_valid = fout_result_valid_t;

endmodule
