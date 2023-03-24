`timescale 1ns / 1ps

`include "def.sv"

(* keep_hierarchy = "yes" *) module pe #(
    parameter PE_UPDT_DATA_WIDTH = `DFLT_PE_UPDT_DATA_WIDTH,
    parameter MM2S_TAG_WIDTH     = `DFLT_MEM_TAG_WIDTH,

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

    parameter PBUF_NUM          = `PARAM_PBUF_NUM,
    parameter BRAM_NUM_PER_PBUF = `PARAM_BRAM_NUM_PER_PBUF,
    parameter PBUF_ADDR_WIDTH   = `PARAM_PBUF_ADDR_WIDTH,
    parameter PBUF_DATA_WIDTH   = `PARAM_PBUF_DATA_WIDTH,
    parameter PBUF_DATA_NUM     = `PARAM_PBUF_DATA_NUM,

    parameter RF_NUM          = `PARAM_RF_NUM,
    parameter RF_NUM_PER_ABUF = `PARAM_RF_NUM_PER_ABUF,
    parameter RF_ADDR_WIDTH   = `PARAM_RF_ADDR_WIDTH,
    parameter RF_DATA_WIDTH   = `PARAM_RF_DATA_WIDTH,

    parameter PARAM_A_K = `HW_CONFIG_A_K,
    parameter PARAM_A_C = `HW_CONFIG_A_C,
    parameter PARAM_A_H = `HW_CONFIG_A_H,
    parameter PARAM_A_W = `HW_CONFIG_A_W,
    parameter PARAM_A_I = `HW_CONFIG_A_I,
    parameter PARAM_A_J = `HW_CONFIG_A_J
) (
    // common signal 
    input  logic                            clk,
    input  logic                            rst_n,
    // pe config information (decoded from instructions)
    input  logic                            pe_config_updt,
    input  logic [                     5:0] s_k_index_config_updt,
    input  logic [                     5:0] s_c_index_config_updt,
    input  logic [                     3:0] s_h_index_config_updt,
    input  logic [                     3:0] s_w_index_config_updt,
    input  logic                            pe_config_exec,
    input  logic [                     5:0] s_k_index_config_exec,
    input  logic [                     5:0] s_c_index_config_exec,
    input  logic [                     3:0] s_h_index_config_exec,
    input  logic [                     3:0] s_w_index_config_exec,
    input  logic                            pe_config_wb,
    input  logic [                     5:0] s_k_index_config_wb,
    input  logic [                     5:0] s_c_index_config_wb,
    input  logic [                     3:0] s_h_index_config_wb,
    input  logic [                     3:0] s_w_index_config_wb,
    // 0- macc; 1- max pooling
    input  logic                            comp_type,
    // 0- weights are from buffer (conv); 1- weights are fixed (pooling)   
    input  logic                            w_fixed,
    // pe idle state, 0 - idle (will not execution, update and wb whatever s index)
    input  logic                            pe_idle_state_updt,
    input  logic                            pe_idle_state_wb,
    // pe update input data and tag (act and w)
    input  logic [  PE_UPDT_DATA_WIDTH-1:0] pe_updt_data         [              3:0],
    input  logic [PE_UPDT_DATA_WIDTH/8-1:0] pe_updt_data_keep    [              3:0],
    input  logic [                     3:0] pe_updt_data_last,
    input  logic [                     3:0] pe_updt_valid,
    input  logic [      MM2S_TAG_WIDTH-1:0] pe_updt_tag          [              3:0],
    input  logic [                     3:0] pe_updt_tag_valid,
    input  logic                            awbuf_updt_rvs,
    // execute abuf
    input  logic [                     9:0] abuf2rf_updt_idx     [              2:0],
    // update rf
    input  logic [     RF_NUM_PER_ABUF-1:0] rf_updt_en,
    input  logic                            rf_updt_sel,
    input  logic                            rf_updt_addr_rst,
    // input  logic [RF_ADDR_WIDTH-1:0]        rf_updt_addr        [RF_NUM_PER_ABUF-1:0]   ,
    // execute rf
    input  logic                            rf_exec_sel,
    input  logic [       RF_ADDR_WIDTH-1:0] rf_exec_addr,
    // execute wbuf 
    input  logic [WBUF_EXEC_ADDR_WIDTH-1:0] wbuf_exec_addr,
    // execute psumbuf    
    input  logic [     PBUF_ADDR_WIDTH-1:0] pbuf_exec_rd_addr,
    input  logic                            pbuf_exec_wr_en,
    input  logic [     PBUF_ADDR_WIDTH-1:0] pbuf_exec_wr_addr,
    // control signals for exec
    input  logic [                     5:0] s_k_index_exec,
    input  logic [                     5:0] s_c_index_exec,
    input  logic [                     3:0] s_h_index_exec,
    input  logic [                     3:0] s_w_index_exec,
    // control signals for cu
    input  logic                            adder_rst_en,
    input  logic                            pbuf_exec_rd_rst_en,
    // wb pbuf
    input  logic                            pbuf_wb_rvs,
    input  logic [     PBUF_ADDR_WIDTH-1:0] pbuf_wb_addr,
    input  logic [                     5:0] pbuf_wb_f_k,
    // (* dont_touch = "yes" *) input  logic [PBUF_DATA_NUM-1:0]        pbuf_wb_valid      ,
    input  logic [                     5:0] wb_s_idx_k,
    input  logic [                     3:0] wb_s_idx_h,
    input  logic [                     3:0] wb_s_idx_w,
    output logic [     PBUF_DATA_WIDTH-1:0] pbuf_wb_data         [PBUF_DATA_NUM-1:0]
);

    // configuaration of s index (updt)
    logic [3:0] s_w_conf_updt;
    logic [3:0] s_h_conf_updt;
    logic [5:0] s_c_conf_updt;
    logic [5:0] s_k_conf_updt;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            s_w_conf_updt <= 4'd0;
            s_h_conf_updt <= 4'd0;
            s_c_conf_updt <= 6'd0;
            s_k_conf_updt <= 6'd0;
        end else if (pe_config_exec) begin
            s_w_conf_updt <= s_w_index_config_updt;
            s_h_conf_updt <= s_h_index_config_updt;
            s_c_conf_updt <= s_c_index_config_updt;
            s_k_conf_updt <= s_k_index_config_updt;
        end
    end

    // configuaration of s index (exec)
    logic [3:0] s_w_conf_exec;
    logic [3:0] s_h_conf_exec;
    logic [5:0] s_c_conf_exec;
    logic [5:0] s_k_conf_exec;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            s_w_conf_exec <= 4'd0;
            s_h_conf_exec <= 4'd0;
            s_c_conf_exec <= 6'd0;
            s_k_conf_exec <= 6'd0;
        end else if (pe_config_exec) begin
            s_w_conf_exec <= s_w_index_config_exec;
            s_h_conf_exec <= s_h_index_config_exec;
            s_c_conf_exec <= s_c_index_config_exec;
            s_k_conf_exec <= s_k_index_config_exec;
        end
    end

    // configuaration of s index (wb)
    logic [3:0] s_w_conf_wb;
    logic [3:0] s_h_conf_wb;
    logic [5:0] s_c_conf_wb;
    logic [5:0] s_k_conf_wb;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            s_w_conf_wb <= 4'd0;
            s_h_conf_wb <= 4'd0;
            s_c_conf_wb <= 6'd0;
            s_k_conf_wb <= 6'd0;
        end else if (pe_config_wb) begin
            s_w_conf_wb <= s_w_index_config_wb;
            s_h_conf_wb <= s_h_index_config_wb;
            s_c_conf_wb <= s_c_index_config_wb;
            s_k_conf_wb <= s_k_index_config_wb;
        end
    end

    // configuaration of computation type and idle state
    logic comp_type_r, w_fixed_r, pe_idle_state_updt_r, pe_idle_state_wb_r;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            comp_type_r          <= 1'b0;
            w_fixed_r            <= 1'b0;
            pe_idle_state_updt_r <= 1'b0;
            pe_idle_state_wb_r   <= 1'b0;
        end else if (pe_config_exec) begin
            comp_type_r          <= comp_type;
            w_fixed_r            <= w_fixed;
            pe_idle_state_updt_r <= pe_idle_state_updt;
            pe_idle_state_wb_r   <= pe_idle_state_wb;
        end
    end

    // check if this pe needs execution
    logic pe_exec_en = 1'b0;
    always_comb begin
        pe_exec_en =    (s_k_conf_exec <= s_k_index_exec) & (s_c_conf_exec <= s_c_index_exec) & 
                        (s_h_conf_exec <= s_h_index_exec) & (s_w_conf_exec <= s_w_index_exec);
    end

    // receive tag and decode information
    logic [3:0] s_w_idx[3:0];
    logic [3:0] s_h_idx[3:0];
    logic [5:0] s_c_idx[3:0];
    logic [5:0] s_k_idx[3:0];
    logic [1:0] dtype  [3:0];

    genvar pe_updt_idx;
    generate
        for (pe_updt_idx = 0; pe_updt_idx < 4; pe_updt_idx++) begin
            always_comb begin
                s_w_idx[pe_updt_idx] = pe_updt_tag[pe_updt_idx][3:0];
                s_h_idx[pe_updt_idx] = pe_updt_tag[pe_updt_idx][7:4];
                s_c_idx[pe_updt_idx] = pe_updt_tag[pe_updt_idx][13:8];
                s_k_idx[pe_updt_idx] = pe_updt_tag[pe_updt_idx][5:0];
                dtype[pe_updt_idx]   = pe_updt_tag[pe_updt_idx][62:61];
            end
        end
    endgenerate

    logic [3:0] updt_abuf_sel_en, updt_wbuf_sel_en;
    // logic [MM2S_TAG_WIDTH-1:0]       pe_updt_tag         [3:0];
    generate
        for (pe_updt_idx = 0; pe_updt_idx < 4; pe_updt_idx++) begin
            always_comb begin
                updt_abuf_sel_en[pe_updt_idx]   =   pe_updt_tag_valid[pe_updt_idx] & (dtype[pe_updt_idx] == 2'b00) & 
                                                    (s_c_idx[pe_updt_idx] == s_c_conf_updt) & (s_h_idx[pe_updt_idx] == s_h_conf_updt) & 
                                                    (s_w_idx[pe_updt_idx] == s_w_conf_updt);
                updt_wbuf_sel_en[pe_updt_idx]   =   pe_updt_tag_valid[pe_updt_idx] & (dtype[pe_updt_idx] == 2'b01) & 
                                                    (s_k_idx[pe_updt_idx] == s_k_conf_updt) & (s_c_idx[pe_updt_idx] == s_c_conf_updt);
            end
        end
    endgenerate

    logic [1:0] updt_sel_act, updt_sel_w;
    logic tag_abuf_eof, tag_abuf_eot;

    // since r_info, pad_info will be used in execution phase, we need to set up double buffer for them
    logic [9:0] r_c_0, r_ih_0, r_iw_0, r_c_1, r_ih_1, r_iw_1;
    logic [2:0] pad_t_0, pad_l_0, pad_t_1, pad_l_1;
    logic abuf_info_sel;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_sel_act <= 0;
            tag_abuf_eof <= 1'b0;
            tag_abuf_eot <= 1'b0;
            r_c_0        <= 0;
            r_ih_0       <= 0;
            r_iw_0       <= 0;
            pad_t_0      <= 0;
            pad_l_0      <= 0;
            r_c_1        <= 0;
            r_ih_1       <= 0;
            r_iw_1       <= 0;
            pad_t_1      <= 0;
            pad_l_1      <= 0;
        end else if (updt_abuf_sel_en[0]) begin
            updt_sel_act <= 0;
            tag_abuf_eof <= pe_updt_tag[0][54];
            tag_abuf_eot <= pe_updt_tag[0][55];
            if (~abuf_info_sel) begin
                r_c_0   <= pe_updt_tag[0][43:34];
                r_ih_0  <= pe_updt_tag[0][33:24];
                r_iw_0  <= pe_updt_tag[0][23:14];
                pad_t_0 <= pe_updt_tag[0][49:47];
                pad_l_0 <= pe_updt_tag[0][46:44];
            end else if (abuf_info_sel) begin
                r_c_1   <= pe_updt_tag[0][43:34];
                r_ih_1  <= pe_updt_tag[0][33:24];
                r_iw_1  <= pe_updt_tag[0][23:14];
                pad_t_1 <= pe_updt_tag[0][49:47];
                pad_l_1 <= pe_updt_tag[0][46:44];
            end
        end else if (updt_abuf_sel_en[1]) begin
            updt_sel_act <= 1;
            tag_abuf_eof <= pe_updt_tag[1][54];
            tag_abuf_eot <= pe_updt_tag[1][55];
            if (~abuf_info_sel) begin
                r_c_0   <= pe_updt_tag[1][43:34];
                r_ih_0  <= pe_updt_tag[1][33:24];
                r_iw_0  <= pe_updt_tag[1][23:14];
                pad_t_0 <= pe_updt_tag[1][49:47];
                pad_l_0 <= pe_updt_tag[1][46:44];
            end else if (abuf_info_sel) begin
                r_c_1   <= pe_updt_tag[1][43:34];
                r_ih_1  <= pe_updt_tag[1][33:24];
                r_iw_1  <= pe_updt_tag[1][23:14];
                pad_t_1 <= pe_updt_tag[1][49:47];
                pad_l_1 <= pe_updt_tag[1][46:44];
            end
        end else if (updt_abuf_sel_en[2]) begin
            updt_sel_act <= 2;
            tag_abuf_eof <= pe_updt_tag[2][54];
            tag_abuf_eot <= pe_updt_tag[2][55];
            if (~abuf_info_sel) begin
                r_c_0   <= pe_updt_tag[2][43:34];
                r_ih_0  <= pe_updt_tag[2][33:24];
                r_iw_0  <= pe_updt_tag[2][23:14];
                pad_t_0 <= pe_updt_tag[2][49:47];
                pad_l_0 <= pe_updt_tag[2][46:44];
            end else if (abuf_info_sel) begin
                r_c_1   <= pe_updt_tag[2][43:34];
                r_ih_1  <= pe_updt_tag[2][33:24];
                r_iw_1  <= pe_updt_tag[2][23:14];
                pad_t_1 <= pe_updt_tag[2][49:47];
                pad_l_1 <= pe_updt_tag[2][46:44];
            end
        end else if (updt_abuf_sel_en[3]) begin
            updt_sel_act <= 3;
            tag_abuf_eof <= pe_updt_tag[3][54];
            tag_abuf_eot <= pe_updt_tag[3][55];
            if (~abuf_info_sel) begin
                r_c_0   <= pe_updt_tag[3][43:34];
                r_ih_0  <= pe_updt_tag[3][33:24];
                r_iw_0  <= pe_updt_tag[3][23:14];
                pad_t_0 <= pe_updt_tag[3][49:47];
                pad_l_0 <= pe_updt_tag[3][46:44];
            end else if (abuf_info_sel) begin
                r_c_1   <= pe_updt_tag[3][43:34];
                r_ih_1  <= pe_updt_tag[3][33:24];
                r_iw_1  <= pe_updt_tag[3][23:14];
                pad_t_1 <= pe_updt_tag[3][49:47];
                pad_l_1 <= pe_updt_tag[3][46:44];
            end
        end
    end

    logic [9:0] exec_r_c, exec_r_ih, exec_r_iw;
    logic [2:0] exec_pad_t, exec_pad_l;
    // always_comb begin
    //     exec_r_c    = (abuf_info_sel)?r_c_0:r_c_1;
    //     exec_r_ih   = (abuf_info_sel)?r_ih_0:r_ih_1;
    //     exec_r_iw   = (abuf_info_sel)?r_iw_0:r_iw_1;
    //     exec_pad_t  = (abuf_info_sel)?pad_t_0:pad_t_1;
    //     exec_pad_l  = (abuf_info_sel)?pad_l_0:pad_l_1;
    // end
    always_ff @(posedge clk) begin
        exec_r_c   <= (abuf_info_sel) ? r_c_0 : r_c_1;
        exec_r_ih  <= (abuf_info_sel) ? r_ih_0 : r_ih_1;
        exec_r_iw  <= (abuf_info_sel) ? r_iw_0 : r_iw_1;
        exec_pad_t <= (abuf_info_sel) ? pad_t_0 : pad_t_1;
        exec_pad_l <= (abuf_info_sel) ? pad_l_0 : pad_l_1;
    end

    // timing optimization - intermediates
    // logic [ABUF_EXEC_ADDR_WIDTH-1:0] exec_r_ih_r_iw;
    // always_ff @( posedge clk ) begin
    //     exec_r_ih_r_iw <= exec_r_ih * exec_r_iw;
    // end

    // f_info, bpw_info will be used in update phase, so one buffer is enough
    logic [2:0] wbuf_f_i, wbuf_f_j;
    logic [5:0] wbuf_f_k, wbuf_f_c;
    logic [8:0] wbuf_wpb;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_sel_w <= 0;
        end else if (updt_wbuf_sel_en[0]) begin
            updt_sel_w <= 0;
            wbuf_f_i   <= pe_updt_tag[0][49:47];
            wbuf_f_j   <= pe_updt_tag[0][46:44];
            wbuf_f_k   <= pe_updt_tag[0][43:38];
            wbuf_f_c   <= pe_updt_tag[0][37:32];
            wbuf_wpb   <= pe_updt_tag[0][29:21];
        end else if (updt_wbuf_sel_en[1]) begin
            updt_sel_w <= 1;
            wbuf_f_i   <= pe_updt_tag[1][49:47];
            wbuf_f_j   <= pe_updt_tag[1][46:44];
            wbuf_f_k   <= pe_updt_tag[1][43:38];
            wbuf_f_c   <= pe_updt_tag[1][37:32];
            wbuf_wpb   <= pe_updt_tag[1][29:21];
        end else if (updt_wbuf_sel_en[2]) begin
            updt_sel_w <= 2;
            wbuf_f_i   <= pe_updt_tag[2][49:47];
            wbuf_f_j   <= pe_updt_tag[2][46:44];
            wbuf_f_k   <= pe_updt_tag[2][43:38];
            wbuf_f_c   <= pe_updt_tag[2][37:32];
            wbuf_wpb   <= pe_updt_tag[2][29:21];
        end else if (updt_wbuf_sel_en[3]) begin
            updt_sel_w <= 3;
            wbuf_f_i   <= pe_updt_tag[3][49:47];
            wbuf_f_j   <= pe_updt_tag[3][46:44];
            wbuf_f_k   <= pe_updt_tag[3][43:38];
            wbuf_f_c   <= pe_updt_tag[3][37:32];
            wbuf_wpb   <= pe_updt_tag[3][29:21];
        end
    end

    // update address generation
    logic abuf_updt_start, wbuf_updt_start, abuf_updt_done, wbuf_updt_done;
    logic abuf_updt_state, wbuf_updt_state;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            abuf_updt_state <= 1'b0;
        end else if (abuf_updt_start) begin
            abuf_updt_state <= 1'b1;
        end else if (abuf_updt_done) begin
            abuf_updt_state <= 1'b0;
        end
    end
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wbuf_updt_state <= 1'b0;
        end else if (wbuf_updt_start) begin
            wbuf_updt_state <= 1'b1;
        end else if (wbuf_updt_done) begin
            wbuf_updt_state <= 1'b0;
        end
    end

    // assign abuf_updt_start  = (abuf_updt_state == 1'b0)&(updt_abuf_sel_en!=4'b0000)&(pe_idle_state_r);
    // assign wbuf_updt_start  = (wbuf_updt_state == 1'b0)&(updt_wbuf_sel_en!=4'b0000)&(pe_idle_state_r);
    assign abuf_updt_start = (updt_abuf_sel_en != 4'b0000) & (pe_idle_state_updt_r);
    assign wbuf_updt_start = (updt_wbuf_sel_en != 4'b0000) & (pe_idle_state_updt_r);

    logic [ABUF_UPDT_ADDR_WIDTH-1:0] abuf_updt_addr;
    logic [WBUF_UPDT_ADDR_WIDTH-1:0] wbuf_updt_addr;
    logic [            ABUF_NUM-1:0] abuf_updt_en;
    logic [            WBUF_NUM-1:0] wbuf_updt_en;
    logic                            abuf_updt_sel;
    logic                            wbuf_updt_sel;
    logic                            updt_abuf_eof;
    logic                            updt_abuf_eot;

    // assign updt_abuf_eof = tag_abuf_eof & pe_updt_data_last[updt_sel_act];
    // assign updt_abuf_eot = tag_abuf_eot & pe_updt_data_last[updt_sel_act];
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_abuf_eof <= 1'b0;
            updt_abuf_eot <= 1'b0;
        end else begin
            updt_abuf_eof <= tag_abuf_eof & pe_updt_data_last[updt_sel_act] & pe_updt_valid[updt_sel_act];
            updt_abuf_eot <= tag_abuf_eot & pe_updt_data_last[updt_sel_act] & pe_updt_valid[updt_sel_act];
        end
    end
    // always_ff @( posedge clk ) begin
    //     abuf_info_sel <= abuf_updt_sel;
    // end
    assign abuf_info_sel = abuf_updt_sel;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            abuf_updt_sel <= 1'b0;
            wbuf_updt_sel <= 1'b0;
        end else if (awbuf_updt_rvs) begin
            abuf_updt_sel <= ~abuf_updt_sel;
            wbuf_updt_sel <= ~wbuf_updt_sel;
        end
    end

    logic [PE_UPDT_DATA_WIDTH/8-1:0] abuf_updt_data_keep[3:0];
    logic [PE_UPDT_DATA_WIDTH/8-1:0] wbuf_updt_data_keep[3:0];
    generate
        for (pe_updt_idx = 0; pe_updt_idx < 4; pe_updt_idx++) begin
            always_ff @(posedge clk) begin
                abuf_updt_data_keep[pe_updt_idx] <= pe_updt_data_keep[pe_updt_idx];
                wbuf_updt_data_keep[pe_updt_idx] <= pe_updt_data_keep[pe_updt_idx];
            end
        end
    endgenerate


    logic abuf_updt_en_i, wbuf_updt_en_i;
    logic abuf_full_words_flag, wbuf_full_words_flag;
    // always_ff @( posedge clk ) begin
    //     if (~rst_n) begin
    //         abuf_full_words_flag <= 1'b0;
    //     end
    //     else if (pe_updt_valid[updt_sel_act] & abuf_full_words_flag) begin
    //         abuf_full_words_flag <= 1'b0;
    //     end
    //     else if (pe_updt_valid[updt_sel_act] & (pe_updt_data_keep[updt_sel_act] != 4'b1111)) begin
    //         abuf_full_words_flag <= 1'b1;
    //     end
    // end
    always_comb begin
        abuf_full_words_flag = pe_updt_valid[updt_sel_act] & (pe_updt_data_keep[updt_sel_act] != 4'b1111) & (pe_updt_data_keep[updt_sel_act] != 4'b0000);
    end

    // always_ff @( posedge clk ) begin
    //     if (~rst_n) begin
    //         wbuf_full_words_flag <= 1'b0;
    //     end
    //     else if (pe_updt_valid[updt_sel_w] & wbuf_full_words_flag) begin
    //         wbuf_full_words_flag <= 1'b0;
    //     end
    //     else if (pe_updt_valid[updt_sel_w] & (pe_updt_data_keep[updt_sel_w] != 4'b1111)) begin
    //         wbuf_full_words_flag <= 1'b1;
    //     end
    // end
    always_comb begin
        wbuf_full_words_flag = pe_updt_valid[updt_sel_w] & (pe_updt_data_keep[updt_sel_w] != 4'b1111) & (pe_updt_data_keep[updt_sel_w] != 4'b0000);
    end

    // always_comb begin
    //     abuf_updt_en_i = abuf_updt_state & pe_updt_valid[updt_sel_act] & (pe_updt_data_keep[updt_sel_act]==4'b1111 | abuf_full_words_flag);
    //     wbuf_updt_en_i = wbuf_updt_state & pe_updt_valid[updt_sel_w]  & (pe_updt_data_keep[updt_sel_w]==4'b1111 | wbuf_full_words_flag);
    // end
    always_ff @(posedge clk) begin
        abuf_updt_en_i <= abuf_updt_state & pe_updt_valid[updt_sel_act] & (pe_updt_data_keep[updt_sel_act]==4'b1111 | abuf_full_words_flag);
        wbuf_updt_en_i <= wbuf_updt_state & pe_updt_valid[updt_sel_w]  & (pe_updt_data_keep[updt_sel_w]==4'b1111 | wbuf_full_words_flag);
    end

    pe_ctrl_updt pe_ctrl_updt_inst (
        .clk            (clk),
        .rst_n          (rst_n),
        .abuf_updt_start(abuf_updt_start),
        .wbuf_updt_start(wbuf_updt_start),
        .abuf_updt_en_i (abuf_updt_en_i),
        .wbuf_updt_en_i (wbuf_updt_en_i),
        .abuf_updt_done (abuf_updt_done),
        .wbuf_updt_done (wbuf_updt_done),
        .abuf_updt_addr (abuf_updt_addr),
        .wbuf_updt_addr (wbuf_updt_addr),
        .abuf_updt_en   (abuf_updt_en),
        .wbuf_updt_en   (wbuf_updt_en),
        .updt_abuf_eof  (updt_abuf_eof),
        .updt_abuf_eot  (updt_abuf_eot),
        .wbuf_f_i       (wbuf_f_i),
        .wbuf_f_j       (wbuf_f_j),
        .wbuf_f_k       (wbuf_f_k),
        .wbuf_f_c       (wbuf_f_c),
        .wbuf_wpb       (wbuf_wpb)
    );

    // act buffer
    logic [PE_UPDT_DATA_WIDTH-1:0] abuf_updt_data;
    always_ff @(posedge clk) begin
        abuf_updt_data <= pe_updt_data[updt_sel_act];
    end
    // assign abuf_updt_data = pe_updt_data[updt_sel_act];

    logic [     ABUF_DATA_WIDTH-1:0] abuf_exec_data_p   [ABUF_NUM-1:0];
    logic [     ABUF_DATA_WIDTH-1:0] abuf_exec_data     [ABUF_NUM-1:0];

    // abuf execution
    logic [ABUF_EXEC_ADDR_WIDTH-1:0] abuf_exec_addr_out;

    logic [                     9:0] abuf2rf_updt_idx_d [         2:0];

    // delay 1 cycle
    always_ff @(posedge clk) begin
        abuf2rf_updt_idx_d[0] <= abuf2rf_updt_idx[0];
        abuf2rf_updt_idx_d[1] <= abuf2rf_updt_idx[1];
        abuf2rf_updt_idx_d[2] <= abuf2rf_updt_idx[2];
    end

    abuf_exec_addr abuf_exec_addr_gen_inst (
        .clk               (clk),
        .rst_n             (rst_n),
        .abuf2rf_updt_idx  (abuf2rf_updt_idx),
        .exec_pad_t        (exec_pad_t),
        .exec_pad_l        (exec_pad_l),
        .exec_r_iw         (exec_r_iw),
        .exec_r_ih         (exec_r_ih),
        .abuf_exec_addr_out(abuf_exec_addr_out)
    );


    logic [PE_UPDT_DATA_WIDTH/8-1:0] abuf_updt_wr_en     [ABUF_NUM-1:0];
    logic [PE_UPDT_DATA_WIDTH/8-1:0] abuf_updt_wr_en_temp[ABUF_NUM-1:0];

    logic                            if_padding;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            if_padding <= 1'b0;
        end else begin
            if_padding <=   (abuf2rf_updt_idx_d[2] < exec_pad_l)|(abuf2rf_updt_idx_d[2] > (exec_r_iw + exec_pad_l - 1))|
                            (abuf2rf_updt_idx_d[1] < exec_pad_t)|(abuf2rf_updt_idx_d[1] > (exec_r_ih + exec_pad_t - 1))|
                            (abuf2rf_updt_idx_d[0] > (exec_r_c - 1));
        end
    end

    genvar a_k_idx, a_h_idx, a_w_idx, a_c_idx, a_i_idx, a_j_idx;
    generate
        for (a_c_idx = 0; a_c_idx < PARAM_A_C; a_c_idx++) begin
            new_buf_sdp #(
                .BUF_UPDT_ADDR_WIDTH(ABUF_UPDT_ADDR_WIDTH),
                .BUF_UPDT_DATA_WIDTH(PE_UPDT_DATA_WIDTH),
                .BUF_EXEC_ADDR_WIDTH(ABUF_EXEC_ADDR_WIDTH),
                .BUF_EXEC_DATA_WIDTH(ABUF_DATA_WIDTH)
            ) abufbuf_inst (
                .clk           (clk),
                .buf_updt_wr_en(abuf_updt_wr_en[a_c_idx]),
                .buf_updt_sel  (abuf_updt_sel),
                .buf_updt_addr (abuf_updt_addr),
                .buf_updt_data (abuf_updt_data),
                .buf_exec_sel  (~abuf_updt_sel),
                .buf_exec_addr (abuf_exec_addr_out),
                .buf_exec_data (abuf_exec_data_p[a_c_idx])
            );
            assign abuf_updt_wr_en_temp[a_c_idx]   =  (abuf_updt_en_i & abuf_updt_en[a_c_idx])?4'b1111:4'b0000;
            assign abuf_updt_wr_en[a_c_idx]        =  abuf_updt_data_keep[updt_sel_act] & abuf_updt_wr_en_temp[a_c_idx];
            always_ff @(posedge clk) begin
                // abuf_exec_data[a_c_idx]         <=  ((abuf2rf_updt_idx_d[2] < exec_pad_l)|(abuf2rf_updt_idx_d[2] > (exec_r_iw + exec_pad_l - 1))|
                //                                     (abuf2rf_updt_idx_d[1] < exec_pad_t)|(abuf2rf_updt_idx_d[1] > (exec_r_ih + exec_pad_t - 1))|
                //                                     (abuf2rf_updt_idx_d[0] > (exec_r_c - 1)))?0:abuf_exec_data_p[a_c_idx];
                abuf_exec_data[a_c_idx] <= (if_padding) ? 0 : abuf_exec_data_p[a_c_idx];
            end
        end
    endgenerate

    // Weight Buffer
    logic [PE_UPDT_DATA_WIDTH-1:0] wbuf_updt_data;
    always_ff @(posedge clk) begin
        wbuf_updt_data <= pe_updt_data[updt_sel_w];
    end
    // assign wbuf_updt_data = pe_updt_data[updt_sel_w];

    logic [     WBUF_DATA_WIDTH-1:0] wbuf_exec_data_p    [WBUF_NUM-1:0];
    logic [     WBUF_DATA_WIDTH-1:0] wbuf_exec_data      [WBUF_NUM-1:0];

    logic [PE_UPDT_DATA_WIDTH/8-1:0] wbuf_updt_wr_en     [WBUF_NUM-1:0];
    logic [PE_UPDT_DATA_WIDTH/8-1:0] wbuf_updt_wr_en_temp[WBUF_NUM-1:0];

    generate
        for (a_k_idx = 0; a_k_idx < PARAM_A_K; a_k_idx++) begin
            for (a_c_idx = 0; a_c_idx < PARAM_A_C; a_c_idx++) begin
                for (a_i_idx = 0; a_i_idx < PARAM_A_I; a_i_idx++) begin
                    for (a_j_idx = 0; a_j_idx < PARAM_A_J; a_j_idx++) begin
                        new_buf_sdp #(
                            .BUF_UPDT_ADDR_WIDTH(WBUF_UPDT_ADDR_WIDTH),
                            .BUF_UPDT_DATA_WIDTH(PE_UPDT_DATA_WIDTH),
                            .BUF_EXEC_ADDR_WIDTH(WBUF_EXEC_ADDR_WIDTH),
                            .BUF_EXEC_DATA_WIDTH(WBUF_DATA_WIDTH)
                        ) wbuf_inst (
                            .clk(clk),
                            .buf_updt_wr_en(wbuf_updt_wr_en[wbuf_idx(
                                a_k_idx, a_c_idx, a_i_idx, a_j_idx
                            )]),
                            .buf_updt_sel(wbuf_updt_sel),
                            .buf_updt_addr(wbuf_updt_addr),
                            .buf_updt_data(wbuf_updt_data),
                            .buf_exec_sel(~wbuf_updt_sel),
                            .buf_exec_addr(wbuf_exec_addr),
                            .buf_exec_data(wbuf_exec_data_p[wbuf_idx(
                                a_k_idx, a_c_idx, a_i_idx, a_j_idx
                            )])
                        );
                        assign wbuf_updt_wr_en_temp[wbuf_idx(
                            a_k_idx, a_c_idx, a_i_idx, a_j_idx
                        )] = (wbuf_updt_en_i & wbuf_updt_en[wbuf_idx(
                            a_k_idx, a_c_idx, a_i_idx, a_j_idx
                        )]) ? 4'b1111 : 4'b0000;
                        assign wbuf_updt_wr_en[wbuf_idx(
                            a_k_idx, a_c_idx, a_i_idx, a_j_idx
                        )] = wbuf_updt_data_keep[updt_sel_w] & wbuf_updt_wr_en_temp[wbuf_idx(
                            a_k_idx, a_c_idx, a_i_idx, a_j_idx
                        )];
                        always_ff @(posedge clk) begin
                            wbuf_exec_data[wbuf_idx(a_k_idx, a_c_idx, a_i_idx, a_j_idx)]
                                <= (w_fixed_r) ? 8'b00001000 :
                                wbuf_exec_data_p[wbuf_idx(a_k_idx, a_c_idx, a_i_idx, a_j_idx)];
                        end
                    end
                end
            end
        end
    endgenerate

    // Psum Buffer
    logic [PBUF_ADDR_WIDTH-1:0] pbuf_exec_addr;
    always_ff @(posedge clk) begin
        pbuf_exec_addr <= pbuf_exec_wr_en ? pbuf_exec_wr_addr : pbuf_exec_rd_addr;
    end
    logic pbuf_exec_wr_en_r;
    always_ff @(posedge clk) begin
        pbuf_exec_wr_en_r <= pbuf_exec_wr_en;
    end

`ifdef PARAM_PBUF_A_K_ONE
    logic [PBUF_DATA_WIDTH-1:0] pbuf_wb_data_p[PBUF_DATA_NUM-1:0];
