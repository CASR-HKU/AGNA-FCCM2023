`timescale 1ns / 1ps

`include "def.sv"

module top_wrapper #(
    parameter PS_CTRL_AXI_ADDR_WIDTH = `DFLT_PS_CTRL_AXI_ADDR_WIDTH,
    parameter PS_CTRL_AXI_DATA_WIDTH = `DFLT_PS_CTRL_AXI_DATA_WIDTH,
    parameter AUX_AXI_ADDR_WIDTH     = `DFLT_AUX_AXI_ADDR_WIDTH,
    parameter AUX_AXI_DATA_WIDTH     = `DFLT_AUX_AXI_DATA_WIDTH,
    parameter CORE_AXI_ADDR_WIDTH    = `DFLT_CORE_AXI_ADDR_WIDTH,
    parameter CORE_AXI_DATA_WIDTH    = `DFLT_CORE_AXI_DATA_WIDTH
) (
    // common signal
    // (* X_INTERFACE_PARAMETER = "<parameter_name1> <parameter_value1>, <parameter_name2> <parameter_value2>" *)
    input  wire                                clk,
    input  wire                                rst_n,
    output wire                                interrupt,
`ifdef PS_CTRL_ENABLE
    // s_axi_control, AXI4-Lite slave
    output wire                                s_axi_control_awready,
    input  wire                                s_axi_control_awvalid,
    input  wire [  PS_CTRL_AXI_ADDR_WIDTH-1:0] s_axi_control_awaddr,
    output wire                                s_axi_control_wready,
    input  wire                                s_axi_control_wvalid,
    input  wire [  PS_CTRL_AXI_DATA_WIDTH-1:0] s_axi_control_wdata,
    input  wire [PS_CTRL_AXI_DATA_WIDTH/8-1:0] s_axi_control_wstrb,
    input  wire                                s_axi_control_bready,
    output wire                                s_axi_control_bvalid,
    output wire [                         1:0] s_axi_control_bresp,
    output wire                                s_axi_control_arready,
    input  wire                                s_axi_control_arvalid,
    input  wire [  PS_CTRL_AXI_ADDR_WIDTH-1:0] s_axi_control_araddr,
    input  wire                                s_axi_control_rready,
    output wire                                s_axi_control_rvalid,
    output wire [  PS_CTRL_AXI_DATA_WIDTH-1:0] s_axi_control_rdata,
    output wire [                         1:0] s_axi_control_rresp,
`endif
`ifdef AUX_AXI_ENABLE
    // m_axi_aux, AXI4 master
    input  wire                                m_axi_aux_awready,
    output wire                                m_axi_aux_awvalid,
    output wire [      AUX_AXI_ADDR_WIDTH-1:0] m_axi_aux_awaddr,
    output wire [                         7:0] m_axi_aux_awlen,
    output wire [                         2:0] m_axi_aux_awsize,
    output wire [                         1:0] m_axi_aux_awburst,
    output wire [                         1:0] m_axi_aux_awlock,
    output wire [                         3:0] m_axi_aux_awregion,
    output wire [                         3:0] m_axi_aux_awcache,
    output wire [                         2:0] m_axi_aux_awprot,
    output wire [                         3:0] m_axi_aux_awqos,
    input  wire                                m_axi_aux_wready,
    output wire                                m_axi_aux_wvalid,
    output wire [      AUX_AXI_DATA_WIDTH-1:0] m_axi_aux_wdata,
    output wire [    AUX_AXI_DATA_WIDTH/8-1:0] m_axi_aux_wstrb,
    output wire                                m_axi_aux_wlast,
    output wire                                m_axi_aux_bready,
    input  wire                                m_axi_aux_bvalid,
    input  wire [                         1:0] m_axi_aux_bresp,
    input  wire                                m_axi_aux_arready,
    output wire                                m_axi_aux_arvalid,
    output wire [      AUX_AXI_ADDR_WIDTH-1:0] m_axi_aux_araddr,
    output wire [                         7:0] m_axi_aux_arlen,
    output wire [                       2 : 0] m_axi_aux_arsize,
    output wire [                       1 : 0] m_axi_aux_arburst,
    output wire [                       1 : 0] m_axi_aux_arlock,
    output wire [                       3 : 0] m_axi_aux_arregion,
    output wire [                       3 : 0] m_axi_aux_arcache,
    output wire [                       2 : 0] m_axi_aux_arprot,
    output wire [                       3 : 0] m_axi_aux_arqos,
    output wire                                m_axi_aux_rready,
    input  wire                                m_axi_aux_rvalid,
    input  wire [      AUX_AXI_DATA_WIDTH-1:0] m_axi_aux_rdata,
    input  wire [                         1:0] m_axi_aux_rresp,
    input  wire                                m_axi_aux_rlast,
`endif
    // m_axi_core, AXI4 master
    input  wire                                m_axi_core_awready,
    output wire                                m_axi_core_awvalid,
    output wire [     CORE_AXI_ADDR_WIDTH-1:0] m_axi_core_awaddr,
    output wire [                         7:0] m_axi_core_awlen,
    input  wire                                m_axi_core_wready,
    output wire                                m_axi_core_wvalid,
    output wire [     CORE_AXI_DATA_WIDTH-1:0] m_axi_core_wdata,
    output wire [   CORE_AXI_DATA_WIDTH/8-1:0] m_axi_core_wstrb,
    output wire                                m_axi_core_wlast,
    output wire                                m_axi_core_bready,
    input  wire                                m_axi_core_bvalid,
    input  wire [                         1:0] m_axi_core_bresp,
    input  wire                                m_axi_core_arready,
    output wire                                m_axi_core_arvalid,
    output wire [     CORE_AXI_ADDR_WIDTH-1:0] m_axi_core_araddr,
    output wire [                         7:0] m_axi_core_arlen,
    output wire                                m_axi_core_rready,
    input  wire                                m_axi_core_rvalid,
    input  wire [     CORE_AXI_DATA_WIDTH-1:0] m_axi_core_rdata,
    input  wire [                         1:0] m_axi_core_rresp,
    input  wire                                m_axi_core_rlast
);


    top top_inst (
        .clk                  (clk),
        .rst_n                (rst_n),
        .interrupt            (interrupt),
`ifdef PS_CTRL_ENABLE
        .s_axi_control_awready(s_axi_control_awready),
        .s_axi_control_awvalid(s_axi_control_awvalid),
        .s_axi_control_awaddr (s_axi_control_awaddr),
        .s_axi_control_wready (s_axi_control_wready),
        .s_axi_control_wvalid (s_axi_control_wvalid),
        .s_axi_control_wdata  (s_axi_control_wdata),
        .s_axi_control_wstrb  (s_axi_control_wstrb),
        .s_axi_control_bready (s_axi_control_bready),
        .s_axi_control_bvalid (s_axi_control_bvalid),
        .s_axi_control_bresp  (s_axi_control_bresp),
        .s_axi_control_arready(s_axi_control_arready),
        .s_axi_control_arvalid(s_axi_control_arvalid),
        .s_axi_control_araddr (s_axi_control_araddr),
        .s_axi_control_rready (s_axi_control_rready),
        .s_axi_control_rvalid (s_axi_control_rvalid),
        .s_axi_control_rdata  (s_axi_control_rdata),
        .s_axi_control_rresp  (s_axi_control_rresp),
`endif
`ifdef AUX_AXI_ENABLE
        .m_axi_aux_awready    (m_axi_aux_awready),
        .m_axi_aux_awvalid    (m_axi_aux_awvalid),
        .m_axi_aux_awaddr     (m_axi_aux_awaddr),
        .m_axi_aux_awlen      (m_axi_aux_awlen),
        .m_axi_aux_awsize     (m_axi_aux_awsize),
        .m_axi_aux_awburst    (m_axi_aux_awburst),
        .m_axi_aux_awlock     (m_axi_aux_awlock),
        .m_axi_aux_awregion   (m_axi_aux_awregion),
        .m_axi_aux_awcache    (m_axi_aux_awcache),
        .m_axi_aux_awprot     (m_axi_aux_awprot),
        .m_axi_aux_awqos      (m_axi_aux_awqos),
        .m_axi_aux_wready     (m_axi_aux_wready),
        .m_axi_aux_wvalid     (m_axi_aux_wvalid),
        .m_axi_aux_wdata      (m_axi_aux_wdata),
        .m_axi_aux_wstrb      (m_axi_aux_wstrb),
        .m_axi_aux_wlast      (m_axi_aux_wlast),
        .m_axi_aux_bready     (m_axi_aux_bready),
        .m_axi_aux_bvalid     (m_axi_aux_bvalid),
        .m_axi_aux_bresp      (m_axi_aux_bresp),
        .m_axi_aux_arready    (m_axi_aux_arready),
        .m_axi_aux_arvalid    (m_axi_aux_arvalid),
        .m_axi_aux_araddr     (m_axi_aux_araddr),
        .m_axi_aux_arlen      (m_axi_aux_arlen),
        .m_axi_aux_arsize     (m_axi_aux_arsize),
        .m_axi_aux_arburst    (m_axi_aux_arburst),
        .m_axi_aux_arlock     (m_axi_aux_arlock),
        .m_axi_aux_arregion   (m_axi_aux_arregion),
        .m_axi_aux_arcache    (m_axi_aux_arcache),
        .m_axi_aux_arprot     (m_axi_aux_arprot),
        .m_axi_aux_arqos      (m_axi_aux_arqos),
        .m_axi_aux_rready     (m_axi_aux_rready),
        .m_axi_aux_rvalid     (m_axi_aux_rvalid),
        .m_axi_aux_rdata      (m_axi_aux_rdata),
        .m_axi_aux_rresp      (m_axi_aux_rresp),
        .m_axi_aux_rlast      (m_axi_aux_rlast),
`endif
        .m_axi_core_awready   (m_axi_core_awready),
        .m_axi_core_awvalid   (m_axi_core_awvalid),
        .m_axi_core_awaddr    (m_axi_core_awaddr),
        .m_axi_core_awlen     (m_axi_core_awlen),
        .m_axi_core_wready    (m_axi_core_wready),
        .m_axi_core_wvalid    (m_axi_core_wvalid),
        .m_axi_core_wdata     (m_axi_core_wdata),
        .m_axi_core_wstrb     (m_axi_core_wstrb),
        .m_axi_core_wlast     (m_axi_core_wlast),
        .m_axi_core_bready    (m_axi_core_bready),
        .m_axi_core_bvalid    (m_axi_core_bvalid),
        .m_axi_core_bresp     (m_axi_core_bresp),
        .m_axi_core_arready   (m_axi_core_arready),
        .m_axi_core_arvalid   (m_axi_core_arvalid),
        .m_axi_core_araddr    (m_axi_core_araddr),
        .m_axi_core_arlen     (m_axi_core_arlen),
        .m_axi_core_rready    (m_axi_core_rready),
        .m_axi_core_rvalid    (m_axi_core_rvalid),
        .m_axi_core_rdata     (m_axi_core_rdata),
        .m_axi_core_rresp     (m_axi_core_rresp),
        .m_axi_core_rlast     (m_axi_core_rlast)
    );

endmodule