`timescale 1ns / 1ps

`include "def.sv"

module s2mm_ctrl #(
    parameter AXI_ADDR_WIDTH   = `DFLT_CORE_AXI_ADDR_WIDTH,
    parameter AXI_DATA_WIDTH   = `DFLT_CORE_AXI_DATA_WIDTH,
    // parameter S2MM_TAG_WIDTH    =   `DFLT_CORE_S2MM_TAG_WIDTH       ,
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
    // input axis_s2mm_instr
    output logic                              s_axis_s2mm_instr_tready,
    input  logic                              s_axis_s2mm_instr_tvalid,
    input  logic [CORE_INSTR_WIDTH-1:0]       s_axis_s2mm_instr_tdata,
    // output axis_s2mm_cmd
    input  logic                              m_axis_s2mm_cmd_tready,
    output logic                              m_axis_s2mm_cmd_tvalid,
    output logic [  CORE_CMD_WIDTH-1:0]       m_axis_s2mm_cmd_tdata,
    // input axis_s2mm_sts
    output logic                              s_axis_s2mm_sts_tready,
    input  logic                              s_axis_s2mm_sts_tvalid,
    input  logic [  CORE_STS_WIDTH-1:0]       s_axis_s2mm_sts_tdata,
    input  logic                              s_axis_s2mm_sts_tkeep,
    input  logic                              s_axis_s2mm_sts_tlast,
    // input axis_s2mm
    output logic                              s_axis_s2mm_tready,
    input  logic                              s_axis_s2mm_tvalid,
    input  logic [  AXI_DATA_WIDTH-1:0]       s_axis_s2mm_tdata,
    input  logic [AXI_DATA_WIDTH/8-1:0]       s_axis_s2mm_tkeep,
    input  logic                              s_axis_s2mm_tlast,
    // // input axis_s2mm_tag
    // output logic                            s_axis_s2mm_tag_tready  ,
    // input  logic                            s_axis_s2mm_tag_tvalid  ,
    // input  logic [S2MM_TAG_WIDTH-1:0]       s_axis_s2mm_tag_tdata   ,
    // input  logic [S2MM_TAG_WIDTH/8-1:0]     s_axis_s2mm_tag_tkeep   ,
    // input  logic                            s_axis_s2mm_tag_tlast   ,
    // output axis_s2mm
    input  logic                              m_axis_s2mm_tready,
    output logic                              m_axis_s2mm_tvalid,
    output logic [  AXI_DATA_WIDTH-1:0]       m_axis_s2mm_tdata,
    output logic [AXI_DATA_WIDTH/8-1:0]       m_axis_s2mm_tkeep,
    output logic                              m_axis_s2mm_tlast
);

    // handshake
    logic
        s_axis_s2mm_instr_hs,
        m_axis_s2mm_cmd_hs,
        s_axis_s2mm_sts_hs,
        s_axis_s2mm_hs,
        m_axis_s2mm_hs,
        i_axis_s2mm_instr_hs;

    logic almost_full_s2mm;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            status[0] <= 32'h0;
        end else begin
            status[0][31:12] <= s_axis_s2mm_sts_hs ? status[0][31:12] + 1 : status[0][31:12];
            status[0][11:4]  <= s_axis_s2mm_sts_hs ? s_axis_s2mm_sts_tdata : status[0][11:4];
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            status[1] <= 32'h0;
        end else begin
            // status[1][31:16] <= m_axis_s2mm_hs ? status[1][31:16]+1 : status[1][31:16];
            // status[1][15:0]  <= s_axis_s2mm_hs ? status[1][15:0]+1  : status[1][15:0];
            status[1][31:16] <= m_axis_s2mm_cmd_hs ? status[1][31:16] + 1 : status[1][31:16];
            status[1][15:0]  <= m_axis_s2mm_hs & m_axis_s2mm_tlast ? status[1][15:0]+1  : status[1][15:0];
        end
    end

    logic [CORE_INSTR_WIDTH - 1 : 0] i_axis_s2mm_instr_tdata;
    logic                            i_axis_s2mm_instr_tvalid;
    logic                            i_axis_s2mm_instr_tready;

    always_comb begin
        s_axis_s2mm_instr_hs = s_axis_s2mm_instr_tready & s_axis_s2mm_instr_tvalid;
        i_axis_s2mm_instr_hs = i_axis_s2mm_instr_tready & i_axis_s2mm_instr_tvalid;
        m_axis_s2mm_cmd_hs   = m_axis_s2mm_cmd_tready & m_axis_s2mm_cmd_tvalid;
        s_axis_s2mm_sts_hs   = s_axis_s2mm_sts_tready & s_axis_s2mm_sts_tvalid;
        s_axis_s2mm_hs       = s_axis_s2mm_tready & s_axis_s2mm_tvalid;
        // s_axis_s2mm_tag_hs  =   s_axis_s2mm_tag_tready    & s_axis_s2mm_tag_tvalid  ;
        m_axis_s2mm_hs       = m_axis_s2mm_tready & m_axis_s2mm_tvalid;
    end

    // status always ready
    always_comb begin
        s_axis_s2mm_sts_tready = 1;
        // m_axis_s2mm_tlast      = 1'b0;
    end

    // memory sub-instruction fifo
    fifo_axis #(
        .FIFO_AXIS_DEPTH(128),
        .FIFO_AXIS_TDATA_WIDTH(CORE_INSTR_WIDTH)
    ) s2mm_instr_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tready(i_axis_s2mm_instr_tready),
        .m_axis_tvalid(i_axis_s2mm_instr_tvalid),
        .m_axis_tdata(i_axis_s2mm_instr_tdata),
        .s_axis_tready(s_axis_s2mm_instr_tready),
        .s_axis_tvalid(s_axis_s2mm_instr_tvalid),
        .s_axis_tdata(s_axis_s2mm_instr_tdata),
        .s_axis_tkeep(10'b11_1111_1111),
        .s_axis_tlast(1'b0)
    );

    // s2mm cmd generation
    s2mm_cmd_gen #(
        .CORE_INSTR_WIDTH(CORE_INSTR_WIDTH),
        .CORE_CMD_WIDTH  (CORE_CMD_WIDTH)
    ) s2mm_cmd_tag_gen_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_s2mm_instr_tdata(i_axis_s2mm_instr_tdata),
        .s_axis_s2mm_instr_tvalid(i_axis_s2mm_instr_tvalid),
        .s_axis_s2mm_instr_tready(i_axis_s2mm_instr_tready),
        .m_axis_s2mm_cmd_tdata(m_axis_s2mm_cmd_tdata),
        .m_axis_s2mm_cmd_tvalid(m_axis_s2mm_cmd_tvalid),
        .m_axis_s2mm_cmd_tready(m_axis_s2mm_cmd_tready)
    );

    // s2mm data fifo (to avoid stall)
    fifo_axis #(
        .FIFO_AXIS_DEPTH(1024),
        .FIFO_AXIS_TDATA_WIDTH(AXI_DATA_WIDTH),
        .FIFO_ADV_FEATURES("141C")
    ) s2mm_data_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .almost_full_axis(almost_full_s2mm),
        .m_axis_tready(m_axis_s2mm_tready),
        .m_axis_tvalid(m_axis_s2mm_tvalid),
        .m_axis_tdata(m_axis_s2mm_tdata),
        .m_axis_tkeep(m_axis_s2mm_tkeep),
        .m_axis_tlast(m_axis_s2mm_tlast),
        .s_axis_tready(s_axis_s2mm_tready),
        .s_axis_tvalid(s_axis_s2mm_tvalid),
        .s_axis_tdata(s_axis_s2mm_tdata),
        .s_axis_tkeep(s_axis_s2mm_tkeep),
        .s_axis_tlast(s_axis_s2mm_tlast)
    );

endmodule
