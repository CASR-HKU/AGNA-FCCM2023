`timescale 1ns/1ps

`include "def.sv"

module acti_unit #(
    parameter AXI_DATA_WIDTH        =   `DFLT_CORE_AXI_DATA_WIDTH
) (
    // common signals
    input  logic                            clk                         ,
    input  logic                            rst_n                       ,
    // input axis res2ac
    output logic                            s_axis_res2ac_tready        ,
    input  logic                            s_axis_res2ac_tvalid        ,
    input  logic [AXI_DATA_WIDTH-1:0]       s_axis_res2ac_tdata         ,
    input  logic [AXI_DATA_WIDTH/8-1:0]     s_axis_res2ac_tkeep         ,
    input  logic                            s_axis_res2ac_tlast         ,
    // output axis ac2mem
    input  logic                            m_axis_ac2mem_tready        ,
    output logic                            m_axis_ac2mem_tvalid        ,
    output logic [AXI_DATA_WIDTH-1:0]       m_axis_ac2mem_tdata         ,
    output logic [AXI_DATA_WIDTH/8-1:0]     m_axis_ac2mem_tkeep         ,
    output logic                            m_axis_ac2mem_tlast        
);
    // only supports 8-bit optimization now
    logic signed [7:0] act_in   [AXI_DATA_WIDTH/8-1:0];
    logic signed [7:0] act_out  [AXI_DATA_WIDTH/8-1:0];

    // only implement relu function now
    logic ac_en;
    genvar byte_idx;
    generate
        for (byte_idx = 0; byte_idx < AXI_DATA_WIDTH/8; byte_idx ++) begin
            always_ff @( posedge clk ) begin
                if (~rst_n) begin
                    act_out[byte_idx] <= 0;
                end
                // else if (ac_en) begin
                //     if (~act_in[byte_idx][7]) act_out[byte_idx] <= act_in[byte_idx];
                //     else act_out[byte_idx] <= act_in[byte_idx] - 1;
                // end
                // for debugging, we ignore activation
                else begin
                    act_out[byte_idx] <= act_in[byte_idx];
                end
            end
            always_comb begin
                act_in[byte_idx] = s_axis_res2ac_tdata[(byte_idx+1)*8-1:8*byte_idx];
                m_axis_ac2mem_tdata[(byte_idx+1)*8-1:8*byte_idx] = act_out[byte_idx];
            end
        end
    endgenerate
    
    always_comb begin
        s_axis_res2ac_tready = m_axis_ac2mem_tready;
    end

    // control of tvalid
    assign ac_en = s_axis_res2ac_tready & s_axis_res2ac_tvalid & (~m_axis_ac2mem_tvalid|(m_axis_ac2mem_tready));
    always_ff @( posedge clk ) begin
        if (~rst_n) begin
            m_axis_ac2mem_tvalid <= 1'b0;
        end
        else if (m_axis_ac2mem_tvalid&m_axis_ac2mem_tready&(~ac_en)) begin
            m_axis_ac2mem_tvalid <= 1'b0;
        end
        else if (ac_en) begin
            m_axis_ac2mem_tvalid <= 1'b1;
        end
    end

    always_ff @( posedge clk ) begin
        if (~rst_n) begin
            m_axis_ac2mem_tkeep <= 16'd0;
            m_axis_ac2mem_tlast <= 1'b0;
        end
        else if (ac_en) begin
            m_axis_ac2mem_tkeep <= s_axis_res2ac_tkeep;
            m_axis_ac2mem_tlast <= s_axis_res2ac_tlast;
        end
    end

endmodule