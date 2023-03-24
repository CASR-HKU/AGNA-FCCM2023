`timescale 1ns / 1ps

`include "def.sv"

(*use_dsp48 = "no" *) module pe_ctrl_updt #(
    parameter BUF_UPDT_ADDR_WIDTH = 9,
    parameter ABUF_NUM            = `PARAM_ABUF_NUM,
    parameter WBUF_NUM            = `PARAM_WBUF_NUM,
    parameter PARAM_A_K           = `HW_CONFIG_A_K,
    parameter PARAM_A_C           = `HW_CONFIG_A_C,
    parameter PARAM_A_I           = `HW_CONFIG_A_I,
    parameter PARAM_A_J           = `HW_CONFIG_A_J
) (
    // common signal
    input  logic                           clk,
    input  logic                           rst_n,
    // update abuf, wbuf
    input  logic                           abuf_updt_start,
    input  logic                           wbuf_updt_start,
    input  logic                           abuf_updt_en_i,
    input  logic                           wbuf_updt_en_i,
    output logic                           abuf_updt_done,
    output logic                           wbuf_updt_done,
    output logic [BUF_UPDT_ADDR_WIDTH-1:0] abuf_updt_addr,
    output logic [BUF_UPDT_ADDR_WIDTH-1:0] wbuf_updt_addr,
    output logic [           ABUF_NUM-1:0] abuf_updt_en,
    output logic [           WBUF_NUM-1:0] wbuf_updt_en,
    // output logic                            abuf_updt_en_s  ,
    // output logic                            wbuf_updt_en_s  ,
    // end of frame and end of tile
    input  logic                           updt_abuf_eof,
    input  logic                           updt_abuf_eot,
    // f & bpw info 
    input  logic [                    2:0] wbuf_f_i,
    input  logic [                    2:0] wbuf_f_j,
    input  logic [                    5:0] wbuf_f_k,
    input  logic [                    5:0] wbuf_f_c,
    input  logic [                    8:0] wbuf_wpb
);

    // state control
    logic abuf_updt_en_s, wbuf_updt_en_s;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            abuf_updt_en_s <= 1'b0;
        end else begin
            if (abuf_updt_start) begin
                abuf_updt_en_s <= 1'b1;
            end else if (abuf_updt_done) begin
                abuf_updt_en_s <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wbuf_updt_en_s <= 1'b0;
        end else begin
            if (wbuf_updt_start) begin
                wbuf_updt_en_s <= 1'b1;
            end else if (wbuf_updt_done) begin
                wbuf_updt_en_s <= 1'b0;
            end
        end
    end

    // abufbuf update
    logic abuf_updt_buf_end;
    logic [BUF_UPDT_ADDR_WIDTH-1:0] abuf_updt_addr_r;
    assign abuf_updt_addr = abuf_updt_addr_r;

    // always_ff @( posedge clk ) begin
    //     if (~rst_n) begin
    //         abuf_updt_addr <= 0;
    //     end
    //     else abuf_updt_addr <= abuf_updt_addr_r;
    // end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            abuf_updt_addr_r <= 0;
        end  // TODO: abufish control signal here
        else if (abuf_updt_en_s) begin
            if (updt_abuf_eot) begin
                abuf_updt_addr_r <= 0;
            end else if (updt_abuf_eof) begin
                abuf_updt_addr_r <= 0;
            end else if (abuf_updt_en_i) begin
                abuf_updt_addr_r <= abuf_updt_addr_r + 1;
            end
        end
    end
    assign abuf_updt_buf_end = abuf_updt_en_s & updt_abuf_eof;

    logic [5:0] abuf_updt_buf_cnt;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            abuf_updt_buf_cnt <= 0;
        end  // TODO: abufish control signal here
        else if (abuf_updt_en_s) begin
            if (updt_abuf_eot) begin
                abuf_updt_buf_cnt <= 0;
            end else if (abuf_updt_buf_end) begin
                abuf_updt_buf_cnt <= abuf_updt_buf_cnt + 1;
            end
        end
    end
    assign abuf_updt_done = abuf_updt_en_s & updt_abuf_eot;

    genvar i;
    generate
        for (i = 0; i < ABUF_NUM; i++) begin
            assign abuf_updt_en[i] = (abuf_updt_buf_cnt == i) & abuf_updt_en_s;
        end
    endgenerate

    // wbuf update
    logic w_updt_buf_end;
    logic [BUF_UPDT_ADDR_WIDTH-1:0] wbuf_updt_addr_r;
    assign wbuf_updt_addr = wbuf_updt_addr_r;

    // always_ff @( posedge clk ) begin
    //     if (~rst_n) begin
    //         wbuf_updt_addr <= 0;
    //     end
    //     else wbuf_updt_addr <= wbuf_updt_addr_r;
    // end

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wbuf_updt_addr_r <= 0;
        end  // TODO: abufish control signal here
        else if (wbuf_updt_en_s) begin
            if (wbuf_updt_addr_r == (wbuf_wpb - 1)) begin
                wbuf_updt_addr_r <= 0;
            end else if (wbuf_updt_en_i) begin
                wbuf_updt_addr_r <= wbuf_updt_addr_r + 1;
            end
        end
    end
    assign w_updt_buf_end = wbuf_updt_en_s & (wbuf_updt_addr_r == (wbuf_wpb - 1));

    logic [2:0] wbuf_updt_cnt_fi, wbuf_updt_cnt_fj;
    logic [5:0] wbuf_updt_cnt_fk, wbuf_updt_cnt_fc;
    logic wbuf_updt_cnt_fi_end, wbuf_updt_cnt_fj_end, wbuf_updt_cnt_fk_end, wbuf_updt_cnt_fc_end;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wbuf_updt_cnt_fj <= 0;
        end  // TODO: abufish control signal here
        else if (w_updt_buf_end & wbuf_updt_en_s) begin
            if (wbuf_updt_cnt_fj == wbuf_f_j - 1) begin
                wbuf_updt_cnt_fj <= 0;
            end else wbuf_updt_cnt_fj <= wbuf_updt_cnt_fj + 1;
        end
    end
    assign wbuf_updt_cnt_fj_end = w_updt_buf_end & (wbuf_updt_cnt_fj == wbuf_f_j - 1);

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wbuf_updt_cnt_fi <= 0;
        end  // TODO: abufish control signal here
        else if (wbuf_updt_cnt_fj_end & wbuf_updt_en_s) begin
            if (wbuf_updt_cnt_fi == wbuf_f_i - 1) begin
                wbuf_updt_cnt_fi <= 0;
            end else wbuf_updt_cnt_fi <= wbuf_updt_cnt_fi + 1;
        end
    end
    assign wbuf_updt_cnt_fi_end = wbuf_updt_cnt_fj_end & (wbuf_updt_cnt_fi == wbuf_f_i - 1);

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wbuf_updt_cnt_fc <= 0;
        end  // TODO: abufish control signal here
        else if (wbuf_updt_cnt_fi_end & wbuf_updt_en_s) begin
            if (wbuf_updt_cnt_fc == wbuf_f_c - 1) begin
                wbuf_updt_cnt_fc <= 0;
            end else wbuf_updt_cnt_fc <= wbuf_updt_cnt_fc + 1;
        end
    end
    assign wbuf_updt_cnt_fc_end = wbuf_updt_cnt_fi_end & (wbuf_updt_cnt_fc == wbuf_f_c - 1);

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wbuf_updt_cnt_fk <= 0;
        end  // TODO: abufish control signal here
        else if (wbuf_updt_cnt_fc_end & wbuf_updt_en_s) begin
            if (wbuf_updt_cnt_fk == wbuf_f_k - 1) begin
                wbuf_updt_cnt_fk <= 0;
            end else wbuf_updt_cnt_fk <= wbuf_updt_cnt_fk + 1;
        end
    end
    assign wbuf_updt_cnt_fk_end = wbuf_updt_cnt_fc_end & (wbuf_updt_cnt_fk == wbuf_f_k - 1);

    assign wbuf_updt_done = wbuf_updt_cnt_fk_end;

    genvar wbuf_fk_idx, wbuf_fc_idx, wbuf_fi_idx, wbuf_fj_idx;
    generate
        for (wbuf_fk_idx = 0; wbuf_fk_idx < PARAM_A_K; wbuf_fk_idx++) begin
            for (wbuf_fc_idx = 0; wbuf_fc_idx < PARAM_A_C; wbuf_fc_idx++) begin
                for (wbuf_fi_idx = 0; wbuf_fi_idx < PARAM_A_I; wbuf_fi_idx++) begin
                    for (wbuf_fj_idx = 0; wbuf_fj_idx < PARAM_A_J; wbuf_fj_idx++) begin
                        assign wbuf_updt_en[wbuf_idx(
                            wbuf_fk_idx, wbuf_fc_idx, wbuf_fi_idx, wbuf_fj_idx
                        )] = ((wbuf_fk_idx == wbuf_updt_cnt_fk) & (
                              wbuf_fc_idx == wbuf_updt_cnt_fc) & (wbuf_fi_idx == wbuf_updt_cnt_fi) &
                              (wbuf_fj_idx == wbuf_updt_cnt_fj)) & wbuf_updt_en_s;
                    end
                end
            end
        end
    endgenerate

    // logic abuf_updt_sel_r;
    // always_ff @( posedge clk ) begin
    //     if (~rst_n) begin
    //        abuf_updt_sel_r <= 1'b0;
    //     end 
    //     else if (abuf_updt_done) begin
    //        abuf_updt_sel_r <= ~abuf_updt_sel_r;
    //     end
    // end
    // assign abuf_updt_sel = abuf_updt_sel_r;

    // logic wbuf_updt_sel_r;
    // always_ff @( posedge clk ) begin
    //     if (~rst_n) begin
    //        wbuf_updt_sel_r <= 1'b0;
    //     end 
    //     else if (wbuf_updt_done) begin
    //        wbuf_updt_sel_r <= ~wbuf_updt_sel_r;
    //     end
    // end
    // assign wbuf_updt_sel = wbuf_updt_sel_r;

endmodule
