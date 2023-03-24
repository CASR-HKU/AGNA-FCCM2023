`timescale 1ns / 1ps

`include "def.sv"

(*use_dsp48 = "no" *) module pe_ctrl_wb #(
    parameter PBUF_NUM          = `PARAM_PBUF_NUM,
    parameter BRAM_NUM_PER_PBUF = `PARAM_BRAM_NUM_PER_PBUF,
    parameter PBUF_ADDR_WIDTH   = `PARAM_PBUF_ADDR_WIDTH,
    parameter PBUF_DATA_WIDTH   = `PARAM_PBUF_DATA_WIDTH,
    parameter PBUF_DATA_NUM     = `PARAM_PBUF_DATA_NUM,

    parameter PARAM_A_K = `HW_CONFIG_A_K,
    parameter PARAM_A_H = `HW_CONFIG_A_H,
    parameter PARAM_A_W = `HW_CONFIG_A_W
) (
    // common signal
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic                       pe2lc_fifo_prog_full,
    // fetch foutbuf for writing back
    output logic [PBUF_ADDR_WIDTH-1:0] pbuf_wb_addr,
    output logic [  PBUF_DATA_NUM-1:0] pbuf_wb_valid,
    output logic [                5:0] pbuf_wb_f_k,
    // control singals
    input  logic                       wb_tile_start,
    output logic                       wb_tile_done,
    output logic [               15:0] psum_channel,
    output logic                       psum_wb_state,
    // buffer address control
    // f loop factor
    input  logic [                5:0] F_LOOP_FACTORS_W,
    input  logic [                5:0] F_LOOP_FACTORS_H,
    input  logic [                5:0] F_LOOP_FACTORS_K,
    // pq & pqf loop factor
    input  logic [                8:0] PQ_LOOP_FACTORS_W,
    input  logic [                8:0] PQ_LOOP_FACTORS_H,
    input  logic [                8:0] PQ_LOOP_FACTORS_K,
    // real size of the pbuf (r_k, r_h, r_w, in most cases they are equal to f*q*p)
    input  logic [                9:0] r_k,
    input  logic [                8:0] r_h,
    input  logic [                8:0] r_w,
    // start output channel of this tile
    input  logic [               15:0] psum_channel_start
);

    // write back state
    logic wb_state;
    logic wb_tile_done_p;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            wb_state <= 1'b0;
        end else if (wb_tile_done_p) begin
            wb_state <= 1'b0;
        end else if (wb_tile_start) begin
            wb_state <= 1'b1;
        end
    end

    logic wb_state_p;
    assign wb_state_p = wb_state & (~pe2lc_fifo_prog_full);
    // assign psum_wb_state = wb_state_p;
    delay_chain #(
        .DW (1),
        .LEN(4)
    ) delay_psum_wb_state (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (wb_state_p),
        .out(psum_wb_state)
    );
    delay_chain #(
        .DW (1),
        .LEN(4)
    ) delay_wb_tile_done (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (wb_tile_done_p),
        .out(wb_tile_done)
    );

    // loop - pq & pqf
    logic [8:0] cnt_pq_w, cnt_pq_h, cnt_f_k, cnt_pq_k;
    logic cnt_pq_w_end, cnt_pq_h_end, cnt_f_k_end, cnt_pq_k_end;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            cnt_pq_w <= 9'd0;
        end else if (wb_state_p) begin
            if (cnt_pq_w == PQ_LOOP_FACTORS_W - 1) begin
                cnt_pq_w <= 9'd0;
            end else begin
                cnt_pq_w <= cnt_pq_w + 1;
            end
        end
    end
    assign cnt_pq_w_end = wb_state_p & (cnt_pq_w == PQ_LOOP_FACTORS_W - 1);

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            cnt_pq_h <= 9'd0;
        end else if (cnt_pq_w_end) begin
            if (cnt_pq_h == PQ_LOOP_FACTORS_H - 1) begin
                cnt_pq_h <= 9'd0;
            end else begin
                cnt_pq_h <= cnt_pq_h + 1;
            end
        end
    end
    assign cnt_pq_h_end = cnt_pq_w_end & (cnt_pq_h == PQ_LOOP_FACTORS_H - 1);

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            cnt_f_k <= 9'd0;
        end else if (cnt_pq_h_end) begin
            if (cnt_f_k == F_LOOP_FACTORS_K - 1) begin
                cnt_f_k <= 9'd0;
            end else begin
                cnt_f_k <= cnt_f_k + 1;
            end
        end
    end
    assign cnt_f_k_end = cnt_pq_h_end & (cnt_f_k == F_LOOP_FACTORS_K - 1);

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            cnt_pq_k <= 9'd0;
        end else if (wb_state & cnt_f_k_end) begin
            if (cnt_pq_k == PQ_LOOP_FACTORS_K - 1) begin
                cnt_pq_k <= 9'd0;
            end else begin
                cnt_pq_k <= cnt_pq_k + 1;
            end
        end
    end
    assign cnt_pq_k_end   = cnt_f_k_end & (cnt_pq_k == PQ_LOOP_FACTORS_K - 1);
    assign wb_tile_done_p = cnt_pq_k_end;

    // address (pq)
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            pbuf_wb_addr <= 0;
        end else begin
            pbuf_wb_addr <= cnt_pq_k * PQ_LOOP_FACTORS_H * PQ_LOOP_FACTORS_W + cnt_pq_h * PQ_LOOP_FACTORS_W + cnt_pq_w;
        end
    end

    // indicates the current data belongs to which output channel (for BN operation)
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            psum_channel <= 0;
        end else begin
            psum_channel <= psum_channel_start + cnt_pq_k * F_LOOP_FACTORS_K + cnt_f_k;
        end
    end

    // generate the valid and keep signals for each pbuf
    logic a_k_en;
    logic [PARAM_A_H-1:0] a_h_en;
    logic [PARAM_A_W-1:0] a_w_en;

    // a_k enable
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            a_k_en <= 1'b0;
        end else begin
            a_k_en <= wb_state & ((cnt_pq_k * F_LOOP_FACTORS_K + cnt_f_k) < r_k);
        end
    end

    logic [PBUF_DATA_NUM-1:0] pbuf_wb_valid_r;
    genvar a_h, a_w;
    generate
        for (a_h = 0; a_h < PARAM_A_H; a_h++) begin
            for (a_w = 0; a_w < PARAM_A_W; a_w++) begin
                // a_h enable
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        a_h_en[a_h] <= 1'b0;
                    end else begin
                        a_h_en[a_h] <= wb_state & ((cnt_pq_h * F_LOOP_FACTORS_H + a_h) < r_h) & (a_h <= (F_LOOP_FACTORS_H - 1));
                    end
                end
                // a_w enable
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        a_w_en[a_w] <= 1'b0;
                    end else begin
                        a_w_en[a_w] <= wb_state & ((cnt_pq_w * F_LOOP_FACTORS_W + a_w) < r_w) & (a_w <= (F_LOOP_FACTORS_W - 1));
                    end
                end
                always_comb begin
                    pbuf_wb_valid_r[pbuf_idx_wb(a_h, a_w)] = a_k_en & a_h_en[a_h] & a_w_en[a_w];
                end
            end
        end
    endgenerate

    delay_chain #(
        .DW (PBUF_DATA_NUM),
        .LEN(3)
    ) delay_pbuf_wb_valid (
        .clk(clk),
        .rst(rst_n),
        .en (1'b1),
        .in (pbuf_wb_valid_r),
        .out(pbuf_wb_valid)
    );

    // always_ff @( posedge clk ) begin
    //     pbuf_wb_valid <= pbuf_wb_valid_r;
    // end

    logic [8:0] cnt_f_k_r;
    always_ff @(posedge clk) begin
        cnt_f_k_r   <= cnt_f_k;
        pbuf_wb_f_k <= cnt_f_k_r;
    end

endmodule
