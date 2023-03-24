`timescale 1ns / 1ps

`include "def.sv"

module prefetch_buf #(
    parameter AXI_DATA_WIDTH = `DFLT_CORE_AXI_DATA_WIDTH,
    parameter MM2S_TAG_WIDTH = `DFLT_MEM_TAG_WIDTH
) (
    // common signals
    input  logic                              clk,
    input  logic                              rst_n,
    output logic [                 1:0][31:0] status,
    input  logic                              layer_proc_status,
    // input axis_itf2buf
    output logic                              s_axis_itf2buf_tready,
    input  logic                              s_axis_itf2buf_tvalid,
    input  logic [  AXI_DATA_WIDTH-1:0]       s_axis_itf2buf_tdata,
    input  logic [AXI_DATA_WIDTH/8-1:0]       s_axis_itf2buf_tkeep,
    input  logic                              s_axis_itf2buf_tlast,
    input  logic [                 1:0]       s_axis_itf2buf_tdest,
    // input axis_itf2buf_tag
    output logic                              s_axis_itf2buf_tag_tready,
    input  logic                              s_axis_itf2buf_tag_tvalid,
    input  logic [  MM2S_TAG_WIDTH-1:0]       s_axis_itf2buf_tag_tdata,
    input  logic [MM2S_TAG_WIDTH/8-1:0]       s_axis_itf2buf_tag_tkeep,
    input  logic                              s_axis_itf2buf_tag_tlast,
    input  logic [                 1:0]       s_axis_itf2buf_tag_tdest,
    // output axis_buf2int
    input  logic                              m_axis_buf2int_tready,
    output logic                              m_axis_buf2int_tvalid,
    output logic [  AXI_DATA_WIDTH-1:0]       m_axis_buf2int_tdata,
    output logic [AXI_DATA_WIDTH/8-1:0]       m_axis_buf2int_tkeep,
    output logic                              m_axis_buf2int_tlast,
    output logic [                 1:0]       m_axis_buf2int_tdest,
    // output axis_buf2int_tag
    input  logic                              m_axis_buf2int_tag_tready,
    output logic                              m_axis_buf2int_tag_tvalid,
    output logic [  MM2S_TAG_WIDTH-1:0]       m_axis_buf2int_tag_tdata,
    output logic [MM2S_TAG_WIDTH/8-1:0]       m_axis_buf2int_tag_tkeep,
    output logic                              m_axis_buf2int_tag_tlast,
    output logic [                 1:0]       m_axis_buf2int_tag_tdest
);

    logic empty_prebuf, full_prebuf;
    always_comb begin
        empty_prebuf = ~m_axis_buf2int_tvalid;
        full_prebuf  = ~s_axis_itf2buf_tready;
    end

    // this module is only used as buffer for the mm2s data and tags
    // data buffer
    fifo_axis #(
        .FIFO_AXIS_DEPTH(2048),
        .FIFO_AXIS_TDATA_WIDTH(AXI_DATA_WIDTH)
    ) mm2s_pre_data_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tready(m_axis_buf2int_tready),
        .m_axis_tvalid(m_axis_buf2int_tvalid),
        .m_axis_tdata(m_axis_buf2int_tdata),
        .m_axis_tkeep(m_axis_buf2int_tkeep),
        .m_axis_tlast(m_axis_buf2int_tlast),
        .m_axis_tdest(m_axis_buf2int_tdest),
        .s_axis_tready(s_axis_itf2buf_tready),
        .s_axis_tvalid(s_axis_itf2buf_tvalid),
        .s_axis_tdata(s_axis_itf2buf_tdata),
        .s_axis_tkeep(s_axis_itf2buf_tkeep),
        .s_axis_tlast(s_axis_itf2buf_tlast),
        .s_axis_tdest(s_axis_itf2buf_tdest)
    );

    logic [31:0] cnt_prebuf_empty, cnt_prebuf_full;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            cnt_prebuf_empty <= 0;
        end else if (empty_prebuf & layer_proc_status) begin
            cnt_prebuf_empty <= cnt_prebuf_empty + 1;
        end
    end
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            cnt_prebuf_full <= 0;
        end else if (full_prebuf) begin
            cnt_prebuf_full <= cnt_prebuf_full + 1;
        end
    end

    // tag buffer
    fifo_axis #(
        .FIFO_AXIS_DEPTH(512),
        .FIFO_AXIS_TDATA_WIDTH(MM2S_TAG_WIDTH)
    ) mm2s_pre_tag_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tready(m_axis_buf2int_tag_tready),
        .m_axis_tvalid(m_axis_buf2int_tag_tvalid),
        .m_axis_tdata(m_axis_buf2int_tag_tdata),
        .m_axis_tkeep(m_axis_buf2int_tag_tkeep),
        .m_axis_tlast(m_axis_buf2int_tag_tlast),
        .m_axis_tdest(m_axis_buf2int_tag_tdest),
        .s_axis_tready(s_axis_itf2buf_tag_tready),
        .s_axis_tvalid(s_axis_itf2buf_tag_tvalid),
        .s_axis_tdata(s_axis_itf2buf_tag_tdata),
        .s_axis_tkeep(s_axis_itf2buf_tag_tkeep),
        .s_axis_tlast(s_axis_itf2buf_tag_tlast),
        .s_axis_tdest(s_axis_itf2buf_tag_tdest)
    );

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            status[0] <= 32'h0;
            status[1] <= 32'h0;
        end else begin
            status[0] <= cnt_prebuf_empty;
            status[1] <= cnt_prebuf_full;
        end
    end

endmodule
