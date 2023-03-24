`timescale 1ns / 1ps

`include "def.sv"

module layout_converter #(
    parameter PBUF_DATA_WIDTH  = `PARAM_PBUF_DATA_WIDTH,
    parameter PBUF_DATA_NUM    = `PARAM_PBUF_DATA_NUM,
    parameter AXI_DATA_WIDTH   = `DFLT_CORE_AXI_DATA_WIDTH,
    parameter PE_LC_DATA_WIDTH = `PARAM_PE_LC_DATA_WIDTH,
    parameter CORE_INSTR_WIDTH = `DFLT_CORE_INSTR_WIDTH,

    parameter PARAM_A_K = `HW_CONFIG_A_K,
    parameter PARAM_A_H = `HW_CONFIG_A_H,
    parameter PARAM_A_W = `HW_CONFIG_A_W
) (
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          ap_start,
    // input axis layout_convert instruction
    output logic                          s_axis_lc_instr_tready,
    input  logic                          s_axis_lc_instr_tvalid,
    input  logic [  CORE_INSTR_WIDTH-1:0] s_axis_lc_instr_tdata,
    // input axis pe2lc data
    output logic                          s_axis_pe2lc_tready,
    input  logic                          s_axis_pe2lc_tvalid,
    input  logic [  PE_LC_DATA_WIDTH-1:0] s_axis_pe2lc_tdata,
    input  logic [PE_LC_DATA_WIDTH/8-1:0] s_axis_pe2lc_tkeep,
    input  logic                          s_axis_pe2lc_tlast,
    // output axis lc2res data
    input  logic                          m_axis_lc2res_tready,
    output logic                          m_axis_lc2res_tvalid,
    output logic [    AXI_DATA_WIDTH-1:0] m_axis_lc2res_tdata,
    output logic [  AXI_DATA_WIDTH/8-1:0] m_axis_lc2res_tkeep,
    output logic                          m_axis_lc2res_tlast,
    output logic                          m_axis_lc2res_tuser
);

    // instructions fifo
    logic                        i_axis_lc_instr_tready;
    logic                        i_axis_lc_instr_tvalid;
    logic [CORE_INSTR_WIDTH-1:0] i_axis_lc_instr_tdata;
    fifo_axis #(
        .FIFO_AXIS_DEPTH(64),
        .FIFO_AXIS_TDATA_WIDTH(CORE_INSTR_WIDTH)
    ) lc_instr_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tready(i_axis_lc_instr_tready),
        .m_axis_tvalid(i_axis_lc_instr_tvalid),
        .m_axis_tdata(i_axis_lc_instr_tdata),
        .s_axis_tready(s_axis_lc_instr_tready),
        .s_axis_tvalid(s_axis_lc_instr_tvalid),
        .s_axis_tdata(s_axis_lc_instr_tdata)
    );

    // ap_start_r should always be 1 after ap_start
    logic ap_start_r;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            ap_start_r <= 1'b0;
        end else if (ap_start) begin
            ap_start_r <= 1'b1;
        end
    end

    // new layout convert
    layout_convert_0 layout_convert_hls (
        .ap_clk(clk),  // input wire ap_clk
        .ap_rst_n(rst_n),  // input wire ap_rst_n
        .ap_start(ap_start_r),  // input wire ap_start
        // .s_axis_lc_instr_TVALID (i_axis_lc_instr_tvalid),  // input wire s_axis_lc_instr_TVALID
        // .s_axis_lc_instr_TREADY (i_axis_lc_instr_tready),  // output wire s_axis_lc_instr_TREADY
        // .s_axis_lc_instr_TDATA  (i_axis_lc_instr_tdata),  // input wire [63 : 0] s_axis_lc_instr_TDATA
        .s_axis_lc_instr_dout(i_axis_lc_instr_tdata),  // input wire [63 : 0] s_axis_lc_instr_dout
        .s_axis_lc_instr_empty_n(i_axis_lc_instr_tvalid),  // input wire s_axis_lc_instr_empty_n
        .s_axis_lc_instr_read(i_axis_lc_instr_tready),  // output wire s_axis_lc_instr_read
        .s_axis_pe2lc_TVALID(s_axis_pe2lc_tvalid),  // input wire s_axis_pe2lc_TVALID
        .s_axis_pe2lc_TREADY(s_axis_pe2lc_tready),  // output wire s_axis_pe2lc_TREADY
        .s_axis_pe2lc_TDATA(s_axis_pe2lc_tdata),  // input wire [63 : 0] s_axis_pe2lc_TDATA
        .s_axis_pe2lc_TLAST(s_axis_pe2lc_tlast),  // input wire [0 : 0] s_axis_pe2lc_TLAST
        .s_axis_pe2lc_TKEEP(s_axis_pe2lc_tkeep),  // input wire [7 : 0] s_axis_pe2lc_TKEEP
        .s_axis_pe2lc_TSTRB(28'h0000000),  // input wire [7 : 0] s_axis_pe2lc_TSTRB
        // .s_axis_pe2lc_TUSER(1'b0),          // input wire [0 : 0] s_axis_pe2lc_TUSER
        .m_axis_dbus_TVALID(m_axis_lc2res_tvalid),  // output wire m_axis_lc2res_TVALID
        .m_axis_dbus_TREADY(m_axis_lc2res_tready),  // input wire m_axis_lc2res_TREADY
        .m_axis_dbus_TDATA(m_axis_lc2res_tdata),  // output wire [127 : 0] m_axis_lc2res_TDATA
        .m_axis_dbus_TLAST(m_axis_lc2res_tlast),  // output wire [0 : 0] m_axis_lc2res_TLAST
        .m_axis_dbus_TKEEP(m_axis_lc2res_tkeep),  // output wire [15 : 0] m_axis_lc2res_TKEEP
        .m_axis_dbus_TUSER(m_axis_lc2res_tuser)  // output wire [0 : 0] m_axis_dbus_TUSER
    );

    // lc_fake lc_fake_inst (
    // .clk(clk),
    // .rst_n(rst_n),
    // // input lc instructions
    // .s_axis_lc_instr_tdata(i_axis_lc_instr_tdata),
    // .s_axis_lc_instr_tvalid(i_axis_lc_instr_tvalid),
    // .s_axis_lc_instr_tready(i_axis_lc_instr_tready),
    // // input axis wb data               
    // .s_axis_pe2lc_tready(s_axis_pe2lc_tready)         ,
    // .s_axis_pe2lc_tvalid(s_axis_pe2lc_tvalid)         ,
    // .s_axis_pe2lc_tdata(s_axis_pe2lc_tdata)          ,
    // .s_axis_pe2lc_tkeep(s_axis_pe2lc_tkeep)          ,
    // .s_axis_pe2lc_tlast(s_axis_pe2lc_tlast)          ,
    // // output axis lc2res
    // .m_axis_lc2res_tready(m_axis_lc2res_tready)        ,
    // .m_axis_lc2res_tvalid(m_axis_lc2res_tvalid)        ,
    // .m_axis_lc2res_tdata(m_axis_lc2res_tdata)         ,
    // .m_axis_lc2res_tkeep(m_axis_lc2res_tkeep)         ,
    // .m_axis_lc2res_tlast(m_axis_lc2res_tlast)         
    // );

endmodule
