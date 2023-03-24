`timescale 1ns / 1ps

`include "def.sv"

module mm2s_ctrl #(
    parameter AXI_ADDR_WIDTH   = `DFLT_CORE_AXI_ADDR_WIDTH,
    parameter AXI_DATA_WIDTH   = `DFLT_CORE_AXI_DATA_WIDTH,
    parameter MM2S_TAG_WIDTH   = `DFLT_MEM_TAG_WIDTH,
    parameter CORE_CMD_WIDTH   = `DFLT_MEM_CMD_WIDTH,
    parameter CORE_STS_WIDTH   = `DFLT_MEM_STS_WIDTH,
    parameter CORE_INSTR_WIDTH = `DFLT_CORE_INSTR_WIDTH
) (
    // common signal
    input  logic                              clk,
    input  logic                              rst_n,
    // variable signal
    input  logic [                31:0]       scalar,
    output logic [                 1:0][31:0] status,
    // input axis_mm2s_instr
    output logic                              s_axis_mm2s_instr_tready,
    input  logic                              s_axis_mm2s_instr_tvalid,
    input  logic [CORE_INSTR_WIDTH-1:0]       s_axis_mm2s_instr_tdata,
    // output axis_mm2s_cmd
    input  logic                              m_axis_mm2s_cmd_tready,
    output logic                              m_axis_mm2s_cmd_tvalid,
    output logic [  CORE_CMD_WIDTH-1:0]       m_axis_mm2s_cmd_tdata,
    // input axis_mm2s_sts
    output logic                              s_axis_mm2s_sts_tready,
    input  logic                              s_axis_mm2s_sts_tvalid,
    input  logic [  CORE_STS_WIDTH-1:0]       s_axis_mm2s_sts_tdata,
    input  logic                              s_axis_mm2s_sts_tkeep,
    input  logic                              s_axis_mm2s_sts_tlast,
    // input axis_mm2s
    output logic                              s_axis_mm2s_tready,
    input  logic                              s_axis_mm2s_tvalid,
    input  logic [  AXI_DATA_WIDTH-1:0]       s_axis_mm2s_tdata,
    input  logic [AXI_DATA_WIDTH/8-1:0]       s_axis_mm2s_tkeep,
    input  logic                              s_axis_mm2s_tlast,
    // output axis_mm2s
    input  logic                              m_axis_mm2s_tready,
    output logic                              m_axis_mm2s_tvalid,
    output logic [  AXI_DATA_WIDTH-1:0]       m_axis_mm2s_tdata,
    output logic [AXI_DATA_WIDTH/8-1:0]       m_axis_mm2s_tkeep,
    output logic                              m_axis_mm2s_tlast,
    output logic [                 1:0]       m_axis_mm2s_tdest,
    // output axis_mm2s_tag
    input  logic                              m_axis_mm2s_tag_tready,
    output logic                              m_axis_mm2s_tag_tvalid,
    output logic [  MM2S_TAG_WIDTH-1:0]       m_axis_mm2s_tag_tdata,
    output logic [MM2S_TAG_WIDTH/8-1:0]       m_axis_mm2s_tag_tkeep,
    output logic                              m_axis_mm2s_tag_tlast,
    output logic [                 1:0]       m_axis_mm2s_tag_tdest
);

    // handshake
    logic
        s_axis_mm2s_instr_hs,
        m_axis_mm2s_cmd_hs,
        s_axis_mm2s_sts_hs,
        s_axis_mm2s_hs,
        m_axis_mm2s_hs,
        m_axis_mm2s_tag_hs,
        i_axis_mm2s_instr_hs;

    logic [CORE_INSTR_WIDTH - 1 : 0] i_axis_mm2s_instr_tdata;
    logic                            i_axis_mm2s_instr_tvalid;
    logic                            i_axis_mm2s_instr_tready;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            status[0] <= 32'h0;
        end else begin
            status[0][31:8] <= m_axis_mm2s_cmd_hs ? status[0][31:8] + 1 : status[0][31:8];
            status[0][7:0]  <= s_axis_mm2s_sts_hs ? s_axis_mm2s_sts_tdata : status[0][7:0];
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            status[1] <= 32'h0;
        end else begin
            status[1][15:0]  <= i_axis_mm2s_instr_hs ? status[1][15:0] + 1 : status[1][15:0];
            status[1][31:16] <= s_axis_mm2s_sts_hs ? status[1][31:16] + 1 : status[1][31:16];
        end
    end

    always_comb begin
        s_axis_mm2s_instr_hs = s_axis_mm2s_instr_tready & s_axis_mm2s_instr_tvalid;
        i_axis_mm2s_instr_hs = i_axis_mm2s_instr_tready & i_axis_mm2s_instr_tvalid;
        m_axis_mm2s_cmd_hs   = m_axis_mm2s_cmd_tready & m_axis_mm2s_cmd_tvalid;
        s_axis_mm2s_sts_hs   = s_axis_mm2s_sts_tready & s_axis_mm2s_sts_tvalid;
        s_axis_mm2s_hs       = s_axis_mm2s_tready & s_axis_mm2s_tvalid;
        m_axis_mm2s_hs       = m_axis_mm2s_tready & m_axis_mm2s_tvalid;
        m_axis_mm2s_tag_hs   = m_axis_mm2s_tag_tready & m_axis_mm2s_tag_tvalid;
    end

    // status always ready
    always_comb begin
        s_axis_mm2s_sts_tready = 1;
    end

    // memory sub-instruction fifo
    fifo_axis #(
        .FIFO_AXIS_DEPTH(128),
        .FIFO_AXIS_TDATA_WIDTH(CORE_INSTR_WIDTH)
    ) mm2s_instr_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tready(i_axis_mm2s_instr_tready),
        .m_axis_tvalid(i_axis_mm2s_instr_tvalid),
        .m_axis_tdata(i_axis_mm2s_instr_tdata),
        .s_axis_tready(s_axis_mm2s_instr_tready),
        .s_axis_tvalid(s_axis_mm2s_instr_tvalid),
        .s_axis_tdata(s_axis_mm2s_instr_tdata),
        .s_axis_tkeep(10'b11_1111_1111),
        .s_axis_tlast(1'b0)
    );

    // cmd & tag generation
    logic [MM2S_TAG_WIDTH - 1 : 0] i_axis_tag_tdata;
    logic                          i_axis_tag_tvalid;
    logic                          i_axis_tag_tready;
    // logic [9:0]                         words_per_tile;
    mm2s_cmd_gen #(
        .CORE_INSTR_WIDTH(CORE_INSTR_WIDTH),
        .CORE_CMD_WIDTH  (CORE_CMD_WIDTH),
        .MM2S_TAG_WIDTH  (MM2S_TAG_WIDTH)
    ) mm2s_cmd_tag_gen_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_mm2s_instr_tdata(i_axis_mm2s_instr_tdata),
        .s_axis_mm2s_instr_tvalid(i_axis_mm2s_instr_tvalid),
        .s_axis_mm2s_instr_tready(i_axis_mm2s_instr_tready),
        .m_axis_mm2s_cmd_tdata(m_axis_mm2s_cmd_tdata),
        .m_axis_mm2s_cmd_tvalid(m_axis_mm2s_cmd_tvalid),
        .m_axis_mm2s_cmd_tready(m_axis_mm2s_cmd_tready),
        .m_axis_tag_tdata(i_axis_tag_tdata),
        .m_axis_tag_tvalid(i_axis_tag_tvalid),
        .m_axis_tag_tready(i_axis_tag_tready)
        // .words_per_tile(words_per_tile)
    );

    // data-tag matching
    mm2s_tag_match #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .MM2S_TAG_WIDTH(MM2S_TAG_WIDTH)
    ) mm2s_tag_match_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_mm2s_tready(s_axis_mm2s_tready),
        .s_axis_mm2s_tvalid(s_axis_mm2s_tvalid),
        .s_axis_mm2s_tdata(s_axis_mm2s_tdata),
        .s_axis_mm2s_tkeep(s_axis_mm2s_tkeep),
        .s_axis_mm2s_tlast(s_axis_mm2s_tlast),
        .s_axis_mm2s_tag_tready(i_axis_tag_tready),
        .s_axis_mm2s_tag_tvalid(i_axis_tag_tvalid),
        .s_axis_mm2s_tag_tdata(i_axis_tag_tdata),
        .s_axis_mm2s_tag_tkeep(8'b1111_1111),
        .s_axis_mm2s_tag_tlast(1'b0),
        .m_axis_mm2s_tready(m_axis_mm2s_tready),
        .m_axis_mm2s_tvalid(m_axis_mm2s_tvalid),
        .m_axis_mm2s_tdata(m_axis_mm2s_tdata),
        .m_axis_mm2s_tkeep(m_axis_mm2s_tkeep),
        .m_axis_mm2s_tlast(m_axis_mm2s_tlast),
        .m_axis_mm2s_tdest(m_axis_mm2s_tdest),
        .m_axis_mm2s_tag_tready(m_axis_mm2s_tag_tready),
        .m_axis_mm2s_tag_tvalid(m_axis_mm2s_tag_tvalid),
        .m_axis_mm2s_tag_tdata(m_axis_mm2s_tag_tdata),
        .m_axis_mm2s_tag_tkeep(m_axis_mm2s_tag_tkeep),
        .m_axis_mm2s_tag_tlast(m_axis_mm2s_tag_tlast),
        .m_axis_mm2s_tag_tdest(m_axis_mm2s_tag_tdest)
        // .words_per_tile(words_per_tile)
    );

endmodule
