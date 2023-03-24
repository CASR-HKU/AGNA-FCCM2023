`timescale 1ns / 1ps

`include "def.sv"

module mm2s_tag_match #(
    parameter AXI_DATA_WIDTH = `DFLT_CORE_AXI_DATA_WIDTH,
    parameter MM2S_TAG_WIDTH = `DFLT_MEM_TAG_WIDTH
) (
    input  logic                        clk,
    input  logic                        rst_n,
    // input axis_mm2s
    output logic                        s_axis_mm2s_tready,
    input  logic                        s_axis_mm2s_tvalid,
    input  logic [  AXI_DATA_WIDTH-1:0] s_axis_mm2s_tdata,
    input  logic [AXI_DATA_WIDTH/8-1:0] s_axis_mm2s_tkeep,
    input  logic                        s_axis_mm2s_tlast,
    // input axis_mm2s_tag
    output logic                        s_axis_mm2s_tag_tready,
    input  logic                        s_axis_mm2s_tag_tvalid,
    input  logic [  MM2S_TAG_WIDTH-1:0] s_axis_mm2s_tag_tdata,
    input  logic [MM2S_TAG_WIDTH/8-1:0] s_axis_mm2s_tag_tkeep,
    input  logic                        s_axis_mm2s_tag_tlast,
    // in the future we may need status for out-of-order
    // output axis_mm2s
    input  logic                        m_axis_mm2s_tready,
    output logic                        m_axis_mm2s_tvalid,
    output logic [  AXI_DATA_WIDTH-1:0] m_axis_mm2s_tdata,
    output logic [AXI_DATA_WIDTH/8-1:0] m_axis_mm2s_tkeep,
    output logic                        m_axis_mm2s_tlast,
    output logic [                 1:0] m_axis_mm2s_tdest,
    // output axis_mm2s_tag
    input  logic                        m_axis_mm2s_tag_tready,
    output logic                        m_axis_mm2s_tag_tvalid,
    output logic [  MM2S_TAG_WIDTH-1:0] m_axis_mm2s_tag_tdata,
    output logic [MM2S_TAG_WIDTH/8-1:0] m_axis_mm2s_tag_tkeep,
    output logic                        m_axis_mm2s_tag_tlast,
    output logic [                 1:0] m_axis_mm2s_tag_tdest
);

    // for now, what we need is only a fifo for tag stream because of in-order
    logic [MM2S_TAG_WIDTH-1:0] i_axis_mm2s_tag_tdata;
    logic i_axis_mm2s_tag_tready, i_axis_mm2s_tag_tvalid;
    fifo_axis #(
        .FIFO_AXIS_DEPTH(64),
        .FIFO_AXIS_TDATA_WIDTH(MM2S_TAG_WIDTH)
    ) mm2s_tag_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tready(i_axis_mm2s_tag_tready),
        .m_axis_tvalid(i_axis_mm2s_tag_tvalid),
        .m_axis_tdata(i_axis_mm2s_tag_tdata),
        .s_axis_tready(s_axis_mm2s_tag_tready),
        .s_axis_tvalid(s_axis_mm2s_tag_tvalid),
        .s_axis_tdata(s_axis_mm2s_tag_tdata),
        .s_axis_tkeep(8'b1111_1111),
        .s_axis_tlast(1'b0)
    );

    // match
    logic i_axis_mm2s_tag_hs, m_axis_mm2s_tag_hs;
    assign i_axis_mm2s_tag_hs = i_axis_mm2s_tag_tready & i_axis_mm2s_tag_tvalid;
    assign m_axis_mm2s_tag_hs = m_axis_mm2s_tag_tready & m_axis_mm2s_tag_tvalid;

    logic tag_received;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            tag_received <= 1'b0;
        end else if (s_axis_mm2s_tlast & s_axis_mm2s_tvalid & s_axis_mm2s_tready) begin
            tag_received <= 1'b0;
        end else if (i_axis_mm2s_tag_hs) begin
            tag_received <= 1'b1;
        end
    end

    logic m_tag_out_en;
    always_comb begin
        m_tag_out_en = i_axis_mm2s_tag_hs & ((~m_axis_mm2s_tag_tvalid) | m_axis_mm2s_tag_tready);
    end

    logic m_axis_mm2s_tag_tvalid_r;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            m_axis_mm2s_tag_tvalid_r <= 1'b0;
        end else if (m_axis_mm2s_tag_hs & (~m_tag_out_en)) begin
            m_axis_mm2s_tag_tvalid_r <= 1'b0;
        end else if (m_tag_out_en) begin
            m_axis_mm2s_tag_tvalid_r <= 1'b1;
        end
    end

    always_comb begin
        i_axis_mm2s_tag_tready = (~tag_received) & m_axis_mm2s_tag_tready;
        m_axis_mm2s_tag_tvalid = m_axis_mm2s_tag_tvalid_r;
    end

    always_ff @(posedge clk) begin
        if (m_tag_out_en) begin
            m_axis_mm2s_tag_tdata <= i_axis_mm2s_tag_tdata;
        end
    end

    // tag_btd
    // logic  [3:0] bytes_to_drop;
    // always_ff @( posedge clk ) begin
    //     if (~rst_n) begin
    //         bytes_to_drop <= 4'b0000;
    //     end
    //     else if (i_axis_mm2s_tag_hs) begin
    //         bytes_to_drop <= i_axis_mm2s_tag_tdata[53:50];
    //     end
    // end

    // stream destination
    logic [1:0] tag_data_type;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            tag_data_type <= 2'b00;
        end else if (i_axis_mm2s_tag_hs) begin
            tag_data_type <= i_axis_mm2s_tag_tdata[62:61];
        end
    end

    // tkeep in the last transfer
    // logic  [AXI_DATA_WIDTH/8-1:0] m_axis_mm2s_tkeep_last;
    // always_comb begin
    //     case (bytes_to_drop)
    //         4'b0000: m_axis_mm2s_tkeep_last = 16'hffff;
    //         4'b0001: m_axis_mm2s_tkeep_last = 16'h7fff;
    //         4'b0010: m_axis_mm2s_tkeep_last = 16'h3fff;
    //         4'b0011: m_axis_mm2s_tkeep_last = 16'h1fff;
    //         4'b0100: m_axis_mm2s_tkeep_last = 16'h0fff;
    //         4'b0101: m_axis_mm2s_tkeep_last = 16'h07ff;
    //         4'b0110: m_axis_mm2s_tkeep_last = 16'h03ff;
    //         4'b0111: m_axis_mm2s_tkeep_last = 16'h01ff;
    //         4'b1000: m_axis_mm2s_tkeep_last = 16'h00ff;
    //         4'b1001: m_axis_mm2s_tkeep_last = 16'h007f;
    //         4'b1010: m_axis_mm2s_tkeep_last = 16'h003f;
    //         4'b1011: m_axis_mm2s_tkeep_last = 16'h001f;
    //         4'b1100: m_axis_mm2s_tkeep_last = 16'h000f;
    //         4'b1101: m_axis_mm2s_tkeep_last = 16'h0007;
    //         4'b1110: m_axis_mm2s_tkeep_last = 16'h0003;
    //         4'b1111: m_axis_mm2s_tkeep_last = 16'h0001;
    //         default: m_axis_mm2s_tkeep_last = 16'hffff;
    //     endcase
    // end

    // passthrough input stream to output stream
    // drop the tkeep according to BTD in tags
    // need to be modified in the future to support out-of-order
    always_comb begin
        s_axis_mm2s_tready = m_axis_mm2s_tready;
        m_axis_mm2s_tvalid = s_axis_mm2s_tvalid;
        m_axis_mm2s_tdata  = s_axis_mm2s_tdata;
        m_axis_mm2s_tlast  = s_axis_mm2s_tlast;
        // if (s_axis_mm2s_tlast) begin
        //     // m_axis_mm2s_tkeep_last works as "gate"
        //     m_axis_mm2s_tkeep = s_axis_mm2s_tkeep & m_axis_mm2s_tkeep_last;
        // end    
        // else m_axis_mm2s_tkeep = s_axis_mm2s_tkeep;
        m_axis_mm2s_tkeep  = s_axis_mm2s_tkeep;
    end

    always_comb begin
        m_axis_mm2s_tdest       =   ((tag_data_type == 2'b00)|(tag_data_type == 2'b01))?2'b00:
                                    (tag_data_type == 2'b11)?2'b01:2'b10;
        m_axis_mm2s_tag_tdest   =   ((tag_data_type == 2'b00)|(tag_data_type == 2'b01))?2'b00:
                                    (tag_data_type == 2'b11)?2'b01:2'b10;
    end

    assign m_axis_mm2s_tag_tkeep = 8'b1111_1111;
    assign m_axis_mm2s_tag_tlast = 1'b0;

endmodule
