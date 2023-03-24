`timescale 1ns / 1ps

`include "def.sv"

module agna_core #(
    parameter AXI_ADDR_WIDTH      = `DFLT_CORE_AXI_ADDR_WIDTH,
    parameter AXI_DATA_WIDTH      = `DFLT_CORE_AXI_DATA_WIDTH,
    parameter MM2S_TAG_WIDTH      = `DFLT_MEM_TAG_WIDTH,
    parameter CORE_CMD_WIDTH      = `DFLT_MEM_CMD_WIDTH,
    parameter CORE_STS_WIDTH      = `DFLT_MEM_STS_WIDTH,
    parameter CORE_INSTR_WIDTH    = `DFLT_CORE_INSTR_WIDTH,
    parameter PE_UPDT_DATA_WIDTH  = `DFLT_PE_UPDT_DATA_WIDTH,
    parameter BN_UPDT_DATA_WIDTH  = `DFLT_BN_UPDT_DATA_WIDTH,
    parameter RES_UPDT_DATA_WIDTH = `DFLT_RES_UPDT_DATA_WIDTH,
    parameter PE_LC_DATA_WIDTH    = `PARAM_PE_LC_DATA_WIDTH,

    parameter PE_NUM = `HW_CONFIG_PE_NUM
) (
    // common signal
    input  logic                              clk,
    input  logic                              rst_n,
    // control signal
    input  logic                              ap_start,
    output logic                              ap_done,
    output logic                              ap_idle,
    output logic                              ap_ready,
    input  logic [                 3:0][31:0] scalar,
    output logic [                10:0][31:0] status,
    input  logic [                31:0]       instr_num,
    // m_axi, AXI4 master
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
    // input axis_instr
    output logic                              s_axis_instr_tready,
    input  logic                              s_axis_instr_tvalid,
    input  logic [  AXI_DATA_WIDTH-1:0]       s_axis_instr_tdata
);

    logic                                   i_axis_instr_tready;
    logic                                   i_axis_instr_tvalid;
    logic [       AXI_DATA_WIDTH-1:0]       i_axis_instr_tdata;

    // i_axis_mm2s_instr
    logic                                   i_axis_mm2s_instr_tready;
    logic                                   i_axis_mm2s_instr_tvalid;
    logic [     CORE_INSTR_WIDTH-1:0]       i_axis_mm2s_instr_tdata;

    // i_axis_mm2s_instr
    logic                                   i_axis_s2mm_instr_tready;
    logic                                   i_axis_s2mm_instr_tvalid;
    logic [     CORE_INSTR_WIDTH-1:0]       i_axis_s2mm_instr_tdata;

    // updt instr
    logic                                   i_axis_updt_instr_tready;
    logic                                   i_axis_updt_instr_tvalid;
    logic [     CORE_INSTR_WIDTH-1:0]       i_axis_updt_instr_tdata;

    // exec instr
    logic                                   i_axis_exec_instr_tready;
    logic                                   i_axis_exec_instr_tvalid;
    logic [     CORE_INSTR_WIDTH-1:0]       i_axis_exec_instr_tdata;

    // wb instr
    logic                                   i_axis_wb_instr_tready;
    logic                                   i_axis_wb_instr_tvalid;
    logic [     CORE_INSTR_WIDTH-1:0]       i_axis_wb_instr_tdata;

    // layout converter instructions
    logic                                   i_axis_lc_instr_tready;
    logic                                   i_axis_lc_instr_tvalid;
    logic [     CORE_INSTR_WIDTH-1:0]       i_axis_lc_instr_tdata;

    // res adder instructions
    logic                                   i_axis_res_instr_tready;
    logic                                   i_axis_res_instr_tvalid;
    logic                                   i_axis_res_instr_tdata;  // 0 - no res, 1 - res

    // i_axis_mm2s
    logic                                   i_axis_mm2s_tready;
    logic                                   i_axis_mm2s_tvalid;
    logic [       AXI_DATA_WIDTH-1:0]       i_axis_mm2s_tdata;
    logic [     AXI_DATA_WIDTH/8-1:0]       i_axis_mm2s_tkeep;
    logic                                   i_axis_mm2s_tlast;
    logic [                      1:0]       i_axis_mm2s_tdest;

    // i_axis_mm2s_tag
    logic                                   i_axis_mm2s_tag_tready;
    logic                                   i_axis_mm2s_tag_tvalid;
    logic [       MM2S_TAG_WIDTH-1:0]       i_axis_mm2s_tag_tdata;
    logic [     MM2S_TAG_WIDTH/8-1:0]       i_axis_mm2s_tag_tkeep;
    logic                                   i_axis_mm2s_tag_tlast;
    logic [                      1:0]       i_axis_mm2s_tag_tdest;

    // i_axis_s2mm
    logic                                   i_axis_s2mm_tready;
    logic                                   i_axis_s2mm_tvalid;
    logic [       AXI_DATA_WIDTH-1:0]       i_axis_s2mm_tdata;
    logic [     AXI_DATA_WIDTH/8-1:0]       i_axis_s2mm_tkeep;
    logic                                   i_axis_s2mm_tlast;

    // i_axis_buf2int
    logic                                   i_axis_buf2int_tready;
    logic                                   i_axis_buf2int_tvalid;
    logic [       AXI_DATA_WIDTH-1:0]       i_axis_buf2int_tdata;
    logic [     AXI_DATA_WIDTH/8-1:0]       i_axis_buf2int_tkeep;
    logic                                   i_axis_buf2int_tlast;
    logic [                      1:0]       i_axis_buf2int_tdest;

    // i_axis_buf2int_tag
    logic                                   i_axis_buf2int_tag_tready;
    logic                                   i_axis_buf2int_tag_tvalid;
    logic [       MM2S_TAG_WIDTH-1:0]       i_axis_buf2int_tag_tdata;
    logic [     MM2S_TAG_WIDTH/8-1:0]       i_axis_buf2int_tag_tkeep;
    logic                                   i_axis_buf2int_tag_tlast;
    logic [                      1:0]       i_axis_buf2int_tag_tdest;

    // i_axis_int2pe
    logic                                   i_axis_int2pe_tready;
    logic                                   i_axis_int2pe_tvalid;
    logic [       AXI_DATA_WIDTH-1:0]       i_axis_int2pe_tdata;
    logic [     AXI_DATA_WIDTH/8-1:0]       i_axis_int2pe_tkeep;
    logic                                   i_axis_int2pe_tlast;

    // i_axis_int2pe_tag
    logic                                   i_axis_int2pe_tag_tready;
    logic                                   i_axis_int2pe_tag_tvalid;
    logic [       MM2S_TAG_WIDTH-1:0]       i_axis_int2pe_tag_tdata;
    logic [     MM2S_TAG_WIDTH/8-1:0]       i_axis_int2pe_tag_tkeep;
    logic                                   i_axis_int2pe_tag_tlast;

    // i_axis_int2bn
    logic                                   i_axis_int2bn_tready;
    logic                                   i_axis_int2bn_tvalid;
    logic [   BN_UPDT_DATA_WIDTH-1:0]       i_axis_int2bn_tdata;
    logic [ BN_UPDT_DATA_WIDTH/8-1:0]       i_axis_int2bn_tkeep;
    logic                                   i_axis_int2bn_tlast;

    // i_axis_int2bn_tag
    logic                                   i_axis_int2bn_tag_tready;
    logic                                   i_axis_int2bn_tag_tvalid;
    logic [       MM2S_TAG_WIDTH-1:0]       i_axis_int2bn_tag_tdata;
    logic [     MM2S_TAG_WIDTH/8-1:0]       i_axis_int2bn_tag_tkeep;
    logic                                   i_axis_int2bn_tag_tlast;

    // i_axis_int2res
    logic                                   i_axis_int2res_tready;
    logic                                   i_axis_int2res_tvalid;
    logic [  RES_UPDT_DATA_WIDTH-1:0]       i_axis_int2res_tdata;
    logic [RES_UPDT_DATA_WIDTH/8-1:0]       i_axis_int2res_tkeep;
    logic                                   i_axis_int2res_tlast;

    // i_axis_int2res_tag
    logic                                   i_axis_int2res_tag_tready;
    logic                                   i_axis_int2res_tag_tvalid;
    logic [       MM2S_TAG_WIDTH-1:0]       i_axis_int2res_tag_tdata;
    logic [     MM2S_TAG_WIDTH/8-1:0]       i_axis_int2res_tag_tkeep;
    logic                                   i_axis_int2res_tag_tlast;

    // i_axis_pe2lc
    logic                                   i_axis_pe2lc_tready;
    logic                                   i_axis_pe2lc_tvalid;
    logic [     PE_LC_DATA_WIDTH-1:0]       i_axis_pe2lc_tdata;
    logic [   PE_LC_DATA_WIDTH/8-1:0]       i_axis_pe2lc_tkeep;
    logic                                   i_axis_pe2lc_tlast;

    // i_axis_lc2res
    logic                                   i_axis_lc2res_tready;
    logic                                   i_axis_lc2res_tvalid;
    logic [       AXI_DATA_WIDTH-1:0]       i_axis_lc2res_tdata;
    logic [     AXI_DATA_WIDTH/8-1:0]       i_axis_lc2res_tkeep;
    logic                                   i_axis_lc2res_tlast;
    logic                                   i_axis_lc2res_tuser;

    // i_axis_res2ac
    logic                                   i_axis_res2ac_tready;
    logic                                   i_axis_res2ac_tvalid;
    logic [       AXI_DATA_WIDTH-1:0]       i_axis_res2ac_tdata;
    logic [     AXI_DATA_WIDTH/8-1:0]       i_axis_res2ac_tkeep;
    logic                                   i_axis_res2ac_tlast;

    // i_axis_ac2mem
    logic                                   i_axis_ac2mem_tready;
    logic                                   i_axis_ac2mem_tvalid;
    logic [       AXI_DATA_WIDTH-1:0]       i_axis_ac2mem_tdata;
    logic [     AXI_DATA_WIDTH/8-1:0]       i_axis_ac2mem_tkeep;
    logic                                   i_axis_ac2mem_tlast;

    logic                                   res_layer_enable;

    logic                                   i_axis_eolfb_tready;
    logic                                   i_axis_eolfb_tvalid;
    logic                                   i_axis_eolfb_tdata;

    logic                                   i_axis_wbfb_tready;
    logic                                   i_axis_wbfb_tvalid;
    logic                                   i_axis_wbfb_tdata;

    logic [                     31:0]       mem_itf_scalar;
    // logic       [31:0] core_ctrl_status;
    logic [                      1:0][31:0] prebuf_status;
    logic [                     31:0]       core_instr_status;
    logic [                      3:0][31:0] mem_itf_status;
    logic [                      3:0][31:0] pe_array_status;
    // logic [31:0]        axi_status;
    logic [                     31:0]       res_adder_status;
    logic                                   updt_proc_sts;

    logic axi_core_ar_hs, axi_core_r_hs, axi_core_aw_hs, axi_core_w_hs, axi_core_b_hs;
    always_comb begin
        axi_core_ar_hs = m_axi_core_arready & m_axi_core_arvalid;
        axi_core_r_hs  = m_axi_core_rready & m_axi_core_rvalid;
        axi_core_aw_hs = m_axi_core_awready & m_axi_core_awvalid;
        axi_core_w_hs  = m_axi_core_wready & m_axi_core_wvalid;
        axi_core_b_hs  = m_axi_core_bready & m_axi_core_bvalid;
    end

    always_comb begin
        ap_idle        = 0;
        ap_ready       = 0;
        mem_itf_scalar = scalar[0];
        status[3:0]    = mem_itf_status;
        status[7:4]    = pe_array_status;
        status[8]      = lat_cnt;
        status[9]      = res_adder_status;
        status[10]     = core_instr_status;
        // status[10]      = axi_status;
    end

    // always_ff @(posedge clk) begin
    //     if (~rst_n) begin
    //         axi_status <= 0;
    //     end
    //     else begin
    //         axi_status <= axi_core_b_hs ? axi_status+1 : axi_status;
    //     end
    // end

    // latency counter
    logic [31:0] lat_cnt;
    logic instr_hs_status, lat_status;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            instr_hs_status <= 1'b0;
        end else if (s_axis_instr_tready & s_axis_instr_tvalid) begin
            instr_hs_status <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            lat_status <= 1'b0;
        end else if (mem_itf_status[2][3:0] == 4'b1111) begin
            lat_status <= 1'b0;
        end else if (s_axis_instr_tready & s_axis_instr_tvalid & (~instr_hs_status)) begin
            lat_status <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            lat_cnt <= 32'd0;
        end else if (lat_status) begin
            lat_cnt <= lat_cnt + 1;
        end
    end

    always_comb begin
        i_axis_int2res_tag_tready = 1'b1;
    end

    /******************************************** core_ctrl ********************************************/
    // core controller to generate instructions
    fifo_axis #(
        .FIFO_AXIS_DEPTH      (16),
        .FIFO_AXIS_TDATA_WIDTH(AXI_DATA_WIDTH)
    ) core_instr_fifo (
        //common signal
        .clk          (clk),
        .rst_n        (rst_n),
        // s_axis
        .s_axis_tready(s_axis_instr_tready),
        .s_axis_tvalid(s_axis_instr_tvalid),
        .s_axis_tdata (s_axis_instr_tdata),
        .s_axis_tkeep (16'hffff),
        .s_axis_tlast (1'b0),
        // m_axis
        .m_axis_tready(i_axis_instr_tready),
        .m_axis_tvalid(i_axis_instr_tvalid),
        .m_axis_tdata (i_axis_instr_tdata)
    );

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            core_instr_status <= 32'h0;
        end else
            core_instr_status <= (i_axis_instr_tvalid & i_axis_instr_tready) ? core_instr_status + 1 : core_instr_status;
    end

    core_controller_0 core_ctrl_inst (
        .ap_clk(clk),  // input wire ap_clk
        .ap_rst(~rst_n),  // input wire ap_rst
        .ap_start(ap_start),  // input wire ap_start
        .ap_done(ap_done),  // output wire ap_done
        //   .ap_ready(ap_ready),                              // output wire ap_ready
        //   .ap_idle(ap_idle),                                // output wire ap_idle
        .instr_num(instr_num),  // input wire [31 : 0] instr_num
        .s_core_instr_dout(i_axis_instr_tdata),  // input wire [127 : 0] s_core_instr_dout
        .s_core_instr_empty_n(i_axis_instr_tvalid),  // input wire s_core_instr_empty_n
        .s_core_instr_read(i_axis_instr_tready),  // output wire s_core_instr_read
        .s_done_instr_dout(i_axis_eolfb_tdata),  // input wire [0 : 0] s_done_instr_dout
        .s_done_instr_empty_n(i_axis_eolfb_tvalid),  // input wire s_done_instr_empty_n
        .s_done_instr_read(i_axis_eolfb_tready),  // output wire s_done_instr_read
        .m_res_instr_din(i_axis_res_instr_tdata),  // output wire [0 : 0] m_res_instr_din
        .m_res_instr_full_n(i_axis_res_instr_tready),  // input wire m_res_instr_full_n
        .m_res_instr_write(i_axis_res_instr_tvalid),  // output wire m_res_instr_write
        .m_mm2s_instr_din(i_axis_mm2s_instr_tdata),  // output wire [63 : 0] m_mm2s_instr_din
        .m_mm2s_instr_full_n(i_axis_mm2s_instr_tready),  // input wire m_mm2s_instr_full_n
        .m_mm2s_instr_write(i_axis_mm2s_instr_tvalid),  // output wire m_mm2s_instr_write
        .m_s2mm_instr_din(i_axis_s2mm_instr_tdata),  // output wire [63 : 0] m_s2mm_instr_din
        .m_s2mm_instr_full_n(i_axis_s2mm_instr_tready),  // input wire m_s2mm_instr_full_n
        .m_s2mm_instr_write(i_axis_s2mm_instr_tvalid),  // output wire m_s2mm_instr_write
        .m_pe_updt_instr_din(i_axis_updt_instr_tdata),  // output wire [63 : 0] m_pe_conf_instr_din
        .m_pe_updt_instr_full_n(i_axis_updt_instr_tready),  // input wire m_pe_conf_instr_full_n
        .m_pe_updt_instr_write(i_axis_updt_instr_tvalid),  // output wire m_pe_conf_instr_write
        .m_pe_exec_instr_din(i_axis_exec_instr_tdata),  // output wire [63 : 0] m_pe_exec_instr_din
        .m_pe_exec_instr_full_n(i_axis_exec_instr_tready),  // input wire m_pe_exec_instr_full_n
        .m_pe_exec_instr_write(i_axis_exec_instr_tvalid),  // output wire m_pe_exec_instr_write
        .m_pe_wb_instr_din(i_axis_wb_instr_tdata),  // output wire [63 : 0] m_pe_wb_instr_din
        .m_pe_wb_instr_full_n(i_axis_wb_instr_tready),  // input wire m_pe_wb_instr_full_n
        .m_pe_wb_instr_write(i_axis_wb_instr_tvalid),  // output wire m_pe_wb_instr_write
        .m_lc_instr_din(i_axis_lc_instr_tdata),  // output wire [63 : 0] m_lc_instr_din
        .m_lc_instr_full_n(i_axis_lc_instr_tready),  // input wire m_lc_instr_full_n
        .m_lc_instr_write(i_axis_lc_instr_tvalid)  // output wire m_lc_instr_write
    );
    /******************************************** core_ctrl ********************************************/

    /****************************************** core_mem_itf ******************************************/
    core_mem_itf #(
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .CORE_CMD_WIDTH  (CORE_CMD_WIDTH),
        .CORE_STS_WIDTH  (CORE_STS_WIDTH),
        .MM2S_TAG_WIDTH  (MM2S_TAG_WIDTH),
        .CORE_INSTR_WIDTH(CORE_INSTR_WIDTH)
    ) core_mem_itf_inst (
        // common signal
        .clk                     (clk),
        .rst_n                   (rst_n),
        // variable signal
        .scalar                  (mem_itf_scalar),
        .status                  (mem_itf_status),
        // m_axi_core
        .m_axi_core_awready      (m_axi_core_awready),
        .m_axi_core_awvalid      (m_axi_core_awvalid),
        .m_axi_core_awaddr       (m_axi_core_awaddr),
        .m_axi_core_awlen        (m_axi_core_awlen),
        .m_axi_core_awid         (m_axi_core_awid),
        .m_axi_core_awsize       (m_axi_core_awsize),
        .m_axi_core_awburst      (m_axi_core_awburst),
        .m_axi_core_awprot       (m_axi_core_awprot),
        .m_axi_core_awcache      (m_axi_core_awcache),
        .m_axi_core_awuser       (m_axi_core_awuser),
        .m_axi_core_wready       (m_axi_core_wready),
        .m_axi_core_wvalid       (m_axi_core_wvalid),
        .m_axi_core_wdata        (m_axi_core_wdata),
        .m_axi_core_wstrb        (m_axi_core_wstrb),
        .m_axi_core_wlast        (m_axi_core_wlast),
        .m_axi_core_bready       (m_axi_core_bready),
        .m_axi_core_bvalid       (m_axi_core_bvalid),
        .m_axi_core_bresp        (m_axi_core_bresp),
        .m_axi_core_arready      (m_axi_core_arready),
        .m_axi_core_arvalid      (m_axi_core_arvalid),
        .m_axi_core_araddr       (m_axi_core_araddr),
        .m_axi_core_arlen        (m_axi_core_arlen),
        .m_axi_core_arid         (m_axi_core_arid),
        .m_axi_core_arsize       (m_axi_core_arsize),
        .m_axi_core_arburst      (m_axi_core_arburst),
        .m_axi_core_arprot       (m_axi_core_arprot),
        .m_axi_core_arcache      (m_axi_core_arcache),
        .m_axi_core_aruser       (m_axi_core_aruser),
        .m_axi_core_rready       (m_axi_core_rready),
        .m_axi_core_rvalid       (m_axi_core_rvalid),
        .m_axi_core_rdata        (m_axi_core_rdata),
        .m_axi_core_rresp        (m_axi_core_rresp),
        .m_axi_core_rlast        (m_axi_core_rlast),
        // input axis_mm2s_instr
        .s_axis_mm2s_instr_tready(i_axis_mm2s_instr_tready),
        .s_axis_mm2s_instr_tvalid(i_axis_mm2s_instr_tvalid),
        .s_axis_mm2s_instr_tdata (i_axis_mm2s_instr_tdata),
        // input axis_s2mm_instr
        .s_axis_s2mm_instr_tready(i_axis_s2mm_instr_tready),
        .s_axis_s2mm_instr_tvalid(i_axis_s2mm_instr_tvalid),
        .s_axis_s2mm_instr_tdata (i_axis_s2mm_instr_tdata),
        // output axis_mm2s
        .m_axis_mm2s_tready      (i_axis_mm2s_tready),
        .m_axis_mm2s_tvalid      (i_axis_mm2s_tvalid),
        .m_axis_mm2s_tdata       (i_axis_mm2s_tdata),
        .m_axis_mm2s_tkeep       (i_axis_mm2s_tkeep),
        .m_axis_mm2s_tlast       (i_axis_mm2s_tlast),
        .m_axis_mm2s_tdest       (i_axis_mm2s_tdest),
        // output axis_mm2s_tag
        .m_axis_mm2s_tag_tready  (i_axis_mm2s_tag_tready),
        .m_axis_mm2s_tag_tvalid  (i_axis_mm2s_tag_tvalid),
        .m_axis_mm2s_tag_tdata   (i_axis_mm2s_tag_tdata),
        .m_axis_mm2s_tag_tkeep   (i_axis_mm2s_tag_tkeep),
        .m_axis_mm2s_tag_tlast   (i_axis_mm2s_tag_tlast),
        .m_axis_mm2s_tag_tdest   (i_axis_mm2s_tag_tdest),
        // input axis_s2mm
        .s_axis_s2mm_tready      (i_axis_s2mm_tready),
        .s_axis_s2mm_tvalid      (i_axis_s2mm_tvalid),
        .s_axis_s2mm_tdata       (i_axis_s2mm_tdata),
        .s_axis_s2mm_tkeep       (i_axis_s2mm_tkeep),
        .s_axis_s2mm_tlast       (i_axis_s2mm_tlast)
    );

    /****************************************** core_mem_itf ******************************************/

    /**************************************** prefetch_buffer ****************************************/
    prefetch_buf #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .MM2S_TAG_WIDTH(MM2S_TAG_WIDTH)
    ) prefetch_buf_inst (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .status                   (prebuf_status),
        .layer_proc_status        (updt_proc_sts),
        // input axis_itf2buf
        .s_axis_itf2buf_tready    (i_axis_mm2s_tready),
        .s_axis_itf2buf_tvalid    (i_axis_mm2s_tvalid),
        .s_axis_itf2buf_tdata     (i_axis_mm2s_tdata),
        .s_axis_itf2buf_tkeep     (i_axis_mm2s_tkeep),
        .s_axis_itf2buf_tlast     (i_axis_mm2s_tlast),
        .s_axis_itf2buf_tdest     (i_axis_mm2s_tdest),
        // input axis_itf2buf_tag
        .s_axis_itf2buf_tag_tready(i_axis_mm2s_tag_tready),
        .s_axis_itf2buf_tag_tvalid(i_axis_mm2s_tag_tvalid),
        .s_axis_itf2buf_tag_tdata (i_axis_mm2s_tag_tdata),
        .s_axis_itf2buf_tag_tkeep (i_axis_mm2s_tag_tkeep),
        .s_axis_itf2buf_tag_tlast (i_axis_mm2s_tag_tlast),
        .s_axis_itf2buf_tag_tdest (i_axis_mm2s_tag_tdest),
        // output axis_buf2int
        .m_axis_buf2int_tready    (i_axis_buf2int_tready),
        .m_axis_buf2int_tvalid    (i_axis_buf2int_tvalid),
        .m_axis_buf2int_tdata     (i_axis_buf2int_tdata),
        .m_axis_buf2int_tkeep     (i_axis_buf2int_tkeep),
        .m_axis_buf2int_tlast     (i_axis_buf2int_tlast),
        .m_axis_buf2int_tdest     (i_axis_buf2int_tdest),
        // output axis_buf2int_tag
        .m_axis_buf2int_tag_tready(i_axis_buf2int_tag_tready),
        .m_axis_buf2int_tag_tvalid(i_axis_buf2int_tag_tvalid),
        .m_axis_buf2int_tag_tdata (i_axis_buf2int_tag_tdata),
        .m_axis_buf2int_tag_tkeep (i_axis_buf2int_tag_tkeep),
        .m_axis_buf2int_tag_tlast (i_axis_buf2int_tag_tlast),
        .m_axis_buf2int_tag_tdest (i_axis_buf2int_tag_tdest)
    );
    /**************************************** prefetch_buffer ****************************************/

    /**************************************** axis_interconnect ****************************************/
    axis_interconnect #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .MM2S_TAG_WIDTH(MM2S_TAG_WIDTH)
    ) axis_interconnect_inst (
        // common signals
        .clk                      (clk),
        .rst_n                    (rst_n),
        // input axis_buf2int
        .s_axis_buf2int_tready    (i_axis_buf2int_tready),
        .s_axis_buf2int_tvalid    (i_axis_buf2int_tvalid),
        .s_axis_buf2int_tdata     (i_axis_buf2int_tdata),
        .s_axis_buf2int_tkeep     (i_axis_buf2int_tkeep),
        .s_axis_buf2int_tlast     (i_axis_buf2int_tlast),
        .s_axis_buf2int_tdest     (i_axis_buf2int_tdest),
        // input axis_buf2int_tag
        .s_axis_buf2int_tag_tready(i_axis_buf2int_tag_tready),
        .s_axis_buf2int_tag_tvalid(i_axis_buf2int_tag_tvalid),
        .s_axis_buf2int_tag_tdata (i_axis_buf2int_tag_tdata),
        .s_axis_buf2int_tag_tkeep (i_axis_buf2int_tag_tkeep),
        .s_axis_buf2int_tag_tlast (i_axis_buf2int_tag_tlast),
        .s_axis_buf2int_tag_tdest (i_axis_buf2int_tag_tdest),
        // output axis_int2pe (for act and w)
        .m_axis_int2pe_tready     (i_axis_int2pe_tready),
        .m_axis_int2pe_tvalid     (i_axis_int2pe_tvalid),
        .m_axis_int2pe_tdata      (i_axis_int2pe_tdata),
        .m_axis_int2pe_tkeep      (i_axis_int2pe_tkeep),
        .m_axis_int2pe_tlast      (i_axis_int2pe_tlast),
        // output axis_int2pe_tag (for act and w)
        .m_axis_int2pe_tag_tready (i_axis_int2pe_tag_tready),
        .m_axis_int2pe_tag_tvalid (i_axis_int2pe_tag_tvalid),
        .m_axis_int2pe_tag_tdata  (i_axis_int2pe_tag_tdata),
        .m_axis_int2pe_tag_tkeep  (i_axis_int2pe_tag_tkeep),
        .m_axis_int2pe_tag_tlast  (i_axis_int2pe_tag_tlast),
        // output axis_int2bn (only for bn)
        .m_axis_int2bn_tready     (i_axis_int2bn_tready),
        .m_axis_int2bn_tvalid     (i_axis_int2bn_tvalid),
        .m_axis_int2bn_tdata      (i_axis_int2bn_tdata),
        .m_axis_int2bn_tkeep      (i_axis_int2bn_tkeep),
        .m_axis_int2bn_tlast      (i_axis_int2bn_tlast),
        // output axis_int2bn_tag (only for bn)
        .m_axis_int2bn_tag_tready (i_axis_int2bn_tag_tready),
        .m_axis_int2bn_tag_tvalid (i_axis_int2bn_tag_tvalid),
        .m_axis_int2bn_tag_tdata  (i_axis_int2bn_tag_tdata),
        .m_axis_int2bn_tag_tkeep  (i_axis_int2bn_tag_tkeep),
        .m_axis_int2bn_tag_tlast  (i_axis_int2bn_tag_tlast),
        // output axis_int2res (only for res adder)
        .m_axis_int2res_tready    (i_axis_int2res_tready),
        .m_axis_int2res_tvalid    (i_axis_int2res_tvalid),
        .m_axis_int2res_tdata     (i_axis_int2res_tdata),
        .m_axis_int2res_tkeep     (i_axis_int2res_tkeep),
        .m_axis_int2res_tlast     (i_axis_int2res_tlast),
        // output axis_int2res_tag (only for res adder)
        .m_axis_int2res_tag_tready(i_axis_int2res_tag_tready),
        .m_axis_int2res_tag_tvalid(i_axis_int2res_tag_tvalid),
        .m_axis_int2res_tag_tdata (i_axis_int2res_tag_tdata),
        .m_axis_int2res_tag_tkeep (i_axis_int2res_tag_tkeep),
        .m_axis_int2res_tag_tlast (i_axis_int2res_tag_tlast)
    );
    /**************************************** axis_interconnect ****************************************/

    /********************************************* pe array *********************************************/
    pe_array #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .MM2S_TAG_WIDTH(MM2S_TAG_WIDTH),
        .CORE_INSTR_WIDTH(CORE_INSTR_WIDTH),
        .PE_UPDT_DATA_WIDTH(PE_UPDT_DATA_WIDTH)
    ) pe_array_inst (
        // common signal
        .clk                     (clk),
        .rst_n                   (rst_n),
        .status                  (pe_array_status),
        // input axis updt instruction
        .s_axis_updt_instr_tready(i_axis_updt_instr_tready),
        .s_axis_updt_instr_tvalid(i_axis_updt_instr_tvalid),
        .s_axis_updt_instr_tdata (i_axis_updt_instr_tdata),
        // input axis exec instruction
        .s_axis_exec_instr_tready(i_axis_exec_instr_tready),
        .s_axis_exec_instr_tvalid(i_axis_exec_instr_tvalid),
        .s_axis_exec_instr_tdata (i_axis_exec_instr_tdata),
        // input axis wb instruction
        .s_axis_wb_instr_tready  (i_axis_wb_instr_tready),
        .s_axis_wb_instr_tvalid  (i_axis_wb_instr_tvalid),
        .s_axis_wb_instr_tdata   (i_axis_wb_instr_tdata),
        // input axis update data
        .s_axis_int2pe_tready    (i_axis_int2pe_tready),
        .s_axis_int2pe_tvalid    (i_axis_int2pe_tvalid),
        .s_axis_int2pe_tdata     (i_axis_int2pe_tdata),
        .s_axis_int2pe_tkeep     (i_axis_int2pe_tkeep),
        .s_axis_int2pe_tlast     (i_axis_int2pe_tlast),
        // input axis update tag
        .s_axis_int2pe_tag_tready(i_axis_int2pe_tag_tready),
        .s_axis_int2pe_tag_tvalid(i_axis_int2pe_tag_tvalid),
        .s_axis_int2pe_tag_tdata (i_axis_int2pe_tag_tdata),
        .s_axis_int2pe_tag_tkeep (i_axis_int2pe_tag_tkeep),
        .s_axis_int2pe_tag_tlast (i_axis_int2pe_tag_tlast),
        // input axis bn data
        .s_axis_int2bn_tready    (i_axis_int2bn_tready),
        .s_axis_int2bn_tvalid    (i_axis_int2bn_tvalid),
        .s_axis_int2bn_tdata     (i_axis_int2bn_tdata),
        .s_axis_int2bn_tkeep     (i_axis_int2bn_tkeep),
        .s_axis_int2bn_tlast     (i_axis_int2bn_tlast),
        // input axis bn tag
        .s_axis_int2bn_tag_tready(i_axis_int2bn_tag_tready),
        .s_axis_int2bn_tag_tvalid(i_axis_int2bn_tag_tvalid),
        .s_axis_int2bn_tag_tdata (i_axis_int2bn_tag_tdata),
        .s_axis_int2bn_tag_tkeep (i_axis_int2bn_tag_tkeep),
        .s_axis_int2bn_tag_tlast (i_axis_int2bn_tag_tlast),
        // output axis wb data               
        .m_axis_pe2lc_tready     (i_axis_pe2lc_tready),
        .m_axis_pe2lc_tvalid     (i_axis_pe2lc_tvalid),
        .m_axis_pe2lc_tdata      (i_axis_pe2lc_tdata),
        .m_axis_pe2lc_tkeep      (i_axis_pe2lc_tkeep),
        .m_axis_pe2lc_tlast      (i_axis_pe2lc_tlast),
        // output axis wb_fb
        .m_axis_eolfb_tready     (i_axis_eolfb_tready),
        .m_axis_eolfb_tvalid     (i_axis_eolfb_tvalid),
        .m_axis_eolfb_tdata      (i_axis_eolfb_tdata),
        .updt_status             (updt_proc_sts)
    );
    /********************************************* pe array *********************************************/

    /***************************************** layout converter *****************************************/
    layout_converter lc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .ap_start(ap_start),
        .s_axis_lc_instr_tready(i_axis_lc_instr_tready),
        .s_axis_lc_instr_tvalid(i_axis_lc_instr_tvalid),
        .s_axis_lc_instr_tdata(i_axis_lc_instr_tdata),
        .s_axis_pe2lc_tready(i_axis_pe2lc_tready),
        .s_axis_pe2lc_tvalid(i_axis_pe2lc_tvalid),
        .s_axis_pe2lc_tdata(i_axis_pe2lc_tdata),
        .s_axis_pe2lc_tkeep(i_axis_pe2lc_tkeep),
        .s_axis_pe2lc_tlast(i_axis_pe2lc_tlast),
        .m_axis_lc2res_tready(i_axis_lc2res_tready),
        .m_axis_lc2res_tvalid(i_axis_lc2res_tvalid),
        .m_axis_lc2res_tdata(i_axis_lc2res_tdata),
        .m_axis_lc2res_tkeep(i_axis_lc2res_tkeep),
        .m_axis_lc2res_tlast(i_axis_lc2res_tlast),
        .m_axis_lc2res_tuser(i_axis_lc2res_tuser)
    );
    /***************************************** layout converter *****************************************/

    /****************************************** residual adder ******************************************/
    res_adder #(
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .ABUF_DATA_WIDTH(8)
    ) res_adder_inst (
        // common signals
        .clk                    (clk),
        .rst_n                  (rst_n),
        .status                 (res_adder_status),
        // instructions (only 1-bit now)
        .s_axis_res_instr_tready(i_axis_res_instr_tready),
        .s_axis_res_instr_tvalid(i_axis_res_instr_tvalid),
        .s_axis_res_instr_tdata (i_axis_res_instr_tdata),
        // input fout data stream
        .s_axis_lc2res_tready   (i_axis_lc2res_tready),
        .s_axis_lc2res_tvalid   (i_axis_lc2res_tvalid),
        .s_axis_lc2res_tdata    (i_axis_lc2res_tdata),
        .s_axis_lc2res_tkeep    (i_axis_lc2res_tkeep),
        .s_axis_lc2res_tlast    (i_axis_lc2res_tlast),
        .s_axis_lc2res_tuser    (i_axis_lc2res_tuser),
        // input residual data stream
        .s_axis_int2res_tready  (i_axis_int2res_tready),
        .s_axis_int2res_tvalid  (i_axis_int2res_tvalid),
        .s_axis_int2res_tdata   (i_axis_int2res_tdata),
        .s_axis_int2res_tkeep   (i_axis_int2res_tkeep),
        .s_axis_int2res_tlast   (i_axis_int2res_tlast),
        // output results data stream
        .m_axis_res2ac_tready   (i_axis_res2ac_tready),
        .m_axis_res2ac_tvalid   (i_axis_res2ac_tvalid),
        .m_axis_res2ac_tdata    (i_axis_res2ac_tdata),
        .m_axis_res2ac_tkeep    (i_axis_res2ac_tkeep),
        .m_axis_res2ac_tlast    (i_axis_res2ac_tlast)
    );

    /****************************************** residual adder ******************************************/

    /***************************************** activation module *****************************************/
    acti_unit #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) acti_unit_inst (
        // common signals
        .clk                 (clk),
        .rst_n               (rst_n),
        // input axis res2ac
        .s_axis_res2ac_tready(i_axis_res2ac_tready),
        .s_axis_res2ac_tvalid(i_axis_res2ac_tvalid),
        .s_axis_res2ac_tdata (i_axis_res2ac_tdata),
        .s_axis_res2ac_tkeep (i_axis_res2ac_tkeep),
        .s_axis_res2ac_tlast (i_axis_res2ac_tlast),
        // output axis ac2mem
        .m_axis_ac2mem_tready(i_axis_ac2mem_tready),
        .m_axis_ac2mem_tvalid(i_axis_ac2mem_tvalid),
        .m_axis_ac2mem_tdata (i_axis_ac2mem_tdata),
        .m_axis_ac2mem_tkeep (i_axis_ac2mem_tkeep),
        .m_axis_ac2mem_tlast (i_axis_ac2mem_tlast)
    );
    /***************************************** activation module *****************************************/

    /*********************************************** s2mm ***********************************************/
    always_comb begin
        i_axis_s2mm_tvalid   = i_axis_ac2mem_tvalid;
        i_axis_s2mm_tdata    = i_axis_ac2mem_tdata;
        i_axis_s2mm_tkeep    = i_axis_ac2mem_tkeep;
        i_axis_s2mm_tlast    = i_axis_ac2mem_tlast;
        i_axis_ac2mem_tready = i_axis_s2mm_tready;
    end
    /*********************************************** s2mm ***********************************************/

endmodule
