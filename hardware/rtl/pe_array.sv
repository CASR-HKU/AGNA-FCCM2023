`timescale 1ns / 1ps

`include "def.sv"

(* keep_hierarchy = "yes" *) module pe_array #(
    parameter AXI_DATA_WIDTH       = `DFLT_CORE_AXI_DATA_WIDTH,
    parameter MM2S_TAG_WIDTH       = `DFLT_MEM_TAG_WIDTH,
    parameter CORE_INSTR_WIDTH     = `DFLT_CORE_INSTR_WIDTH,
    parameter PE_UPDT_DATA_WIDTH   = `DFLT_PE_UPDT_DATA_WIDTH,
    parameter BN_UPDT_DATA_WIDTH   = `DFLT_BN_UPDT_DATA_WIDTH,
    parameter PE_LC_DATA_WIDTH     = `PARAM_PE_LC_DATA_WIDTH,
    parameter PARAM_PE_NUM         = `HW_CONFIG_PE_NUM,
    parameter ABUF_NUM             = `PARAM_ABUF_NUM,
    parameter BRAM_NUM_PER_ABUF    = `PARAM_BRAM_NUM_PER_ABUF,
    parameter ABUF_UPDT_ADDR_WIDTH = (`PARAM_ABUF_ADDR_WIDTH - 2),
    parameter ABUF_EXEC_ADDR_WIDTH = `PARAM_ABUF_ADDR_WIDTH,
    parameter ABUF_DATA_WIDTH      = `PARAM_ABUF_DATA_WIDTH,
    parameter WBUF_NUM             = `PARAM_WBUF_NUM,
    parameter BRAM_NUM_PER_WBUF    = `PARAM_BRAM_NUM_PER_WBUF,
    parameter WBUF_UPDT_ADDR_WIDTH = (`PARAM_WBUF_ADDR_WIDTH - 2),
    parameter WBUF_EXEC_ADDR_WIDTH = `PARAM_WBUF_ADDR_WIDTH,
    parameter WBUF_DATA_WIDTH      = `PARAM_WBUF_DATA_WIDTH,
    parameter PBUF_NUM             = `PARAM_PBUF_NUM,
    parameter BRAM_NUM_PER_PBUF    = `PARAM_BRAM_NUM_PER_PBUF,
    parameter PBUF_ADDR_WIDTH      = `PARAM_PBUF_ADDR_WIDTH,
    parameter PBUF_DATA_WIDTH      = `PARAM_PBUF_DATA_WIDTH,
    parameter PBUF_DATA_NUM        = `PARAM_PBUF_DATA_NUM,
    parameter RF_NUM               = `PARAM_RF_NUM,
    parameter RF_NUM_PER_ABUF      = `PARAM_RF_NUM_PER_ABUF,
    parameter RF_ADDR_WIDTH        = `PARAM_RF_ADDR_WIDTH,
    parameter RF_DATA_WIDTH        = `PARAM_RF_DATA_WIDTH,
    parameter BN_DATA_WIDTH        = `PARAM_BNBUF_DATA_WIDTH,
    parameter BN_ADDR_WIDTH        = `PARAM_BNBUF_ADDR_WIDTH,
    parameter PARAM_A_K            = `HW_CONFIG_A_K,
    parameter PARAM_A_C            = `HW_CONFIG_A_C,
    parameter PARAM_A_H            = `HW_CONFIG_A_H,
    parameter PARAM_A_W            = `HW_CONFIG_A_W,
    parameter PARAM_A_I            = `HW_CONFIG_A_I,
    parameter PARAM_A_J            = `HW_CONFIG_A_J
) (
    // common signal
    input  logic                                  clk,
    input  logic                                  rst_n,
    // variable signal
    output logic [                     3:0][31:0] status,
    // input axis updt instruction
    output logic                                  s_axis_updt_instr_tready,
    input  logic                                  s_axis_updt_instr_tvalid,
    input  logic [    CORE_INSTR_WIDTH-1:0]       s_axis_updt_instr_tdata,
    // input axis exec instruction
    output logic                                  s_axis_exec_instr_tready,
    input  logic                                  s_axis_exec_instr_tvalid,
    input  logic [    CORE_INSTR_WIDTH-1:0]       s_axis_exec_instr_tdata,
    // input axis wb instruction
    output logic                                  s_axis_wb_instr_tready,
    input  logic                                  s_axis_wb_instr_tvalid,
    input  logic [    CORE_INSTR_WIDTH-1:0]       s_axis_wb_instr_tdata,
    // input axis update data
    output logic                                  s_axis_int2pe_tready,
    input  logic                                  s_axis_int2pe_tvalid,
    input  logic [      AXI_DATA_WIDTH-1:0]       s_axis_int2pe_tdata,
    input  logic [    AXI_DATA_WIDTH/8-1:0]       s_axis_int2pe_tkeep,
    input  logic                                  s_axis_int2pe_tlast,
    // input axis update tag
    output logic                                  s_axis_int2pe_tag_tready,
    input  logic                                  s_axis_int2pe_tag_tvalid,
    input  logic [      MM2S_TAG_WIDTH-1:0]       s_axis_int2pe_tag_tdata,
    input  logic [    MM2S_TAG_WIDTH/8-1:0]       s_axis_int2pe_tag_tkeep,
    input  logic                                  s_axis_int2pe_tag_tlast,
    // input axis bn data
    output logic                                  s_axis_int2bn_tready,
    input  logic                                  s_axis_int2bn_tvalid,
    input  logic [  BN_UPDT_DATA_WIDTH-1:0]       s_axis_int2bn_tdata,
    input  logic [BN_UPDT_DATA_WIDTH/8-1:0]       s_axis_int2bn_tkeep,
    input  logic                                  s_axis_int2bn_tlast,
    // input axis bn tag
    output logic                                  s_axis_int2bn_tag_tready,
    input  logic                                  s_axis_int2bn_tag_tvalid,
    input  logic [      MM2S_TAG_WIDTH-1:0]       s_axis_int2bn_tag_tdata,
    input  logic [    MM2S_TAG_WIDTH/8-1:0]       s_axis_int2bn_tag_tkeep,
    input  logic                                  s_axis_int2bn_tag_tlast,
    // output axis wb data               
    input  logic                                  m_axis_pe2lc_tready,
    output logic                                  m_axis_pe2lc_tvalid,
    output logic [    PE_LC_DATA_WIDTH-1:0]       m_axis_pe2lc_tdata,
    output logic [  PE_LC_DATA_WIDTH/8-1:0]       m_axis_pe2lc_tkeep,
    output logic                                  m_axis_pe2lc_tlast,
    // output axis wb_fb
    input  logic                                  m_axis_eolfb_tready,
    output logic                                  m_axis_eolfb_tvalid,
    output logic                                  m_axis_eolfb_tdata,
    // just for test
    output logic                                  updt_status
);

    /***************************** pe instruction - updt *****************************/
    logic                        i_axis_updt_instr_tready;
    logic                        i_axis_updt_instr_tvalid;
    logic [CORE_INSTR_WIDTH-1:0] i_axis_updt_instr_tdata;

    fifo_axis #(
        .FIFO_AXIS_DEPTH(16),
        .FIFO_AXIS_TDATA_WIDTH(CORE_INSTR_WIDTH)
    ) pe_updt_instr_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tready(i_axis_updt_instr_tready),
        .m_axis_tvalid(i_axis_updt_instr_tvalid),
        .m_axis_tdata(i_axis_updt_instr_tdata),
        .s_axis_tready(s_axis_updt_instr_tready),
        .s_axis_tvalid(s_axis_updt_instr_tvalid),
        .s_axis_tdata(s_axis_updt_instr_tdata)
    );

    // handshake signals in sub-instructions
    logic hs_i_axis_updt_instr;
    assign hs_i_axis_updt_instr = i_axis_updt_instr_tvalid & i_axis_updt_instr_tready;

    logic       pe_config_updt            [PARAM_PE_NUM-1:0];
    logic [5:0] s_k_index_config_updt;
    logic [5:0] s_c_index_config_updt;
    logic [3:0] s_h_index_config_updt;
    logic [3:0] s_w_index_config_updt;
    logic       pe_idle_state_config_updt;
    logic [5:0] pe_index_config_updt;

    always_ff @(posedge clk) begin
        if (hs_i_axis_updt_instr) begin
            s_w_index_config_updt     <= i_axis_updt_instr_tdata[3:0];
            s_h_index_config_updt     <= i_axis_updt_instr_tdata[7:4];
            s_c_index_config_updt     <= i_axis_updt_instr_tdata[13:8];
            s_k_index_config_updt     <= i_axis_updt_instr_tdata[19:14];
            pe_idle_state_config_updt <= i_axis_updt_instr_tdata[20];
            pe_index_config_updt      <= i_axis_updt_instr_tdata[26:21];
        end
    end

    genvar pe_idx;
    generate
        for (pe_idx = 0; pe_idx < PARAM_PE_NUM; pe_idx++) begin
            always_ff @(posedge clk) begin
                pe_config_updt[pe_idx] <= hs_i_axis_updt_instr & (pe_index_config_updt == pe_idx);
            end
        end
    endgenerate
    /***************************** pe instruction - updt *****************************/

    /***************************** pe instruction - exec *****************************/
    logic                        i_axis_exec_instr_tready;
    logic                        i_axis_exec_instr_tvalid;
    logic [CORE_INSTR_WIDTH-1:0] i_axis_exec_instr_tdata;

    fifo_axis #(
        .FIFO_AXIS_DEPTH(16),
        .FIFO_AXIS_TDATA_WIDTH(CORE_INSTR_WIDTH)
    ) pe_exec_instr_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tready(i_axis_exec_instr_tready),
        .m_axis_tvalid(i_axis_exec_instr_tvalid),
        .m_axis_tdata(i_axis_exec_instr_tdata),
        .s_axis_tready(s_axis_exec_instr_tready),
        .s_axis_tvalid(s_axis_exec_instr_tvalid),
        .s_axis_tdata(s_axis_exec_instr_tdata)
    );

    // handshake signals in sub-instructions
    logic hs_i_axis_exec_instr;
    assign hs_i_axis_exec_instr = i_axis_exec_instr_tvalid & i_axis_exec_instr_tready;

    logic       pe_config_exec            [PARAM_PE_NUM-1:0];
    logic       pe_idle_state_config_exec;
    logic [5:0] s_k_index_config_exec;
    logic [5:0] s_c_index_config_exec;
    logic [3:0] s_h_index_config_exec;
    logic [3:0] s_w_index_config_exec;
    logic [5:0] pe_index_config_exec;

    logic [2:0] param_type_exec;
    assign param_type_exec = i_axis_exec_instr_tdata[62:60];
    logic instr_type_exec;
    assign instr_type_exec = i_axis_exec_instr_tdata[63];

    // decode pe parameters
    // NOTE: the inside pe factors order is [k, h, w, c, i, j]
    // f loop factor
    logic [ 5:0] F_LOOP_FACTORS_EXEC  [5:0];
    // q loop factor
    logic [ 9:0] Q_LOOP_FACTORS_EXEC  [5:0];
    // p loop factor
    logic [ 9:0] P_LOOP_FACTORS_EXEC  [5:0];
    // strpad factor
    logic [ 2:0] STRPAD_FACTORS_EXEC  [1:0];
    // pq loop factor (for wbuf shape and pbuf shape)
    logic [ 8:0] PQ_LOOP_FACTORS_EXEC [5:0];
    // wbuf address shape (execution)
    logic [ 8:0] WBUF_ADDR_SHAPE_EXEC [3:0];
    // pbuf address shape (execution)
    logic [ 8:0] PSUM_ADDR_SHAPE_EXEC [2:0];
    // pqf loop factor
    logic [ 9:0] PQF_LOOP_FACTORS_EXEC[5:0];
    // end of model
    logic        end_of_model_exec;

    // layer size
    logic [15:0] layer_k_exec;
    logic [8:0] layer_h_exec, layer_w_exec;
    // computation type of this layer
    logic comp_type_exec, w_fixed_exec, w_addr_comp_exec;
    logic depth_wise_exec;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            F_LOOP_FACTORS_EXEC[5]   <= 0;
            F_LOOP_FACTORS_EXEC[4]   <= 0;
            F_LOOP_FACTORS_EXEC[3]   <= 0;
            F_LOOP_FACTORS_EXEC[2]   <= 0;
            F_LOOP_FACTORS_EXEC[1]   <= 0;
            F_LOOP_FACTORS_EXEC[0]   <= 0;
            STRPAD_FACTORS_EXEC[1]   <= 0;
            STRPAD_FACTORS_EXEC[0]   <= 0;
            Q_LOOP_FACTORS_EXEC[5]   <= 0;
            Q_LOOP_FACTORS_EXEC[4]   <= 0;
            Q_LOOP_FACTORS_EXEC[3]   <= 0;
            Q_LOOP_FACTORS_EXEC[2]   <= 0;
            Q_LOOP_FACTORS_EXEC[1]   <= 0;
            Q_LOOP_FACTORS_EXEC[0]   <= 0;
            P_LOOP_FACTORS_EXEC[5]   <= 0;
            P_LOOP_FACTORS_EXEC[4]   <= 0;
            P_LOOP_FACTORS_EXEC[3]   <= 0;
            P_LOOP_FACTORS_EXEC[2]   <= 0;
            P_LOOP_FACTORS_EXEC[1]   <= 0;
            P_LOOP_FACTORS_EXEC[0]   <= 0;
            PQ_LOOP_FACTORS_EXEC[5]  <= 0;
            PQ_LOOP_FACTORS_EXEC[4]  <= 0;
            PQ_LOOP_FACTORS_EXEC[3]  <= 0;
            PQ_LOOP_FACTORS_EXEC[2]  <= 0;
            PQ_LOOP_FACTORS_EXEC[1]  <= 0;
            PQ_LOOP_FACTORS_EXEC[0]  <= 0;
            PQF_LOOP_FACTORS_EXEC[5] <= 0;
            PQF_LOOP_FACTORS_EXEC[4] <= 0;
            PQF_LOOP_FACTORS_EXEC[3] <= 0;
            PQF_LOOP_FACTORS_EXEC[2] <= 0;
            PQF_LOOP_FACTORS_EXEC[1] <= 0;
            PQF_LOOP_FACTORS_EXEC[0] <= 0;
            end_of_model_exec        <= 1'b0;
        end else if (hs_i_axis_exec_instr & (~instr_type_exec)) begin
            if (param_type_exec == 3'b000) begin
                F_LOOP_FACTORS_EXEC[5] <= i_axis_exec_instr_tdata[21:18];
                F_LOOP_FACTORS_EXEC[4] <= i_axis_exec_instr_tdata[25:22];
                F_LOOP_FACTORS_EXEC[3] <= i_axis_exec_instr_tdata[35:26];
                F_LOOP_FACTORS_EXEC[2] <= i_axis_exec_instr_tdata[8:0];
                F_LOOP_FACTORS_EXEC[1] <= i_axis_exec_instr_tdata[17:9];
                F_LOOP_FACTORS_EXEC[0] <= i_axis_exec_instr_tdata[45:36];
                STRPAD_FACTORS_EXEC[1] <= i_axis_exec_instr_tdata[51:49];
                STRPAD_FACTORS_EXEC[0] <= i_axis_exec_instr_tdata[48:46];
                end_of_model_exec      <= i_axis_exec_instr_tdata[52];
            end else if (param_type_exec == 3'b001) begin
                Q_LOOP_FACTORS_EXEC[5] <= i_axis_exec_instr_tdata[21:18];
                Q_LOOP_FACTORS_EXEC[4] <= i_axis_exec_instr_tdata[25:22];
                Q_LOOP_FACTORS_EXEC[3] <= i_axis_exec_instr_tdata[35:26];
                Q_LOOP_FACTORS_EXEC[2] <= i_axis_exec_instr_tdata[8:0];
                Q_LOOP_FACTORS_EXEC[1] <= i_axis_exec_instr_tdata[17:9];
                Q_LOOP_FACTORS_EXEC[0] <= i_axis_exec_instr_tdata[45:36];
            end else if (param_type_exec == 3'b010) begin
                P_LOOP_FACTORS_EXEC[5] <= i_axis_exec_instr_tdata[21:18];
                P_LOOP_FACTORS_EXEC[4] <= i_axis_exec_instr_tdata[25:22];
                P_LOOP_FACTORS_EXEC[3] <= i_axis_exec_instr_tdata[35:26];
                P_LOOP_FACTORS_EXEC[2] <= i_axis_exec_instr_tdata[8:0];
                P_LOOP_FACTORS_EXEC[1] <= i_axis_exec_instr_tdata[17:9];
                P_LOOP_FACTORS_EXEC[0] <= i_axis_exec_instr_tdata[45:36];
            end else if (param_type_exec == 3'b011) begin
                PQ_LOOP_FACTORS_EXEC[5] <= i_axis_exec_instr_tdata[21:18];
                PQ_LOOP_FACTORS_EXEC[4] <= i_axis_exec_instr_tdata[25:22];
                PQ_LOOP_FACTORS_EXEC[3] <= i_axis_exec_instr_tdata[35:26];
                PQ_LOOP_FACTORS_EXEC[2] <= i_axis_exec_instr_tdata[8:0];
                PQ_LOOP_FACTORS_EXEC[1] <= i_axis_exec_instr_tdata[17:9];
                PQ_LOOP_FACTORS_EXEC[0] <= i_axis_exec_instr_tdata[45:36];
            end else if (param_type_exec == 3'b100) begin
                PQF_LOOP_FACTORS_EXEC[5] <= i_axis_exec_instr_tdata[21:18];
                PQF_LOOP_FACTORS_EXEC[4] <= i_axis_exec_instr_tdata[25:22];
                PQF_LOOP_FACTORS_EXEC[3] <= i_axis_exec_instr_tdata[35:26];
                PQF_LOOP_FACTORS_EXEC[2] <= i_axis_exec_instr_tdata[8:0];
                PQF_LOOP_FACTORS_EXEC[1] <= i_axis_exec_instr_tdata[17:9];
                PQF_LOOP_FACTORS_EXEC[0] <= i_axis_exec_instr_tdata[45:36];
            end
        end
    end

    logic depth_wise;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            comp_type_exec   <= 1'b0;
            w_fixed_exec     <= 1'b0;
            w_addr_comp_exec <= 1'b0;
            depth_wise_exec  <= 1'b0;
        end else if (hs_i_axis_exec_instr & (~instr_type_exec) & (param_type_exec == 3'b101)) begin
            comp_type_exec   <= (i_axis_exec_instr_tdata[53:52] == 2'b00) | (i_axis_exec_instr_tdata[53:52] == 2'b01);
            w_fixed_exec     <= (i_axis_exec_instr_tdata[53:52] == 2'b10) | (i_axis_exec_instr_tdata[53:52] == 2'b11);
            w_addr_comp_exec <= (i_axis_exec_instr_tdata[53:52] == 2'b10) | (i_axis_exec_instr_tdata[53:52] == 2'b11)| 
                                (i_axis_exec_instr_tdata[53:52] == 2'b01);
            depth_wise_exec <= (i_axis_exec_instr_tdata[53:52] != 2'b00);
        end
    end

    always_comb begin
        WBUF_ADDR_SHAPE_EXEC[0] = depth_wise_exec ? 9'd1 : PQ_LOOP_FACTORS_EXEC[0];  // k
        WBUF_ADDR_SHAPE_EXEC[1] = PQ_LOOP_FACTORS_EXEC[3];  // c
        WBUF_ADDR_SHAPE_EXEC[2] = PQ_LOOP_FACTORS_EXEC[4];  // i
        WBUF_ADDR_SHAPE_EXEC[3] = PQ_LOOP_FACTORS_EXEC[5];  // j

        PSUM_ADDR_SHAPE_EXEC[0] = PQ_LOOP_FACTORS_EXEC[0];  // k
        PSUM_ADDR_SHAPE_EXEC[1] = PQ_LOOP_FACTORS_EXEC[1];  // h
        PSUM_ADDR_SHAPE_EXEC[2] = PQ_LOOP_FACTORS_EXEC[2];  // w
    end

    always_ff @(posedge clk) begin
        if (hs_i_axis_exec_instr & (~instr_type_exec) & (param_type_exec == 3'b111)) begin
            s_w_index_config_exec     <= i_axis_exec_instr_tdata[3:0];
            s_h_index_config_exec     <= i_axis_exec_instr_tdata[7:4];
            s_c_index_config_exec     <= i_axis_exec_instr_tdata[13:8];
            s_k_index_config_exec     <= i_axis_exec_instr_tdata[19:14];
            pe_idle_state_config_exec <= i_axis_exec_instr_tdata[20];
            pe_index_config_exec      <= i_axis_exec_instr_tdata[26:21];
        end
    end

    generate
        for (pe_idx = 0; pe_idx < PARAM_PE_NUM; pe_idx++) begin
            always_ff @(posedge clk) begin
                pe_config_exec[pe_idx] <= hs_i_axis_exec_instr & (~instr_type_exec) & (param_type_exec == 3'b111) & (pe_index_config_exec == pe_idx);
            end
        end
    endgenerate

    // decode pe instructions
    logic [5:0] ex_s_idx_k, ex_s_idx_c;
    logic [3:0] ex_s_idx_h, ex_s_idx_w;
    logic pbuf_wb_rvs_r;
    logic tc_reset;
    logic exec_instr_eol;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            ex_s_idx_w <= 0;
            ex_s_idx_h <= 0;
            ex_s_idx_c <= 0;
            ex_s_idx_k <= 0;
        end else if (hs_i_axis_exec_instr & instr_type_exec) begin
            ex_s_idx_w <= i_axis_exec_instr_tdata[3:0];
            ex_s_idx_h <= i_axis_exec_instr_tdata[7:4];
            ex_s_idx_c <= i_axis_exec_instr_tdata[13:8];
            ex_s_idx_k <= i_axis_exec_instr_tdata[19:14];
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            tc_reset       <= 1'b0;
            pbuf_wb_rvs_r  <= 1'b0;
            exec_instr_eol <= 1'b0;
        end else if (hs_i_axis_exec_instr & instr_type_exec) begin
            tc_reset       <= i_axis_exec_instr_tdata[59];
            pbuf_wb_rvs_r  <= i_axis_exec_instr_tdata[58];
            exec_instr_eol <= i_axis_exec_instr_tdata[60] & (~end_of_model_exec);
        end
    end

    // decode finish
    logic instr_dec_valid_ex;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            instr_dec_valid_ex <= 1'b0;
        end else begin
            instr_dec_valid_ex <= hs_i_axis_exec_instr & instr_type_exec;
        end
    end

    /***************************** pe instruction - exec *****************************/

    /****************************** pe instruction - wb ******************************/
    logic                        i_axis_wb_instr_tready;
    logic                        i_axis_wb_instr_tvalid;
    logic [CORE_INSTR_WIDTH-1:0] i_axis_wb_instr_tdata;

    fifo_axis #(
        .FIFO_AXIS_DEPTH(16),
        .FIFO_AXIS_TDATA_WIDTH(CORE_INSTR_WIDTH)
    ) pe_wb_instr_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tready(i_axis_wb_instr_tready),
        .m_axis_tvalid(i_axis_wb_instr_tvalid),
        .m_axis_tdata(i_axis_wb_instr_tdata),
        .s_axis_tready(s_axis_wb_instr_tready),
        .s_axis_tvalid(s_axis_wb_instr_tvalid),
        .s_axis_tdata(s_axis_wb_instr_tdata)
    );

    // handshake signals in sub-instructions
    logic hs_i_axis_wb_instr;
    assign hs_i_axis_wb_instr = i_axis_wb_instr_tvalid & i_axis_wb_instr_tready;

    logic       pe_config_wb            [PARAM_PE_NUM-1:0];
    logic       pe_idle_state_config_wb;
    logic [5:0] s_k_index_config_wb;
    logic [5:0] s_c_index_config_wb;
    logic [3:0] s_h_index_config_wb;
    logic [3:0] s_w_index_config_wb;
    logic [5:0] pe_index_config_wb;

    logic [2:0] param_type_wb;
    assign param_type_wb = i_axis_wb_instr_tdata[62:60];

    logic instr_type_wb;
    assign instr_type_wb = i_axis_wb_instr_tdata[63];

    // decode pe parameters
    // NOTE: the inside pe factors order is [k, h, w, c, i, j]
    // f loop factor
    logic [ 5:0] F_LOOP_FACTORS_WB  [5:0];
    // q loop factor
    logic [ 9:0] Q_LOOP_FACTORS_WB  [5:0];
    // p loop factor
    logic [ 9:0] P_LOOP_FACTORS_WB  [5:0];
    // strpad factor
    logic [ 2:0] STRPAD_FACTORS_WB  [1:0];
    // pq loop factor (for wbuf shape and pbuf shape)
    logic [ 8:0] PQ_LOOP_FACTORS_WB [5:0];
    // pqf loop factor
    logic [ 9:0] PQF_LOOP_FACTORS_WB[5:0];

    // layer size
    logic [15:0] layer_k_wb;
    logic [8:0] layer_h_wb, layer_w_wb;
    // if this layer needs bn & res adder
    logic bn_enable_layer;
    // computation type of this layer
    logic comp_type_wb, w_fixed_wb, w_addr_comp_wb;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            F_LOOP_FACTORS_WB[5]   <= 0;
            F_LOOP_FACTORS_WB[4]   <= 0;
            F_LOOP_FACTORS_WB[3]   <= 0;
            F_LOOP_FACTORS_WB[2]   <= 0;
            F_LOOP_FACTORS_WB[1]   <= 0;
            F_LOOP_FACTORS_WB[0]   <= 0;
            STRPAD_FACTORS_WB[1]   <= 0;
            STRPAD_FACTORS_WB[0]   <= 0;
            Q_LOOP_FACTORS_WB[5]   <= 0;
            Q_LOOP_FACTORS_WB[4]   <= 0;
            Q_LOOP_FACTORS_WB[3]   <= 0;
            Q_LOOP_FACTORS_WB[2]   <= 0;
            Q_LOOP_FACTORS_WB[1]   <= 0;
            Q_LOOP_FACTORS_WB[0]   <= 0;
            P_LOOP_FACTORS_WB[5]   <= 0;
            P_LOOP_FACTORS_WB[4]   <= 0;
            P_LOOP_FACTORS_WB[3]   <= 0;
            P_LOOP_FACTORS_WB[2]   <= 0;
            P_LOOP_FACTORS_WB[1]   <= 0;
            P_LOOP_FACTORS_WB[0]   <= 0;
            PQ_LOOP_FACTORS_WB[5]  <= 0;
            PQ_LOOP_FACTORS_WB[4]  <= 0;
            PQ_LOOP_FACTORS_WB[3]  <= 0;
            PQ_LOOP_FACTORS_WB[2]  <= 0;
            PQ_LOOP_FACTORS_WB[1]  <= 0;
            PQ_LOOP_FACTORS_WB[0]  <= 0;
            PQF_LOOP_FACTORS_WB[5] <= 0;
            PQF_LOOP_FACTORS_WB[4] <= 0;
            PQF_LOOP_FACTORS_WB[3] <= 0;
            PQF_LOOP_FACTORS_WB[2] <= 0;
            PQF_LOOP_FACTORS_WB[1] <= 0;
            PQF_LOOP_FACTORS_WB[0] <= 0;
            layer_w_wb             <= 0;
            layer_h_wb             <= 0;
            layer_k_wb             <= 0;
        end else if (hs_i_axis_wb_instr & (~instr_type_wb)) begin
            if (param_type_wb == 3'b000) begin
                F_LOOP_FACTORS_WB[5] <= i_axis_wb_instr_tdata[21:18];
                F_LOOP_FACTORS_WB[4] <= i_axis_wb_instr_tdata[25:22];
                F_LOOP_FACTORS_WB[3] <= i_axis_wb_instr_tdata[35:26];
                F_LOOP_FACTORS_WB[2] <= i_axis_wb_instr_tdata[8:0];
                F_LOOP_FACTORS_WB[1] <= i_axis_wb_instr_tdata[17:9];
                F_LOOP_FACTORS_WB[0] <= i_axis_wb_instr_tdata[45:36];
                STRPAD_FACTORS_WB[1] <= i_axis_wb_instr_tdata[51:49];
                STRPAD_FACTORS_WB[0] <= i_axis_wb_instr_tdata[48:46];
            end else if (param_type_wb == 3'b001) begin
                Q_LOOP_FACTORS_WB[5] <= i_axis_wb_instr_tdata[21:18];
                Q_LOOP_FACTORS_WB[4] <= i_axis_wb_instr_tdata[25:22];
                Q_LOOP_FACTORS_WB[3] <= i_axis_wb_instr_tdata[35:26];
                Q_LOOP_FACTORS_WB[2] <= i_axis_wb_instr_tdata[8:0];
                Q_LOOP_FACTORS_WB[1] <= i_axis_wb_instr_tdata[17:9];
                Q_LOOP_FACTORS_WB[0] <= i_axis_wb_instr_tdata[45:36];
            end else if (param_type_wb == 3'b010) begin
                P_LOOP_FACTORS_WB[5] <= i_axis_wb_instr_tdata[21:18];
                P_LOOP_FACTORS_WB[4] <= i_axis_wb_instr_tdata[25:22];
                P_LOOP_FACTORS_WB[3] <= i_axis_wb_instr_tdata[35:26];
                P_LOOP_FACTORS_WB[2] <= i_axis_wb_instr_tdata[8:0];
                P_LOOP_FACTORS_WB[1] <= i_axis_wb_instr_tdata[17:9];
                P_LOOP_FACTORS_WB[0] <= i_axis_wb_instr_tdata[45:36];
            end else if (param_type_wb == 3'b011) begin
                PQ_LOOP_FACTORS_WB[5] <= i_axis_wb_instr_tdata[21:18];
                PQ_LOOP_FACTORS_WB[4] <= i_axis_wb_instr_tdata[25:22];
                PQ_LOOP_FACTORS_WB[3] <= i_axis_wb_instr_tdata[35:26];
                PQ_LOOP_FACTORS_WB[2] <= i_axis_wb_instr_tdata[8:0];
                PQ_LOOP_FACTORS_WB[1] <= i_axis_wb_instr_tdata[17:9];
                PQ_LOOP_FACTORS_WB[0] <= i_axis_wb_instr_tdata[45:36];
            end else if (param_type_wb == 3'b100) begin
                PQF_LOOP_FACTORS_WB[5] <= i_axis_wb_instr_tdata[21:18];
                PQF_LOOP_FACTORS_WB[4] <= i_axis_wb_instr_tdata[25:22];
                PQF_LOOP_FACTORS_WB[3] <= i_axis_wb_instr_tdata[35:26];
                PQF_LOOP_FACTORS_WB[2] <= i_axis_wb_instr_tdata[8:0];
                PQF_LOOP_FACTORS_WB[1] <= i_axis_wb_instr_tdata[17:9];
                PQF_LOOP_FACTORS_WB[0] <= i_axis_wb_instr_tdata[45:36];
            end else if (param_type_wb == 3'b101) begin
                layer_w_wb <= i_axis_wb_instr_tdata[8:0];
                layer_h_wb <= i_axis_wb_instr_tdata[17:9];
                layer_k_wb <= i_axis_wb_instr_tdata[51:36];
            end
        end
    end

    logic depth_wise_wb;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            comp_type_wb   <= 1'b0;
            w_fixed_wb     <= 1'b0;
            w_addr_comp_wb <= 1'b0;
            depth_wise_wb  <= 1'b0;
        end else if (hs_i_axis_wb_instr & (~instr_type_wb) & (param_type_wb == 3'b101)) begin
            comp_type_wb   <=   (i_axis_wb_instr_tdata[53:52] == 2'b00) | (i_axis_wb_instr_tdata[53:52] == 2'b01);
            w_fixed_wb     <=   (i_axis_wb_instr_tdata[53:52] == 2'b10) | (i_axis_wb_instr_tdata[53:52] == 2'b11);
            w_addr_comp_wb <=   (i_axis_wb_instr_tdata[53:52] == 2'b10) | (i_axis_wb_instr_tdata[53:52] == 2'b11)| 
                                (i_axis_wb_instr_tdata[53:52] == 2'b01);
            depth_wise_wb <= (i_axis_wb_instr_tdata[53:52] != 2'b00);
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            bn_enable_layer <= 1'b0;
        end else if (hs_i_axis_wb_instr & (~instr_type_wb)) begin
            if (param_type_wb == 3'b101) begin
                bn_enable_layer <= i_axis_wb_instr_tdata[54];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (hs_i_axis_wb_instr & (~instr_type_wb) & (param_type_wb == 3'b111)) begin
            s_w_index_config_wb     <= i_axis_wb_instr_tdata[3:0];
            s_h_index_config_wb     <= i_axis_wb_instr_tdata[7:4];
            s_c_index_config_wb     <= i_axis_wb_instr_tdata[13:8];
            s_k_index_config_wb     <= i_axis_wb_instr_tdata[19:14];
            pe_idle_state_config_wb <= i_axis_wb_instr_tdata[20];
            pe_index_config_wb      <= i_axis_wb_instr_tdata[26:21];
        end
    end

    generate
        for (pe_idx = 0; pe_idx < PARAM_PE_NUM; pe_idx++) begin
            always_ff @(posedge clk) begin
                pe_config_wb[pe_idx] <= hs_i_axis_wb_instr & (~instr_type_wb) & (param_type_wb == 3'b111) & (pe_index_config_wb == pe_idx);
            end
        end
    endgenerate

    // decode wb instruction
    logic [9:0] wb_st_idx_k;
    logic [8:0] wb_st_idx_h, wb_st_idx_w;
    logic [5:0] wb_s_idx_k;
    logic [3:0] wb_s_idx_h, wb_s_idx_w;
    logic wb_eos, wb_eol;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wb_s_idx_w  <= 0;
            wb_s_idx_h  <= 0;
            wb_s_idx_k  <= 0;
            wb_st_idx_w <= 0;
            wb_st_idx_h <= 0;
            wb_st_idx_k <= 0;
        end else if (hs_i_axis_wb_instr & instr_type_wb) begin
            wb_s_idx_w  <= i_axis_wb_instr_tdata[3:0];
            wb_s_idx_h  <= i_axis_wb_instr_tdata[7:4];
            wb_s_idx_k  <= i_axis_wb_instr_tdata[19:14];
            wb_st_idx_w <= i_axis_wb_instr_tdata[28:20];
            wb_st_idx_h <= i_axis_wb_instr_tdata[37:29];
            wb_st_idx_k <= i_axis_wb_instr_tdata[57:48];
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wb_eos <= 1'b0;
            wb_eol <= 1'b0;
        end else if (hs_i_axis_wb_instr & instr_type_wb) begin
            wb_eos <= i_axis_wb_instr_tdata[58];
            wb_eol <= i_axis_wb_instr_tdata[59];
        end
    end

    // decode finish (then calculate intermidiates)
    logic instr_dec_valid_wb;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            instr_dec_valid_wb <= 1'b0;
        end else begin
            instr_dec_valid_wb <= hs_i_axis_wb_instr & instr_type_wb;
        end
    end

    // intermidiates (mainly for write back)
    logic [ 9:0] r_k;
    logic [ 8:0] r_h;
    logic [ 8:0] r_w;
    logic [15:0] psum_channel_start;

    // tile start stpqf index (all dimensions), will be used for calculating real shape and padding
    logic [15:0] tile_start_idx_fout[2:0];  // 0 - w, 1 - h, 2 - k

    // tile start stpqf index (all dimensions), will be used for calculating real shape and padding
    logic [15:0] tile_end_idx_fout  [2:0];  // 0 - w, 1 - h, 2 - k

    always_comb begin : tile_start_idx
        tile_start_idx_fout[0] = PQF_LOOP_FACTORS_WB[2] * wb_st_idx_w;
        tile_start_idx_fout[1] = PQF_LOOP_FACTORS_WB[1] * wb_st_idx_h;
        tile_start_idx_fout[2] = PQF_LOOP_FACTORS_WB[0] * wb_st_idx_k;
    end

    always_comb begin : tile_end_idx
        tile_end_idx_fout[0] = tile_start_idx_fout[0] + PQF_LOOP_FACTORS_WB[2] - 1;
        tile_end_idx_fout[1] = tile_start_idx_fout[1] + PQF_LOOP_FACTORS_WB[1] - 1;
        tile_end_idx_fout[2] = tile_start_idx_fout[2] + PQF_LOOP_FACTORS_WB[0] - 1;
    end

    always_ff @(posedge clk) begin : real_tile_shape
        if (~rst_n) begin
            r_w                <= 0;
            r_h                <= 0;
            r_k                <= 0;
            psum_channel_start <= 0;
        end  // Only when the decoding is valid, the intermediates can be calculated
        else if (instr_dec_valid_wb) begin
            r_w                 <= (tile_end_idx_fout[0] > layer_w_wb - 1)                                      ?
                                    layer_w_wb - tile_start_idx_fout[0]                                         :
                                    PQF_LOOP_FACTORS_WB[2]                                                      ;
            r_h                 <= (tile_end_idx_fout[1] > layer_h_wb - 1)                                      ?
                                    layer_h_wb - tile_start_idx_fout[1]                                         :
                                    PQF_LOOP_FACTORS_WB[1]                                                      ;
            r_k                 <= (tile_end_idx_fout[2] > layer_k_wb - 1)                                      ?
                                    layer_k_wb - tile_start_idx_fout[2]                                         :
                                    PQF_LOOP_FACTORS_WB[0]                                                      ;
            psum_channel_start <= tile_start_idx_fout[2];
        end
    end

    /****************************** pe instruction - wb ******************************/

    /*********************************** tag eot ***********************************/
    logic hs_axis_int2pe_tag, hs_axis_int2pe;
    always_comb begin
        hs_axis_int2pe_tag = s_axis_int2pe_tag_tready & s_axis_int2pe_tag_tvalid;
        hs_axis_int2pe     = s_axis_int2pe_tready & s_axis_int2pe_tvalid;
    end

    logic axis_int2pe_tag_eot;
    logic updt_slot_sel_r, updt_slot_sel;
    always_comb begin
        axis_int2pe_tag_eot = hs_axis_int2pe_tag & s_axis_int2pe_tag_tdata[55];
    end
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_slot_sel_r <= 1'b0;
        end else if (hs_axis_int2pe_tag) begin
            updt_slot_sel_r <= s_axis_int2pe_tag_tdata[57];
        end
    end
    /*********************************** tag eot ***********************************/

    /**************************** fifo & data convert *******************************/
    logic [                     3:0] i_axis_pe_updt_tready;
    logic [                     3:0] i_axis_pe_updt_tvalid;
    logic [  PE_UPDT_DATA_WIDTH-1:0] i_axis_pe_updt_tdata      [3:0];
    logic [PE_UPDT_DATA_WIDTH/8-1:0] i_axis_pe_updt_tkeep      [3:0];
    logic [                     3:0] i_axis_pe_updt_tlast;

    logic [                     3:0] i_axis_pe_updt_tag_tready;
    logic [                     3:0] i_axis_pe_updt_tag_tvalid;
    logic [      MM2S_TAG_WIDTH-1:0] i_axis_pe_updt_tag_tdata  [3:0];
    logic [    MM2S_TAG_WIDTH/8-1:0] i_axis_pe_updt_tag_tkeep  [3:0];
    logic [                     3:0] i_axis_pe_updt_tag_tlast;

    logic [                     3:0] i_axis_wrbuf_tready;
    logic [                     3:0] i_axis_wrbuf_tvalid;
    logic [      AXI_DATA_WIDTH-1:0] i_axis_wrbuf_tdata        [3:0];
    logic [    AXI_DATA_WIDTH/8-1:0] i_axis_wrbuf_tkeep        [3:0];
    logic [                     3:0] i_axis_wrbuf_tlast;

    logic [                     3:0] i_axis_wrbuf_tag_tready;
    logic [                     3:0] i_axis_wrbuf_tag_tvalid;
    logic [      MM2S_TAG_WIDTH-1:0] i_axis_wrbuf_tag_tdata    [3:0];
    logic [    MM2S_TAG_WIDTH/8-1:0] i_axis_wrbuf_tag_tkeep    [3:0];
    logic [                     3:0] i_axis_wrbuf_tag_tlast;

    // only used for data, not for tag
    logic [                     3:0] i_axis_rdbuf_tready;
    logic [                     3:0] i_axis_rdbuf_tvalid;
    logic [      AXI_DATA_WIDTH-1:0] i_axis_rdbuf_tdata        [3:0];
    logic [    AXI_DATA_WIDTH/8-1:0] i_axis_rdbuf_tkeep        [3:0];
    logic [                     3:0] i_axis_rdbuf_tlast;

    logic [                     3:0] i_axis_int2pe_tready;
    logic [                     3:0] almost_empty_axis;
    logic [                     3:0] buf_empty;
    logic [                     3:0] pe_updt_sel;

    logic                            all_empty;
    logic                            last_tag_tile;
    logic                            updt_eol;

    always_comb begin
        updt_eol = hs_axis_int2pe_tag & (s_axis_int2pe_tag_tdata[62:61] == 2'b01) & s_axis_int2pe_tag_tdata[31];
    end

    delay_chain #(
        .DW (4),
        .LEN(3)
    ) delay_buf_empty (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (i_axis_rdbuf_tvalid),
        .out(buf_empty)
    );

    always_comb begin
        all_empty = (buf_empty == 4'b0000);
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            last_tag_tile <= 1'b0;
        end else if (last_tag_tile & s_axis_int2pe_tlast & hs_axis_int2pe) begin
            last_tag_tile <= 1'b0;
        end else if (hs_axis_int2pe_tag & axis_int2pe_tag_eot) begin
            last_tag_tile <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            pe_updt_sel <= 4'b0001;  // default: select #1 fifo
        end else if (pe_updt_sel == 4'b0000) begin
            pe_updt_sel <=  ((almost_empty_axis == 4'b0001)|(almost_empty_axis == 4'b0011)|(almost_empty_axis == 4'b0101)|
                            (almost_empty_axis == 4'b0111)|(almost_empty_axis == 4'b1001)|(almost_empty_axis == 4'b1011)|
                            (almost_empty_axis == 4'b1101)|(almost_empty_axis == 4'b1111))                      ?(4'b0001):
                            ((almost_empty_axis == 4'b0010)|(almost_empty_axis == 4'b0110)|(almost_empty_axis == 4'b1010)|
                            (almost_empty_axis == 4'b1110))                                                     ?(4'b0010):
                            ((almost_empty_axis == 4'b0100)|(almost_empty_axis == 4'b1100))                     ?(4'b0100):
                            ((almost_empty_axis == 4'b1000))                                                    ?(4'b1000):
                                                                                                                 (4'b0000);
        end else if (last_tag_tile & s_axis_int2pe_tlast & hs_axis_int2pe) begin
            pe_updt_sel <=  ((almost_empty_axis == 4'b0001)|(almost_empty_axis == 4'b0011)|(almost_empty_axis == 4'b0101)|
                            (almost_empty_axis == 4'b0111)|(almost_empty_axis == 4'b1001)|(almost_empty_axis == 4'b1011)|
                            (almost_empty_axis == 4'b1101)|(almost_empty_axis == 4'b1111))                      ?(4'b0001):
                            ((almost_empty_axis == 4'b0010)|(almost_empty_axis == 4'b0110)|(almost_empty_axis == 4'b1010)|
                            (almost_empty_axis == 4'b1110))                                                     ?(4'b0010):
                            ((almost_empty_axis == 4'b0100)|(almost_empty_axis == 4'b1100))                     ?(4'b0100):
                            ((almost_empty_axis == 4'b1000))                                                    ?(4'b1000):
                                                                                                                 (4'b0000);
        end
    end

    genvar axis_pe_updt_idx;
    generate
        for (axis_pe_updt_idx = 0; axis_pe_updt_idx < 4; axis_pe_updt_idx++) begin
            fifo_axis #(
                .FIFO_AXIS_DEPTH(1024),
                .FIFO_AXIS_TDATA_WIDTH(AXI_DATA_WIDTH),
                .FIFO_ADV_FEATURES("1C14")  // we need almost_empty_axis here
            ) pe_updt_data_fifo (
                .clk(clk),
                .rst_n(rst_n),
                .almost_empty_axis(almost_empty_axis[axis_pe_updt_idx]),
                .m_axis_tready(i_axis_rdbuf_tready[axis_pe_updt_idx]),
                .m_axis_tvalid(i_axis_rdbuf_tvalid[axis_pe_updt_idx]),
                .m_axis_tdata(i_axis_rdbuf_tdata[axis_pe_updt_idx]),
                .m_axis_tkeep(i_axis_rdbuf_tkeep[axis_pe_updt_idx]),
                .m_axis_tlast(i_axis_rdbuf_tlast[axis_pe_updt_idx]),
                .s_axis_tready(i_axis_wrbuf_tready[axis_pe_updt_idx]),
                .s_axis_tvalid(i_axis_wrbuf_tvalid[axis_pe_updt_idx]),
                .s_axis_tdata(i_axis_wrbuf_tdata[axis_pe_updt_idx]),
                .s_axis_tkeep(i_axis_wrbuf_tkeep[axis_pe_updt_idx]),
                .s_axis_tlast(i_axis_wrbuf_tlast[axis_pe_updt_idx])
            );

            axis_dwidth_converter_pe axis_dwidth_converter_pe_inst (
                .aclk(clk),  // input wire aclk
                .aresetn(rst_n),  // input wire aresetn
                .s_axis_tvalid(i_axis_rdbuf_tvalid[axis_pe_updt_idx]),  // input wire s_axis_tvalid
                .s_axis_tready(i_axis_rdbuf_tready[axis_pe_updt_idx]),  // output wire s_axis_tready
                .s_axis_tdata(i_axis_rdbuf_tdata[axis_pe_updt_idx]),    // input wire [127 : 0] s_axis_tdata
                .s_axis_tkeep(i_axis_rdbuf_tkeep[axis_pe_updt_idx]),    // input wire [15 : 0] s_axis_tkeep
                .s_axis_tlast(i_axis_rdbuf_tlast[axis_pe_updt_idx]),  // input wire s_axis_tlast
                .m_axis_tvalid(i_axis_pe_updt_tvalid[axis_pe_updt_idx]),  // output wire m_axis_tvalid
                .m_axis_tready(i_axis_pe_updt_tready[axis_pe_updt_idx]),  // input wire m_axis_tready
                .m_axis_tdata(i_axis_pe_updt_tdata[axis_pe_updt_idx]),    // output wire [31 : 0] m_axis_tdata
                .m_axis_tkeep(i_axis_pe_updt_tkeep[axis_pe_updt_idx]),    // output wire [3 : 0] m_axis_tkeep
                .m_axis_tlast(i_axis_pe_updt_tlast[axis_pe_updt_idx])  // output wire m_axis_tlast
            );

            always_comb begin
                i_axis_int2pe_tready[axis_pe_updt_idx]  = i_axis_wrbuf_tready[axis_pe_updt_idx] &
                                                            pe_updt_sel[axis_pe_updt_idx];
                i_axis_wrbuf_tvalid[axis_pe_updt_idx]   = hs_axis_int2pe &
                                                            pe_updt_sel[axis_pe_updt_idx];
                i_axis_wrbuf_tdata[axis_pe_updt_idx] = s_axis_int2pe_tdata;
                i_axis_wrbuf_tkeep[axis_pe_updt_idx] = s_axis_int2pe_tkeep;
                i_axis_wrbuf_tlast[axis_pe_updt_idx] = s_axis_int2pe_tlast;
            end
        end
    endgenerate

    logic [3:0] tag_received_pe_updt;
    logic [3:0] tag_eos, tag_eol, tag_eom;
    generate
        for (axis_pe_updt_idx = 0; axis_pe_updt_idx < 4; axis_pe_updt_idx++) begin
            fifo_axis #(
                .FIFO_AXIS_DEPTH(512),
                .FIFO_AXIS_TDATA_WIDTH(MM2S_TAG_WIDTH)
            ) pe_updt_tag_fifo (
                .clk(clk),
                .rst_n(rst_n),
                .m_axis_tready(i_axis_pe_updt_tag_tready[axis_pe_updt_idx]),
                .m_axis_tvalid(i_axis_pe_updt_tag_tvalid[axis_pe_updt_idx]),
                .m_axis_tdata(i_axis_pe_updt_tag_tdata[axis_pe_updt_idx]),
                .m_axis_tkeep(i_axis_pe_updt_tag_tkeep[axis_pe_updt_idx]),
                .m_axis_tlast(i_axis_pe_updt_tag_tlast[axis_pe_updt_idx]),
                .s_axis_tready(i_axis_wrbuf_tag_tready[axis_pe_updt_idx]),
                .s_axis_tvalid(i_axis_wrbuf_tag_tvalid[axis_pe_updt_idx]),
                .s_axis_tdata(i_axis_wrbuf_tag_tdata[axis_pe_updt_idx]),
                .s_axis_tkeep(i_axis_wrbuf_tag_tkeep[axis_pe_updt_idx]),
                .s_axis_tlast(i_axis_wrbuf_tag_tlast[axis_pe_updt_idx])
            );

            always_comb begin
                i_axis_wrbuf_tag_tvalid[axis_pe_updt_idx]   =   hs_axis_int2pe_tag & 
                                                                pe_updt_sel[axis_pe_updt_idx];
                i_axis_wrbuf_tag_tdata[axis_pe_updt_idx] = s_axis_int2pe_tag_tdata;
                i_axis_wrbuf_tag_tkeep[axis_pe_updt_idx] = s_axis_int2pe_tag_tkeep;
                i_axis_wrbuf_tag_tlast[axis_pe_updt_idx] = s_axis_int2pe_tag_tlast;
            end

            always_ff @(posedge clk) begin
                if (~rst_n) begin
                    tag_received_pe_updt[axis_pe_updt_idx] <= 1'b0;
                end
                else if (i_axis_pe_updt_tlast[axis_pe_updt_idx]&i_axis_pe_updt_tvalid[axis_pe_updt_idx]) begin
                    tag_received_pe_updt[axis_pe_updt_idx] <= 1'b0;
                end
                else if (i_axis_pe_updt_tag_tready[axis_pe_updt_idx]&i_axis_pe_updt_tag_tvalid[axis_pe_updt_idx]) begin
                    tag_received_pe_updt[axis_pe_updt_idx] <= 1'b1;
                end
            end

            always_comb begin
                i_axis_pe_updt_tag_tready[axis_pe_updt_idx] = (~tag_received_pe_updt[axis_pe_updt_idx]);
            end

            always_ff @(posedge clk) begin
                if (~rst_n) begin
                    tag_eos[axis_pe_updt_idx] <= 1'b0;
                end
                else if (i_axis_pe_updt_tlast[axis_pe_updt_idx]&i_axis_pe_updt_tvalid[axis_pe_updt_idx]&
                        tag_eos[axis_pe_updt_idx]) begin
                    tag_eos[axis_pe_updt_idx] <= 1'b0;
                end
                else if (i_axis_pe_updt_tag_tready[axis_pe_updt_idx]&i_axis_pe_updt_tag_tvalid[axis_pe_updt_idx]&
                        i_axis_pe_updt_tag_tdata[axis_pe_updt_idx][56]) begin
                    tag_eos[axis_pe_updt_idx] <= 1'b1;
                end
            end

            always_ff @(posedge clk) begin
                if (~rst_n) begin
                    tag_eol[axis_pe_updt_idx] <= 1'b0;
                end
                else if (i_axis_pe_updt_tlast[axis_pe_updt_idx]&i_axis_pe_updt_tvalid[axis_pe_updt_idx]&
                        tag_eol[axis_pe_updt_idx]) begin
                    tag_eol[axis_pe_updt_idx] <= 1'b0;
                end
                else if (i_axis_pe_updt_tag_tready[axis_pe_updt_idx]&i_axis_pe_updt_tag_tvalid[axis_pe_updt_idx]&
                        i_axis_pe_updt_tag_tdata[axis_pe_updt_idx][58]) begin
                    tag_eol[axis_pe_updt_idx] <= 1'b1;
                end
            end

            always_ff @(posedge clk) begin
                if (~rst_n) begin
                    tag_eom[axis_pe_updt_idx] <= 1'b0;
                end
                else if (i_axis_pe_updt_tlast[axis_pe_updt_idx]&i_axis_pe_updt_tvalid[axis_pe_updt_idx]&
                        tag_eom[axis_pe_updt_idx]) begin
                    tag_eom[axis_pe_updt_idx] <= 1'b0;
                end
                else if (i_axis_pe_updt_tag_tready[axis_pe_updt_idx]&i_axis_pe_updt_tag_tvalid[axis_pe_updt_idx]&
                        i_axis_pe_updt_tag_tdata[axis_pe_updt_idx][59]) begin
                    tag_eom[axis_pe_updt_idx] <= 1'b1;
                end
            end
        end
    endgenerate

    logic updt_slot_done, updt_slot_done_p, updt_slot_done_r;
    always_comb begin
        updt_slot_done_p    =   (i_axis_pe_updt_tlast[0]&i_axis_pe_updt_tvalid[0]&tag_eos[0])|
                                (i_axis_pe_updt_tlast[1]&i_axis_pe_updt_tvalid[1]&tag_eos[1])|
                                (i_axis_pe_updt_tlast[2]&i_axis_pe_updt_tvalid[2]&tag_eos[2])|
                                (i_axis_pe_updt_tlast[3]&i_axis_pe_updt_tvalid[3]&tag_eos[3]);

    end
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_slot_done_r <= 1'b0;
        end else if (updt_slot_done_r & all_empty) begin
            updt_slot_done_r <= 1'b0;
        end else if (updt_slot_done_p) begin
            updt_slot_done_r <= 1'b1;
        end
    end
    always_comb begin
        updt_slot_done = updt_slot_done_r & all_empty;
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_slot_sel <= 1'b0;
        end else if (updt_slot_done) begin
            updt_slot_sel <= ~updt_slot_sel;
        end
    end

    logic tag_received;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            tag_received <= 1'b0;
        end else if (s_axis_int2pe_tlast & hs_axis_int2pe) begin
            tag_received <= 1'b0;
        end else if (hs_axis_int2pe_tag) begin
            tag_received <= 1'b1;
        end
    end

    // the data tready are all 1'b1 now
    always_comb begin
        i_axis_pe_updt_tready[0] = ~(i_axis_pe_updt_tag_tvalid[0] & i_axis_pe_updt_tag_tready[0]);
        i_axis_pe_updt_tready[1] = ~(i_axis_pe_updt_tag_tvalid[1] & i_axis_pe_updt_tag_tready[1]);
        i_axis_pe_updt_tready[2] = ~(i_axis_pe_updt_tag_tvalid[2] & i_axis_pe_updt_tag_tready[2]);
        i_axis_pe_updt_tready[3] = ~(i_axis_pe_updt_tag_tvalid[3] & i_axis_pe_updt_tag_tready[3]);
    end
    /**************************** fifo & data convert *******************************/

    /********************************* exec control *************************************/
    logic [                     9:0] abuf2rf_updt_idx    [2:0];
    logic [     RF_NUM_PER_ABUF-1:0] rf_updt_en;
    logic                            rf_updt_sel;
    logic                            rf_updt_addr_rst;
    // logic [RF_ADDR_WIDTH-1:0]        rf_updt_addr        [RF_NUM_PER_ABUF-1:0]   ;
    logic                            rf_exec_sel;
    logic [       RF_ADDR_WIDTH-1:0] rf_exec_addr;
    logic [WBUF_EXEC_ADDR_WIDTH-1:0] wbuf_exec_addr;
    logic [     PBUF_ADDR_WIDTH-1:0] pbuf_exec_rd_addr;
    logic                            pbuf_exec_wr_en;
    logic [     PBUF_ADDR_WIDTH-1:0] pbuf_exec_wr_addr;
    logic                            adder_rst_en;
    logic                            pbuf_exec_rd_rst_en;

    logic exec_slot_start, exec_slot_done;

    logic pbuf_wb_rvs;
    logic awbuf_updt_rvs;

    // start execution
    always_comb begin
        exec_slot_start = instr_dec_valid_ex;
        pbuf_wb_rvs     = pbuf_wb_rvs_r & exec_slot_done;
    end

    pe_ctrl_exec pe_ctrl_exec_inst (
        .clk(clk),
        .rst_n(rst_n),
        .abuf2rf_updt_idx(abuf2rf_updt_idx),
        .rf_updt_en(rf_updt_en),
        .rf_updt_sel(rf_updt_sel),
        .rf_updt_addr_rst(rf_updt_addr_rst),
        // .rf_updt_addr(rf_updt_addr),
        .rf_exec_sel(rf_exec_sel),
        .rf_exec_addr(rf_exec_addr),
        .wbuf_exec_addr(wbuf_exec_addr),
        .pbuf_exec_rd_addr(pbuf_exec_rd_addr),
        .pbuf_exec_wr_en(pbuf_exec_wr_en),
        .pbuf_exec_wr_addr(pbuf_exec_wr_addr),
        .F_LOOP_FACTORS(F_LOOP_FACTORS_EXEC),
        .Q_LOOP_FACTORS(Q_LOOP_FACTORS_EXEC),
        .P_LOOP_FACTORS(P_LOOP_FACTORS_EXEC),
        .STRPAD_FACTORS(STRPAD_FACTORS_EXEC),
        .WBUF_ADDR_SHAPE(WBUF_ADDR_SHAPE_EXEC),
        .PSUM_ADDR_SHAPE(PSUM_ADDR_SHAPE_EXEC),
        .exec_slot_start(exec_slot_start),
        .pbuf_exec_rd_rst_en(pbuf_exec_rd_rst_en),
        .adder_rst_en(adder_rst_en),
        .exec_slot_done(exec_slot_done),
        .w_addr_comp(w_addr_comp_exec),
        .tc_reset(tc_reset)
    );
    /********************************* exec control *************************************/

    /********************************* wb control *************************************/
    logic [PBUF_ADDR_WIDTH-1:0] pbuf_wb_addr;
    logic [  PBUF_DATA_NUM-1:0] pbuf_wb_valid;
    logic [                5:0] pbuf_wb_f_k;
    logic                       wb_tile_done;
    logic [               15:0] psum_channel;
    logic                       psum_wb_state;
    logic                       pe2lc_fifo_prog_full;

    // start write back
    logic                       wb_tile_start;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wb_tile_start <= 1'b0;
        end else begin
            wb_tile_start <= instr_dec_valid_wb;
        end
    end

    pe_ctrl_wb pe_ctrl_wb_inst (
        .clk(clk),
        .rst_n(rst_n),
        .pe2lc_fifo_prog_full(pe2lc_fifo_prog_full),
        .pbuf_wb_addr(pbuf_wb_addr),
        .pbuf_wb_valid(pbuf_wb_valid),
        .pbuf_wb_f_k(pbuf_wb_f_k),
        .wb_tile_start(wb_tile_start),
        .wb_tile_done(wb_tile_done),
        .psum_channel(psum_channel),
        .psum_wb_state(psum_wb_state),
        .F_LOOP_FACTORS_W(F_LOOP_FACTORS_WB[2]),
        .F_LOOP_FACTORS_H(F_LOOP_FACTORS_WB[1]),
        .F_LOOP_FACTORS_K(F_LOOP_FACTORS_WB[0]),
        .PQ_LOOP_FACTORS_W(PQ_LOOP_FACTORS_WB[2]),
        .PQ_LOOP_FACTORS_H(PQ_LOOP_FACTORS_WB[1]),
        .PQ_LOOP_FACTORS_K(PQ_LOOP_FACTORS_WB[0]),
        .r_k(r_k),
        .r_h(r_h),
        .r_w(r_w),
        .psum_channel_start(psum_channel_start)
    );
    /********************************* wb control *************************************/

    /********************************* pe array *************************************/
    logic [3:0] hs_i_axis_pe_updt_tag;
    logic [3:0] hs_i_axis_pe_updt;
    generate
        for (axis_pe_updt_idx = 0; axis_pe_updt_idx < 4; axis_pe_updt_idx++) begin
            always_comb begin
                hs_i_axis_pe_updt_tag[axis_pe_updt_idx] = i_axis_pe_updt_tag_tvalid[axis_pe_updt_idx]&i_axis_pe_updt_tag_tready[axis_pe_updt_idx];
                hs_i_axis_pe_updt[axis_pe_updt_idx]     = i_axis_pe_updt_tvalid[axis_pe_updt_idx]&i_axis_pe_updt_tready[axis_pe_updt_idx];
            end
        end
    endgenerate

    (* dont_touch = "yes" *) logic [PBUF_DATA_WIDTH-1:0] pe_pbuf_wb_data [PARAM_PE_NUM-1:0] [PBUF_DATA_NUM-1:0];

    logic [PE_UPDT_DATA_WIDTH-1:0] pe_updt_data_fake[3:0];
    logic [MM2S_TAG_WIDTH-1:0] pe_updt_data_tag_fake[3:0];

    generate
        for (axis_pe_updt_idx = 0; axis_pe_updt_idx < 4; axis_pe_updt_idx++) begin
            always_ff @(posedge clk) begin
                if (hs_i_axis_pe_updt[axis_pe_updt_idx]) begin
                    pe_updt_data_fake[axis_pe_updt_idx] <= i_axis_pe_updt_tdata[axis_pe_updt_idx];
                end
            end
            always_ff @(posedge clk) begin
                if (hs_i_axis_pe_updt_tag[axis_pe_updt_idx]) begin
                    pe_updt_data_tag_fake[axis_pe_updt_idx] <= i_axis_pe_updt_tag_tdata[axis_pe_updt_idx];
                end
            end
        end
    endgenerate
    // timing optimization delay chain
    (* dont_touch = "yes" *)logic [  PE_UPDT_DATA_WIDTH-1:0] pe_updt_data_pe       [PARAM_PE_NUM-1:0] [3:0];
    (* dont_touch = "yes" *)logic [PE_UPDT_DATA_WIDTH/8-1:0] pe_updt_data_keep_pe  [PARAM_PE_NUM-1:0] [3:0];
    (* dont_touch = "yes" *)logic [                     3:0] pe_updt_data_last_pe  [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic [                     3:0] pe_updt_valid_pe      [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic [      MM2S_TAG_WIDTH-1:0] pe_updt_tag_pe        [PARAM_PE_NUM-1:0] [3:0];
    (* dont_touch = "yes" *)logic [                     3:0] pe_updt_tag_valid_pe  [PARAM_PE_NUM-1:0];

    (* dont_touch = "yes" *)logic [                     9:0] abuf2rf_updt_idx_pe   [PARAM_PE_NUM-1:0] [2:0];
    (* dont_touch = "yes" *)logic [     RF_NUM_PER_ABUF-1:0] rf_updt_en_pe         [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic                            rf_updt_sel_pe        [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic                            rf_updt_addr_rst_pe   [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic                            rf_exec_sel_pe        [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic [       RF_ADDR_WIDTH-1:0] rf_exec_addr_pe       [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic [WBUF_EXEC_ADDR_WIDTH-1:0] wbuf_exec_addr_pe     [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic [     PBUF_ADDR_WIDTH-1:0] pbuf_exec_rd_addr_pe  [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic                            pbuf_exec_wr_en_pe    [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic [     PBUF_ADDR_WIDTH-1:0] pbuf_exec_wr_addr_pe  [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic                            adder_rst_en_pe       [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic                            pbuf_exec_rd_rst_en_pe[PARAM_PE_NUM-1:0];

    (* dont_touch = "yes" *)logic [     PBUF_ADDR_WIDTH-1:0] pbuf_wb_addr_pe       [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic [                     5:0] pbuf_wb_f_k_pe        [PARAM_PE_NUM-1:0];
    (* dont_touch = "yes" *)logic                            awbuf_updt_rvs_pe     [PARAM_PE_NUM-1:0];

    generate
        for (pe_idx = 0; pe_idx < PARAM_PE_NUM; pe_idx++) begin
            always_ff @(posedge clk) begin
                pe_updt_data_pe[pe_idx]        <= i_axis_pe_updt_tdata;
                pe_updt_data_keep_pe[pe_idx]   <= i_axis_pe_updt_tkeep;
                pe_updt_data_last_pe[pe_idx]   <= i_axis_pe_updt_tlast;
                pe_updt_valid_pe[pe_idx]       <= hs_i_axis_pe_updt;
                pe_updt_tag_pe[pe_idx]         <= i_axis_pe_updt_tag_tdata;
                pe_updt_tag_valid_pe[pe_idx]   <= hs_i_axis_pe_updt_tag;
                abuf2rf_updt_idx_pe[pe_idx][2] <= abuf2rf_updt_idx[2];
                abuf2rf_updt_idx_pe[pe_idx][1] <= abuf2rf_updt_idx[1];
                abuf2rf_updt_idx_pe[pe_idx][0] <= abuf2rf_updt_idx[0];
                rf_updt_en_pe[pe_idx]          <= rf_updt_en;
                rf_updt_sel_pe[pe_idx]         <= rf_updt_sel;
                rf_updt_addr_rst_pe[pe_idx]    <= rf_updt_addr_rst;
                rf_exec_sel_pe[pe_idx]         <= rf_exec_sel;
                rf_exec_addr_pe[pe_idx]        <= rf_exec_addr;
                wbuf_exec_addr_pe[pe_idx]      <= wbuf_exec_addr;
                pbuf_exec_rd_addr_pe[pe_idx]   <= pbuf_exec_rd_addr;
                pbuf_exec_wr_en_pe[pe_idx]     <= pbuf_exec_wr_en;
                pbuf_exec_wr_addr_pe[pe_idx]   <= pbuf_exec_wr_addr;
                adder_rst_en_pe[pe_idx]        <= adder_rst_en;
                pbuf_exec_rd_rst_en_pe[pe_idx] <= pbuf_exec_rd_rst_en;
                pbuf_wb_addr_pe[pe_idx]        <= pbuf_wb_addr;
                // pbuf_wb_valid_pe[pe_idx]        <= pbuf_wb_valid;
                pbuf_wb_f_k_pe[pe_idx]         <= pbuf_wb_f_k;
                awbuf_updt_rvs_pe[pe_idx]      <= awbuf_updt_rvs;
            end
        end
    endgenerate

    generate
        for (pe_idx = 0; pe_idx < PARAM_PE_NUM; pe_idx++) begin
            pe pe_inst (
                // common signal 
                .clk                  (clk),
                .rst_n                (rst_n),
                // pe config information (decoded from instructions)
                .pe_config_updt       (pe_config_updt[pe_idx]),
                .s_k_index_config_updt(s_k_index_config_updt),
                .s_c_index_config_updt(s_c_index_config_updt),
                .s_h_index_config_updt(s_h_index_config_updt),
                .s_w_index_config_updt(s_w_index_config_updt),
                .pe_config_exec       (pe_config_exec[pe_idx]),
                .s_k_index_config_exec(s_k_index_config_exec),
                .s_c_index_config_exec(s_c_index_config_exec),
                .s_h_index_config_exec(s_h_index_config_exec),
                .s_w_index_config_exec(s_w_index_config_exec),
                .pe_config_wb         (pe_config_wb[pe_idx]),
                .s_k_index_config_wb  (s_k_index_config_wb),
                .s_c_index_config_wb  (s_c_index_config_wb),
                .s_h_index_config_wb  (s_h_index_config_wb),
                .s_w_index_config_wb  (s_w_index_config_wb),
                // 0- macc; 1- max pooling
                .comp_type            (comp_type_exec),
                // 0- weights are from buffer (conv); 1- weights are fixed (pooling)   
                .w_fixed              (w_fixed_exec),
                // pe idle state, 1 - idle (will not execution, update and wb whatever s index)
                .pe_idle_state_updt   (pe_idle_state_config_updt),
                .pe_idle_state_wb     (pe_idle_state_config_wb),
                // pe update input data and tag (act and w)
                .pe_updt_data         (pe_updt_data_pe[pe_idx]),
                .pe_updt_data_keep    (pe_updt_data_keep_pe[pe_idx]),
                .pe_updt_data_last    (pe_updt_data_last_pe[pe_idx]),
                .pe_updt_valid        (pe_updt_valid_pe[pe_idx]),
                .pe_updt_tag          (pe_updt_tag_pe[pe_idx]),
                .pe_updt_tag_valid    (pe_updt_tag_valid_pe[pe_idx]),
                .awbuf_updt_rvs       (awbuf_updt_rvs_pe[pe_idx]),
                // update rf
                .abuf2rf_updt_idx     (abuf2rf_updt_idx_pe[pe_idx]),
                .rf_updt_en           (rf_updt_en_pe[pe_idx]),
                .rf_updt_sel          (rf_updt_sel_pe[pe_idx]),
                .rf_updt_addr_rst     (rf_updt_addr_rst_pe[pe_idx]),
                // .rf_updt_addr       (rf_updt_addr                ),
                // execute rf
                .rf_exec_sel          (rf_exec_sel_pe[pe_idx]),
                .rf_exec_addr         (rf_exec_addr_pe[pe_idx]),
                // execute wbuf 
                .wbuf_exec_addr       (wbuf_exec_addr_pe[pe_idx]),
                // execute pbuf
                .pbuf_exec_rd_addr    (pbuf_exec_rd_addr_pe[pe_idx]),
                .pbuf_exec_wr_en      (pbuf_exec_wr_en_pe[pe_idx]),
                .pbuf_exec_wr_addr    (pbuf_exec_wr_addr_pe[pe_idx]),
                // control signals for exec
                .s_k_index_exec       (ex_s_idx_k),
                .s_c_index_exec       (ex_s_idx_c),
                .s_h_index_exec       (ex_s_idx_h),
                .s_w_index_exec       (ex_s_idx_w),
                // control signals for cu
                .adder_rst_en         (adder_rst_en_pe[pe_idx]),
                .pbuf_exec_rd_rst_en  (pbuf_exec_rd_rst_en_pe[pe_idx]),
                // wb pbuf
                .pbuf_wb_rvs          (pbuf_wb_rvs),
                .pbuf_wb_addr         (pbuf_wb_addr_pe[pe_idx]),
                .pbuf_wb_f_k          (pbuf_wb_f_k_pe[pe_idx]),
                // .pbuf_wb_valid      (pbuf_wb_valid_pe[pe_idx]       ),
                .wb_s_idx_k           (wb_s_idx_k),
                .wb_s_idx_h           (wb_s_idx_h),
                .wb_s_idx_w           (wb_s_idx_w),
                .pbuf_wb_data         (pe_pbuf_wb_data[pe_idx])
            );
        end
    endgenerate
    genvar pbuf_wb_num_idx;
    // generate
    //     for (pe_idx = 0; pe_idx < PARAM_PE_NUM; pe_idx++) begin
    //         for (pbuf_wb_num_idx = 0; pbuf_wb_num_idx < PBUF_DATA_NUM; pbuf_wb_num_idx++) begin
    //             always_ff @(posedge clk) begin
    //                 pe_pbuf_wb_data[pe_idx][pbuf_wb_num_idx][15:12] <= pe_idx;
    //                 pe_pbuf_wb_data[pe_idx][pbuf_wb_num_idx][11:8]  <= pbuf_wb_num_idx;
    //                 pe_pbuf_wb_data[pe_idx][pbuf_wb_num_idx][7:4]   <= pbuf_wb_f_k[3:0];
    //                 pe_pbuf_wb_data[pe_idx][pbuf_wb_num_idx][3:0]   <= pbuf_wb_addr[3:0];
    //             end
    //         end
    //     end
    // endgenerate
    /********************************* pe array *************************************/

    /************* synchronization of update, execution and write back **************/
    // busy and flag will decide currently if it can start tready
    logic updt_busy, exec_busy, wb_busy;
    logic updt_flag, exec_flag, wb_flag;
    // updt_exec_sync: used for update start
    // wb_exec_sync: used for wb start
    // tri_sync: used for exec start 
    // all the start signals are for "xx_tready signals"
    logic updt_exec_sync, wb_exec_sync, tri_sync;

    logic wb_end_of_slot, end_of_layer;
    logic updt_end_of_layer, exec_end_of_layer;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            end_of_layer <= 1'b0;
        end else if (end_of_layer) begin
            end_of_layer <= 1'b0;
        end else if (wb_tile_done & wb_eol) begin
            end_of_layer <= 1'b1;
        end
    end

    logic updt_end_of_layer_p, updt_end_of_layer_r;
    always_comb begin
        updt_end_of_layer_p =   (i_axis_pe_updt_tlast[0]&i_axis_pe_updt_tvalid[0]&tag_eol[0])|
                                (i_axis_pe_updt_tlast[1]&i_axis_pe_updt_tvalid[1]&tag_eol[1])|
                                (i_axis_pe_updt_tlast[2]&i_axis_pe_updt_tvalid[2]&tag_eol[2])|
                                (i_axis_pe_updt_tlast[3]&i_axis_pe_updt_tvalid[3]&tag_eol[3]);
    end
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_end_of_layer_r <= 1'b0;
        end else if (updt_end_of_layer_r & all_empty) begin
            updt_end_of_layer_r <= 1'b0;
        end else if (updt_end_of_layer_p) begin
            updt_end_of_layer_r <= 1'b1;
        end
    end
    always_comb begin
        updt_end_of_layer = updt_end_of_layer_r & all_empty;
    end

    logic updt_end_of_layer_temp;
    always_comb begin
        updt_end_of_layer_temp  =   (tag_eol[0]&(~tag_eom[0]))|
                                    (tag_eol[1]&(~tag_eom[1]))|
                                    (tag_eol[2]&(~tag_eom[2]))|
                                    (tag_eol[3]&(~tag_eom[3]));

    end

    always_comb begin
        exec_end_of_layer = exec_instr_eol & exec_slot_done;
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wb_end_of_slot <= 1'b0;
        end else if (end_of_layer) begin
            wb_end_of_slot <= 1'b0;
        end else if (wb_end_of_slot) begin
            wb_end_of_slot <= 1'b0;
        end else if (wb_tile_done & wb_eos) begin
            wb_end_of_slot <= 1'b1;
        end
    end

    // logic normal_operation;
    // always_ff @( posedge clk ) begin
    //     if (~rst_n) begin
    //         normal_operation <= 1'b0;
    //     end
    //     else if (end_of_layer) begin
    //         normal_operation <= 1'b0;
    //     end
    //     else if (hs_i_axis_pe_conf_instr&(param_type_exec == 3'b101)) begin
    //         normal_operation <= 1'b1;
    //     end
    // end

    logic updt_param_sts, exec_param_sts, wb_param_sts;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_param_sts <= 1'b1;
        end else if (hs_i_axis_updt_instr & i_axis_updt_instr_tdata[59]) begin
            updt_param_sts <= 1'b0;
        end else if (updt_end_of_layer) begin
            updt_param_sts <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wb_param_sts <= 1'b1;
        end  // it is the last configuatation instruction of execution channel
        else if (hs_i_axis_wb_instr & (~instr_type_wb) & (param_type_wb == 3'b101)) begin
            wb_param_sts <= 1'b0;
        end else if (end_of_layer) begin
            wb_param_sts <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            exec_param_sts <= 1'b1;
        end  // it is the last configuatation instruction of execution channel
        else if (hs_i_axis_exec_instr & (~instr_type_exec) & (param_type_exec == 3'b101)) begin
            exec_param_sts <= 1'b0;
        end else if (exec_end_of_layer) begin
            exec_param_sts <= 1'b1;
        end
    end

    logic first_exec, first_exec_slot_done;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            first_exec <= 1'b0;
        end else if (exec_end_of_layer) begin
            first_exec <= 1'b0;
        end else if (exec_slot_done) begin
            first_exec <= 1'b1;
        end
    end
    always_comb begin
        first_exec_slot_done = (~first_exec) & exec_slot_done;
    end

    logic rvs_wb_exec_sync;
    always_comb begin
        rvs_wb_exec_sync = pbuf_wb_rvs_r & wb_exec_sync;
    end

    logic wb_allowed;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wb_allowed <= 1'b0;
        end else if (wb_end_of_slot) begin
            wb_allowed <= 1'b0;
        end else if (rvs_wb_exec_sync) begin
            wb_allowed <= 1'b1;
        end
    end

    always_comb begin
        updt_exec_sync = (~updt_busy) & (~exec_busy) & (updt_flag ^ exec_flag);
        wb_exec_sync = (~wb_busy) & (~exec_busy) & (wb_flag ^ exec_flag);
        tri_sync        =   ((~updt_busy)&(~exec_busy)&(~wb_busy))|
                            ((~updt_busy)&(~exec_busy)&(~wb_flag^exec_flag))|
                            ((~wb_busy)&(~exec_busy)&(~updt_flag^exec_flag));
    end

    logic updt_sts_eol;
    logic updt_real_slot_done, exec_real_slot_done, wb_real_slot_done;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_sts_eol <= 1'b0;
        end else if (hs_i_axis_updt_instr & i_axis_updt_instr_tdata[59]) begin
            updt_sts_eol <= 1'b0;
        end else if (updt_end_of_layer_temp) begin
            updt_sts_eol <= 1'b1;
        end
    end

    always_comb begin
        updt_real_slot_done = (updt_slot_done & (~updt_sts_eol)) | (updt_sts_eol & hs_i_axis_updt_instr & i_axis_updt_instr_tdata[59]);
        exec_real_slot_done = (exec_slot_done & (~exec_instr_eol)) | (exec_instr_eol & hs_i_axis_exec_instr & (~instr_type_exec) & (param_type_exec == 3'b101));
        wb_real_slot_done   = (wb_end_of_slot & (~wb_eol)) | (wb_eol & hs_i_axis_wb_instr & (~instr_type_wb) & (param_type_wb == 3'b101));
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_busy <= 1'b1;
        end else if (updt_exec_sync) begin
            updt_busy <= 1'b1;
        end else if (updt_real_slot_done) begin
            updt_busy <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            exec_busy <= 1'b0;
        end else if (tri_sync) begin
            exec_busy <= 1'b1;
        end else if (exec_real_slot_done) begin
            exec_busy <= 1'b0;
        end
    end

    // always_ff @(posedge clk) begin
    //     if (~rst_n) begin
    //         wb_busy <= 1'b1;
    //     end else if (first_exec_slot_done) begin
    //         wb_busy <= 1'b0;
    //     end else if (rvs_wb_exec_sync) begin
    //         wb_busy <= 1'b1;
    //     end else if (wb_real_slot_done) begin
    //         wb_busy <= 1'b0;
    //     end
    // end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wb_busy <= 1'b0;
        end else if (rvs_wb_exec_sync) begin
            wb_busy <= 1'b1;
        end else if (wb_real_slot_done) begin
            wb_busy <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_flag <= 1'b0;
        end else if (updt_exec_sync) begin
            updt_flag <= ~updt_flag;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            exec_flag <= 1'b1;
        end else if (tri_sync) begin
            exec_flag <= ~exec_flag;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wb_flag <= 1'b1;
        end else if (wb_exec_sync) begin
            wb_flag <= ~wb_flag;
        end
    end

    always_comb begin
        s_axis_int2pe_tready     =  (~hs_axis_int2pe_tag) & updt_busy & (pe_updt_sel != 4'b0000)&(updt_slot_sel == updt_slot_sel_r);
        s_axis_int2pe_tag_tready = updt_busy & (~tag_received) & (pe_updt_sel != 4'b0000);
        // s_axis_int2pe_tag_tready = updt_busy&(~tag_received);
    end

    always_comb begin
        i_axis_updt_instr_tready = updt_param_sts;
    end

    logic i_axis_exec_instr_tready_t, i_axis_wb_instr_tready_t;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            i_axis_exec_instr_tready_t <= 1'b0;
        end else if (hs_i_axis_exec_instr & (~exec_param_sts)) begin
            i_axis_exec_instr_tready_t <= 1'b0;
        end else if (tri_sync & (~exec_param_sts)) begin
            i_axis_exec_instr_tready_t <= 1'b1;
        end
    end

    always_comb begin
        i_axis_exec_instr_tready = exec_param_sts | i_axis_exec_instr_tready_t;
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            i_axis_wb_instr_tready_t <= 1'b0;
        end else if (hs_i_axis_wb_instr & (~wb_param_sts)) begin
            i_axis_wb_instr_tready_t <= 1'b0;
        end
        else if ((wb_allowed|rvs_wb_exec_sync)&(wb_exec_sync|(wb_busy&wb_tile_done&(~wb_eos)))) begin
            i_axis_wb_instr_tready_t <= 1'b1;
        end
    end

    always_comb begin
        i_axis_wb_instr_tready = wb_param_sts | i_axis_wb_instr_tready_t;
    end

    always_comb begin
        awbuf_updt_rvs = updt_exec_sync;
    end

    /************* synchronization of update, execution and write back **************/

    /******************************** adder tree ************************************/
    logic signed [PBUF_DATA_WIDTH-1:0] psum_adder_input_data [PBUF_DATA_NUM-1:0] [PARAM_PE_NUM-1:0];
    logic signed [PBUF_DATA_WIDTH-1:0] psum_adder_output_data[PBUF_DATA_NUM-1:0];

    generate
        for (pbuf_wb_num_idx = 0; pbuf_wb_num_idx < PBUF_DATA_NUM; pbuf_wb_num_idx++) begin
            for (pe_idx = 0; pe_idx < PARAM_PE_NUM; pe_idx++) begin
                always_ff @(posedge clk) begin
                    psum_adder_input_data[pbuf_wb_num_idx][pe_idx] <= pe_pbuf_wb_data[pe_idx][pbuf_wb_num_idx];
                end
                // always_comb begin
                //     psum_adder_input_data[pbuf_wb_num_idx][pe_idx] = pe_pbuf_wb_data[pe_idx][pbuf_wb_num_idx];
                // end
            end
        end
    endgenerate
    // PBUF_DATA_NUM == AH*AW
    generate
        for (pbuf_wb_num_idx = 0; pbuf_wb_num_idx < PBUF_DATA_NUM; pbuf_wb_num_idx++) begin
            adder_tree #(
                .DATA_WIDTH(PBUF_DATA_WIDTH),
                .INPUT_NUM (PARAM_PE_NUM)
            ) psum_adder (
                .clk(clk),
                .rst(~rst_n),
                .en_advance(1'b1),
                .adder_in(psum_adder_input_data[pbuf_wb_num_idx]),
                .adder_out(psum_adder_output_data[pbuf_wb_num_idx])
            );
        end
    endgenerate
    /******************************** adder tree ************************************/

    /******************************** batch norm ************************************/
    logic                              fout_result_valid;
    logic                              bn_result_valid;
    logic        [               15:0] fout_channel;
    logic signed [PBUF_DATA_WIDTH-1:0] bn_output_data    [PBUF_DATA_NUM-1:0];
    logic                              bn_enable_layer_r;

    delay_chain #(
        .DW (1),
        .LEN($clog2(PARAM_PE_NUM) + 1)
    ) delay_fout_result_valid (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (psum_wb_state),
        .out(fout_result_valid)
    );

    // fout channel information should be earlier 1 cycle since bram needs 1 cycle to read
    delay_chain #(
        .DW (16),
        .LEN(($clog2(PARAM_PE_NUM)) + 3)
    ) delay_fout_channel (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (psum_channel),
        .out(fout_channel)
    );

    bn bn_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_int2bn_tready(s_axis_int2bn_tready),
        .s_axis_int2bn_tvalid(s_axis_int2bn_tvalid),
        .s_axis_int2bn_tdata(s_axis_int2bn_tdata),
        .s_axis_int2bn_tkeep(s_axis_int2bn_tkeep),
        .s_axis_int2bn_tlast(s_axis_int2bn_tlast),
        .s_axis_int2bn_tag_tready(s_axis_int2bn_tag_tready),
        .s_axis_int2bn_tag_tvalid(s_axis_int2bn_tag_tvalid),
        .s_axis_int2bn_tag_tdata(s_axis_int2bn_tag_tdata),
        .s_axis_int2bn_tag_tkeep(s_axis_int2bn_tag_tkeep),
        .s_axis_int2bn_tag_tlast(s_axis_int2bn_tag_tlast),
        .fout_channel(fout_channel),
        .bn_input_data(psum_adder_output_data),
        .bn_output_data(bn_output_data),
        .fout_result_valid(fout_result_valid),
        .bn_result_valid(bn_result_valid),
        .bn_enable_layer(bn_enable_layer)
    );

    /******************************** batch norm ************************************/

    /******************************* quantization ***********************************/
    logic [ABUF_DATA_WIDTH-1:0] quantization_data  [PBUF_DATA_NUM-1:0];
    logic                       quant_result_valid;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            quant_result_valid <= 1'b0;
        end else begin
            quant_result_valid <= bn_result_valid;
        end
    end

    generate
        for (pbuf_wb_num_idx = 0; pbuf_wb_num_idx < PBUF_DATA_NUM; pbuf_wb_num_idx++) begin
            always_ff @(posedge clk) begin
                // quantization_data[pbuf_wb_num_idx] <= bn_output_data[pbuf_wb_num_idx][12:5];
                quantization_data[pbuf_wb_num_idx] <= bn_output_data[pbuf_wb_num_idx][ABUF_DATA_WIDTH-1:0];
            end
        end
    endgenerate
    /******************************* quantization ***********************************/

    /****************************** transfer stream **********************************/
    // insert a stream-fifo to avoid stuck
    // MAKE SURE that PE_LC_DATA_WIDTH/8 == PBUF_DATA_NUM
    logic [  PE_LC_DATA_WIDTH-1:0] i_axis_pe2lc_buf_tdata;
    logic                          i_axis_pe2lc_buf_tvalid;
    logic                          i_axis_pe2lc_buf_tready;
    logic [PE_LC_DATA_WIDTH/8-1:0] i_axis_pe2lc_buf_tkeep;
    logic                          i_axis_pe2lc_buf_tlast;

    always_comb begin
        i_axis_pe2lc_buf_tvalid = quant_result_valid;
    end

    generate
        for (pbuf_wb_num_idx = 0; pbuf_wb_num_idx < PBUF_DATA_NUM; pbuf_wb_num_idx++) begin
            always_comb begin
                i_axis_pe2lc_buf_tdata[(pbuf_wb_num_idx+1)*ABUF_DATA_WIDTH-1:pbuf_wb_num_idx*ABUF_DATA_WIDTH] = 
                        quantization_data[pbuf_wb_num_idx];
            end
        end
    endgenerate

    delay_chain #(
        .DW (PBUF_DATA_NUM),
        .LEN($clog2(PARAM_PE_NUM) + 4)
    ) delay_pe2lc_buf_tkeep (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (pbuf_wb_valid),
        .out(i_axis_pe2lc_buf_tkeep)
    );

    delay_chain #(
        .DW (1),
        .LEN($clog2(PARAM_PE_NUM) + 4)
    ) delay_pe2lc_buf_tlast (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (wb_tile_done),
        .out(i_axis_pe2lc_buf_tlast)
    );

    // fifo_axis_sync #(
    //     .FIFO_AXIS_DEPTH(8192),
    //     .FIFO_AXIS_TDATA_WIDTH(PE_LC_DATA_WIDTH)
    // ) fifo_axis_pe2lc (
    //     .clk(clk),
    //     .rst_n(rst_n),
    //     .m_axis_tready(m_axis_pe2lc_tready),
    //     .m_axis_tvalid(m_axis_pe2lc_tvalid),
    //     .m_axis_tdata(m_axis_pe2lc_tdata),
    //     .m_axis_tkeep(m_axis_pe2lc_tkeep),
    //     .m_axis_tlast(m_axis_pe2lc_tlast),
    //     .s_axis_tready(i_axis_pe2lc_buf_tready),
    //     .s_axis_tvalid(i_axis_pe2lc_buf_tvalid),
    //     .s_axis_tdata(i_axis_pe2lc_buf_tdata),
    //     .s_axis_tkeep(i_axis_pe2lc_buf_tkeep),
    //     .s_axis_tlast(i_axis_pe2lc_buf_tlast)
    // );

    fifo_axis #(
        .FIFO_AXIS_DEPTH(1024),
        .FIFO_AXIS_TDATA_WIDTH(PE_LC_DATA_WIDTH),
        .FIFO_ADV_FEATURES("1416"),
        .FIFO_PROG_FULL_THRESH(1000)
    ) fifo_axis_pe2lc (
        .clk(clk),
        .rst_n(rst_n),
        .prog_full_axis(pe2lc_fifo_prog_full),
        .m_axis_tready(m_axis_pe2lc_tready),
        .m_axis_tvalid(m_axis_pe2lc_tvalid),
        .m_axis_tdata(m_axis_pe2lc_tdata),
        .m_axis_tkeep(m_axis_pe2lc_tkeep),
        .m_axis_tlast(m_axis_pe2lc_tlast),
        .s_axis_tready(i_axis_pe2lc_buf_tready),
        .s_axis_tvalid(i_axis_pe2lc_buf_tvalid),
        .s_axis_tdata(i_axis_pe2lc_buf_tdata),
        .s_axis_tkeep(i_axis_pe2lc_buf_tkeep),
        .s_axis_tlast(i_axis_pe2lc_buf_tlast)
    );

    /****************************** transfer stream **********************************/

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            m_axis_eolfb_tvalid <= 1'b0;
        end else if (m_axis_eolfb_tvalid & m_axis_eolfb_tready) begin
            m_axis_eolfb_tvalid <= 1'b0;
        end else if (end_of_layer) begin
            m_axis_eolfb_tvalid <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            m_axis_eolfb_tdata <= 1'b0;
        end else if (m_axis_eolfb_tvalid & m_axis_eolfb_tready) begin
            m_axis_eolfb_tdata <= 1'b0;
        end else if (end_of_layer) begin
            m_axis_eolfb_tdata <= 1'b1;
        end
    end

    logic [19:0] cnt_pe2lc_fifo_prog_full;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            cnt_pe2lc_fifo_prog_full <= 0;
        end else if (pe2lc_fifo_prog_full) begin
            cnt_pe2lc_fifo_prog_full <= cnt_pe2lc_fifo_prog_full + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            status[0] <= 32'h0;
        end else begin
            // status[0][31: 16]    <= hs_i_axis_exec_instr   ? status[0][31: 16]+1 : status[0][31: 16];
            // status[0][15: 0]     <= hs_i_axis_wb_instr     ? status[0][ 15: 0]+1 : status[0][ 15: 0];
            status[0][31:12] <= cnt_pe2lc_fifo_prog_full;
            status[0][11:0]  <= updt_slot_done ? status[0][11:0] + 1 : status[0][11:0];
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            status[1] <= 32'h0;
        end else begin
            status[1][31:16] <= wb_tile_done ? status[1][31:16] + 1 : status[1][31:16];
            status[1][15:0]  <= exec_slot_done ? status[1][15:0] + 1 : status[1][15:0];
        end
    end

    // count the cycles of read and wb
    logic updt_proc, wb_proc;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_proc <= 1'b0;
        end else if (updt_eol) begin
            updt_proc <= 1'b0;
        end else if (hs_axis_int2pe_tag) begin
            updt_proc <= 1'b1;
        end
    end
    assign updt_status = updt_proc;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wb_proc <= 1'b0;
        end else if (end_of_layer) begin
            wb_proc <= 1'b0;
        end else if (hs_i_axis_wb_instr) begin
            wb_proc <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            status[2] <= 32'h0;
        end else begin
            // status[2]               <= updt_busy&updt_proc   ? status[2]+1 : status[2];
            status[2] <= end_of_layer ? status[2] + 1 : status[2];
            // status[2][16]        <= updt_busy;
            // status[2][17]        <= exec_busy;
            // status[2][18]        <= wb_busy;
            // status[2][19]        <= updt_flag;
            // status[2][20]        <= exec_flag;
            // status[2][21]        <= wb_flag;
            // status[2][30:22]     <= 0;
            // status[2][31]        <= end_of_layer;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            status[3] <= 32'h0;
        end else begin
            // status[3]               <= (m_axis_pe2lc_tready&m_axis_pe2lc_tvalid&m_axis_pe2lc_tlast)? status[3]+1 : status[3];
            status[3] <= (m_axis_eolfb_tvalid & m_axis_eolfb_tready) ? status[3] + 1 : status[3];
            // status[2][16]        <= updt_busy;
            // status[2][17]        <= exec_busy;
            // status[2][18]        <= wb_busy;
            // status[2][19]        <= updt_flag;
            // status[2][20]        <= exec_flag;
            // status[2][21]        <= wb_flag;
            // status[2][30:22]     <= 0;
            // status[2][31]        <= end_of_layer;
        end
    end

endmodule