`else
    logic [PBUF_DATA_WIDTH-1:0] pbuf_wb_data_p[PARAM_A_K-1:0][PBUF_DATA_NUM-1:0];
`endif
    logic [PBUF_DATA_WIDTH-1:0] pbuf_exec_rd_data  [PBUF_NUM-1:0];
    logic [PBUF_DATA_WIDTH-1:0] pbuf_exec_wr_data  [PBUF_NUM-1:0];
    logic [PBUF_DATA_WIDTH-1:0] pbuf_exec_wr_data_p[PBUF_NUM-1:0];
    logic [PBUF_DATA_WIDTH-1:0] maxpool_result     [PBUF_NUM-1:0];

    // wb selection control
    logic                       pbuf_wb_sel;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            pbuf_wb_sel <= 1'b0;
        end  // when receiving the reverse signal, wb_sel will be reversed
             // currently, all the pe share the same pbuf_wb_rvs (with different delay if applicable)
        else if (pbuf_wb_rvs) begin
            pbuf_wb_sel <= ~pbuf_wb_sel;
        end
    end

    // wb enable control
    logic pbuf_wb_enable = 1'b0;
    always_comb begin
        pbuf_wb_enable =    pe_idle_state_wb_r & (s_w_conf_wb == wb_s_idx_w) & (s_h_conf_wb == wb_s_idx_h) &
                            (s_k_conf_wb == wb_s_idx_k);
    end

