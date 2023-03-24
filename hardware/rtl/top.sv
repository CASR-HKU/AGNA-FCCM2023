`timescale 1ns / 1ps

`include "def.sv"

module top #(
    parameter PS_CTRL_AXI_ADDR_WIDTH = `DFLT_PS_CTRL_AXI_ADDR_WIDTH,
    parameter PS_CTRL_AXI_DATA_WIDTH = `DFLT_PS_CTRL_AXI_DATA_WIDTH,
    parameter AUX_AXI_ADDR_WIDTH     = `DFLT_AUX_AXI_ADDR_WIDTH,
    parameter AUX_AXI_DATA_WIDTH     = `DFLT_AUX_AXI_DATA_WIDTH,
    parameter CORE_AXI_ADDR_WIDTH    = `DFLT_CORE_AXI_ADDR_WIDTH,
    parameter CORE_AXI_DATA_WIDTH    = `DFLT_CORE_AXI_DATA_WIDTH
) (
    // common signal
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

    /***************************************** PS control *****************************************/
    logic ap_start, ap_done, ap_idle, ap_ready;
    logic [31:0] aux_instr_scalar, aux_instr_status, aux_debug_scalar, aux_debug_status;
    logic [63:0] aux_instr_addr, aux_debug_addr;
    logic [                   3:0][31:0] core_scalar;
    logic [                  10:0][31:0] core_status;

    // instructions from aux to agna core
    logic                                i_axis_instr_tready;
    logic                                i_axis_instr_tvalid;
    logic [AUX_AXI_DATA_WIDTH-1:0]       i_axis_instr_tdata;

    // two ap_done sync
    logic aux_ap_start, core_ap_start;

    logic aux_ap_done, core_ap_done;
    logic aux_ap_sync, core_ap_sync;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            aux_ap_sync <= 1'b0;
        end else if (aux_ap_sync & core_ap_sync) begin
            aux_ap_sync <= 1'b0;
        end else if (aux_ap_done) begin
            aux_ap_sync <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            core_ap_sync <= 1'b0;
        end else if (aux_ap_sync & core_ap_sync) begin
            core_ap_sync <= 1'b0;
        end else if (core_ap_done) begin
            core_ap_sync <= 1'b1;
        end
    end

    always_comb begin
        ap_done = aux_ap_sync & core_ap_sync;
    end

    // always_comb begin
    //     aux_ap_start = ap_start & (~aux_ap_sync);
    //     core_ap_start = ap_start & (~core_ap_sync);
    // end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            aux_debug_status <= 32'h0;
        end else begin
            aux_debug_status[7:0]   <= (core_ap_start&core_ap_done) ? aux_debug_status[7:0]+1 : aux_debug_status[7:0];
            aux_debug_status[15:8]  <= (aux_ap_start&aux_ap_done)  ? aux_debug_status[15:8]+1 : aux_debug_status[15:8];
            aux_debug_status[31:16] <= (ap_start&ap_done)      ? aux_debug_status[31:16]+1 : aux_debug_status[31:16];
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            aux_ap_start <= 1'b0;
        end else if (aux_ap_done) begin
            aux_ap_start <= 1'b0;
        end else if (ap_start & (~aux_ap_sync)) begin
            aux_ap_start <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            core_ap_start <= 1'b0;
        end else if (core_ap_done) begin
            core_ap_start <= 1'b0;
        end else if (ap_start & (~core_ap_sync)) begin
            core_ap_start <= 1'b1;
        end
    end

`ifdef PS_CTRL_ENABLE
    ps_ctrl ps_ctrl_inst (
        // common signal
        .clk                  (clk),
        .rst_n                (rst_n),
        .clk_en               (1'b1),
        .interrupt            (interrupt),
        // s_axi_control, AXI4-Lite slave
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
        // ps_control signal
        .ap_start             (ap_start),
        .ap_done              (ap_done),
        .ap_idle              (ap_idle),
        .ap_ready             (ap_ready),
        .aux_instr_scalar     (aux_instr_scalar),
        .aux_instr_addr       (aux_instr_addr),
        .aux_instr_status     (aux_instr_status),
        .aux_debug_scalar     (aux_debug_scalar),
        .aux_debug_addr       (aux_debug_addr),
        .aux_debug_status     (aux_debug_status),
        .core_scalar          (core_scalar),
        .core_status          (core_status)
    );
`else
    always_comb begin
        // fake ps_control signal
        ap_start = 0;
        ap_done = 0;
        ap_idle = 0;
        ap_ready = 0;
        aux_instr_scalar = 32'hBEEF_AAAA;
        aux_instr_addr = 64'h0000_0000_CAFE_A000;
        aux_debug_scalar = 32'hBEEF_BBBB;
        aux_debug_addr = 64'h0000_0000_CAFE_B000;
        core_scalar = 'b0;
    end
`endif
    /***************************************** PS control *****************************************/

    /****************************************** anga aux ******************************************/
    agna_aux_0 agna_aux_inst (
        .ap_local_block    (aux_instr_status[0]),     // output wire ap_local_block
        .ap_local_deadlock (aux_instr_status[1]),     // output wire ap_local_deadlock
        .ap_clk            (clk),                     // input wire ap_clk
        .ap_rst_n          (rst_n),                   // input wire ap_rst_n
        .ap_start          (aux_ap_start),            // input wire ap_start
        .ap_done           (aux_ap_done),             // output wire ap_done
        .ap_idle           (ap_idle),                 // output wire ap_idle
        .ap_ready          (ap_ready),                // output wire ap_ready
        .m_axi_aux_AWREADY (m_axi_aux_awready),       // input wire m_axi_aux_AWREADY
        .m_axi_aux_AWVALID (m_axi_aux_awvalid),       // output wire m_axi_aux_AWVALID
        .m_axi_aux_AWADDR  (m_axi_aux_awaddr),        // output wire [63 : 0] m_axi_aux_AWADDR
        .m_axi_aux_AWLEN   (m_axi_aux_awlen),         // output wire [7 : 0] m_axi_aux_AWLEN
        .m_axi_aux_AWSIZE  (m_axi_aux_awsize),        // output wire [2 : 0] m_axi_aux_AWSIZE
        .m_axi_aux_AWBURST (m_axi_aux_awburst),       // output wire [1 : 0] m_axi_aux_AWBURST
        .m_axi_aux_AWLOCK  (m_axi_aux_awlock),        // output wire [1 : 0] m_axi_aux_AWLOCK
        .m_axi_aux_AWREGION(m_axi_aux_awregion),      // output wire [3 : 0] m_axi_aux_AWREGION
        .m_axi_aux_AWCACHE (m_axi_aux_awcache),       // output wire [3 : 0] m_axi_aux_AWCACHE
        .m_axi_aux_AWPROT  (m_axi_aux_awprot),        // output wire [2 : 0] m_axi_aux_AWPROT
        .m_axi_aux_AWQOS   (m_axi_aux_awqos),         // output wire [3 : 0] m_axi_aux_AWQOS
        .m_axi_aux_WREADY  (m_axi_aux_wready),        // input wire m_axi_aux_WREADY
        .m_axi_aux_WVALID  (m_axi_aux_wvalid),        // output wire m_axi_aux_WVALID
        .m_axi_aux_WDATA   (m_axi_aux_wdata),         // output wire [127 : 0] m_axi_aux_WDATA
        .m_axi_aux_WSTRB   (m_axi_aux_wstrb),         // output wire [15 : 0] m_axi_aux_WSTRB
        .m_axi_aux_WLAST   (m_axi_aux_wlast),         // output wire m_axi_aux_WLAST
        .m_axi_aux_BREADY  (m_axi_aux_bready),        // output wire m_axi_aux_BREADY
        .m_axi_aux_BVALID  (m_axi_aux_bvalid),        // input wire m_axi_aux_BVALID
        .m_axi_aux_BRESP   (m_axi_aux_bresp),         // input wire [1 : 0] m_axi_aux_BRESP
        .m_axi_aux_ARREADY (m_axi_aux_arready),       // input wire m_axi_aux_ARREADY
        .m_axi_aux_ARVALID (m_axi_aux_arvalid),       // output wire m_axi_aux_ARVALID
        .m_axi_aux_ARADDR  (m_axi_aux_araddr),        // output wire [63 : 0] m_axi_aux_ARADDR
        .m_axi_aux_ARLEN   (m_axi_aux_arlen),         // output wire [7 : 0] m_axi_aux_ARLEN
        .m_axi_aux_ARSIZE  (m_axi_aux_arsize),        // output wire [2 : 0] m_axi_aux_ARSIZE
        .m_axi_aux_ARBURST (m_axi_aux_arburst),       // output wire [1 : 0] m_axi_aux_ARBURST
        .m_axi_aux_ARLOCK  (m_axi_aux_arlock),        // output wire [1 : 0] m_axi_aux_ARLOCK
        .m_axi_aux_ARREGION(m_axi_aux_arregion),      // output wire [3 : 0] m_axi_aux_ARREGION
        .m_axi_aux_ARCACHE (m_axi_aux_arcache),       // output wire [3 : 0] m_axi_aux_ARCACHE
        .m_axi_aux_ARPROT  (m_axi_aux_arprot),        // output wire [2 : 0] m_axi_aux_ARPROT
        .m_axi_aux_ARQOS   (m_axi_aux_arqos),         // output wire [3 : 0] m_axi_aux_ARQOS
        .m_axi_aux_RREADY  (m_axi_aux_rready),        // output wire m_axi_aux_RREADY
        .m_axi_aux_RVALID  (m_axi_aux_rvalid),        // input wire m_axi_aux_RVALID
        .m_axi_aux_RDATA   (m_axi_aux_rdata),         // input wire [127 : 0] m_axi_aux_RDATA
        .m_axi_aux_RRESP   (m_axi_aux_rresp),         // input wire [1 : 0] m_axi_aux_RRESP
        .m_axi_aux_RLAST   (m_axi_aux_rlast),         // input wire m_axi_aux_RLAST
        .instr_base_addr   (aux_instr_addr[31:0]),    // input wire [31 : 0] instr_base_addr
        .instr_num         (aux_instr_scalar[30:0]),  // input wire [31 : 0] instr_num
        // .en_write_test     (aux_instr_scalar[31]),    // input wire en_write_test
        .core_instr_din    (i_axis_instr_tdata),      // output wire [144 : 0] core_instr_din
        .core_instr_full_n (i_axis_instr_tready),     // input wire core_instr_full_n
        .core_instr_write  (i_axis_instr_tvalid)      // output wire core_instr_write
    );
    /****************************************** anga aux ******************************************/

    /***************************************** anga core ******************************************/
    agna_core agna_core_inst (
        // common signal
        .clk                (clk),
        .rst_n              (rst_n),
        // control signal
        .ap_start           (core_ap_start),
        .ap_done            (core_ap_done),
        // .ap_idle                    (ap_idle                ),
        // .ap_ready                   (ap_ready               ),
        .scalar             (core_scalar),
        .instr_num          (aux_instr_scalar[30:0]),
        .status             (core_status),
        // m_axi, AXI4 master
        .m_axi_core_awready (m_axi_core_awready),
        .m_axi_core_awvalid (m_axi_core_awvalid),
        .m_axi_core_awaddr  (m_axi_core_awaddr),
        .m_axi_core_awlen   (m_axi_core_awlen),
        .m_axi_core_awid    (m_axi_core_awid),
        .m_axi_core_awsize  (m_axi_core_awsize),
        .m_axi_core_awburst (m_axi_core_awburst),
        .m_axi_core_awprot  (m_axi_core_awprot),
        .m_axi_core_awcache (m_axi_core_awcache),
        .m_axi_core_awuser  (m_axi_core_awuser),
        .m_axi_core_wready  (m_axi_core_wready),
        .m_axi_core_wvalid  (m_axi_core_wvalid),
        .m_axi_core_wdata   (m_axi_core_wdata),
        .m_axi_core_wstrb   (m_axi_core_wstrb),
        .m_axi_core_wlast   (m_axi_core_wlast),
        .m_axi_core_bready  (m_axi_core_bready),
        .m_axi_core_bvalid  (m_axi_core_bvalid),
        .m_axi_core_bresp   (m_axi_core_bresp),
        .m_axi_core_arready (m_axi_core_arready),
        .m_axi_core_arvalid (m_axi_core_arvalid),
        .m_axi_core_araddr  (m_axi_core_araddr),
        .m_axi_core_arlen   (m_axi_core_arlen),
        .m_axi_core_arid    (m_axi_core_arid),
        .m_axi_core_arsize  (m_axi_core_arsize),
        .m_axi_core_arburst (m_axi_core_arburst),
        .m_axi_core_arprot  (m_axi_core_arprot),
        .m_axi_core_arcache (m_axi_core_arcache),
        .m_axi_core_aruser  (m_axi_core_aruser),
        .m_axi_core_rready  (m_axi_core_rready),
        .m_axi_core_rvalid  (m_axi_core_rvalid),
        .m_axi_core_rdata   (m_axi_core_rdata),
        .m_axi_core_rresp   (m_axi_core_rresp),
        .m_axi_core_rlast   (m_axi_core_rlast),
        // input axis_instr
        .s_axis_instr_tready(i_axis_instr_tready),
        .s_axis_instr_tvalid(i_axis_instr_tvalid),
        .s_axis_instr_tdata (i_axis_instr_tdata)
    );
    /***************************************** anga core ******************************************/

endmodule
