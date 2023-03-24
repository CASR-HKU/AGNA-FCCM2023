`timescale 1ns / 1ps

`include "def.sv"

(*use_dsp48 = "no" *) module pe_ctrl_exec #(
    parameter ABUF_NUM          = `PARAM_ABUF_NUM,
    parameter BRAM_NUM_PER_ABUF = `PARAM_BRAM_NUM_PER_ABUF,
    parameter ABUF_ADDR_WIDTH   = `PARAM_ABUF_ADDR_WIDTH,
    parameter ABUF_DATA_WIDTH   = `PARAM_ABUF_DATA_WIDTH,

    parameter WBUF_NUM          = `PARAM_WBUF_NUM,
    parameter BRAM_NUM_PER_WBUF = `PARAM_BRAM_NUM_PER_WBUF,
    parameter WBUF_ADDR_WIDTH   = `PARAM_WBUF_ADDR_WIDTH,
    parameter WBUF_DATA_WIDTH   = `PARAM_WBUF_DATA_WIDTH,

    parameter PBUF_NUM          = `PARAM_PBUF_NUM,
    parameter BRAM_NUM_PER_PBUF = `PARAM_BRAM_NUM_PER_PBUF,
    parameter PBUF_ADDR_WIDTH   = `PARAM_PBUF_ADDR_WIDTH,
    parameter PBUF_DATA_WIDTH   = `PARAM_PBUF_DATA_WIDTH,

    parameter RF_NUM          = `PARAM_RF_NUM,
    parameter RF_NUM_PER_ABUF = `PARAM_RF_NUM_PER_ABUF,
    parameter RF_ADDR_WIDTH   = `PARAM_RF_ADDR_WIDTH,
    parameter RF_DATA_WIDTH   = `PARAM_RF_DATA_WIDTH,

    parameter PARAM_A_H = `HW_CONFIG_A_H,
    parameter PARAM_A_W = `HW_CONFIG_A_W,
    parameter PARAM_A_I = `HW_CONFIG_A_I,
    parameter PARAM_A_J = `HW_CONFIG_A_J
) (
    // common signal
    input  logic                       clk,
    input  logic                       rst_n,
    // execute abufbuf
    output logic [                9:0] abuf2rf_updt_idx   [2:0],
    // update rf
    output logic [RF_NUM_PER_ABUF-1:0] rf_updt_en,
    output logic                       rf_updt_sel,
    output logic                       rf_updt_addr_rst,
    // output logic [RF_ADDR_WIDTH-1:0]        rf_updt_addr        [RF_NUM_PER_ABUF-1:0]   ,
    // execute rf
    output logic                       rf_exec_sel,
    output logic [  RF_ADDR_WIDTH-1:0] rf_exec_addr,
    // execute wbuf 
    output logic [WBUF_ADDR_WIDTH-1:0] wbuf_exec_addr,
    // execute psumbuf    
    output logic [PBUF_ADDR_WIDTH-1:0] pbuf_exec_rd_addr,
    output logic                       pbuf_exec_wr_en,
    output logic [PBUF_ADDR_WIDTH-1:0] pbuf_exec_wr_addr,
    // f loop factor
    input  logic [                5:0] F_LOOP_FACTORS     [5:0],
    // q loop factor
    input  logic [                9:0] Q_LOOP_FACTORS     [5:0],
    // p loop factor
    input  logic [                9:0] P_LOOP_FACTORS     [5:0],
    // strpad factor
    input  logic [                2:0] STRPAD_FACTORS     [1:0],
    // wbuf address shape (execution)
    input  logic [                8:0] WBUF_ADDR_SHAPE    [3:0],
    // pbuf address shape (execution)
    input  logic [                8:0] PSUM_ADDR_SHAPE    [2:0],
    // execute enable
    input  logic                       exec_slot_start,
    // control flags
    output logic                       pbuf_exec_rd_rst_en,
    output logic                       adder_rst_en,
    // exec_p_done for global control
    output logic                       exec_slot_done,
    // for depth-wise computation, w_addr_comp = 1'b1
    input  logic                       w_addr_comp,
    // If the current time slot is t_c == 0, indicate execution controller should reset psum
    input  logic                       tc_reset
    // timing optimization
    // input  logic [RF_ADDR_WIDTH-1:0]        rf_exec_addr_qiwj                           , 
    // input  logic [RF_ADDR_WIDTH-1:0]        rf_exec_addr_qwj                            ,
    // input  logic [WBUF_ADDR_WIDTH-1:0]      wbuf_exec_addr_cij                          ,
    // input  logic [WBUF_ADDR_WIDTH-1:0]      wbuf_exec_addr_ij                           ,
    // input  logic [PBUF_ADDR_WIDTH-1:0]      pbuf_exec_rd_addr_hw                        ,
    // input  logic [9:0]                      abuf2rf_updt_idx_1_strqf                    , 
    // input  logic [9:0]                      abuf2rf_updt_idx_1_qf                       ,
    // input  logic [9:0]                      abuf2rf_updt_idx_2_strqf                    , 
    // input  logic [9:0]                      abuf2rf_updt_idx_2_qf                       ,
    // input  logic [9:0]                      ABUF2RF_ADDR_SHAPE_C                        ,
    // input  logic [9:0]                      ABUF2RF_ADDR_SHAPE_IH                       ,
    // input  logic [9:0]                      ABUF2RF_ADDR_SHAPE_IW                       
);

    // state control
    logic exec_en;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            exec_en <= 1'b0;
        end else begin
            if (exec_slot_done_p) begin
                exec_en <= 1'b0;
            end else if (exec_slot_start) begin
                exec_en <= 1'b1;
            end
        end
    end

    /******************************************* optimizing timing ***************************************************/
    logic [RF_ADDR_WIDTH-1:0] rf_exec_addr_qiwj_opt, rf_exec_addr_qwj_opt;
    always_ff @(posedge clk) begin
        // rf_exec_addr_qiwj_opt   <= rf_exec_addr_qiwj;
        // rf_exec_addr_qwj_opt    <= rf_exec_addr_qwj;
        rf_exec_addr_qiwj_opt <= Q_LOOP_FACTORS[4] * Q_LOOP_FACTORS[2] * Q_LOOP_FACTORS[5];
        rf_exec_addr_qwj_opt  <= Q_LOOP_FACTORS[2] * Q_LOOP_FACTORS[5];
    end

    logic [WBUF_ADDR_WIDTH-1:0] wbuf_exec_addr_cij_opt, wbuf_exec_addr_ij_opt;
    always_ff @(posedge clk) begin
        // wbuf_exec_addr_cij_opt <= wbuf_exec_addr_cij;
        // wbuf_exec_addr_ij_opt  <= wbuf_exec_addr_ij;
        wbuf_exec_addr_cij_opt <= WBUF_ADDR_SHAPE[1] * WBUF_ADDR_SHAPE[2] * WBUF_ADDR_SHAPE[3];
        wbuf_exec_addr_ij_opt  <= WBUF_ADDR_SHAPE[2] * WBUF_ADDR_SHAPE[3];
    end

    logic [PBUF_ADDR_WIDTH-1:0] pbuf_exec_rd_addr_hw_opt;
    always_ff @(posedge clk) begin
        // pbuf_exec_rd_addr_hw_opt <= pbuf_exec_rd_addr_hw;
        pbuf_exec_rd_addr_hw_opt <= PSUM_ADDR_SHAPE[1] * PSUM_ADDR_SHAPE[2];
    end

    logic [9:0] abuf2rf_updt_idx_1_strqf_opt, abuf2rf_updt_idx_1_qf_opt;
    logic [9:0] abuf2rf_updt_idx_2_strqf_opt, abuf2rf_updt_idx_2_qf_opt;
    always_ff @(posedge clk) begin
        // abuf2rf_updt_idx_1_strqf_opt    <= abuf2rf_updt_idx_1_strqf;
        // abuf2rf_updt_idx_1_qf_opt       <= abuf2rf_updt_idx_1_qf;
        // abuf2rf_updt_idx_2_strqf_opt    <= abuf2rf_updt_idx_2_strqf;
        // abuf2rf_updt_idx_2_qf_opt       <= abuf2rf_updt_idx_2_qf;
        abuf2rf_updt_idx_1_strqf_opt <= STRPAD_FACTORS[0] * Q_LOOP_FACTORS[1] * F_LOOP_FACTORS[1];
        abuf2rf_updt_idx_1_qf_opt    <= Q_LOOP_FACTORS[4] * F_LOOP_FACTORS[4];
        abuf2rf_updt_idx_2_strqf_opt <= STRPAD_FACTORS[1] * Q_LOOP_FACTORS[2] * F_LOOP_FACTORS[2];
        abuf2rf_updt_idx_2_qf_opt    <= Q_LOOP_FACTORS[5] * F_LOOP_FACTORS[5];
    end
    /******************************************* optimizing timing ***************************************************/

    logic [9:0] ABUF2RF_ADDR_SHAPE[2:0];  // Q_C, QF_IH, QF_IW
    always_ff @(posedge clk) begin
        // ABUF2RF_ADDR_SHAPE[0]   <= ABUF2RF_ADDR_SHAPE_C;
        // ABUF2RF_ADDR_SHAPE[1]   <= ABUF2RF_ADDR_SHAPE_IH;
        // ABUF2RF_ADDR_SHAPE[2]   <= ABUF2RF_ADDR_SHAPE_IW;
        ABUF2RF_ADDR_SHAPE[0] <= Q_LOOP_FACTORS[3];
        ABUF2RF_ADDR_SHAPE[1]   <= STRPAD_FACTORS[0]*(Q_LOOP_FACTORS[1]*F_LOOP_FACTORS[1]-1)+Q_LOOP_FACTORS[4]*F_LOOP_FACTORS[4];
        ABUF2RF_ADDR_SHAPE[2]   <= STRPAD_FACTORS[1]*(Q_LOOP_FACTORS[2]*F_LOOP_FACTORS[2]-1)+Q_LOOP_FACTORS[5]*F_LOOP_FACTORS[5];
    end

    // loop for q and p factors
    logic [9:0] q_factor_cnt[5:0];
    logic [5:0] q_factor_dim_end;  // signals for loop ending.
    logic [9:0] p_factor_cnt[5:0];
    logic [5:0] p_factor_dim_end;  // signals for loop ending.

    logic [9:0] updt_cnt_abuf2rf[2:0];
    logic [2:0] updt_abuf2rf_dim_end;  // signals for loop ending.
    logic [8:0] p_factor_cnt_abuf2rf[5:0];
    logic [5:0] p_factor_abuf2rf_dim_end;  // signals for loop ending.    

    // counter gate control (for sync between updt and exec)
    // if the timimng is not good, give the control signal to outside instruction
    logic updt_gate;
    logic exec_gate;
    logic rf_w_fout_exec_en;  // only after first rf update finishes, exec rf can start
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            updt_gate <= 1'b0;
        end else if (exec_en & rf_w_fout_exec_en & (~exec_gate)) begin
            if (q_factor_dim_end[0]) begin
                updt_gate <= 1'b0;
            end else if (updt_abuf2rf_dim_end[0]) begin
                updt_gate <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            exec_gate <= 1'b0;
        end else if (exec_en & (~updt_gate)) begin
            if (updt_abuf2rf_dim_end[0]) begin
                exec_gate <= 1'b0;
            end else if (q_factor_dim_end[0]) begin
                exec_gate <= 1'b1;
            end
        end
    end

    // loop for abuf2rf
    logic abuf2rf_qf_end;
    logic abuf2rf_updt_gate;  // for the last rf exec, this signal will be asserted
    assign abuf2rf_qf_end = updt_abuf2rf_dim_end[0];

    // delayed abuf2rf_qf_end (for rf reset/reverse control)
    logic abuf2rf_qf_end_d;
    delay_chain #(
        .DW (1),
        .LEN(4)
    ) delay_abuf2rf_qf_end (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (abuf2rf_qf_end),
        .out(abuf2rf_qf_end_d)
    );
    always_comb begin
        rf_updt_addr_rst = abuf2rf_qf_end_d;
    end

    genvar abuf2rf_dim_gen;
    generate
        for (abuf2rf_dim_gen = 2; abuf2rf_dim_gen >= 0; abuf2rf_dim_gen--) begin
            if (abuf2rf_dim_gen == 2) begin  // the first loop (iw)
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        updt_cnt_abuf2rf[abuf2rf_dim_gen] <= 0;
                    end else if (exec_en & (~updt_gate) & (~abuf2rf_updt_gate)) begin
                        if (updt_cnt_abuf2rf[abuf2rf_dim_gen]==ABUF2RF_ADDR_SHAPE[abuf2rf_dim_gen]-1) begin // reach the bound
                            updt_cnt_abuf2rf[abuf2rf_dim_gen] <= 0;
                        end else begin
                            updt_cnt_abuf2rf[abuf2rf_dim_gen] <= updt_cnt_abuf2rf[abuf2rf_dim_gen] + 1;
                        end
                    end
                end
                assign updt_abuf2rf_dim_end[abuf2rf_dim_gen] = exec_en & (~updt_gate) & (~abuf2rf_updt_gate) & (updt_cnt_abuf2rf[abuf2rf_dim_gen]==ABUF2RF_ADDR_SHAPE[abuf2rf_dim_gen]-1);
            end else begin  // other loops (q2f_iw and q2_ich)
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        updt_cnt_abuf2rf[abuf2rf_dim_gen] <= 0;
                    end
                    else if (exec_en & updt_abuf2rf_dim_end[abuf2rf_dim_gen+1] & (~updt_gate)) begin
                        if (updt_cnt_abuf2rf[abuf2rf_dim_gen]==ABUF2RF_ADDR_SHAPE[abuf2rf_dim_gen]-1) begin // reach the bound
                            updt_cnt_abuf2rf[abuf2rf_dim_gen] <= 0;
                        end else begin
                            updt_cnt_abuf2rf[abuf2rf_dim_gen] <= updt_cnt_abuf2rf[abuf2rf_dim_gen] + 1;
                        end
                    end
                end
                assign updt_abuf2rf_dim_end[abuf2rf_dim_gen] = (updt_cnt_abuf2rf[abuf2rf_dim_gen]==ABUF2RF_ADDR_SHAPE[abuf2rf_dim_gen]-1)&updt_abuf2rf_dim_end[abuf2rf_dim_gen+1];
            end
        end
    endgenerate


    // p loop for abuf2rf update
    genvar p_abuf2rf_dim_gen;
    generate
        for (p_abuf2rf_dim_gen = 5; p_abuf2rf_dim_gen >= 0; p_abuf2rf_dim_gen--) begin
            if (p_abuf2rf_dim_gen == 5) begin  // the first loop (p_oh)
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen] <= 0;
                    end  // TODO: abufish the control signal
                         // Done
                    else if (exec_en & updt_abuf2rf_dim_end[0]& (~updt_gate) & (~abuf2rf_updt_gate)) begin
                        if (p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen]==P_LOOP_FACTORS[p_abuf2rf_dim_gen]-1) begin // reach the bound
                            p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen] <= 0;
                        end else begin
                            p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen] <= p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen] + 1;
                        end
                    end
                end
                assign p_factor_abuf2rf_dim_end[p_abuf2rf_dim_gen] = updt_abuf2rf_dim_end[0]&(p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen]==P_LOOP_FACTORS[p_abuf2rf_dim_gen]-1);
            end else begin  // other loops
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen] <= 0;
                    end
                    else if (exec_en & updt_abuf2rf_dim_end[0] & p_factor_abuf2rf_dim_end[p_abuf2rf_dim_gen+1] & (~updt_gate)&(~abuf2rf_updt_gate)) begin
                        if (p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen]==P_LOOP_FACTORS[p_abuf2rf_dim_gen]-1) begin // reach the bound
                            p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen] <= 0;
                        end else begin
                            p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen] <= p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen] + 1;
                        end
                    end
                end
                assign p_factor_abuf2rf_dim_end[p_abuf2rf_dim_gen] = updt_abuf2rf_dim_end[0]&(p_factor_cnt_abuf2rf[p_abuf2rf_dim_gen]==P_LOOP_FACTORS[p_abuf2rf_dim_gen]-1)&
                        p_factor_abuf2rf_dim_end[p_abuf2rf_dim_gen+1];
            end
        end
    endgenerate

    // enable control for rf, w and fout execution. Only after the rf receive the first block (qf), the execution can start.
    // that means only rf_w_fout_exec_en == 1, the p and q will begin to loop
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            rf_w_fout_exec_en <= 1'b0;
        end else if (exec_slot_done_p) begin
            rf_w_fout_exec_en <= 1'b0;
        end else if (updt_abuf2rf_dim_end[0]) begin
            rf_w_fout_exec_en <= 1'b1;
        end
    end

    // loop for q factor
    genvar q_dim_gen;
    generate
        for (q_dim_gen = 5; q_dim_gen >= 0; q_dim_gen--) begin
            if (q_dim_gen == 5) begin  // the first loop (q_kh)
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        q_factor_cnt[q_dim_gen] <= 0;
                    end  // TODO: abufish the control signal
                         // Done
                    else if (exec_en & rf_w_fout_exec_en & (~exec_gate)) begin
                        if (q_factor_cnt[q_dim_gen]==Q_LOOP_FACTORS[q_dim_gen]-1) begin // reach the bound
                            q_factor_cnt[q_dim_gen] <= 0;
                        end else begin
                            q_factor_cnt[q_dim_gen] <= q_factor_cnt[q_dim_gen] + 1;
                        end
                    end
                end
                assign q_factor_dim_end[q_dim_gen] = exec_en & rf_w_fout_exec_en & (~exec_gate) & (q_factor_cnt[q_dim_gen]==Q_LOOP_FACTORS[q_dim_gen]-1);
            end else begin  // other loops
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        q_factor_cnt[q_dim_gen] <= 0;
                    end  // TODO: abufish the control signal
                         // Done
                    else if (exec_en & rf_w_fout_exec_en & q_factor_dim_end[q_dim_gen+1] & (~exec_gate)) begin
                        if (q_factor_cnt[q_dim_gen]==Q_LOOP_FACTORS[q_dim_gen]-1) begin // reach the bound
                            q_factor_cnt[q_dim_gen] <= 0;
                        end else begin
                            q_factor_cnt[q_dim_gen] <= q_factor_cnt[q_dim_gen] + 1;
                        end
                    end
                end
                assign q_factor_dim_end[q_dim_gen] = (q_factor_cnt[q_dim_gen]==Q_LOOP_FACTORS[q_dim_gen]-1)&q_factor_dim_end[q_dim_gen+1];
            end
        end
    endgenerate

    // loop for p factor
    genvar p_dim_gen;
    generate
        for (p_dim_gen = 5; p_dim_gen >= 0; p_dim_gen--) begin
            if (p_dim_gen == 5) begin  // the first loop (p_oh)
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        p_factor_cnt[p_dim_gen] <= 0;
                    end  // TODO: abufish the control signal
                         // Done
                    else if (exec_en & rf_w_fout_exec_en & q_factor_dim_end[0] & (~exec_gate)) begin
                        if (p_factor_cnt[p_dim_gen]==P_LOOP_FACTORS[p_dim_gen]-1) begin // reach the bound
                            p_factor_cnt[p_dim_gen] <= 0;
                        end else begin
                            p_factor_cnt[p_dim_gen] <= p_factor_cnt[p_dim_gen] + 1;
                        end
                    end
                end
                assign p_factor_dim_end[p_dim_gen] = q_factor_dim_end[0]&(p_factor_cnt[p_dim_gen]==P_LOOP_FACTORS[p_dim_gen]-1);
            end else begin  // other loops
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        p_factor_cnt[p_dim_gen] <= 0;
                    end  // TODO: abufish the control signal
                         // Done
                    else if (exec_en & rf_w_fout_exec_en & q_factor_dim_end[0] & p_factor_dim_end[p_dim_gen+1] & (~exec_gate)) begin
                        if (p_factor_cnt[p_dim_gen]==P_LOOP_FACTORS[p_dim_gen]-1) begin // reach the bound
                            p_factor_cnt[p_dim_gen] <= 0;
                        end else begin
                            p_factor_cnt[p_dim_gen] <= p_factor_cnt[p_dim_gen] + 1;
                        end
                    end
                end
                assign p_factor_dim_end[p_dim_gen] = q_factor_dim_end[0]&(p_factor_cnt[p_dim_gen]==P_LOOP_FACTORS[p_dim_gen]-1)&p_factor_dim_end[p_dim_gen+1];
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            abuf2rf_updt_gate <= 1'b0;
        end else if (p_factor_dim_end[0]) begin
            abuf2rf_updt_gate <= 1'b0;
        end else if (p_factor_abuf2rf_dim_end[0]) begin
            abuf2rf_updt_gate <= 1'b1;
        end
    end

    // abuf2rf update
    // timing optimization
    // logic [9:0] abuf2rf_updt_idx_0_opt,     abuf2rf_updt_idx_1_opt_1, abuf2rf_updt_idx_1_opt_2;
    // logic [9:0] abuf2rf_updt_idx_2_opt_1,   abuf2rf_updt_idx_2_opt_2;
    // always_ff @( posedge clk ) begin
    //     abuf2rf_updt_idx_0_opt      <= p_factor_cnt_abuf2rf[3]*Q_LOOP_FACTORS[3];
    //     abuf2rf_updt_idx_1_opt_1    <= abuf2rf_updt_idx_1_strqf_opt*p_factor_cnt_abuf2rf[1];
    //     abuf2rf_updt_idx_1_opt_2    <= abuf2rf_updt_idx_1_qf_opt*p_factor_cnt_abuf2rf[4];
    //     abuf2rf_updt_idx_2_opt_1    <= abuf2rf_updt_idx_2_strqf_opt*p_factor_cnt_abuf2rf[2];
    //     abuf2rf_updt_idx_2_opt_2    <= abuf2rf_updt_idx_2_qf_opt*p_factor_cnt_abuf2rf[5];
    // end
    // logic [9:0] updt_cnt_abuf2rf_d [2:0];
    // always_ff @( posedge clk ) begin
    //     updt_cnt_abuf2rf_d[0] <= updt_cnt_abuf2rf[0];
    //     updt_cnt_abuf2rf_d[1] <= updt_cnt_abuf2rf[1];
    //     updt_cnt_abuf2rf_d[2] <= updt_cnt_abuf2rf[2];
    // end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            abuf2rf_updt_idx[0] <= 0;
            abuf2rf_updt_idx[1] <= 0;
            abuf2rf_updt_idx[2] <= 0;
        end else begin
            abuf2rf_updt_idx[0] <=  p_factor_cnt_abuf2rf[3]*Q_LOOP_FACTORS[3]+updt_cnt_abuf2rf[0];
            abuf2rf_updt_idx[1] <=  abuf2rf_updt_idx_1_strqf_opt*p_factor_cnt_abuf2rf[1]+
                                    abuf2rf_updt_idx_1_qf_opt*p_factor_cnt_abuf2rf[4]+
                                    updt_cnt_abuf2rf[1];
            abuf2rf_updt_idx[2] <=  abuf2rf_updt_idx_2_strqf_opt*p_factor_cnt_abuf2rf[2]+
                                    abuf2rf_updt_idx_2_qf_opt*p_factor_cnt_abuf2rf[5]+
                                    updt_cnt_abuf2rf[2];
        end
    end

    // generate the rf update address and write enable control
    // only if the wr_en is 1, the data will be written to rf
    logic [RF_NUM_PER_ABUF-1:0] rf_iw_en, rf_ih_en;
    // logic [RF_ADDR_WIDTH-1:0] rf_updt_addr_r [RF_NUM_PER_ABUF-1:0];
    logic [RF_NUM_PER_ABUF-1:0] rf_updt_en_r;
    logic [RF_NUM_PER_ABUF-1:0][8:0] rf_q_h_cnt, rf_q_w_cnt, rf_q_i_cnt, rf_q_j_cnt;

    logic rf_en_state;
    assign rf_en_state = exec_en & (~updt_gate) & (~abuf2rf_updt_gate);

    /******************************************* optimizing timing ***************************************************/
    logic [5:0] opt_f_base_idx_iw[RF_NUM_PER_ABUF-1:0];
    logic [5:0] opt_f_base_idx_ih[RF_NUM_PER_ABUF-1:0];
    logic [7:0] opt_f_str_iw;
    logic [7:0] opt_f_str_ih;

    always_ff @(posedge clk) begin
        opt_f_str_iw <= F_LOOP_FACTORS[2] * STRPAD_FACTORS[1];
        opt_f_str_ih <= F_LOOP_FACTORS[1] * STRPAD_FACTORS[0];
    end

    genvar a_h, a_w, a_i, a_j;
    generate
        for (a_h = 0; a_h < PARAM_A_H; a_h++) begin
            for (a_w = 0; a_w < PARAM_A_W; a_w++) begin
                for (a_i = 0; a_i < PARAM_A_I; a_i++) begin
                    for (a_j = 0; a_j < PARAM_A_J; a_j++) begin
                        always_ff @(posedge clk) begin
                            opt_f_base_idx_iw[rf_idx_in_abuf(
                                a_h, a_w, a_i, a_j
                            )] <= a_w * STRPAD_FACTORS[1] + a_j;
                            opt_f_base_idx_ih[rf_idx_in_abuf(
                                a_h, a_w, a_i, a_j
                            )] <= a_h * STRPAD_FACTORS[0] + a_i;
                        end
                    end
                end
            end
        end
    endgenerate
    /******************************************* optimizing timing ***************************************************/

    generate
        for (a_h = 0; a_h < PARAM_A_H; a_h++) begin
            for (a_w = 0; a_w < PARAM_A_W; a_w++) begin
                for (a_i = 0; a_i < PARAM_A_I; a_i++) begin
                    for (a_j = 0; a_j < PARAM_A_J; a_j++) begin
                        assign rf_ih_en[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] = rf_en_state & (updt_cnt_abuf2rf[1] == opt_f_base_idx_ih[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] + (rf_q_h_cnt[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] * opt_f_str_ih + rf_q_i_cnt[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] * F_LOOP_FACTORS[4]));
                        assign rf_iw_en[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] = rf_en_state & (updt_cnt_abuf2rf[2] == opt_f_base_idx_iw[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] + (rf_q_w_cnt[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] * opt_f_str_iw + rf_q_j_cnt[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] * F_LOOP_FACTORS[5]));
                        assign rf_updt_en_r[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] = rf_ih_en[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] & rf_iw_en[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )];
                        // always_ff @( posedge clk ) begin
                        //     if (~rst_n) begin
                        //         rf_updt_en[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 1'b0;
                        //     end
                        //     else begin
                        //         rf_updt_en[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= rf_updt_en_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)];
                        //     end
                        // end
                        delay_chain #(
                            .DW (1),
                            .LEN(4)
                        ) delay_rf_updt_en (
                            .clk(clk),
                            .rst(rst_n),
                            .en (1'b1),
                            .in (rf_updt_en_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)]),
                            .out(rf_updt_en[rf_idx_in_abuf(a_h, a_w, a_i, a_j)])
                        );
                        // rf_q count 
                        always_ff @(posedge clk) begin
                            if (~rst_n) begin
                                rf_q_h_cnt[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                                rf_q_w_cnt[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                                rf_q_i_cnt[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                                rf_q_j_cnt[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                            end else begin
                                if (rf_updt_en_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)]) begin
                                    if (rf_q_j_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] == Q_LOOP_FACTORS[5] - 1) begin
                                        rf_q_j_cnt[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                                    end else
                                        rf_q_j_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] <= rf_q_j_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] + 1;
                                end
                                if (rf_updt_en_r[rf_idx_in_abuf(
                                        a_h, a_w, a_i, a_j
                                    )] & (rf_q_j_cnt[rf_idx_in_abuf(
                                        a_h, a_w, a_i, a_j
                                    )] == Q_LOOP_FACTORS[5] - 1)) begin
                                    if (rf_q_w_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] == Q_LOOP_FACTORS[2] - 1) begin
                                        rf_q_w_cnt[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                                    end else
                                        rf_q_w_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] <= rf_q_w_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] + 1;
                                end
                                if (rf_updt_en_r[rf_idx_in_abuf(
                                        a_h, a_w, a_i, a_j
                                    )] & (rf_q_j_cnt[rf_idx_in_abuf(
                                        a_h, a_w, a_i, a_j
                                    )] == Q_LOOP_FACTORS[5] - 1) & (rf_q_w_cnt[rf_idx_in_abuf(
                                        a_h, a_w, a_i, a_j
                                    )] == Q_LOOP_FACTORS[2] - 1)) begin
                                    if (rf_q_i_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] == Q_LOOP_FACTORS[4] - 1) begin
                                        rf_q_i_cnt[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                                    end else
                                        rf_q_i_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] <= rf_q_i_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] + 1;
                                end
                                if (rf_updt_en_r[rf_idx_in_abuf(
                                        a_h, a_w, a_i, a_j
                                    )] & (rf_q_j_cnt[rf_idx_in_abuf(
                                        a_h, a_w, a_i, a_j
                                    )] == Q_LOOP_FACTORS[5] - 1) & (rf_q_w_cnt[rf_idx_in_abuf(
                                        a_h, a_w, a_i, a_j
                                    )] == Q_LOOP_FACTORS[2] - 1) & (rf_q_i_cnt[rf_idx_in_abuf(
                                        a_h, a_w, a_i, a_j
                                    )] == Q_LOOP_FACTORS[4] - 1)) begin
                                    if (rf_q_h_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] == Q_LOOP_FACTORS[1] - 1) begin
                                        rf_q_h_cnt[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                                    end else
                                        rf_q_h_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] <= rf_q_h_cnt[rf_idx_in_abuf(
                                            a_h, a_w, a_i, a_j
                                        )] + 1;
                                end
                            end
                        end
                        // addr counter (+1 every cycle)
                        // assign rf_updt_addr[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] = rf_updt_addr_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)];
                        // always_ff @( posedge clk ) begin
                        //     if (~rst_n) begin
                        //         rf_updt_addr_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                        //     end
                        //     else if (abuf2rf_qf_end_d) begin
                        //         rf_updt_addr_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                        //     end
                        //     else if (exec_en & rf_updt_en[rf_idx_in_abuf(a_h, a_w, a_i, a_j)]) begin
                        //         rf_updt_addr_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= rf_updt_addr_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] + 1;
                        //     end
                        // end
                    end
                end
            end
        end
    endgenerate

    // rf, w and out execution
    // calculate execution addr index (for wbuf and outbuf)
    // NOTE: if the timing is not good, try to insert pipeline here
    logic [8:0] exec_addr_idx[5:0];
    genvar exec_addr_gen;
    generate
        for (exec_addr_gen = 0; exec_addr_gen < 6; exec_addr_gen++) begin
            always_ff @(posedge clk) begin
                if (~rst_n) begin
                    exec_addr_idx[exec_addr_gen] <= 0;
                end else begin
                    exec_addr_idx[exec_addr_gen] <= p_factor_cnt[exec_addr_gen]*Q_LOOP_FACTORS[exec_addr_gen]+q_factor_cnt[exec_addr_gen];
                end
            end
        end
    endgenerate


    // generate the rf exec address
    // NOTE that the order has been modified
    // MODIFIED: 220705 - rf order has been changed to [q_h, q_i, q_w, q_j]
    logic [RF_ADDR_WIDTH-1:0] rf_exec_addr_p;
    // optimize timing
    // logic [RF_ADDR_WIDTH-1:0] rf_exec_opt_1, rf_exec_opt_2, rf_exec_opt_3, rf_exec_opt_4;
    // always_ff @( posedge clk ) begin
    //     rf_exec_opt_1 <= q_factor_cnt[1]*rf_exec_addr_qiwj_opt;
    //     rf_exec_opt_2 <= q_factor_cnt[4]*rf_exec_addr_qwj_opt;
    //     rf_exec_opt_3 <= q_factor_cnt[2]*Q_LOOP_FACTORS[5];
    //     rf_exec_opt_4 <= q_factor_cnt[5];
    // end
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            rf_exec_addr_p <= 0;
        end else begin
            rf_exec_addr_p <=   q_factor_cnt[1]*rf_exec_addr_qiwj_opt+q_factor_cnt[4]*rf_exec_addr_qwj_opt+
                                q_factor_cnt[2]*Q_LOOP_FACTORS[5]+q_factor_cnt[5];
        end
    end

    // wbuf addr delay
    delay_chain #(
        .DW (RF_ADDR_WIDTH),
        .LEN(4)
    ) delay_rf_exec_addr (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (rf_exec_addr_p),
        .out(rf_exec_addr)
    );

    // generate the w_buf exec address
    logic [8:0] wbuf_exec_addr_idx[3:0];  // [och, ich, kw, kh]
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wbuf_exec_addr_idx[0] <= 0;
            wbuf_exec_addr_idx[1] <= 0;
            wbuf_exec_addr_idx[2] <= 0;
            wbuf_exec_addr_idx[3] <= 0;
        end else begin
            wbuf_exec_addr_idx[0] <= (w_addr_comp) ? 6'd1 : exec_addr_idx[0];
            wbuf_exec_addr_idx[1] <= exec_addr_idx[3];
            wbuf_exec_addr_idx[2] <= exec_addr_idx[4];
            wbuf_exec_addr_idx[3] <= exec_addr_idx[5];
        end
    end

    logic [WBUF_ADDR_WIDTH-1:0] wbuf_exec_addr_r;
    // timing optimization
    // logic [WBUF_ADDR_WIDTH-1:0] wbuf_addr_opt_1, wbuf_addr_opt_2, wbuf_addr_opt_3, wbuf_addr_opt_4;
    // always_ff @( posedge clk ) begin
    //     wbuf_addr_opt_1 <= wbuf_exec_addr_idx[0]*wbuf_exec_addr_cij_opt;
    //     wbuf_addr_opt_2 <= wbuf_exec_addr_idx[1]*wbuf_exec_addr_ij_opt;
    //     wbuf_addr_opt_3 <= wbuf_exec_addr_idx[2]*WBUF_ADDR_SHAPE[3];
    //     wbuf_addr_opt_4 <= wbuf_exec_addr_idx[3];
    // end
    // assign wbuf_exec_addr = wbuf_exec_addr_r;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wbuf_exec_addr_r <= 0;
        end else begin
            wbuf_exec_addr_r <= wbuf_exec_addr_idx[0]*wbuf_exec_addr_cij_opt+
                                wbuf_exec_addr_idx[1]*wbuf_exec_addr_ij_opt+
                                wbuf_exec_addr_idx[2]*WBUF_ADDR_SHAPE[3]+wbuf_exec_addr_idx[3];
            // wbuf_exec_addr_r <= wbuf_exec_addr_idx[0]*Q_LOOP_FACTORS[1]+wbuf_exec_addr_idx[1]*Q_LOOP_FACTORS[2]+
            //                 wbuf_exec_addr_idx[2]*Q_LOOP_FACTORS[3]+wbuf_exec_addr_idx[3];
        end
    end

    // wbuf addr delay
    delay_chain #(
        .DW (WBUF_ADDR_WIDTH),
        .LEN(2)
    ) delay_wbuf_exec_addr (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (wbuf_exec_addr_r),
        .out(wbuf_exec_addr)
    );

    // generate the out_buf exec address
    logic [8:0] pbuf_exec_addr_idx[2:0];  // [och, ow, oh]
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            pbuf_exec_addr_idx[0] <= 0;
            pbuf_exec_addr_idx[1] <= 0;
            pbuf_exec_addr_idx[2] <= 0;
        end else begin
            pbuf_exec_addr_idx[0] <= exec_addr_idx[0];
            pbuf_exec_addr_idx[1] <= exec_addr_idx[1];
            pbuf_exec_addr_idx[2] <= exec_addr_idx[2];
        end
    end

    logic [PBUF_ADDR_WIDTH-1:0] pbuf_exec_rd_addr_p;
    // timing optimization
    // logic [PBUF_ADDR_WIDTH-1:0] pbuf_addr_opt_1, pbuf_addr_opt_2, pbuf_addr_opt_3;
    // always_ff @( posedge clk ) begin
    //     pbuf_addr_opt_1 <= pbuf_exec_addr_idx[0]*pbuf_exec_rd_addr_hw_opt;
    //     pbuf_addr_opt_2 <= pbuf_exec_addr_idx[1]*PSUM_ADDR_SHAPE[2];
    //     pbuf_addr_opt_3 <= pbuf_exec_addr_idx[2];
    // end
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            pbuf_exec_rd_addr_p <= 0;
        end else begin
            pbuf_exec_rd_addr_p <=  pbuf_exec_addr_idx[0]*pbuf_exec_rd_addr_hw_opt+
                                    pbuf_exec_addr_idx[1]*PSUM_ADDR_SHAPE[2]+
                                    pbuf_exec_addr_idx[2];
        end
    end

    // read/write enable of foutbuf and adder_in_ext_en control 
    logic inner_fout_en;
    assign inner_fout_en = (q_factor_cnt[3] == 0) & (q_factor_cnt[4] == 0) & (q_factor_cnt[5] == 0);
    delay_chain #(
        .DW (1),
        .LEN(`PARAM_CNT_ADDR_DELAY + `PARAM_ADDR_DSP_OUT_DELAY + `PARAM_ADDER_TREE_DELAY)
    ) delay_fout_adder_in_ext_en (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (inner_fout_en),
        .out(adder_rst_en)
    );

    logic wr_en_p;
    assign wr_en_p = (q_factor_dim_end[3]) & (q_factor_dim_end[4]) & (q_factor_dim_end[5]);
    delay_chain #(
        .DW (1),
        .LEN(`PARAM_CU_EXEC_DELAY)
    ) delay_fout_wr_en (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (wr_en_p),
        .out(pbuf_exec_wr_en)
    );

    logic pbuf_exec_rd_rst_en_p;
    assign pbuf_exec_rd_rst_en_p = wr_en_p&(p_factor_cnt[3]==0)&(p_factor_cnt[4]==0)&(p_factor_cnt[5]==0)&tc_reset;
    delay_chain #(
        .DW (1),
        .LEN(`PARAM_CU_EXEC_DELAY - `PARAM_FOUT_WR_DELAY - 1)
    ) delay_fout_rd_rst_en (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (pbuf_exec_rd_rst_en_p),
        .out(pbuf_exec_rd_rst_en)
    );

    // foutbuf read delay
    delay_chain #(
        .DW (PBUF_ADDR_WIDTH),
        .LEN(`PARAM_CU_EXEC_DELAY - `PARAM_FOUT_WR_DELAY - 3)
    ) delay_fout_rd_addr (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (pbuf_exec_rd_addr_p),
        .out(pbuf_exec_rd_addr)
    );

    // foutbuf write delay
    logic [PBUF_ADDR_WIDTH-1:0] pbuf_exec_wr_addr_r;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            pbuf_exec_wr_addr_r <= 0;
        end else begin
            pbuf_exec_wr_addr_r <= pbuf_exec_rd_addr;
        end
    end
    assign pbuf_exec_wr_addr = pbuf_exec_wr_addr_r;

    // double buffer select control
    logic rf_updt_sel_r;
    logic rf_exec_sel_r;

    logic rf_updt_sel_p;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            rf_updt_sel_r <= 1'b0;
        end  // TODO: abufish the control signal
             // Done
        else if (exec_en) begin
            if ((abuf2rf_qf_end&((~rf_w_fout_exec_en)|exec_gate))|(q_factor_dim_end[0]&updt_gate)) begin
                rf_updt_sel_r <= ~rf_updt_sel_r;
            end
        end
    end
    // assign rf_updt_sel_p = (~updt_exec_gate_sel)?rf_updt_sel_r:(rf_w_fout_exec_en)?(~rf_exec_sel_r):rf_updt_sel_r;
    assign rf_updt_sel_p = rf_updt_sel_r;
    delay_chain #(
        .DW (1),
        .LEN(`PARAM_CNT_ADDR_DELAY - 1)
    ) delay_rf_updt_sel (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (rf_updt_sel_p),
        .out(rf_updt_sel)
    );

    logic rf_exec_sel_p;
    assign rf_exec_sel_p = (rf_w_fout_exec_en) ? (~rf_updt_sel_r) : 1'b0;
    delay_chain #(
        .DW (1),
        .LEN(`PARAM_CNT_ADDR_DELAY - 1)
    ) delay_rf_exec_sel (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (rf_exec_sel_p),
        .out(rf_exec_sel)
    );

    logic exec_slot_done_p;
    assign exec_slot_done_p = p_factor_dim_end[0];

    delay_chain #(
        .DW (1),
        .LEN(`PARAM_CU_EXEC_DELAY + 2)
    ) delay_exec_slot_done (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (exec_slot_done_p),
        .out(exec_slot_done)
    );

endmodule
