`timescale 1ns / 1ps

`include "def.sv"

(*use_dsp48 = "no" *) module mm2s_cmd_gen #(
    parameter CORE_INSTR_WIDTH = 64,
    parameter CORE_CMD_WIDTH   = 80,
    parameter MM2S_TAG_WIDTH   = 64
) (
    input  logic                            clk,
    input  logic                            rst_n,
    // input stream - sub-instructions
    input  logic [CORE_INSTR_WIDTH - 1 : 0] s_axis_mm2s_instr_tdata,
    input  logic                            s_axis_mm2s_instr_tvalid,
    output logic                            s_axis_mm2s_instr_tready,
    // output stream - data mover cmd
    output logic [  CORE_CMD_WIDTH - 1 : 0] m_axis_mm2s_cmd_tdata,
    output logic                            m_axis_mm2s_cmd_tvalid,
    input  logic                            m_axis_mm2s_cmd_tready,
    // output stream - tag (will be sent to another fifo for matching)
    output logic [  MM2S_TAG_WIDTH - 1 : 0] m_axis_tag_tdata,
    output logic                            m_axis_tag_tvalid,
    input  logic                            m_axis_tag_tready
    // total length = words_per_tile * SK * SC
    // output logic [9:0]                          words_per_tile
);

    /***************************** decode the sub-instructions ******************************/
    // handshake signals in sub-instructions channel
    logic hs_s_axis_mm2s_instr;
    logic instr_type;
    assign hs_s_axis_mm2s_instr = s_axis_mm2s_instr_tvalid & s_axis_mm2s_instr_tready;
    assign instr_type = s_axis_mm2s_instr_tdata[63];

    // parameters (update per layer)
    logic [2:0] param_type;
    assign param_type = s_axis_mm2s_instr_tdata[62:60];

    logic [9:0] pqf_param_k, pqf_param_c, pq_param_c;
    logic [8:0] pqf_param_ih, pqf_param_iw, pqf_param_h, pqf_param_w;
    logic [3:0] pqf_param_i, pqf_param_j;
    logic [15:0] layer_k, layer_c;
    logic [8:0] layer_ih, layer_iw, layer_h, layer_w;
    logic [5:0] f_param_k, f_param_c, f_param_h, f_param_w;
    logic [2:0] f_param_i, f_param_j;
    logic [2:0] str_h, str_w;
    logic [2:0] layer_pad_b, layer_pad_r, layer_pad_t, layer_pad_l;
    logic [9:0] wbuf_wpb;
    logic       end_of_model;  // eom

    // intermediates - some long-length multiply results
    logic [17:0] layer_iw_layer_ih, layer_w_layer_h;
    logic [27:0] wbuf_btt;
    logic [27:0] layer_iw_ih_pq_c;
    logic [ 7:0] pqf_i_pqf_j;
    logic [17:0] pqf_i_pqf_j_pqf_c;

    logic [31:0] act_layer_baddr, w_layer_baddr, res_layer_baddr, bn_layer_baddr;

    // variables (update per tile)
    logic [1:0] data_type;  // 00 - ACT, 01 - W, 10 - Res adder, 11 - BN
    logic eos_tile;  // generate EOF signal in the data mover cmd
    logic updt_slot_sel;  // select update time slot (double buffer)
    logic [9:0] st_idx_k, st_idx_c;
    logic [8:0] st_idx_h, st_idx_w;
    logic [5:0] s_idx_k, s_idx_c;
    logic [3:0] s_idx_h, s_idx_w;
    logic updt_pe_eol;

    always_ff @(posedge clk) begin : dec_param_instr
        if (hs_s_axis_mm2s_instr & (~instr_type)) begin
            if (param_type == 3'b000) begin
                pqf_param_i  <= s_axis_mm2s_instr_tdata[59:56];
                pqf_param_ih <= s_axis_mm2s_instr_tdata[55:47];
                pqf_param_iw <= s_axis_mm2s_instr_tdata[46:38];
                pqf_param_k  <= s_axis_mm2s_instr_tdata[37:28];
                pqf_param_c  <= s_axis_mm2s_instr_tdata[27:18];
                pqf_param_h  <= s_axis_mm2s_instr_tdata[17:9];
                pqf_param_w  <= s_axis_mm2s_instr_tdata[8:0];
            end else if (param_type == 3'b001) begin
                pqf_param_j <= s_axis_mm2s_instr_tdata[59:56];
                layer_ih    <= s_axis_mm2s_instr_tdata[55:47];
                layer_iw    <= s_axis_mm2s_instr_tdata[46:38];
                layer_k     <= s_axis_mm2s_instr_tdata[33:18];
                layer_h     <= s_axis_mm2s_instr_tdata[17:9];
                layer_w     <= s_axis_mm2s_instr_tdata[8:0];
            end else if (param_type == 3'b010) begin
                layer_c     <= s_axis_mm2s_instr_tdata[57:42];
                layer_pad_t <= s_axis_mm2s_instr_tdata[41:39];
                layer_pad_l <= s_axis_mm2s_instr_tdata[38:36];
                str_h       <= s_axis_mm2s_instr_tdata[35:33];
                str_w       <= s_axis_mm2s_instr_tdata[32:30];
                f_param_k   <= s_axis_mm2s_instr_tdata[29:24];
                f_param_c   <= s_axis_mm2s_instr_tdata[23:18];
                f_param_i   <= s_axis_mm2s_instr_tdata[17:15];
                f_param_j   <= s_axis_mm2s_instr_tdata[14:12];
                f_param_h   <= s_axis_mm2s_instr_tdata[11:6];
                f_param_w   <= s_axis_mm2s_instr_tdata[5:0];
            end else if (param_type == 3'b011) begin
                pq_param_c      <= s_axis_mm2s_instr_tdata[59:50];
                layer_w_layer_h <= s_axis_mm2s_instr_tdata[49:32];
                act_layer_baddr <= s_axis_mm2s_instr_tdata[31:0];
            end else if (param_type == 3'b100) begin
                wbuf_wpb          <= s_axis_mm2s_instr_tdata[59:50];
                layer_iw_layer_ih <= s_axis_mm2s_instr_tdata[49:32];
                w_layer_baddr     <= s_axis_mm2s_instr_tdata[31:0];
            end else if (param_type == 3'b101) begin
                wbuf_btt        <= s_axis_mm2s_instr_tdata[59:32];
                res_layer_baddr <= s_axis_mm2s_instr_tdata[31:0];
            end else if (param_type == 3'b110) begin
                layer_iw_ih_pq_c <= s_axis_mm2s_instr_tdata[59:32];
                bn_layer_baddr   <= s_axis_mm2s_instr_tdata[31:0];
            end else if (param_type == 3'b111) begin
                end_of_model      <= s_axis_mm2s_instr_tdata[58];
                pqf_i_pqf_j       <= s_axis_mm2s_instr_tdata[57:50];
                // words_per_tile      <= s_axis_mm2s_instr_tdata[59:50];
                pqf_i_pqf_j_pqf_c <= s_axis_mm2s_instr_tdata[49:32];
            end
        end
    end

    always_ff @(posedge clk) begin : dec_variable_instr
        if (hs_s_axis_mm2s_instr & instr_type) begin
            data_type     <= s_axis_mm2s_instr_tdata[62:61];
            updt_pe_eol   <= s_axis_mm2s_instr_tdata[60];
            updt_slot_sel <= s_axis_mm2s_instr_tdata[59];
            eos_tile      <= s_axis_mm2s_instr_tdata[58];
            st_idx_k      <= s_axis_mm2s_instr_tdata[57:48];
            st_idx_c      <= s_axis_mm2s_instr_tdata[47:38];
            st_idx_h      <= s_axis_mm2s_instr_tdata[37:29];
            st_idx_w      <= s_axis_mm2s_instr_tdata[28:20];
            s_idx_k       <= s_axis_mm2s_instr_tdata[19:14];
            s_idx_c       <= s_axis_mm2s_instr_tdata[13:8];
            s_idx_h       <= s_axis_mm2s_instr_tdata[7:4];
            s_idx_w       <= s_axis_mm2s_instr_tdata[3:0];
        end
    end
    /***************************** decode the sub-instructions ******************************/

    /*************************** generate intermediate variables ****************************/
    // indicates that the new mem_instruction is read and all the registers are valid
    logic instr_dec_valid, instr_dec_valid_d, instr_dec_valid_d2;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            instr_dec_valid    <= 1'b0;
            instr_dec_valid_d  <= 1'b0;
            instr_dec_valid_d2 <= 1'b0;
        end else begin
            instr_dec_valid    <= hs_s_axis_mm2s_instr & instr_type;
            instr_dec_valid_d  <= instr_dec_valid;
            instr_dec_valid_d2 <= instr_dec_valid_d;
        end
    end

    // tile start stpqf index (all dimensions), will be used for calculating real shape and padding
    logic [15:0] tile_start_idx_act[2:0];  // 0 - iw, 1 - ih, 2 - c
    logic [15:0] tile_start_idx_w  [1:0];  // 0 - c, 1 - k (i, j = 1)
    logic [15:0] tile_start_idx_res[2:0];  // 0 - w, 1 - h, 2 - k

    // tile start stpqf index (all dimensions), will be used for calculating real shape and padding
    logic [15:0] tile_end_idx_act  [2:0];  // 0 - iw, 1 - ih, 2 - c
    logic [15:0] tile_end_idx_w    [1:0];  // 0 - c, 1 - k (i, j = 1)
    logic [15:0] tile_end_idx_res  [2:0];  // 0 - w, 1 - h, 2 - k

    always_ff @(posedge clk) begin
        // if (instr_dec_valid) begin
        tile_start_idx_act[0] <= pqf_param_w * str_w * st_idx_w;
        tile_start_idx_act[1] <= pqf_param_h * str_h * st_idx_h;
        tile_start_idx_act[2] <= pqf_param_c * st_idx_c;
        // w
        tile_start_idx_w[0]   <= pqf_param_c * st_idx_c;
        tile_start_idx_w[1]   <= pqf_param_k * st_idx_k;
        // res
        tile_start_idx_res[0] <= pqf_param_w * st_idx_w;
        tile_start_idx_res[1] <= pqf_param_h * st_idx_h;
        tile_start_idx_res[2] <= pqf_param_k * st_idx_k;
        // end
    end

    // always_comb begin : tile_start_idx
    //     // act
    //     tile_start_idx_act[0] = pqf_param_w * str_w * st_idx_w;
    //     tile_start_idx_act[1] = pqf_param_h * str_h * st_idx_h;
    //     tile_start_idx_act[2] = pqf_param_c * st_idx_c;
    //     // w
    //     tile_start_idx_w  [0] = pqf_param_c * st_idx_c;
    //     tile_start_idx_w  [1] = pqf_param_k * st_idx_k;
    //     // res
    //     tile_start_idx_res[0] = pqf_param_w * st_idx_w;
    //     tile_start_idx_res[1] = pqf_param_h * st_idx_h;
    //     tile_start_idx_res[2] = pqf_param_k * st_idx_k;
    // end

    always_comb begin : tile_end_idx
        // act
        tile_end_idx_act[0] = tile_start_idx_act[0] + pqf_param_iw - 1;
        tile_end_idx_act[1] = tile_start_idx_act[1] + pqf_param_ih - 1;
        tile_end_idx_act[2] = tile_start_idx_act[2] + pqf_param_c - 1;
        // w
        tile_end_idx_w[0]   = tile_start_idx_w[0] + pqf_param_c - 1;
        tile_end_idx_w[1]   = tile_start_idx_w[1] + pqf_param_k - 1;
        // res
        tile_end_idx_res[0] = tile_start_idx_res[0] + pqf_param_w - 1;
        tile_end_idx_res[1] = tile_start_idx_res[1] + pqf_param_h - 1;
        tile_end_idx_res[2] = tile_start_idx_res[2] + pqf_param_k - 1;
    end

    // intermediates - real shape of the current tile
    logic [9:0] r_c, r_k, r_ih, r_iw, r_h, r_w;
    always_ff @(posedge clk) begin : real_tile_shape
        // Only when the decoding is valid, the intermediates can be calculated
        if (instr_dec_valid_d) begin
            r_iw    <= ((tile_start_idx_act[0]<layer_pad_l)&&(tile_end_idx_act[0]>=(layer_iw+layer_pad_l-1)))   ? 
                        layer_iw                                                                                :
                        ((tile_start_idx_act[0]<layer_pad_l))                                                   ? 
                        pqf_param_iw - layer_pad_l                                                              :
                        (tile_end_idx_act[0]>=(layer_iw+layer_pad_l-1))                                         ?
                        layer_iw + layer_pad_l - tile_start_idx_act[0]                                          :
                        pqf_param_iw                                                                            ;
            r_ih    <= ((tile_start_idx_act[1]<layer_pad_t)&&(tile_end_idx_act[1]>=(layer_ih+layer_pad_t-1)))   ? 
                        layer_ih                                                                                :
                        ((tile_start_idx_act[1]<layer_pad_l))                                                   ? 
                        pqf_param_ih - layer_pad_t                                                              :
                        (tile_end_idx_act[1]>=(layer_ih+layer_pad_t-1))                                         ?
                        layer_ih + layer_pad_t - tile_start_idx_act[1]                                          :
                        pqf_param_ih                                                                            ;
            r_c     <= (tile_end_idx_act[2] >= layer_c - 1)                                                     ?
                        layer_c - tile_start_idx_act[2]                                                         :
                        pqf_param_c                                                                             ;
            r_w     <= (tile_end_idx_res[0] >= layer_w - 1)                                                     ?
                        layer_w - tile_start_idx_res[0]                                                         :
                        pqf_param_w                                                                             ;
            r_h     <= (tile_end_idx_res[1] >= layer_h - 1)                                                     ?
                        layer_h - tile_start_idx_res[1]                                                         :
                        pqf_param_h                                                                             ;
            r_k     <= (tile_end_idx_res[2] >= layer_k - 1)                                                     ?
                        layer_k - tile_start_idx_res[2]                                                         :
                        pqf_param_k                                                                             ;
        end
    end

    // intermediates - padding of the current tile, only used for act
    logic [2:0] act_pad_l, act_pad_t, act_pad_r, act_pad_b;
    always_ff @(posedge clk) begin : tile_padding
        // Only when the decoding is valid, the intermediates can be calculated
        // if (instr_dec_valid_d) begin
        act_pad_l <= (tile_start_idx_act[0] < layer_pad_l) ? layer_pad_l : 0;
        act_pad_t <= (tile_start_idx_act[1] < layer_pad_t) ? layer_pad_t : 0;
        act_pad_r <= ((tile_start_idx_act[0]<layer_pad_l)&&(tile_end_idx_act[0]>=(layer_iw+layer_pad_l-1))) ? 
                        pqf_param_iw - layer_pad_l - layer_iw                                                   :
                        (tile_end_idx_act[0]>=(layer_iw+layer_pad_l-1))                                         ? 
                        pqf_param_iw - (layer_iw + layer_pad_l - tile_start_idx_act[0])                         :
                        0                                                                                       ;
        act_pad_b <= ((tile_start_idx_act[1]<layer_pad_t)&&(tile_end_idx_act[1]>=(layer_ih+layer_pad_t-1))) ? 
                        pqf_param_ih - layer_pad_t - layer_ih                                                   :
                        (tile_end_idx_act[1]>=(layer_ih+layer_pad_t-1))                                         ? 
                        pqf_param_ih - (layer_ih + layer_pad_t - tile_start_idx_act[1])                         :
                        0                                                                                       ;
        // end
    end

    // intermediates - data mover starting base address (based on layer_addr and st_idx) of this tile
    // seperate the base_saddr calculation into 2 cycles for timing optimization 
    logic [17:0] opt_idxh_layeriw, opt_idxh_layerw;
    logic [21:0] opt_idxc_layeriwih, opt_idxc_pqfij, opt_idxk_pqfijc, opt_idxk_layerwh;
    always_ff @(posedge clk) begin
        opt_idxh_layeriw   <= tile_start_idx_act[1] * layer_iw;
        opt_idxc_layeriwih <= tile_start_idx_act[2] * layer_iw_layer_ih;
        opt_idxc_pqfij     <= tile_start_idx_w[0] * pqf_i_pqf_j;
        opt_idxk_pqfijc    <= tile_start_idx_w[1] * pqf_i_pqf_j_pqf_c;
        opt_idxh_layerw    <= tile_start_idx_res[1] * layer_w;
        opt_idxk_layerwh   <= tile_start_idx_res[2] * layer_w_layer_h;
    end

    logic [31:0] base_saddr;
    always_ff @(posedge clk) begin : tile_base_saddr
        // if (instr_dec_valid_d) begin 
        if (data_type == 2'b00) begin  // ACT
            // base_saddr <= act_layer_baddr + (tile_start_idx_act[0] + tile_start_idx_act[1] * 
            //             layer_iw + tile_start_idx_act[2] * layer_iw_layer_ih);
            base_saddr  <= act_layer_baddr + tile_start_idx_act[0] + opt_idxh_layeriw + opt_idxc_layeriwih;
        end else if (data_type == 2'b01) begin  // W
            // base_saddr <= w_layer_baddr + (tile_start_idx_w[0] * pqf_i_pqf_j + tile_start_idx_w[1] * pqf_i_pqf_j_pqf_c);
            base_saddr <= w_layer_baddr + opt_idxc_pqfij + opt_idxk_pqfijc;
        end else if (data_type == 2'b10) begin  // RES
            // base_saddr <= res_layer_baddr + (tile_start_idx_res[0] + tile_start_idx_res[1] * 
            //             layer_w + tile_start_idx_res[2] * layer_w_layer_h);
            base_saddr  <= res_layer_baddr + tile_start_idx_res[0] + opt_idxh_layerw + opt_idxk_layerwh;
        end else if (data_type == 2'b11) begin  // BN
            base_saddr <= bn_layer_baddr;
        end
        // end
    end

    // intermediates - real btt (based on start and end index) of this tile, and cmd generation mode
    logic [22:0] gen_btt;
    logic [ 3:0] s_dsa;  // starting dsa in the first transfer, used for accumulation
    logic [ 1:0] cmd_gen_mode;  // 00 - per row; 01 - per channel; 10 - per frame; 11 - only once

    always_ff @(posedge clk) begin : tile_real_btt
        // if (instr_dec_valid_d) begin
        if (~rst_n) begin
            gen_btt <= 0;
        end else if (data_type == 2'b00) begin  // ACT
            if ((tile_start_idx_act[0]<=layer_pad_l)&&(tile_end_idx_act[0]>=(layer_iw+layer_pad_l-1)&&
                    (tile_start_idx_act[1]<=layer_pad_t)&&(tile_end_idx_act[1]>=(layer_ih+layer_pad_t-1)))) begin // TIW == IW & TIH == IH
                cmd_gen_mode <= 2'b10;
                gen_btt <= layer_iw_ih_pq_c;
            end
                else if ((tile_start_idx_act[0]<=layer_pad_l)&&(tile_end_idx_act[0]>=(layer_iw+layer_pad_l-1))) begin // TIW == IW only
                cmd_gen_mode <= 2'b01;
                gen_btt <= layer_iw * r_ih;
            end else begin  // TIW != IW
                cmd_gen_mode <= 2'b00;
                gen_btt <= r_iw;
            end
        end else if (data_type == 2'b01) begin  // W
            cmd_gen_mode <= 2'b11;
            gen_btt <= wbuf_btt;
        end else if (data_type == 2'b10) begin  // RES
            if ((tile_start_idx_res[0] == 0)&&(tile_end_idx_res[0] >= layer_w - 1)&&
                    (tile_start_idx_res[1] == 0)&&(tile_end_idx_res[1] >= layer_h - 1)) begin
                cmd_gen_mode <= 2'b11;
                gen_btt <= layer_w_layer_h * r_k;
            end else if ((tile_start_idx_res[0] == 0) && (tile_end_idx_res[0] >= layer_w - 1)) begin
                cmd_gen_mode <= 2'b01;
                gen_btt <= layer_w * r_h;
            end else begin
                cmd_gen_mode <= 2'b00;
                gen_btt <= r_w;
            end
        end else if (data_type == 2'b11) begin  // BN
            cmd_gen_mode <= 2'b11;
            gen_btt <= layer_k << 2;
        end
        // end
    end
    always_comb begin
        s_dsa = gen_btt[3:0];  // NEED to be parameterized
    end

    // intermediates - the layer size for address iteration (only for act and res)
    logic [19:0] layer_sizec, layer_size;
    always_ff @(posedge clk) begin
        // if (instr_dec_valid_d) begin
        if (data_type == 2'b00) begin  // ACT
            layer_sizec <= layer_iw_ih_pq_c;
            layer_size  <= layer_iw_layer_ih;
        end else if (data_type == 2'b10) begin
            layer_sizec <= layer_w_layer_h * r_k;
            layer_size  <= layer_w_layer_h;
        end
        // end
    end

    // intermediates - total bytes for one w buffer (only for w)
    logic [9:0] words_per_wbuf;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            words_per_wbuf <= 9'd128;
        end
        if (instr_dec_valid_d2) begin
            if (data_type == 2'b01) begin
                words_per_wbuf <= wbuf_wpb;
            end
        end
    end
    /*************************** generate intermediate variables ****************************/

    /****************** Generate data mover cmd based on sub-instructions *******************/
    // for each instruction read, start a mover_begin
    logic mover_begin;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            mover_begin <= 1'b0;
        end else mover_begin <= instr_dec_valid_d2;
    end

    // generation state
    logic gen_state;
    logic mover_gen_end;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            gen_state <= 1'b0;
        end else if (mover_gen_end) begin
            gen_state <= 1'b0;
        end else if (mover_begin) begin
            gen_state <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            s_axis_mm2s_instr_tready <= 1'b1;
        end else if (hs_s_axis_mm2s_instr & instr_type) begin
            s_axis_mm2s_instr_tready <= 1'b0;
        end else if (mover_gen_end) begin
            s_axis_mm2s_instr_tready <= 1'b1;
        end
    end

    /************************ cmd generation loop - act ************************/
    logic cnt_en;
    logic [9:0] cnt_tih, cnt_pq_ich, cnt_f_ich;
    logic cnt_tih_end, cnt_pq_ich_end, cnt_f_ich_end;
    always_ff @(posedge clk) begin : loop_r_ih
        if (mover_begin) begin
            cnt_tih <= 10'd0;
        end else if ((cmd_gen_mode == 2'b00) & cnt_en & gen_state) begin
            if (cnt_tih == r_ih - 1) begin
                cnt_tih <= 10'd0;
            end else cnt_tih <= cnt_tih + 1;
        end
    end
    assign cnt_tih_end = (cnt_tih == r_ih - 1);

    logic [9:0] r_c_idx, r_c_idx_f;
    // assign r_c_idx = pq_param_c * cnt_f_ich + cnt_pq_ich;
    logic loop_end_pqc, loop_end_fc;
    assign loop_end_pqc = (r_c_idx == r_c - 1);
    assign loop_end_fc  = ((r_c_idx_f + pq_param_c) >= r_c) & (cmd_gen_mode == 2'b10);
    always_ff @(posedge clk) begin : loop_pq_c  // TODO: ADD CONFLICT WITH PQF_C>R_C
        if (mover_begin) begin
            cnt_pq_ich <= 10'd0;
            r_c_idx    <= 10'd0;
        end else if ((cmd_gen_mode == 2'b00) & cnt_en & cnt_tih_end & gen_state) begin
            if (loop_end_pqc) begin
                cnt_pq_ich <= 10'd0;
                r_c_idx    <= 10'd0;
            end else if (cnt_pq_ich == pq_param_c - 1) begin
                cnt_pq_ich <= 10'd0;
                r_c_idx    <= r_c_idx + 1;
            end else begin
                cnt_pq_ich <= cnt_pq_ich + 1;
                r_c_idx    <= r_c_idx + 1;
            end
        end else if ((cmd_gen_mode == 2'b01) & cnt_en & gen_state) begin
            if (loop_end_pqc) begin
                cnt_pq_ich <= 10'd0;
                r_c_idx    <= 10'd0;
            end else if (cnt_pq_ich == pq_param_c - 1) begin
                cnt_pq_ich <= 10'd0;
                r_c_idx    <= r_c_idx + 1;
            end else begin
                cnt_pq_ich <= cnt_pq_ich + 1;
                r_c_idx    <= r_c_idx + 1;
            end
        end
    end
    assign cnt_pq_ich_end = (cnt_pq_ich == pq_param_c - 1) | loop_end_pqc;

    always_ff @(posedge clk) begin : loop_f_c
        if (mover_begin) begin
            cnt_f_ich <= 10'd0;
            r_c_idx_f <= 10'd0;
        end
        else if ((cmd_gen_mode == 2'b00)&cnt_en&cnt_pq_ich_end&cnt_tih_end&gen_state) begin
            if (loop_end_pqc) begin
                cnt_f_ich <= 10'd0;
            end else if (cnt_f_ich == f_param_c - 1) begin
                cnt_f_ich <= 10'd0;
            end else cnt_f_ich <= cnt_f_ich + 1;
        end else if ((cmd_gen_mode == 2'b01) & cnt_en & cnt_pq_ich_end & gen_state) begin
            if (loop_end_pqc) begin
                cnt_f_ich <= 10'd0;
            end else if (cnt_f_ich == f_param_c - 1) begin
                cnt_f_ich <= 10'd0;
            end else cnt_f_ich <= cnt_f_ich + 1;
        end else if ((cmd_gen_mode == 2'b10) & cnt_en & gen_state) begin
            if (loop_end_fc) begin
                cnt_f_ich <= 10'd0;
                r_c_idx_f <= 10'd0;
            end else if (cnt_f_ich == f_param_c - 1) begin
                cnt_f_ich <= 10'd0;
                r_c_idx_f <= 10'd0;
            end else begin
                cnt_f_ich <= cnt_f_ich + 1;
                r_c_idx_f <= r_c_idx_f + pq_param_c;
            end
        end
    end
    assign cnt_f_ich_end = (cnt_f_ich == f_param_c - 1) | loop_end_pqc | loop_end_fc;
    /************************ cmd generation loop - act ************************/

    /************************ cmd generation loop - res ************************/
    logic [9:0] cnt_th, cnt_tk;
    logic cnt_th_end, cnt_tk_end;
    always_ff @(posedge clk) begin : loop_r_h
        if (mover_begin) begin
            cnt_th <= 9'd0;
        end else if ((cmd_gen_mode == 2'b00) & cnt_en & gen_state) begin
            if (cnt_th == r_h - 1) begin
                cnt_th <= 9'd0;
            end else cnt_th <= cnt_th + 1;
        end
    end
    assign cnt_th_end = (cnt_th == r_h - 1);

    always_ff @(posedge clk) begin : loop_r_k
        if (mover_begin) begin
            cnt_tk <= 10'd0;
        end else if ((cmd_gen_mode == 2'b00) & cnt_en & cnt_th_end & gen_state) begin
            if (cnt_tk == r_k - 1) begin
                cnt_tk <= 10'd0;
            end else cnt_tk <= cnt_tk + 1;
        end else if ((cmd_gen_mode == 2'b01) & cnt_en & gen_state) begin
            if (cnt_tk == r_k - 1) begin
                cnt_tk <= 10'd0;
            end else cnt_tk <= cnt_tk + 1;
        end
    end
    assign cnt_tk_end = (cnt_tk == r_k - 1);
    /************************ cmd generation loop - res ************************/

    logic mover_hs;
    assign mover_hs = m_axis_mm2s_cmd_tvalid & m_axis_mm2s_cmd_tready;

    // for cmd_gen_mode == 2'b11
    logic mover_begin_d;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            mover_begin_d <= 1'b0;
        end else if (mover_hs & (cmd_gen_mode == 2'b11)) begin
            mover_begin_d <= 1'b0;
        end else if (mover_begin & (cmd_gen_mode == 2'b11)) begin
            mover_begin_d <= 1'b1;
        end
    end

    logic mover_gen_end_act, mover_gen_end_res, mover_gen_end_w, mover_gen_end_bn;
    assign mover_gen_end_act = (cmd_gen_mode == 2'b11)?(mover_hs & mover_begin_d):
                                (cmd_gen_mode == 2'b10)?(mover_hs&cnt_f_ich_end):
                                (cmd_gen_mode == 2'b01)?(mover_hs&cnt_pq_ich_end&cnt_f_ich_end):
                                (mover_hs&cnt_tih_end&cnt_pq_ich_end&cnt_f_ich_end);
    assign mover_gen_end_res = (cmd_gen_mode == 2'b11)?(mover_hs & mover_begin_d):
                                (cmd_gen_mode == 2'b01)?(mover_hs&cnt_tk_end):
                                (mover_hs&cnt_th_end&cnt_tk_end);
    assign mover_gen_end_w = mover_hs & mover_begin_d;
    assign mover_gen_end_bn = mover_hs & mover_begin_d;

    assign mover_gen_end     = (data_type == 2'b00)?mover_gen_end_act:(data_type == 2'b01)?mover_gen_end_w:
                                (data_type == 2'b10)?mover_gen_end_res:mover_gen_end_bn;

    // generate the final cmd for data mover
    logic       mover_eof;
    logic [5:0] mover_dsa;
    assign mover_eof = 1'b1;

    logic [22:0] mover_btt;
    assign mover_btt = (gen_btt == 23'd0) ? layer_iw_layer_ih : gen_btt;

    // generate starting address
    logic [31:0] mover_gen_addr;
    always_ff @(posedge clk) begin : saddr_gen
        if (mover_begin) begin
            mover_gen_addr <= base_saddr;
        end else if (gen_state & cnt_en) begin
            if (cmd_gen_mode == 2'b10) begin  // directly generate one instruction for data mover
                mover_gen_addr <= mover_gen_addr + layer_sizec;
            end else if (cmd_gen_mode == 2'b01) begin
                mover_gen_addr <= mover_gen_addr + layer_size;
            end else if (cmd_gen_mode == 2'b00) begin
                mover_gen_addr <= (data_type == 2'b00) ? (mover_gen_addr + layer_iw) :
                                    (mover_gen_addr + layer_w);
            end
        end
    end

    // always_comb begin
    //     if (data_type == 2'b00) begin // ACT
    //         mover_gen_addr = act_layer_baddr;
    //     end
    //     else if (data_type == 2'b01) begin // W
    //         mover_gen_addr = w_layer_baddr;
    //     end
    //     else if (data_type == 2'b10) begin // RES
    //         mover_gen_addr = res_layer_baddr;
    //     end
    //     else if (data_type == 2'b11) begin // BN
    //         mover_gen_addr = bn_layer_baddr;                
    //     end
    //     else begin
    //         mover_gen_addr = act_layer_baddr;
    //     end
    // end

    // always_comb begin
    //     mover_gen_addr = act_layer_baddr;
    // end

    // generate DSA
    // Note that only support 8-bit (16 bytes per transfer) now.
    // If we need to support 16-bit, need to change the parameters
    logic [3:0] dsa_ptr = '0;
    always_ff @(posedge clk) begin : mover_dsa_gen
        if (mover_begin) begin
            dsa_ptr <= 4'd0;
        end else if (gen_state & cnt_en) begin
            if ((data_type == 2'b00) & cnt_pq_ich_end) begin
                dsa_ptr <= 4'd0;
            end else dsa_ptr <= dsa_ptr + s_dsa;
        end
    end
    assign mover_dsa[3:0] = (data_type == 2'b10) ? 4'd0 : dsa_ptr;
    assign mover_dsa[5:4] = 0;

    // final data mover cmd. If CORE_CMD_WIDTH changed, need to modify clearly
    assign m_axis_mm2s_cmd_tdata[22:0] = mover_btt;  // BTT
    assign m_axis_mm2s_cmd_tdata[23] = 1'b1;  // TYPE
    assign m_axis_mm2s_cmd_tdata[29:24] = mover_dsa;  // TYPE
    assign m_axis_mm2s_cmd_tdata[30] = mover_eof;  // EOF
    // assign m_axis_mm2s_cmd_tdata[31]    = (mover_gen_addr[3:0] == 4'b0000)?1'b0:1'b1; // DRR
    assign m_axis_mm2s_cmd_tdata[31] = 1'b1;  // DRR
    assign m_axis_mm2s_cmd_tdata[63:32] = mover_gen_addr;  // SADDR
    assign m_axis_mm2s_cmd_tdata[79:64] = 0;

    // cmd stream control
    assign cnt_en = gen_state&(~m_axis_mm2s_cmd_tvalid|(m_axis_mm2s_cmd_tready&m_axis_tag_tready));
    logic mover_valid_r;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            mover_valid_r <= 1'b0;
        end else if (mover_hs & (~cnt_en)) begin
            mover_valid_r <= 1'b0;
        end else if (mover_hs & (cmd_gen_mode == 2'b11)) begin
            mover_valid_r <= 1'b0;
        end else if (cnt_en | mover_begin) begin
            mover_valid_r <= 1'b1;
        end
    end
    assign m_axis_mm2s_cmd_tvalid = gen_state & mover_valid_r;

    /****************** Generate data mover cmd based on sub-instructions *******************/

    /*********************** Generate tag based on sub-instructions ************************/
    logic [1:0] tag_data_type;
    logic tag_eom, tag_eol, tag_eos, tag_eot, tag_eof;
    logic [3:0] tag_btd;
    logic [5:0] tag_pad_info;  // only when this tile is act, this field is valid
    logic [9:0] tag_r_ih, tag_r_iw, tag_r_c;  // only when this tile is act, this field is valid

    assign tag_data_type = data_type;
    // assign tag_eof = (cmd_gen_mode == 2'b11)?1'b1:(cmd_gen_mode == 2'b10|cmd_gen_mode == 2'b01)?
    //                 (cnt_pq_ich_end):(cnt_tih_end&cnt_pq_ich_end);
    // assign tag_eot = (cmd_gen_mode == 2'b11)?1'b1:(cmd_gen_mode == 2'b10|cmd_gen_mode == 2'b01)?
    //                 (cnt_pq_ich_end&cnt_f_ich_end):(cnt_tih_end&cnt_pq_ich_end&cnt_f_ich_end);
    assign tag_eom = end_of_model & tag_eol;
    assign tag_eol = updt_pe_eol & tag_eot;
    assign tag_eof = (cmd_gen_mode == 2'b11|cmd_gen_mode == 2'b10)?1'b1:(cmd_gen_mode == 2'b01)?
                    (cnt_pq_ich_end):(cnt_tih_end&cnt_pq_ich_end);
    assign tag_eot = (cmd_gen_mode == 2'b11)?1'b1:(cmd_gen_mode == 2'b10)?cnt_f_ich_end:(cmd_gen_mode == 2'b01)?
                    (cnt_pq_ich_end&cnt_f_ich_end):(cnt_tih_end&cnt_pq_ich_end&cnt_f_ich_end);
    assign tag_eos = tag_eot & eos_tile;
    // assign tag_btd = mover_btd;
    assign tag_btd = 0;
    assign tag_pad_info[2:0] = act_pad_l;
    assign tag_pad_info[5:3] = act_pad_t;
    assign tag_r_c = r_c;
    assign tag_r_ih = r_ih;
    assign tag_r_iw = r_iw;

    always_comb begin
        m_axis_tag_tdata[63]    = 1'b0;
        m_axis_tag_tdata[62:61] = tag_data_type;
        m_axis_tag_tdata[60]    = 1'b0;
        m_axis_tag_tdata[59]    = tag_eom;
        m_axis_tag_tdata[58]    = tag_eol;
        m_axis_tag_tdata[57]    = updt_slot_sel;
        m_axis_tag_tdata[56]    = tag_eos;
        m_axis_tag_tdata[55]    = tag_eot;
        m_axis_tag_tdata[54]    = tag_eof;
        m_axis_tag_tdata[53:50] = tag_btd;
        if (data_type == 2'b00) begin
            m_axis_tag_tdata[49:44] = tag_pad_info;
            m_axis_tag_tdata[43:34] = tag_r_c;
            m_axis_tag_tdata[33:24] = tag_r_ih;
            m_axis_tag_tdata[23:14] = tag_r_iw;
            m_axis_tag_tdata[13:8]  = s_idx_c;
            m_axis_tag_tdata[7:4]   = s_idx_h;
            m_axis_tag_tdata[3:0]   = s_idx_w;
        end else if (data_type == 2'b01) begin
            m_axis_tag_tdata[49:47] = f_param_i;
            m_axis_tag_tdata[46:44] = f_param_j;
            m_axis_tag_tdata[43:38] = f_param_k;
            m_axis_tag_tdata[37:32] = f_param_c;
            m_axis_tag_tdata[31]    = updt_pe_eol;
            m_axis_tag_tdata[30:21] = words_per_wbuf;
            m_axis_tag_tdata[20:14] = 0;
            m_axis_tag_tdata[13:8]  = s_idx_c;
            m_axis_tag_tdata[7:6]   = 0;
            m_axis_tag_tdata[5:0]   = s_idx_k;
        end else begin
            m_axis_tag_tdata[49:0] = 0;
        end
    end

    // tag stream control
    logic tag_hs;
    logic tag_valid_r;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            tag_valid_r <= 1'b0;
        end else if (tag_hs & (~cnt_en)) begin
            tag_valid_r <= 1'b0;
        end else if (tag_hs & (cmd_gen_mode == 2'b11)) begin
            tag_valid_r <= 1'b0;
        end else if (cnt_en | mover_begin) begin
            tag_valid_r <= 1'b1;
        end
    end
    assign tag_hs = m_axis_tag_tvalid & m_axis_tag_tready;
    assign m_axis_tag_tvalid = gen_state & tag_valid_r;

    /*********************** Generate tag based on sub-instructions ************************/

endmodule
