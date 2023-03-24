`timescale 1ns / 1ps

`include "def.sv"

module axis_interconnect #(
    parameter AXI_DATA_WIDTH      = `DFLT_CORE_AXI_DATA_WIDTH,
    parameter BN_UPDT_DATA_WIDTH  = `DFLT_BN_UPDT_DATA_WIDTH,
    parameter RES_UPDT_DATA_WIDTH = `DFLT_RES_UPDT_DATA_WIDTH,
    parameter MM2S_TAG_WIDTH      = `DFLT_MEM_TAG_WIDTH
) (
    // common signals
    input  logic                             clk,
    input  logic                             rst_n,
    // input axis_buf2int
    output logic                             s_axis_buf2int_tready,
    input  logic                             s_axis_buf2int_tvalid,
    input  logic [       AXI_DATA_WIDTH-1:0] s_axis_buf2int_tdata,
    input  logic [     AXI_DATA_WIDTH/8-1:0] s_axis_buf2int_tkeep,
    input  logic                             s_axis_buf2int_tlast,
    input  logic [                      1:0] s_axis_buf2int_tdest,
    // input axis_buf2int_tag
    output logic                             s_axis_buf2int_tag_tready,
    input  logic                             s_axis_buf2int_tag_tvalid,
    input  logic [       MM2S_TAG_WIDTH-1:0] s_axis_buf2int_tag_tdata,
    input  logic [     MM2S_TAG_WIDTH/8-1:0] s_axis_buf2int_tag_tkeep,
    input  logic                             s_axis_buf2int_tag_tlast,
    input  logic [                      1:0] s_axis_buf2int_tag_tdest,
    // output axis_int2pe (for act and w)
    input  logic                             m_axis_int2pe_tready,
    output logic                             m_axis_int2pe_tvalid,
    output logic [       AXI_DATA_WIDTH-1:0] m_axis_int2pe_tdata,
    output logic [     AXI_DATA_WIDTH/8-1:0] m_axis_int2pe_tkeep,
    output logic                             m_axis_int2pe_tlast,
    // output axis_int2pe_tag (for act and w)
    input  logic                             m_axis_int2pe_tag_tready,
    output logic                             m_axis_int2pe_tag_tvalid,
    output logic [       MM2S_TAG_WIDTH-1:0] m_axis_int2pe_tag_tdata,
    output logic [     MM2S_TAG_WIDTH/8-1:0] m_axis_int2pe_tag_tkeep,
    output logic                             m_axis_int2pe_tag_tlast,
    // output axis_int2bn (only for bn)
    input  logic                             m_axis_int2bn_tready,
    output logic                             m_axis_int2bn_tvalid,
    output logic [   BN_UPDT_DATA_WIDTH-1:0] m_axis_int2bn_tdata,
    output logic [ BN_UPDT_DATA_WIDTH/8-1:0] m_axis_int2bn_tkeep,
    output logic                             m_axis_int2bn_tlast,
    // output axis_int2bn_tag (only for bn)
    input  logic                             m_axis_int2bn_tag_tready,
    output logic                             m_axis_int2bn_tag_tvalid,
    output logic [       MM2S_TAG_WIDTH-1:0] m_axis_int2bn_tag_tdata,
    output logic [     MM2S_TAG_WIDTH/8-1:0] m_axis_int2bn_tag_tkeep,
    output logic                             m_axis_int2bn_tag_tlast,
    // output axis_int2res (only for res adder)
    input  logic                             m_axis_int2res_tready,
    output logic                             m_axis_int2res_tvalid,
    output logic [  RES_UPDT_DATA_WIDTH-1:0] m_axis_int2res_tdata,
    output logic [RES_UPDT_DATA_WIDTH/8-1:0] m_axis_int2res_tkeep,
    output logic                             m_axis_int2res_tlast,
    // output axis_int2res_tag (only for res adder)
    input  logic                             m_axis_int2res_tag_tready,
    output logic                             m_axis_int2res_tag_tvalid,
    output logic [       MM2S_TAG_WIDTH-1:0] m_axis_int2res_tag_tdata,
    output logic [     MM2S_TAG_WIDTH/8-1:0] m_axis_int2res_tag_tkeep,
    output logic                             m_axis_int2res_tag_tlast
);

    logic axis_mm2s_decode_err, axis_mm2s_tag_decode_err;

    // not used in modules after interconnect
    logic [1:0] i_M00_AXIS_TDEST, i_M01_AXIS_TDEST, i_M02_AXIS_TDEST;
    logic [1:0] i_M00_AXIS_TAG_TDEST, i_M01_AXIS_TAG_TDEST, i_M02_AXIS_TAG_TDEST;

    axis_interconnect_data axis_mm2s_interconnect_inst (
        .ACLK            (clk),                    // input wire ACLK
        .ARESETN         (rst_n),                  // input wire ARESETN
        .S00_AXIS_ACLK   (clk),                    // input wire S00_AXIS_ACLK
        .S00_AXIS_ARESETN(rst_n),                  // input wire S00_AXIS_ARESETN
        .S00_AXIS_TVALID (s_axis_buf2int_tvalid),  // input wire S00_AXIS_TVALID
        .S00_AXIS_TREADY (s_axis_buf2int_tready),  // output wire S00_AXIS_TREADY
        .S00_AXIS_TDATA  (s_axis_buf2int_tdata),   // input wire [127 : 0] S00_AXIS_TDATA
        .S00_AXIS_TKEEP  (s_axis_buf2int_tkeep),   // input wire [15 : 0] S00_AXIS_TKEEP
        .S00_AXIS_TLAST  (s_axis_buf2int_tlast),   // input wire S00_AXIS_TLAST
        .S00_AXIS_TDEST  (s_axis_buf2int_tdest),   // input wire [1 : 0] S00_AXIS_TDEST
        .M00_AXIS_ACLK   (clk),                    // input wire M00_AXIS_ACLK
        .M01_AXIS_ACLK   (clk),                    // input wire M01_AXIS_ACLK
        .M02_AXIS_ACLK   (clk),                    // input wire M02_AXIS_ACLK
        .M00_AXIS_ARESETN(rst_n),                  // input wire M00_AXIS_ARESETN
        .M01_AXIS_ARESETN(rst_n),                  // input wire M01_AXIS_ARESETN
        .M02_AXIS_ARESETN(rst_n),                  // input wire M02_AXIS_ARESETN
        .M00_AXIS_TVALID (m_axis_int2pe_tvalid),   // output wire M00_AXIS_TVALID
        .M01_AXIS_TVALID (m_axis_int2bn_tvalid),   // output wire M01_AXIS_TVALID
        .M02_AXIS_TVALID (m_axis_int2res_tvalid),  // output wire M02_AXIS_TVALID
        .M00_AXIS_TREADY (m_axis_int2pe_tready),   // input wire M00_AXIS_TREADY
        .M01_AXIS_TREADY (m_axis_int2bn_tready),   // input wire M01_AXIS_TREADY
        .M02_AXIS_TREADY (m_axis_int2res_tready),  // input wire M02_AXIS_TREADY
        .M00_AXIS_TDATA  (m_axis_int2pe_tdata),    // output wire [31 : 0] M00_AXIS_TDATA
        .M01_AXIS_TDATA  (m_axis_int2bn_tdata),    // output wire [31 : 0] M01_AXIS_TDATA
        .M02_AXIS_TDATA  (m_axis_int2res_tdata),   // output wire [127 : 0] M02_AXIS_TDATA
        .M00_AXIS_TKEEP  (m_axis_int2pe_tkeep),    // output wire [3 : 0] M00_AXIS_TKEEP
        .M01_AXIS_TKEEP  (m_axis_int2bn_tkeep),    // output wire [3 : 0] M01_AXIS_TKEEP
        .M02_AXIS_TKEEP  (m_axis_int2res_tkeep),   // output wire [15 : 0] M02_AXIS_TKEEP
        .M00_AXIS_TLAST  (m_axis_int2pe_tlast),    // output wire M00_AXIS_TLAST
        .M01_AXIS_TLAST  (m_axis_int2bn_tlast),    // output wire M01_AXIS_TLAST
        .M02_AXIS_TLAST  (m_axis_int2res_tlast),   // output wire M02_AXIS_TLAST
        .M00_AXIS_TDEST  (i_M00_AXIS_TDEST),       // output wire [1 : 0] M00_AXIS_TDEST
        .M01_AXIS_TDEST  (i_M01_AXIS_TDEST),       // output wire [1 : 0] M01_AXIS_TDEST
        .M02_AXIS_TDEST  (i_M02_AXIS_TDEST),       // output wire [1 : 0] M02_AXIS_TDEST
        .S00_DECODE_ERR  (axis_mm2s_decode_err)    // output wire S00_DECODE_ERR
    );

    axis_interconnect_tag axis_mm2s_tag_interconnect_inst (
        .ACLK            (clk),                        // input wire ACLK
        .ARESETN         (rst_n),                      // input wire ARESETN
        .S00_AXIS_ACLK   (clk),                        // input wire S00_AXIS_ACLK
        .S00_AXIS_ARESETN(rst_n),                      // input wire S00_AXIS_ARESETN
        .S00_AXIS_TVALID (s_axis_buf2int_tag_tvalid),  // input wire S00_AXIS_TVALID
        .S00_AXIS_TREADY (s_axis_buf2int_tag_tready),  // output wire S00_AXIS_TREADY
        .S00_AXIS_TDATA  (s_axis_buf2int_tag_tdata),   // input wire [63 : 0] S00_AXIS_TDATA
        .S00_AXIS_TKEEP  (s_axis_buf2int_tag_tkeep),   // input wire [7 : 0] S00_AXIS_TKEEP
        .S00_AXIS_TLAST  (s_axis_buf2int_tag_tlast),   // input wire S00_AXIS_TLAST
        .S00_AXIS_TDEST  (s_axis_buf2int_tag_tdest),   // input wire [1 : 0] S00_AXIS_TDEST
        .M00_AXIS_ACLK   (clk),                        // input wire M00_AXIS_ACLK
        .M01_AXIS_ACLK   (clk),                        // input wire M01_AXIS_ACLK
        .M02_AXIS_ACLK   (clk),                        // input wire M02_AXIS_ACLK
        .M00_AXIS_ARESETN(rst_n),                      // input wire M00_AXIS_ARESETN
        .M01_AXIS_ARESETN(rst_n),                      // input wire M01_AXIS_ARESETN
        .M02_AXIS_ARESETN(rst_n),                      // input wire M02_AXIS_ARESETN
        .M00_AXIS_TVALID (m_axis_int2pe_tag_tvalid),   // output wire M00_AXIS_TVALID
        .M01_AXIS_TVALID (m_axis_int2bn_tag_tvalid),   // output wire M01_AXIS_TVALID
        .M02_AXIS_TVALID (m_axis_int2res_tag_tvalid),  // output wire M02_AXIS_TVALID
        .M00_AXIS_TREADY (m_axis_int2pe_tag_tready),   // input wire M00_AXIS_TREADY
        .M01_AXIS_TREADY (m_axis_int2bn_tag_tready),   // input wire M01_AXIS_TREADY
        .M02_AXIS_TREADY (m_axis_int2res_tag_tready),  // input wire M02_AXIS_TREADY
        .M00_AXIS_TDATA  (m_axis_int2pe_tag_tdata),    // output wire [63 : 0] M00_AXIS_TDATA
        .M01_AXIS_TDATA  (m_axis_int2bn_tag_tdata),    // output wire [63 : 0] M01_AXIS_TDATA
        .M02_AXIS_TDATA  (m_axis_int2res_tag_tdata),   // output wire [63 : 0] M02_AXIS_TDATA
        .M00_AXIS_TKEEP  (m_axis_int2pe_tag_tkeep),    // output wire [7 : 0] M00_AXIS_TKEEP
        .M01_AXIS_TKEEP  (m_axis_int2bn_tag_tkeep),    // output wire [7 : 0] M01_AXIS_TKEEP
        .M02_AXIS_TKEEP  (m_axis_int2res_tag_tkeep),   // output wire [7 : 0] M02_AXIS_TKEEP
        .M00_AXIS_TLAST  (m_axis_int2pe_tag_tlast),    // output wire M00_AXIS_TLAST
        .M01_AXIS_TLAST  (m_axis_int2bn_tag_tlast),    // output wire M01_AXIS_TLAST
        .M02_AXIS_TLAST  (m_axis_int2res_tag_tlast),   // output wire M02_AXIS_TLAST
        .M00_AXIS_TDEST  (i_M00_AXIS_TAG_TDEST),       // output wire [1 : 0] M00_AXIS_TDEST
        .M01_AXIS_TDEST  (i_M01_AXIS_TAG_TDEST),       // output wire [1 : 0] M01_AXIS_TDEST
        .M02_AXIS_TDEST  (i_M02_AXIS_TAG_TDEST),       // output wire [1 : 0] M02_AXIS_TDEST
        .S00_DECODE_ERR  (axis_mm2s_tag_decode_err)    // output wire S00_DECODE_ERR
    );

endmodule