`ifdef PARAM_PBUF_A_K_ONE
    generate
        for (a_h_idx = 0; a_h_idx < PARAM_A_H; a_h_idx++) begin
            for (a_w_idx = 0; a_w_idx < PARAM_A_W; a_w_idx++) begin
                new_buf_tdp #(
                    .BUF_FETCH_ADDR_WIDTH(PBUF_ADDR_WIDTH),
                    .BUF_FETCH_DATA_WIDTH(PBUF_DATA_WIDTH),
                    .BUF_EXEC_ADDR_WIDTH (PBUF_ADDR_WIDTH),
                    .BUF_EXEC_DATA_WIDTH (PBUF_DATA_WIDTH)
                ) pbuf_inst (
                    .clk(clk),
                    .buf_fetch_sel(pbuf_wb_sel),
                    .buf_fetch_addr(pbuf_wb_addr),
                    .buf_fetch_data(pbuf_wb_data_p[pbuf_idx_wb(a_h_idx, a_w_idx)]),
                    .buf_exec_wr_en(pbuf_exec_wr_en_r),
                    .buf_exec_sel(~pbuf_wb_sel),
                    .buf_exec_addr(pbuf_exec_addr),
                    .buf_exec_wr_data(pbuf_exec_wr_data_p[pbuf_idx_wb(a_h_idx, a_w_idx)]),
                    .buf_exec_rd_data(pbuf_exec_rd_data[pbuf_idx_wb(a_h_idx, a_w_idx)])
                );
                always_ff @(posedge clk) begin
                    pbuf_exec_wr_data_p[pbuf_idx_wb(
                        a_h_idx, a_w_idx
                    )] <= (~pe_exec_en) ? (pbuf_exec_rd_data[pbuf_idx_wb(
                        a_h_idx, a_w_idx
                    )]) : (comp_type_r) ? maxpool_result[pbuf_idx_wb(
                        a_h_idx, a_w_idx
                    )] : pbuf_exec_wr_data[pbuf_idx_wb(
                        a_h_idx, a_w_idx
                    )];
                    // pbuf_wb_data[pbuf_idx_wb(a_h_idx,a_w_idx)]             <=   (pbuf_wb_enable&pbuf_wb_valid[pbuf_idx_wb(a_h_idx,a_w_idx)])?
                    //                                                             pbuf_wb_data_p[pbuf_wb_f_k][pbuf_idx_wb(a_h_idx,a_w_idx)]:0;
                end
            end
        end
    endgenerate

    generate
        for (a_h_idx = 0; a_h_idx < PARAM_A_H; a_h_idx++) begin
            for (a_w_idx = 0; a_w_idx < PARAM_A_W; a_w_idx++) begin
                always_ff @(posedge clk) begin
                    pbuf_wb_data[pbuf_idx_wb(a_h_idx, a_w_idx)] <= (pbuf_wb_enable) ?
                        pbuf_wb_data_p[pbuf_idx_wb(a_h_idx, a_w_idx)] : 0;
                end
            end
        end
    endgenerate

`else
    generate
        for (a_k_idx = 0; a_k_idx < PARAM_A_K; a_k_idx++) begin
            for (a_h_idx = 0; a_h_idx < PARAM_A_H; a_h_idx++) begin
                for (a_w_idx = 0; a_w_idx < PARAM_A_W; a_w_idx++) begin
                    new_buf_tdp #(
                        .BUF_FETCH_ADDR_WIDTH(PBUF_ADDR_WIDTH),
                        .BUF_FETCH_DATA_WIDTH(PBUF_DATA_WIDTH),
                        .BUF_EXEC_ADDR_WIDTH (PBUF_ADDR_WIDTH),
                        .BUF_EXEC_DATA_WIDTH (PBUF_DATA_WIDTH)
                    ) pbuf_inst (
                        .clk(clk),
                        .buf_fetch_sel(pbuf_wb_sel),
                        .buf_fetch_addr(pbuf_wb_addr),
                        .buf_fetch_data(pbuf_wb_data_p[a_k_idx][pbuf_idx_wb(a_h_idx, a_w_idx)]),
                        .buf_exec_wr_en(pbuf_exec_wr_en_r),
                        .buf_exec_sel(~pbuf_wb_sel),
                        .buf_exec_addr(pbuf_exec_addr),
                        .buf_exec_wr_data(pbuf_exec_wr_data_p[pbuf_idx(a_k_idx, a_h_idx, a_w_idx)]),
                        .buf_exec_rd_data(pbuf_exec_rd_data[pbuf_idx(a_k_idx, a_h_idx, a_w_idx)])
                    );
                    always_ff @(posedge clk) begin
                        pbuf_exec_wr_data_p[pbuf_idx(
                            a_k_idx, a_h_idx, a_w_idx
                        )] <= (~pe_exec_en) ? (pbuf_exec_rd_data[pbuf_idx(
                            a_k_idx, a_h_idx, a_w_idx
                        )]) : (comp_type_r) ? maxpool_result[pbuf_idx(
                            a_k_idx, a_h_idx, a_w_idx
                        )] : pbuf_exec_wr_data[pbuf_idx(
                            a_k_idx, a_h_idx, a_w_idx
                        )];
                        // pbuf_wb_data[pbuf_idx_wb(a_h_idx,a_w_idx)]             <=   (pbuf_wb_enable&pbuf_wb_valid[pbuf_idx_wb(a_h_idx,a_w_idx)])?
                        //                                                             pbuf_wb_data_p[pbuf_wb_f_k][pbuf_idx_wb(a_h_idx,a_w_idx)]:0;
                    end
                end
            end
        end
    endgenerate

    generate
        for (a_h_idx = 0; a_h_idx < PARAM_A_H; a_h_idx++) begin
            for (a_w_idx = 0; a_w_idx < PARAM_A_W; a_w_idx++) begin
                always_ff @(posedge clk) begin
                    pbuf_wb_data[pbuf_idx_wb(a_h_idx, a_w_idx)] <= (pbuf_wb_enable) ?
                        pbuf_wb_data_p[pbuf_wb_f_k][pbuf_idx_wb(a_h_idx, a_w_idx)] : 0;
                end
            end
        end
    endgenerate
`endif

    // cu
    cu cu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rf_updt_en(rf_updt_en),
        .rf_updt_sel(rf_updt_sel),
        .rf_updt_addr_rst(rf_updt_addr_rst),
        .rf_updt_data(abuf_exec_data),
        .rf_exec_sel(rf_exec_sel),
        .rf_exec_addr(rf_exec_addr),
        .wbuf_exec_data(wbuf_exec_data),
        .pbuf_exec_rd_data(pbuf_exec_rd_data),
        .pbuf_exec_wr_data(pbuf_exec_wr_data),
        .maxpool_result(maxpool_result),
        .adder_rst_en(adder_rst_en),
        .pbuf_exec_rd_rst_en(pbuf_exec_rd_rst_en),
        .comp_type(comp_type_r)
    );

endmodule
