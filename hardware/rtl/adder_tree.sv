`timescale 1ns / 1ps

`include "def.sv"

module adder_tree #(
    parameter DATA_WIDTH = 16,
    parameter INPUT_NUM  = `HW_CONFIG_PE_NUM,
    parameter STAGE_NUM  = $clog2(INPUT_NUM)
) (
    input  wire                         clk,
    rst,
    en_advance,
    input  wire signed [DATA_WIDTH-1:0] adder_in [INPUT_NUM - 1 : 0],
    output logic       [DATA_WIDTH-1:0] adder_out
);

    localparam PART_A_NUM = INPUT_NUM / 2;
    localparam PART_B_NUM = INPUT_NUM - PART_A_NUM;

    genvar i;
    generate
        if (INPUT_NUM == 1) begin
            if (STAGE_NUM > 0) begin
                logic signed [DATA_WIDTH-1:0] delay_rf[STAGE_NUM];
                assign adder_out = delay_rf[0];

                always_ff @(posedge clk) begin
                    if (rst) begin
                        for (int i = 0; i < STAGE_NUM - 1; i++) begin
                            delay_rf[i] <= 0;
                        end
                        delay_rf[STAGE_NUM-1] <= en_advance ? adder_in[0] : 0;
                    end else if (en_advance) begin
                        delay_rf[STAGE_NUM-1] <= adder_in[0];

                        for (int i = 0; i < STAGE_NUM - 1; i++) begin
                            delay_rf[i] <= delay_rf[i+1];
                        end
                    end
                end
            end else begin
                // Single element, no adder tree
                assign adder_out = adder_in[0];
            end
        end else begin

            wire signed  [DATA_WIDTH-1:0] sum_part_a;
            wire signed  [DATA_WIDTH-1:0] sum_part_b;

            logic signed [DATA_WIDTH-1:0] adder_in_a [PART_A_NUM];
            logic signed [DATA_WIDTH-1:0] adder_in_b [PART_B_NUM];

            always_comb begin
                for (int i = 0; i < PART_A_NUM; i++) begin
                    adder_in_a[i] = adder_in[i];
                end

                for (int i = 0; i < PART_B_NUM; i++) begin
                    adder_in_b[i] = adder_in[i+PART_A_NUM];
                end
            end

            if (STAGE_NUM > 0) begin
                // Divide set into two sub trees
                adder_tree #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .INPUT_NUM (PART_A_NUM),
                    .STAGE_NUM (STAGE_NUM - 1)
                ) subtree_a (
                    .clk(clk),
                    .rst(rst),
                    .en_advance(en_advance),
                    .adder_in(adder_in_a),
                    .adder_out(sum_part_a)
                );

                adder_tree #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .INPUT_NUM (PART_B_NUM),
                    .STAGE_NUM (STAGE_NUM - 1)
                ) subtree_b (
                    .clk(clk),
                    .rst(rst),
                    .en_advance(en_advance),
                    .adder_in(adder_in_b),
                    .adder_out(sum_part_b)
                );

                always_ff @(posedge clk) begin
                    if (STAGE_NUM == 1) begin
                        if (en_advance) begin
                            adder_out <= sum_part_a + sum_part_b;
                        end else if (rst) begin
                            adder_out <= 0;
                        end
                    end else begin
                        if (rst) begin
                            adder_out <= 0;
                        end else if (en_advance) begin
                            adder_out <= sum_part_a + sum_part_b;
                        end
                    end
                end
            end else begin
                // Leaf
                adder_tree #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .INPUT_NUM (PART_A_NUM),
                    .STAGE_NUM (0)
                ) subtree_a (
                    .clk(clk),
                    .rst(rst),
                    .en_advance(en_advance),
                    .adder_in(adder_in_a),
                    .adder_out(sum_part_a)
                );

                adder_tree #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .INPUT_NUM (PART_B_NUM),
                    .STAGE_NUM (0)
                ) subtree_b (
                    .clk(clk),
                    .rst(rst),
                    .en_advance(en_advance),
                    .adder_in(adder_in_b),
                    .adder_out(sum_part_b)
                );

                assign adder_out = sum_part_a + sum_part_b;
            end
        end
    endgenerate

endmodule
