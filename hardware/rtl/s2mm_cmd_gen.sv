(*use_dsp48 = "no" *)
module s2mm_cmd_gen #(
    parameter CORE_INSTR_WIDTH = 64,
    parameter CORE_CMD_WIDTH   = 80
) (
    input  logic                            clk,
    input  logic                            rst_n,
    // input stream - sub-instructions
    input  logic [CORE_INSTR_WIDTH - 1 : 0] s_axis_s2mm_instr_tdata,
    input  logic                            s_axis_s2mm_instr_tvalid,
    output logic                            s_axis_s2mm_instr_tready,
    // output stream - data mover cmd
    output logic [  CORE_CMD_WIDTH - 1 : 0] m_axis_s2mm_cmd_tdata,
    output logic                            m_axis_s2mm_cmd_tvalid,
    input  logic                            m_axis_s2mm_cmd_tready
);

    /***************************** decode the sub-instructions ******************************/
    // handshake signals in sub-instructions channel
    logic hs_s_axis_s2mm_instr;
    logic instr_type;
    assign hs_s_axis_s2mm_instr = s_axis_s2mm_instr_tvalid & s_axis_s2mm_instr_tready;
    assign instr_type = s_axis_s2mm_instr_tdata[63];

    // parameters (update per layer)
    logic [2:0] param_type;
    assign param_type = s_axis_s2mm_instr_tdata[62:60];

    logic [9:0] pqf_param_k, pqf_param_c, pq_param_k, pq_param_c;
    logic [8:0] pqf_param_ih, pqf_param_iw, pqf_param_h, pqf_param_w;
    logic [3:0] pqf_param_i, pqf_param_j, pq_param_i, pq_param_j;
    logic [15:0] layer_k;
    logic [8:0] layer_ih, layer_iw, layer_h, layer_w;

    logic [17:0] layer_w_layer_h;
    logic [31:0] fout_layer_baddr;

    // variables (update per tile)
    logic end_of_model;
    logic eos_tile, eom_tile, eol_tile;  // generate EOF signal in the data mover cmd
    logic [9:0] st_idx_k, st_idx_c;
    logic [8:0] st_idx_h, st_idx_w;

    always_ff @(posedge clk) begin : dec_param_instr
        if (hs_s_axis_s2mm_instr & (~instr_type)) begin
            if (param_type == 3'b000) begin
                pqf_param_i  <= s_axis_s2mm_instr_tdata[59:56];
                pqf_param_ih <= s_axis_s2mm_instr_tdata[55:47];
                pqf_param_iw <= s_axis_s2mm_instr_tdata[46:38];
                pqf_param_k  <= s_axis_s2mm_instr_tdata[37:28];
                pqf_param_c  <= s_axis_s2mm_instr_tdata[27:18];
                pqf_param_h  <= s_axis_s2mm_instr_tdata[17:9];
                pqf_param_w  <= s_axis_s2mm_instr_tdata[8:0];
            end else if (param_type == 3'b001) begin
                pqf_param_j <= s_axis_s2mm_instr_tdata[59:56];
                layer_ih    <= s_axis_s2mm_instr_tdata[55:47];
                layer_iw    <= s_axis_s2mm_instr_tdata[46:38];
                layer_k     <= s_axis_s2mm_instr_tdata[33:18];
                layer_h     <= s_axis_s2mm_instr_tdata[17:9];
                layer_w     <= s_axis_s2mm_instr_tdata[8:0];
            end else if (param_type == 3'b011) begin
                layer_w_layer_h <= s_axis_s2mm_instr_tdata[49:32];
            end else if (param_type == 3'b111) begin
                end_of_model     <= s_axis_s2mm_instr_tdata[58];
                fout_layer_baddr <= s_axis_s2mm_instr_tdata[31:0];
            end
        end
    end

    always_ff @(posedge clk) begin : dec_variable_instr
        if (hs_s_axis_s2mm_instr & instr_type) begin
            eol_tile <= s_axis_s2mm_instr_tdata[60];
            eos_tile <= s_axis_s2mm_instr_tdata[58];
            st_idx_k <= s_axis_s2mm_instr_tdata[57:48];
            st_idx_c <= s_axis_s2mm_instr_tdata[47:38];
            st_idx_h <= s_axis_s2mm_instr_tdata[37:29];
            st_idx_w <= s_axis_s2mm_instr_tdata[28:20];
        end
    end

    assign eom_tile = eol_tile & end_of_model;

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
            instr_dec_valid    <= hs_s_axis_s2mm_instr & instr_type;
            instr_dec_valid_d  <= instr_dec_valid;
            instr_dec_valid_d2 <= instr_dec_valid_d;
        end
    end

    // tile start stpqf index (all dimensions), will be used for calculating real shape and padding
    logic [15:0] tile_start_idx_fout[2:0];  // 0 - w, 1 - h, 2 - k

    // tile start stpqf index (all dimensions), will be used for calculating real shape and padding
    logic [15:0] tile_end_idx_fout  [2:0];  // 0 - w, 1 - h, 2 - k

    always_ff @(posedge clk) begin
        // if (instr_dec_valid) begin
        tile_start_idx_fout[0] <= pqf_param_w * st_idx_w;
        tile_start_idx_fout[1] <= pqf_param_h * st_idx_h;
        tile_start_idx_fout[2] <= pqf_param_k * st_idx_k;
        // end
    end

    // always_comb begin : tile_start_idx
    //     tile_start_idx_fout[0] = pqf_param_w * st_idx_w;
    //     tile_start_idx_fout[1] = pqf_param_h * st_idx_h;
    //     tile_start_idx_fout[2] = pqf_param_k * st_idx_k;
    // end

    always_comb begin : tile_end_idx
        tile_end_idx_fout[0] = tile_start_idx_fout[0] + pqf_param_w - 1;
        tile_end_idx_fout[1] = tile_start_idx_fout[1] + pqf_param_h - 1;
        tile_end_idx_fout[2] = tile_start_idx_fout[2] + pqf_param_k - 1;
    end

    // intermediates - real shape of the current tile
    logic [9:0] r_k, r_h, r_w;
    always_ff @(posedge clk) begin : real_tile_shape
        // Only when the decoding is valid, the intermediates can be calculated
        if (instr_dec_valid_d) begin
            r_w     <= (tile_end_idx_fout[0] > layer_w - 1)                                                 ?
                        layer_w - tile_start_idx_fout[0]                                                    :
                        pqf_param_w                                                                         ;
            r_h     <= (tile_end_idx_fout[1] > layer_h - 1)                                                 ?
                        layer_h - tile_start_idx_fout[1]                                                    :
                        pqf_param_h                                                                         ;
            r_k     <= (tile_end_idx_fout[2] > layer_k - 1)                                                 ?
                        layer_k - tile_start_idx_fout[2]                                                    :
                        pqf_param_k                                                                         ;
        end
    end

    // intermediates - data mover starting base address (based on layer_addr and st_idx) of this tile
    logic [17:0] opt_idxh_layerw;
    logic [21:0] opt_idxk_layerwh;
    always_ff @(posedge clk) begin
        opt_idxh_layerw  <= tile_start_idx_fout[1] * layer_w;
        opt_idxk_layerwh <= tile_start_idx_fout[2] * layer_w_layer_h;
    end

    logic [31:0] base_saddr;
    always_ff @(posedge clk) begin : tile_base_saddr
        // Only when the decoding is valid, the intermediates can be calculated
        // if (instr_dec_valid_d) begin 
        // base_saddr <= fout_layer_baddr + (tile_start_idx_fout[0] + tile_start_idx_fout[1] * 
        //             layer_w + tile_start_idx_fout[2] * layer_w_layer_h);
        // end
        base_saddr  <= fout_layer_baddr + tile_start_idx_fout[0] + opt_idxh_layerw + opt_idxk_layerwh;
    end

    // intermediates - real btt (based on start and end index) of this tile, and cmd generation mode
    logic [22:0] gen_btt;
    logic [ 3:0] s_dsa;  // starting dsa in the first transfer, used for accumulation
    logic [ 1:0] cmd_gen_mode;  // 00 - per row; 01 - per channel; 10 - per frame; 11 - only once

    always_ff @(posedge clk) begin : tile_real_btt
        // if (instr_dec_valid_d) begin
        if (~rst_n) begin
            gen_btt <= 0;
        end
            else if ((tile_start_idx_fout[0] == 0)&&(tile_end_idx_fout[0] >= layer_w - 1)&&
                (tile_start_idx_fout[1] == 0)&&(tile_end_idx_fout[1] >= layer_h - 1)) begin
            cmd_gen_mode <= 2'b11;
            gen_btt <= layer_w_layer_h * r_k;
        end else if ((tile_start_idx_fout[0] == 0) && (tile_end_idx_fout[0] >= layer_w - 1)) begin
            cmd_gen_mode <= 2'b01;
            gen_btt <= layer_w * r_h;
        end else begin
            cmd_gen_mode <= 2'b00;
            gen_btt <= r_w;
        end
        // end
    end
    always_comb begin
        s_dsa = gen_btt[3:0];  // NEED to be parameterized
    end

    // intermediates - the layer size for address iteration (only for act and res)
    logic [31:0] layer_sizec, layer_size;
    always_ff @(posedge clk) begin
        // if (instr_dec_valid_d) begin
        layer_sizec <= layer_w_layer_h * r_k;
        layer_size  <= layer_w_layer_h;
        // end
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
            s_axis_s2mm_instr_tready <= 1'b1;
        end else if (hs_s_axis_s2mm_instr & instr_type) begin
            s_axis_s2mm_instr_tready <= 1'b0;
        end else if (mover_gen_end) begin
            s_axis_s2mm_instr_tready <= 1'b1;
        end
    end

    /************************ cmd generation loop - fout ************************/
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
    /************************ cmd generation loop - fout ************************/

    logic mover_hs;
    assign mover_hs = m_axis_s2mm_cmd_tvalid & m_axis_s2mm_cmd_tready;

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

    assign mover_gen_end = (cmd_gen_mode == 2'b11)?(mover_hs & mover_begin_d):
                            (cmd_gen_mode == 2'b01)?(mover_hs&cnt_tk_end):
                            (mover_hs&cnt_th_end&cnt_tk_end);

    // generate the final cmd for data mover
    logic       mover_eof;
    logic [5:0] mover_dsa;
    logic       mover_eom;
    logic [3:0] mover_tag;
    assign mover_eof = 1'b1;
    assign mover_eom    =   (cmd_gen_mode == 2'b11)?(mover_hs & mover_begin_d   & eom_tile):
                            (cmd_gen_mode == 2'b01)?(mover_hs & cnt_tk_end      & eom_tile):
                            (mover_hs & cnt_th_end & cnt_tk_end & eom_tile);
    assign mover_tag = mover_eom ? 4'b1111 : mover_gen_end ? 4'b1100 : 4'b0000;

    // generate cmd btt (not the real btt) and btd (bytes to drop) for tkeep dropping
    logic [22:0] mover_btt;
    assign mover_btt = gen_btt;

    // generate starting address
    logic [31:0] mover_gen_addr = '0;
    always_ff @(posedge clk) begin : saddr_gen
        if (mover_begin) begin
            mover_gen_addr <= base_saddr;
        end else if (gen_state & cnt_en) begin
            if (cmd_gen_mode == 2'b10) begin  // directly generate one instruction for data mover
                mover_gen_addr <= mover_gen_addr + layer_sizec;
            end else if (cmd_gen_mode == 2'b01) begin
                mover_gen_addr <= mover_gen_addr + layer_size;
            end else if (cmd_gen_mode == 2'b00) begin
                mover_gen_addr <= mover_gen_addr + layer_w;
            end
        end
    end

    // always_comb begin
    //     mover_gen_addr = fout_layer_baddr;
    // end

    // final data mover cmd. If CORE_CMD_WIDTH changed, need to modify clearly
    assign m_axis_s2mm_cmd_tdata[22:0] = mover_btt;  // BTT
    assign m_axis_s2mm_cmd_tdata[23] = 1'b1;  // TYPE
    assign m_axis_s2mm_cmd_tdata[29:24] = 0;  // DSA
    assign m_axis_s2mm_cmd_tdata[30] = 1'b1;  // EOF
    // assign m_axis_s2mm_cmd_tdata[31]    = (mover_gen_addr[3:0] == 4'b0000)?1'b0:1'b1; // DRR
    assign m_axis_s2mm_cmd_tdata[31] = 1'b1;  // DRR
    assign m_axis_s2mm_cmd_tdata[63:32] = mover_gen_addr;  // SADDR
    assign m_axis_s2mm_cmd_tdata[71:64] = 0;  // SADDR
    assign m_axis_s2mm_cmd_tdata[75:72] = mover_tag;
    assign m_axis_s2mm_cmd_tdata[79:76] = 0;

    // cmd stream control
    assign cnt_en = gen_state & (~m_axis_s2mm_cmd_tvalid | (m_axis_s2mm_cmd_tready));
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
    assign m_axis_s2mm_cmd_tvalid = gen_state & mover_valid_r;

    /****************** Generate data mover cmd based on sub-instructions *******************/

endmodule
