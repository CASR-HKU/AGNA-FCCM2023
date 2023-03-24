`timescale 1ns / 1ps

`include "def.sv"

module core_mem_itf #(
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
    output logic [                 3:0][31:0] status,
    // m_axi_core
    input  logic                              m_axi_core_awready,
    output logic                              m_axi_core_awvalid,
    output logic [  AXI_ADDR_WIDTH-1:0]       m_axi_core_awaddr,
    output logic [                 7:0]       m_axi_core_awlen,
    output logic [                 3:0]       m_axi_core_awid,
    output logic [                 2:0]       m_axi_core_awsize,
    output logic [                 1:0]       m_axi_core_awburst,
    output logic [                 2:0]       m_axi_core_awprot,
    output logic [                 3:0]       m_axi_core_awcache,
    output logic [                 3:0]       m_axi_core_awuser,
    input  logic                              m_axi_core_wready,
    output logic                              m_axi_core_wvalid,
    output logic [  AXI_DATA_WIDTH-1:0]       m_axi_core_wdata,
    output logic [AXI_DATA_WIDTH/8-1:0]       m_axi_core_wstrb,
    output logic                              m_axi_core_wlast,
    output logic                              m_axi_core_bready,
    input  logic                              m_axi_core_bvalid,
    input  logic [                 1:0]       m_axi_core_bresp,
    input  logic                              m_axi_core_arready,
    output logic                              m_axi_core_arvalid,
    output logic [  AXI_ADDR_WIDTH-1:0]       m_axi_core_araddr,
    output logic [                 7:0]       m_axi_core_arlen,
    output logic [                 3:0]       m_axi_core_arid,
    output logic [                 2:0]       m_axi_core_arsize,
    output logic [                 1:0]       m_axi_core_arburst,
    output logic [                 2:0]       m_axi_core_arprot,
    output logic [                 3:0]       m_axi_core_arcache,
    output logic [                 3:0]       m_axi_core_aruser,
    output logic                              m_axi_core_rready,
    input  logic                              m_axi_core_rvalid,
    input  logic [  AXI_DATA_WIDTH-1:0]       m_axi_core_rdata,
    input  logic [                 1:0]       m_axi_core_rresp,
    input  logic                              m_axi_core_rlast,
    // input axis_mm2s_instr
    output logic                              s_axis_mm2s_instr_tready,
    input  logic                              s_axis_mm2s_instr_tvalid,
    input  logic [CORE_INSTR_WIDTH-1:0]       s_axis_mm2s_instr_tdata,
    // input axis_mm2s_instr
    output logic                              s_axis_s2mm_instr_tready,
    input  logic                              s_axis_s2mm_instr_tvalid,
    input  logic [CORE_INSTR_WIDTH-1:0]       s_axis_s2mm_instr_tdata,
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
    output logic [                 1:0]       m_axis_mm2s_tag_tdest,
    // input axis_s2mm
    output logic                              s_axis_s2mm_tready,
    input  logic                              s_axis_s2mm_tvalid,
    input  logic [  AXI_DATA_WIDTH-1:0]       s_axis_s2mm_tdata,
    input  logic [AXI_DATA_WIDTH/8-1:0]       s_axis_s2mm_tkeep,
    input  logic                              s_axis_s2mm_tlast,
    // output axis wb_fb
    input  logic                              m_axis_wbfb_tready,
    output logic                              m_axis_wbfb_tvalid,
    output logic                              m_axis_wbfb_tdata
);

    // mm2s
    logic                              mm2s_err;
    logic [                31:0]       mm2s_scalar;
    logic [                 1:0][31:0] mm2s_status;
    // mm2s_cmd
    logic                              i_axis_mm2s_cmd_tready;
    logic                              i_axis_mm2s_cmd_tvalid;
    logic [  CORE_CMD_WIDTH-1:0]       i_axis_mm2s_cmd_tdata;
    // mm2s_sts
    logic                              i_axis_mm2s_sts_tready;
    logic                              i_axis_mm2s_sts_tvalid;
    logic [  CORE_STS_WIDTH-1:0]       i_axis_mm2s_sts_tdata;
    logic [                 0:0]       i_axis_mm2s_sts_tkeep;
    logic                              i_axis_mm2s_sts_tlast;
    // axis_mm2s
    logic                              i_axis_mm2s_tready;
    logic                              i_axis_mm2s_tvalid;
    logic [  AXI_DATA_WIDTH-1:0]       i_axis_mm2s_tdata;
    logic [AXI_DATA_WIDTH/8-1:0]       i_axis_mm2s_tkeep;
    logic                              i_axis_mm2s_tlast;

    // s2mm
    logic                              s2mm_err;
    logic [                31:0]       s2mm_scalar;
    logic [                 1:0][31:0] s2mm_status;
    // s2mm_cmd
    logic                              i_axis_s2mm_cmd_tready;
    logic                              i_axis_s2mm_cmd_tvalid;
    logic [  CORE_CMD_WIDTH-1:0]       i_axis_s2mm_cmd_tdata;
    // s2mm_sts
    logic                              i_axis_s2mm_sts_tready;
    logic                              i_axis_s2mm_sts_tvalid;
    logic [  CORE_STS_WIDTH-1:0]       i_axis_s2mm_sts_tdata;
    logic [                 0:0]       i_axis_s2mm_sts_tkeep;
    logic                              i_axis_s2mm_sts_tlast;
    // axis_s2mm
    logic                              i_axis_s2mm_tready;
    logic                              i_axis_s2mm_tvalid;
    logic [  AXI_DATA_WIDTH-1:0]       i_axis_s2mm_tdata;
    logic [AXI_DATA_WIDTH/8-1:0]       i_axis_s2mm_tkeep;
    logic                              i_axis_s2mm_tlast;

    logic [                 3:0]       sts_return;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            sts_return <= 4'b0000;
        end else if (i_axis_s2mm_sts_tready & i_axis_s2mm_sts_tvalid) begin
            sts_return <= i_axis_s2mm_sts_tdata[3:0];
        end
    end

    logic eot_fb_en;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            eot_fb_en <= 1'b0;
        end
    else if (i_axis_s2mm_sts_tready & i_axis_s2mm_sts_tvalid & i_axis_s2mm_sts_tdata[3:0] == 4'b1100) begin
            eot_fb_en <= 1'b1;
        end else eot_fb_en <= 1'b0;
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            m_axis_wbfb_tvalid <= 1'b0;
        end else if (m_axis_wbfb_tvalid & m_axis_wbfb_tready) begin
            m_axis_wbfb_tvalid <= 1'b0;
        end else if (eot_fb_en) begin
            m_axis_wbfb_tvalid <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            m_axis_wbfb_tdata <= 1'b0;
        end else if (m_axis_wbfb_tvalid & m_axis_wbfb_tready) begin
            m_axis_wbfb_tdata <= 1'b0;
        end else if (eot_fb_en) begin
            m_axis_wbfb_tdata <= 1'b1;
        end
    end

    always_comb begin
        status[1:0] = mm2s_status;
        mm2s_scalar = scalar;
        s2mm_scalar = 0;
        status[2][31:4] = s2mm_status[0][31:4];
        status[2][3:0] = sts_return;
        status[3] = s2mm_status[1];
    end


    // always_ff @(posedge clk) begin
    //     if (~rst_n) begin
    //         status[1] <= 32'h0;
    //     end
    //     else begin
    //         // status[1][31:24] <=  ? status[1][31:24]+1 : status[1][31:24];
    //         // status[1][23:16] <=  ? status[1][23:16]+1 : status[1][23:16];
    //         // status[1][15: 8] <=  ? status[1][15: 8]+1 : status[1][15: 8];
    //         // status[1][ 7: 0] <=  ? status[1][ 7: 0]+1 : status[1][ 7: 0];
    //         status[1][4] <= s2mm_err;
    //         status[1][0] <= mm2s_err;
    //     end
    // end

    mm2s_ctrl #(
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .MM2S_TAG_WIDTH  (MM2S_TAG_WIDTH),
        .CORE_CMD_WIDTH  (CORE_CMD_WIDTH),
        .CORE_STS_WIDTH  (CORE_STS_WIDTH),
        .CORE_INSTR_WIDTH(CORE_INSTR_WIDTH)
    ) mm2s_ctrl_inst (
        // common signal
        .clk                     (clk),
        .rst_n                   (rst_n),
        // variable signal
        .scalar                  (mm2s_scalar),
        .status                  (mm2s_status),
        // input axis_mm2s_instr
        .s_axis_mm2s_instr_tready(s_axis_mm2s_instr_tready),
        .s_axis_mm2s_instr_tvalid(s_axis_mm2s_instr_tvalid),
        .s_axis_mm2s_instr_tdata (s_axis_mm2s_instr_tdata),
        // output mm2s_cmd
        .m_axis_mm2s_cmd_tready  (i_axis_mm2s_cmd_tready),
        .m_axis_mm2s_cmd_tvalid  (i_axis_mm2s_cmd_tvalid),
        .m_axis_mm2s_cmd_tdata   (i_axis_mm2s_cmd_tdata),
        // input mm2s_sts
        .s_axis_mm2s_sts_tready  (i_axis_mm2s_sts_tready),
        .s_axis_mm2s_sts_tvalid  (i_axis_mm2s_sts_tvalid),
        .s_axis_mm2s_sts_tdata   (i_axis_mm2s_sts_tdata),
        .s_axis_mm2s_sts_tkeep   (i_axis_mm2s_sts_tkeep),
        .s_axis_mm2s_sts_tlast   (i_axis_mm2s_sts_tlast),
        // input axis_mm2s
        .s_axis_mm2s_tready      (i_axis_mm2s_tready),
        .s_axis_mm2s_tvalid      (i_axis_mm2s_tvalid),
        .s_axis_mm2s_tdata       (i_axis_mm2s_tdata),
        .s_axis_mm2s_tkeep       (i_axis_mm2s_tkeep),
        .s_axis_mm2s_tlast       (i_axis_mm2s_tlast),
        // output axis_mm2s
        .m_axis_mm2s_tready      (m_axis_mm2s_tready),
        .m_axis_mm2s_tvalid      (m_axis_mm2s_tvalid),
        .m_axis_mm2s_tdata       (m_axis_mm2s_tdata),
        .m_axis_mm2s_tkeep       (m_axis_mm2s_tkeep),
        .m_axis_mm2s_tlast       (m_axis_mm2s_tlast),
        .m_axis_mm2s_tdest       (m_axis_mm2s_tdest),
        // output axis_mm2s_tag
        .m_axis_mm2s_tag_tready  (m_axis_mm2s_tag_tready),
        .m_axis_mm2s_tag_tvalid  (m_axis_mm2s_tag_tvalid),
        .m_axis_mm2s_tag_tdata   (m_axis_mm2s_tag_tdata),
        .m_axis_mm2s_tag_tkeep   (m_axis_mm2s_tag_tkeep),
        .m_axis_mm2s_tag_tlast   (m_axis_mm2s_tag_tlast),
        .m_axis_mm2s_tag_tdest   (m_axis_mm2s_tag_tdest)
    );

    s2mm_ctrl #(
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        // .S2MM_TAG_WIDTH                 (S2MM_TAG_WIDTH             ),
        .CORE_CMD_WIDTH  (CORE_CMD_WIDTH),
        .CORE_STS_WIDTH  (CORE_STS_WIDTH),
        .CORE_INSTR_WIDTH(CORE_INSTR_WIDTH)
    ) s2mm_ctrl_inst (
        // common signal
        .clk                     (clk),
        .rst_n                   (rst_n),
        // variable signal
        .scalar                  (s2mm_scalar),
        .status                  (s2mm_status),
        // input axis_s2mm_instr
        .s_axis_s2mm_instr_tready(s_axis_s2mm_instr_tready),
        .s_axis_s2mm_instr_tvalid(s_axis_s2mm_instr_tvalid),
        .s_axis_s2mm_instr_tdata (s_axis_s2mm_instr_tdata),
        // output s2mm_cmd
        .m_axis_s2mm_cmd_tready  (i_axis_s2mm_cmd_tready),
        .m_axis_s2mm_cmd_tvalid  (i_axis_s2mm_cmd_tvalid),
        .m_axis_s2mm_cmd_tdata   (i_axis_s2mm_cmd_tdata),
        // input s2mm_sts
        .s_axis_s2mm_sts_tready  (i_axis_s2mm_sts_tready),
        .s_axis_s2mm_sts_tvalid  (i_axis_s2mm_sts_tvalid),
        .s_axis_s2mm_sts_tdata   (i_axis_s2mm_sts_tdata),
        .s_axis_s2mm_sts_tkeep   (i_axis_s2mm_sts_tkeep),
        .s_axis_s2mm_sts_tlast   (i_axis_s2mm_sts_tlast),
        // input axis_s2mm
        .s_axis_s2mm_tdata       (s_axis_s2mm_tdata),
        .s_axis_s2mm_tkeep       (s_axis_s2mm_tkeep),
        .s_axis_s2mm_tlast       (s_axis_s2mm_tlast),
        .s_axis_s2mm_tvalid      (s_axis_s2mm_tvalid),
        .s_axis_s2mm_tready      (s_axis_s2mm_tready),
        // // input axis_s2mm_tag
        // .s_axis_s2mm_tag_tready         (s_axis_s2mm_tag_tready     ),
        // .s_axis_s2mm_tag_tvalid         (s_axis_s2mm_tag_tvalid     ),
        // .s_axis_s2mm_tag_tdata          (s_axis_s2mm_tag_tdata      ),
        // .s_axis_s2mm_tag_tkeep          (s_axis_s2mm_tag_tkeep      ),
        // .s_axis_s2mm_tag_tlast          (s_axis_s2mm_tag_tlast      ),
        // output axis_s2mm
        .m_axis_s2mm_tdata       (i_axis_s2mm_tdata),
        .m_axis_s2mm_tkeep       (i_axis_s2mm_tkeep),
        .m_axis_s2mm_tlast       (i_axis_s2mm_tlast),
        .m_axis_s2mm_tvalid      (i_axis_s2mm_tvalid),
        .m_axis_s2mm_tready      (i_axis_s2mm_tready)
    );
    always_comb begin
        m_axi_core_araddr[AXI_ADDR_WIDTH-1:36] = 0;
        m_axi_core_awaddr[AXI_ADDR_WIDTH-1:36] = 0;
    end

    axi_datamover_ip axi_datamover_inst (
        // MM2S, general
        .m_axi_mm2s_aclk(clk),  // input wire m_axi_mm2s_aclk
        .m_axi_mm2s_aresetn(rst_n),  // input wire m_axi_mm2s_aresetn
        .mm2s_err(mm2s_err),  // output wire mm2s_err
        .m_axis_mm2s_cmdsts_aclk(clk),  // input wire m_axis_mm2s_cmdsts_aclk
        .m_axis_mm2s_cmdsts_aresetn(rst_n),  // input wire m_axis_mm2s_cmdsts_aresetn
        // MM2S, cmd stream
        .s_axis_mm2s_cmd_tready(i_axis_mm2s_cmd_tready),  // output wire s_axis_mm2s_cmd_tready
        .s_axis_mm2s_cmd_tvalid(i_axis_mm2s_cmd_tvalid),  // input wire s_axis_mm2s_cmd_tvalid
        .s_axis_mm2s_cmd_tdata(i_axis_mm2s_cmd_tdata),  // input wire [71 : 0] s_axis_mm2s_cmd_tdata
        // MM2S, status stream
        .m_axis_mm2s_sts_tready(i_axis_mm2s_sts_tready),  // input wire m_axis_mm2s_sts_tready
        .m_axis_mm2s_sts_tvalid(i_axis_mm2s_sts_tvalid),  // output wire m_axis_mm2s_sts_tvalid
        .m_axis_mm2s_sts_tdata(i_axis_mm2s_sts_tdata),  // output wire [7 : 0] m_axis_mm2s_sts_tdata
        .m_axis_mm2s_sts_tkeep(i_axis_mm2s_sts_tkeep),  // output wire [0 : 0] m_axis_mm2s_sts_tkeep
        .m_axis_mm2s_sts_tlast(i_axis_mm2s_sts_tlast),  // output wire m_axis_mm2s_sts_tlast
        // MM2S, AXI4 read
        .m_axi_mm2s_arid(m_axi_core_arid),  // output wire [3 : 0] m_axi_mm2s_arid
        .m_axi_mm2s_araddr(m_axi_core_araddr[35:0]),  // output wire [31 : 0] m_axi_mm2s_araddr
        .m_axi_mm2s_arlen(m_axi_core_arlen),  // output wire [7 : 0] m_axi_mm2s_arlen
        .m_axi_mm2s_arsize(m_axi_core_arsize),  // output wire [2 : 0] m_axi_mm2s_arsize
        .m_axi_mm2s_arburst(m_axi_core_arburst),  // output wire [1 : 0] m_axi_mm2s_arburst
        .m_axi_mm2s_arprot(m_axi_core_arprot),  // output wire [2 : 0] m_axi_mm2s_arprot
        .m_axi_mm2s_arcache(m_axi_core_arcache),  // output wire [3 : 0] m_axi_mm2s_arcache
        .m_axi_mm2s_aruser(m_axi_core_aruser),  // output wire [3 : 0] m_axi_mm2s_aruser
        .m_axi_mm2s_arvalid(m_axi_core_arvalid),  // output wire m_axi_mm2s_arvalid
        .m_axi_mm2s_arready(m_axi_core_arready),  // input wire m_axi_mm2s_arready
        .m_axi_mm2s_rdata(m_axi_core_rdata),  // input wire [127 : 0] m_axi_mm2s_rdata
        .m_axi_mm2s_rresp(m_axi_core_rresp),  // input wire [1 : 0] m_axi_mm2s_rresp
        .m_axi_mm2s_rlast(m_axi_core_rlast),  // input wire m_axi_mm2s_rlast
        .m_axi_mm2s_rvalid(m_axi_core_rvalid),  // input wire m_axi_mm2s_rvalid
        .m_axi_mm2s_rready(m_axi_core_rready),  // output wire m_axi_mm2s_rready
        // MM2S, AXIS master
        .m_axis_mm2s_tready(i_axis_mm2s_tready),  // input wire m_axis_mm2s_tready
        .m_axis_mm2s_tvalid(i_axis_mm2s_tvalid),  // output wire m_axis_mm2s_tvalid
        .m_axis_mm2s_tdata(i_axis_mm2s_tdata),  // output wire [127 : 0] m_axis_mm2s_tdata
        .m_axis_mm2s_tkeep(i_axis_mm2s_tkeep),  // output wire [15 : 0] m_axis_mm2s_tkeep
        .m_axis_mm2s_tlast(i_axis_mm2s_tlast),  // output wire m_axis_mm2s_tlast
        // S2MM, general
        .m_axi_s2mm_aclk(clk),  // input wire m_axi_s2mm_aclk
        .m_axi_s2mm_aresetn(rst_n),  // input wire m_axi_s2mm_aresetn
        .s2mm_err(s2mm_err),  // output wire s2mm_err
        .m_axis_s2mm_cmdsts_awclk(clk),  // input wire m_axis_s2mm_cmdsts_awclk
        .m_axis_s2mm_cmdsts_aresetn(rst_n),  // input wire m_axis_s2mm_cmdsts_aresetn
        // S2MM, cmd stream
        .s_axis_s2mm_cmd_tready(i_axis_s2mm_cmd_tready),  // output wire s_axis_s2mm_cmd_tready
        .s_axis_s2mm_cmd_tvalid(i_axis_s2mm_cmd_tvalid),  // input wire s_axis_s2mm_cmd_tvalid
        .s_axis_s2mm_cmd_tdata(i_axis_s2mm_cmd_tdata),  // input wire [71 : 0] s_axis_s2mm_cmd_tdata
        // S2MM, status stream
        .m_axis_s2mm_sts_tready(i_axis_s2mm_sts_tready),  // input wire m_axis_s2mm_sts_tready
        .m_axis_s2mm_sts_tvalid(i_axis_s2mm_sts_tvalid),  // output wire m_axis_s2mm_sts_tvalid
        .m_axis_s2mm_sts_tdata(i_axis_s2mm_sts_tdata),  // output wire [7 : 0] m_axis_s2mm_sts_tdata
        .m_axis_s2mm_sts_tkeep(i_axis_s2mm_sts_tkeep),  // output wire [0 : 0] m_axis_s2mm_sts_tkeep
        .m_axis_s2mm_sts_tlast(i_axis_s2mm_sts_tlast),  // output wire m_axis_s2mm_sts_tlast
        // S2MM, AXI4 write
        .m_axi_s2mm_awid(m_axi_core_awid),  // output wire [3 : 0] m_axi_s2mm_awid
        .m_axi_s2mm_awaddr(m_axi_core_awaddr[35:0]),  // output wire [31 : 0] m_axi_s2mm_awaddr
        .m_axi_s2mm_awlen(m_axi_core_awlen),  // output wire [7 : 0] m_axi_s2mm_awlen
        .m_axi_s2mm_awsize(m_axi_core_awsize),  // output wire [2 : 0] m_axi_s2mm_awsize
        .m_axi_s2mm_awburst(m_axi_core_awburst),  // output wire [1 : 0] m_axi_s2mm_awburst
        .m_axi_s2mm_awprot(m_axi_core_awprot),  // output wire [2 : 0] m_axi_s2mm_awprot
        .m_axi_s2mm_awcache(m_axi_core_awcache),  // output wire [3 : 0] m_axi_s2mm_awcache
        .m_axi_s2mm_awuser(m_axi_core_awuser),  // output wire [3 : 0] m_axi_s2mm_awuser
        .m_axi_s2mm_awvalid(m_axi_core_awvalid),  // output wire m_axi_s2mm_awvalid
        .m_axi_s2mm_awready(m_axi_core_awready),  // input wire m_axi_s2mm_awready
        .m_axi_s2mm_wdata(m_axi_core_wdata),  // output wire [127 : 0] m_axi_s2mm_wdata
        .m_axi_s2mm_wstrb(m_axi_core_wstrb),  // output wire [15 : 0] m_axi_s2mm_wstrb
        .m_axi_s2mm_wlast(m_axi_core_wlast),  // output wire m_axi_s2mm_wlast
        .m_axi_s2mm_wvalid(m_axi_core_wvalid),  // output wire m_axi_s2mm_wvalid
        .m_axi_s2mm_wready(m_axi_core_wready),  // input wire m_axi_s2mm_wready
        .m_axi_s2mm_bresp(m_axi_core_bresp),  // input wire [1 : 0] m_axi_s2mm_bresp
        .m_axi_s2mm_bvalid(m_axi_core_bvalid),  // input wire m_axi_s2mm_bvalid
        .m_axi_s2mm_bready(m_axi_core_bready),  // output wire m_axi_s2mm_bready
        // S2MM, AXIS slave
        .s_axis_s2mm_tready(i_axis_s2mm_tready),  // output wire s_axis_s2mm_tready
        .s_axis_s2mm_tvalid(i_axis_s2mm_tvalid),  // input wire s_axis_s2mm_tvalid
        .s_axis_s2mm_tdata(i_axis_s2mm_tdata),  // input wire [127 : 0] s_axis_s2mm_tdata
        .s_axis_s2mm_tkeep(i_axis_s2mm_tkeep),  // input wire [15 : 0] s_axis_s2mm_tkeep
        .s_axis_s2mm_tlast(i_axis_s2mm_tlast)  // input wire s_axis_s2mm_tlast
    );


endmodule
