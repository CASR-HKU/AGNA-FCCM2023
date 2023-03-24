`timescale 1ns / 1ps

`include "def.sv"

module res_adder #(
    parameter AXI_DATA_WIDTH  = `DFLT_CORE_AXI_DATA_WIDTH,
    parameter ABUF_DATA_WIDTH = `PARAM_ABUF_DATA_WIDTH
) (
    // common signals
    input  logic                        clk,
    input  logic                        rst_n,
    output logic [                31:0] status,
    // instructions (only 1-bit now)
    output logic                        s_axis_res_instr_tready,
    input  logic                        s_axis_res_instr_tvalid,
    input  logic                        s_axis_res_instr_tdata,   // 0 - no res, 1 - res
    // input fout data stream
    output logic                        s_axis_lc2res_tready,
    input  logic                        s_axis_lc2res_tvalid,
    input  logic [  AXI_DATA_WIDTH-1:0] s_axis_lc2res_tdata,
    input  logic [AXI_DATA_WIDTH/8-1:0] s_axis_lc2res_tkeep,
    input  logic                        s_axis_lc2res_tlast,
    input  logic                        s_axis_lc2res_tuser,
    // input residual data stream
    output logic                        s_axis_int2res_tready,
    input  logic                        s_axis_int2res_tvalid,
    input  logic [  AXI_DATA_WIDTH-1:0] s_axis_int2res_tdata,
    input  logic [AXI_DATA_WIDTH/8-1:0] s_axis_int2res_tkeep,
    input  logic                        s_axis_int2res_tlast,
    // output results data stream
    input  logic                        m_axis_res2ac_tready,
    output logic                        m_axis_res2ac_tvalid,
    output logic [  AXI_DATA_WIDTH-1:0] m_axis_res2ac_tdata,
    output logic [AXI_DATA_WIDTH/8-1:0] m_axis_res2ac_tkeep,
    output logic                        m_axis_res2ac_tlast
);

    logic res_layer_enable;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            res_layer_enable <= 1'b0;
        end else if (s_axis_res_instr_tready & s_axis_res_instr_tvalid) begin
            res_layer_enable <= s_axis_res_instr_tdata;
        end
    end

    logic res_status;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            res_status <= 1'b0;
        end
        else if (s_axis_lc2res_tready & s_axis_lc2res_tvalid & s_axis_lc2res_tlast & s_axis_lc2res_tuser) begin
            res_status <= 1'b0;
        end else if (s_axis_res_instr_tready & s_axis_res_instr_tvalid) begin
            res_status <= 1'b1;
        end
    end

    always_comb begin
        s_axis_res_instr_tready = (~res_status);
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            status <= 32'h0;
        end else begin
            status[31:16] <= (s_axis_lc2res_tready & s_axis_lc2res_tvalid & s_axis_lc2res_tlast & s_axis_lc2res_tuser) ? status[31:16]+1 : status[31:16];
            status[15:0]  <= (s_axis_res_instr_tready & s_axis_res_instr_tvalid) ? status[15:0]+1 : status[15:0];
        end
    end

    // int2res data fifo
    logic                        i_axis_int2res_tready;
    logic                        i_axis_int2res_tvalid;
    logic [  AXI_DATA_WIDTH-1:0] i_axis_int2res_tdata;
    logic [AXI_DATA_WIDTH/8-1:0] i_axis_int2res_tkeep;
    logic                        i_axis_int2res_tlast;
    fifo_axis #(
        .FIFO_AXIS_DEPTH(512),
        .FIFO_AXIS_TDATA_WIDTH(AXI_DATA_WIDTH)
    ) res_data_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tready(i_axis_int2res_tready),
        .m_axis_tvalid(i_axis_int2res_tvalid),
        .m_axis_tdata(i_axis_int2res_tdata),
        .m_axis_tkeep(i_axis_int2res_tkeep),
        .m_axis_tlast(i_axis_int2res_tlast),
        .s_axis_tready(s_axis_int2res_tready),
        .s_axis_tvalid(s_axis_int2res_tvalid),
        .s_axis_tdata(s_axis_int2res_tdata),
        .s_axis_tkeep(s_axis_int2res_tkeep),
        .s_axis_tlast(s_axis_int2res_tlast)
    );

    logic hs_s_axis_lc2res, hs_i_axis_int2res, hs_m_axis_res2ac, both_valid;
    always_comb begin
        both_valid = i_axis_int2res_tvalid & s_axis_lc2res_tvalid;
    end

    always_comb begin
        i_axis_int2res_tready = res_layer_enable & m_axis_res2ac_tready & both_valid;
        s_axis_lc2res_tready    = res_layer_enable ? (m_axis_res2ac_tready & both_valid) : m_axis_res2ac_tready;
    end

    always_comb begin
        hs_i_axis_int2res = i_axis_int2res_tready & i_axis_int2res_tvalid;
        hs_s_axis_lc2res  = s_axis_lc2res_tready & s_axis_lc2res_tvalid;
        hs_m_axis_res2ac  = m_axis_res2ac_tready & m_axis_res2ac_tvalid;
    end

    // res_results = res_data + fout_data (if res_layer_enable)
    logic signed [ABUF_DATA_WIDTH-1:0] res_results[AXI_DATA_WIDTH/8-1:0];
    logic signed [ABUF_DATA_WIDTH-1:0] res_data   [AXI_DATA_WIDTH/8-1:0];
    logic signed [ABUF_DATA_WIDTH-1:0] fout_data  [AXI_DATA_WIDTH/8-1:0];
    logic adder_en_in, adder_en;  // two handshake signals &
    always_comb begin
        adder_en_in = res_layer_enable ? (hs_i_axis_int2res & hs_s_axis_lc2res) : hs_s_axis_lc2res;
    end
    always_comb begin
        adder_en = adder_en_in & (~m_axis_res2ac_tvalid | (m_axis_res2ac_tready));
    end
    logic [AXI_DATA_WIDTH-1:0] m_axis_res2ac_tdata_res;
    logic [AXI_DATA_WIDTH-1:0] m_axis_res2ac_tdata_nor;

    genvar byte_idx;
    generate
        for (byte_idx = 0; byte_idx < AXI_DATA_WIDTH / 8; byte_idx++) begin
            always_comb begin
                res_data[byte_idx]      = i_axis_int2res_tdata[(byte_idx+1)*ABUF_DATA_WIDTH-1:ABUF_DATA_WIDTH*byte_idx];
                fout_data[byte_idx]     = s_axis_lc2res_tdata[(byte_idx+1)*ABUF_DATA_WIDTH-1:ABUF_DATA_WIDTH*byte_idx];
                res_results[byte_idx] = res_data[byte_idx] + fout_data[byte_idx];
            end
            always_ff @(posedge clk) begin
                if (~rst_n) begin
                    m_axis_res2ac_tdata_res[(byte_idx+1)*ABUF_DATA_WIDTH-1:ABUF_DATA_WIDTH*byte_idx] <= 0;
                    m_axis_res2ac_tdata_nor[(byte_idx+1)*ABUF_DATA_WIDTH-1:ABUF_DATA_WIDTH*byte_idx] <= 0;
                end else if (adder_en) begin
                    m_axis_res2ac_tdata_res[(byte_idx+1)*ABUF_DATA_WIDTH-1:ABUF_DATA_WIDTH*byte_idx] <= res_results[byte_idx];
                    m_axis_res2ac_tdata_nor[(byte_idx+1)*ABUF_DATA_WIDTH-1:ABUF_DATA_WIDTH*byte_idx] <= fout_data[byte_idx];
                end
            end
        end
    endgenerate

    always_comb begin
        m_axis_res2ac_tdata = res_layer_enable ? m_axis_res2ac_tdata_res : m_axis_res2ac_tdata_nor;
    end

    // control of tvalid
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            m_axis_res2ac_tvalid <= 1'b0;
        end else if (hs_m_axis_res2ac & (~adder_en)) begin
            m_axis_res2ac_tvalid <= 1'b0;
        end else if (adder_en) begin
            m_axis_res2ac_tvalid <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            m_axis_res2ac_tkeep <= 16'd0;
            m_axis_res2ac_tlast <= 1'b0;
        end else if (adder_en) begin
            m_axis_res2ac_tkeep <= s_axis_lc2res_tkeep;
            m_axis_res2ac_tlast <= s_axis_lc2res_tlast;
        end
    end

endmodule
