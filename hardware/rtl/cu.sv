`timescale 1ns / 1ps

`include "def.sv"

// (* dont_touch = "yes" *) 

(* keep_hierarchy = "yes" *)
module cu #(
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

    parameter RF_NUM          = `PARAM_RF_NUM,
    parameter RF_NUM_PER_ABUF = `PARAM_RF_NUM_PER_ABUF,
    parameter RF_ADDR_WIDTH   = `PARAM_RF_ADDR_WIDTH,
    parameter RF_DATA_WIDTH   = `PARAM_RF_DATA_WIDTH,

    parameter CU_SIGNAL_NUM = `PARAM_CU_SIGNAL_NUM,
    parameter DSP_GROUP_NUM = `PARAM_GROUP_DSP_NUM,

    parameter PARAM_A_K = `HW_CONFIG_A_K,
    parameter PARAM_A_C = `HW_CONFIG_A_C,
    parameter PARAM_A_H = `HW_CONFIG_A_H,
    parameter PARAM_A_W = `HW_CONFIG_A_W,
    parameter PARAM_A_I = `HW_CONFIG_A_I,
    parameter PARAM_A_J = `HW_CONFIG_A_J
) (
    // common signal
    input  logic                       clk,
    input  logic                       rst_n,
    // update rf
    input  logic [RF_NUM_PER_ABUF-1:0] rf_updt_en,
    input  logic                       rf_updt_sel,
    input  logic                       rf_updt_addr_rst,
    // input  logic [RF_ADDR_WIDTH-1:0]        rf_updt_addr        [RF_NUM_PER_ABUF-1:0]   ,
    input  logic [  RF_DATA_WIDTH-1:0] rf_updt_data       [ABUF_NUM-1:0],
    // execute rf
    input  logic                       rf_exec_sel,
    input  logic [  RF_ADDR_WIDTH-1:0] rf_exec_addr,
    // execute wbuf
    input  logic [WBUF_DATA_WIDTH-1:0] wbuf_exec_data     [WBUF_NUM-1:0],
    // execute pbuf
    input  logic [PBUF_DATA_WIDTH-1:0] pbuf_exec_rd_data  [PBUF_NUM-1:0],
    output logic [PBUF_DATA_WIDTH-1:0] pbuf_exec_wr_data  [PBUF_NUM-1:0],
    // maxpooling results
    output logic [PBUF_DATA_WIDTH-1:0] maxpool_result     [PBUF_NUM-1:0],
    // control signals for cu
    input  logic                       adder_rst_en,
    input  logic                       pbuf_exec_rd_rst_en,
    input  logic                       comp_type
);

    logic [RF_DATA_WIDTH-1:0] rf_exec_data  [RF_NUM-1:0];
    logic [RF_DATA_WIDTH-1:0] rf_exec_data_p[RF_NUM-1:0];

    /************************************************* MACC *************************************************/
    // inter connection

    // Cascaded DSP
`ifdef HW_DSP_CASCADED

    logic [8:0] dsp_opmode;
    logic rst;
    assign rst = ~rst_n;

    logic        [26:0] dsp_a_in     [CU_SIGNAL_NUM-1:0];  // fin << 18
    logic        [17:0] dsp_b_in     [CU_SIGNAL_NUM-1:0];  // w
    logic        [26:0] dsp_d_in     [CU_SIGNAL_NUM-1:0];  // fin
    logic        [44:0] dsp_p_out    [CU_SIGNAL_NUM-1:0];  // 2 results, need to be separated
    logic        [47:0] dsp_cas_in   [CU_SIGNAL_NUM-1:0];  // for cascaded dsp
    logic signed [15:0] dsp_p_out_sep[CU_SIGNAL_NUM-1:0];  // 2 results, need to be separated

    genvar a_k_idx, a_c_idx, a_i_idx, a_j_idx, a_hw_idx;

    logic [26:0] dsp_a_in_tmp[CU_SIGNAL_NUM-1:0];
    logic [17:0] dsp_b_in_tmp[CU_SIGNAL_NUM-1:0];
    logic [26:0] dsp_d_in_tmp[CU_SIGNAL_NUM-1:0];  // fin
    logic [47:0] dsp_pc_out[CU_SIGNAL_NUM-1:0];  // 2 results, need to be separated
    logic signed [15:0] cascade_out[PBUF_NUM-1:0];  // output of cascaded dsp chain
    logic signed [15:0] acc_out             [PBUF_NUM-1:0]; // output of accumulator, one input of fout_exec_adder
    logic signed [15:0] fout_exec_adder_in  [PBUF_NUM-1:0]; // another input of fout_exec_adder (0 or fout_rd_data)

    logic signed [15:0] fout_exec_adder[PBUF_NUM-1:0];  // fout_exec_adder
    assign dsp_opmode = 9'b00_001_01_01;
    generate
        for (a_k_idx = 0; a_k_idx < PARAM_A_K; a_k_idx++) begin
            for (a_hw_idx = 0; a_hw_idx < PARAM_A_H * PARAM_A_W; a_hw_idx++) begin
                for (a_c_idx = 0; a_c_idx < PARAM_A_C; a_c_idx++) begin
                    for (a_i_idx = 0; a_i_idx < PARAM_A_I; a_i_idx++) begin
                        for (a_j_idx = 0; a_j_idx < PARAM_A_J; a_j_idx++) begin
                            assign dsp_a_in_tmp[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = {
                                    rf_exec_data[rf_idx_opt(
                                        a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )][RF_DATA_WIDTH-1],
                                    rf_exec_data[rf_idx_opt(a_hw_idx, a_c_idx, a_i_idx, a_j_idx)],
                                    {(18) {1'b0}}
                                };
                            assign dsp_b_in_tmp[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = {
                                    {(18 - RF_DATA_WIDTH) {wbuf_exec_data[wbuf_idx(
                                        a_k_idx, a_c_idx, a_i_idx, a_j_idx
                                    )][WBUF_DATA_WIDTH-1]}},
                                    wbuf_exec_data[wbuf_idx(a_k_idx, a_c_idx, a_i_idx, a_j_idx)]
                                };
                            assign dsp_d_in_tmp[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = {
                                    {(27 - RF_DATA_WIDTH) {rf_exec_data[rf_idx_opt(
                                        a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )][RF_DATA_WIDTH-1]}},
                                    rf_exec_data[rf_idx_opt(a_hw_idx, a_c_idx, a_i_idx, a_j_idx)]
                                };
                            if (a_c_idx == 0 && a_i_idx == 0 && a_j_idx == 0) begin
                                assign dsp_cas_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = 48'h0000_0000_0000;
                                assign dsp_a_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = dsp_a_in_tmp[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )];
                                assign dsp_b_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = dsp_b_in_tmp[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )];
                                assign dsp_d_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = dsp_d_in_tmp[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )];
                            end else begin
                                // if (delay_length(a_c_idx, a_i_idx, a_j_idx) == 1) begin
                                //     delay_chain_onecyc #(27) delay_dsp_a_one (
                                //         clk,
                                //         rst_n,
                                //         1'b1,
                                //         dsp_a_in_tmp[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )],
                                //         dsp_a_in[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )]
                                //     );
                                //     delay_chain_onecyc #(18) delay_dsp_b_one (
                                //         clk,
                                //         rst_n,
                                //         1'b1,
                                //         dsp_b_in_tmp[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )],
                                //         dsp_b_in[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )]
                                //     );
                                //     delay_chain_onecyc #(27) delay_dsp_d_one (
                                //         clk,
                                //         rst_n,
                                //         1'b1,
                                //         dsp_d_in_tmp[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )],
                                //         dsp_d_in[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )]
                                //     );
                                // end else begin
                                //     delay_chain #(27, delay_length(
                                //         a_c_idx, a_i_idx, a_j_idx
                                //     )) delay_dsp_a (
                                //         clk,
                                //         rst_n,
                                //         1'b1,
                                //         dsp_a_in_tmp[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )],
                                //         dsp_a_in[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )]
                                //     );
                                //     delay_chain #(18, delay_length(
                                //         a_c_idx, a_i_idx, a_j_idx
                                //     )) delay_dsp_b (
                                //         clk,
                                //         rst_n,
                                //         1'b1,
                                //         dsp_b_in_tmp[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )],
                                //         dsp_b_in[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )]
                                //     );
                                //     delay_chain #(27, delay_length(
                                //         a_c_idx, a_i_idx, a_j_idx
                                //     )) delay_dsp_d (
                                //         clk,
                                //         rst_n,
                                //         1'b1,
                                //         dsp_d_in_tmp[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )],
                                //         dsp_d_in[dsp_idx_opt (
                                //             a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                //         )]
                                //     );
                                // end
                                assign dsp_cas_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = dsp_pc_out[dsp_idx_prev_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )];
                                if (a_c_idx==PARAM_A_C-1 && a_i_idx==PARAM_A_I-1 && a_j_idx==PARAM_A_J-1) begin
                                    assign cascade_out[pbuf_idx_opt(
                                        a_k_idx, a_hw_idx
                                    )] = dsp_p_out_sep[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )];
                                end
                            end
                        end
                    end
                end
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        acc_out[pbuf_idx_opt(a_k_idx, a_hw_idx)] <= 0;
                    end else if (adder_rst_en) begin
                        acc_out[pbuf_idx_opt(a_k_idx, a_hw_idx)] <=
                            cascade_out[pbuf_idx_opt(a_k_idx, a_hw_idx)];
                    end else begin
                        acc_out[pbuf_idx_opt(a_k_idx, a_hw_idx)]
                            <= acc_out[pbuf_idx_opt(a_k_idx, a_hw_idx)] +
                            cascade_out[pbuf_idx_opt(a_k_idx, a_hw_idx)];
                    end
                end
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        fout_exec_adder_in[pbuf_idx_opt(a_k_idx, a_hw_idx)] <= 0;
                    end else
                        fout_exec_adder_in[pbuf_idx_opt(
                            a_k_idx, a_hw_idx
                        )] <= pbuf_exec_rd_rst_en ? 0 : pbuf_exec_rd_data[pbuf_idx_opt(
                            a_k_idx, a_hw_idx
                        )];
                end
                assign fout_exec_adder[pbuf_idx_opt(
                    a_k_idx, a_hw_idx
                )] = acc_out[pbuf_idx_opt(
                    a_k_idx, a_hw_idx
                )] + fout_exec_adder_in[pbuf_idx_opt(
                    a_k_idx, a_hw_idx
                )];
                assign pbuf_exec_wr_data[pbuf_idx_opt(
                    a_k_idx, a_hw_idx
                )] = fout_exec_adder[pbuf_idx_opt(
                    a_k_idx, a_hw_idx
                )];
            end
        end
    endgenerate

    // DSP gen
    generate
        for (a_k_idx = 0; a_k_idx < PARAM_A_K; a_k_idx++) begin
            for (
                a_hw_idx = 0; a_hw_idx < PARAM_A_H * PARAM_A_W; a_hw_idx = a_hw_idx + 2
            ) begin  // Make sure that PARAM_CU_OW*PARAM_CU_OH is even number
                for (a_c_idx = 0; a_c_idx < PARAM_A_C; a_c_idx++) begin
                    for (a_i_idx = 0; a_i_idx < PARAM_A_I; a_i_idx++) begin
                        for (a_j_idx = 0; a_j_idx < PARAM_A_J; a_j_idx++) begin
                            if (a_c_idx == 0 && a_i_idx == 0 && a_j_idx == 0) begin
                                DSP48E2 #(
                                    // Feature Control Attributes: Data Path Selection
                                    .AMULTSEL("AD"),  // Selects A input to multiplier (A, AD)
                                    .A_INPUT("DIRECT"),                // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                    .BMULTSEL("B"),  // Selects B input to multiplier (AD, B)
                                    .B_INPUT("DIRECT"),                // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
                                    .PREADDINSEL("A"),  // Selects input to pre-adder (A, B)
                                    .RND(48'h000000000000),  // Rounding Constant
                                    .USE_MULT("MULTIPLY"),             // Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
                                    .USE_SIMD("ONE48"),  // SIMD selection (FOUR12, ONE48, TWO24)
                                    .USE_WIDEXOR("FALSE"),             // Use the Wide XOR function (FALSE, TRUE)
                                    .XORSIMD("XOR24_48_96"),           // Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
                                    // Pattern Detector Attributes: Pattern Detection Configuration
                                    .AUTORESET_PATDET("NO_RESET"),     // NO_RESET, RESET_MATCH, RESET_NOT_MATCH
                                    .AUTORESET_PRIORITY("RESET"),      // Priority of AUTORESET vs. CEP (CEP, RESET).
                                    .MASK(48'h3fffffffffff),           // 48-bit mask value for pattern detect (1=ignore)
                                    .PATTERN(48'h000000000000),        // 48-bit pattern match for pattern detect
                                    .SEL_MASK("MASK"),  // C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
                                    .SEL_PATTERN("PATTERN"),  // Select pattern value (C, PATTERN)
                                    .USE_PATTERN_DETECT("NO_PATDET"),  // Enable pattern detect (NO_PATDET, PATDET)
                                    // Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
                                    .IS_ALUMODE_INVERTED(4'b0000),     // Optional inversion for ALUMODE
                                    .IS_CARRYIN_INVERTED(1'b0),  // Optional inversion for CARRYIN
                                    .IS_CLK_INVERTED(1'b0),  // Optional inversion for CLK
                                    .IS_INMODE_INVERTED(5'b00000),  // Optional inversion for INMODE
                                    .IS_OPMODE_INVERTED(9'b000000000), // Optional inversion for OPMODE
                                    .IS_RSTALLCARRYIN_INVERTED(1'b0),  // Optional inversion for RSTALLCARRYIN
                                    .IS_RSTALUMODE_INVERTED(1'b0),     // Optional inversion for RSTALUMODE
                                    .IS_RSTA_INVERTED(1'b0),  // Optional inversion for RSTA
                                    .IS_RSTB_INVERTED(1'b0),  // Optional inversion for RSTB
                                    .IS_RSTCTRL_INVERTED(1'b0),  // Optional inversion for RSTCTRL
                                    .IS_RSTC_INVERTED(1'b0),  // Optional inversion for RSTC
                                    .IS_RSTD_INVERTED(1'b0),  // Optional inversion for RSTD
                                    .IS_RSTINMODE_INVERTED(1'b0),      // Optional inversion for RSTINMODE
                                    .IS_RSTM_INVERTED(1'b0),  // Optional inversion for RSTM
                                    .IS_RSTP_INVERTED(1'b0),  // Optional inversion for RSTP
                                    // Register Control Attributes: Pipeline Register Configuration
                                    .ACASCREG(1),                      // Number of pipeline stages between A/ACIN and ACOUT (0-2)
                                    .ADREG(0),  // Pipeline stages for pre-adder (0-1)
                                    .ALUMODEREG(0),  // Pipeline stages for ALUMODE (0-1)
                                    .AREG(1),  // Pipeline stages for A (0-2)
                                    .BCASCREG(1),                      // Number of pipeline stages between B/BCIN and BCOUT (0-2)
                                    .BREG(1),  // Pipeline stages for B (0-2)
                                    .CARRYINREG(1),  // Pipeline stages for CARRYIN (0-1)
                                    .CARRYINSELREG(1),  // Pipeline stages for CARRYINSEL (0-1)
                                    .CREG(1),  // Pipeline stages for C (0-1)
                                    .DREG(1),  // Pipeline stages for D (0-1)
                                    .INMODEREG(0),  // Pipeline stages for INMODE (0-1)
                                    .MREG(1),  // Multiplier pipeline stages (0-1)
                                    .OPMODEREG(0),  // Pipeline stages for OPMODE (0-1)
                                    .PREG(1)  // Number of pipeline stages for P (0-1)
                                ) DSP48E2_inst (
                                    // Cascade outputs: Cascade Ports
                                    // .ACOUT(ACOUT),                   // 30-bit output: A port cascade
                                    // .BCOUT(BCOUT),                   // 18-bit output: B cascade
                                    // .CARRYCASCOUT(CARRYCASCOUT),     // 1-bit output: Cascade carry
                                    // .MULTSIGNOUT(MULTSIGNOUT),       // 1-bit output: Multiplier sign cascade
                                    .PCOUT(dsp_pc_out[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 48-bit output: Cascade output
                                    // Control outputs: Control Inputs/Status Bits
                                    // .OVERFLOW(OVERFLOW),             // 1-bit output: Overflow in add/acc
                                    // .PATTERNBDETECT(PATTERNBDETECT), // 1-bit output: Pattern bar detect
                                    // .PATTERNDETECT(PATTERNDETECT),   // 1-bit output: Pattern detect
                                    // .UNDERFLOW(UNDERFLOW),           // 1-bit output: Underflow in add/acc
                                    // Data outputs: Data Ports
                                    // .CARRYOUT(CARRYOUT),             // 4-bit output: Carry
                                    .P(dsp_p_out[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 48-bit output: Primary data
                                    // .XOROUT(XOROUT),                 // 8-bit output: XOR data
                                    // Cascade inputs: Cascade Ports
                                    // .ACIN(ACIN),                     // 30-bit input: A cascade data
                                    // .BCIN(BCIN),                     // 18-bit input: B cascade
                                    // .CARRYCASCIN(CARRYCASCIN),       // 1-bit input: Cascade carry
                                    // .MULTSIGNIN(MULTSIGNIN),         // 1-bit input: Multiplier sign cascade
                                    // .PCIN(dsp_cas_in[dsp_idx_opt(foch,fich,fkw,fkh,fow_oh)]),                     // 48-bit input: P cascade
                                    // Control inputs: Control Inputs/Status Bits
                                    .ALUMODE(4'b0000),  // 4-bit input: ALU control
                                    // .CARRYINSEL(CARRYINSEL),         // 3-bit input: Carry select
                                    .CLK(clk),  // 1-bit input: Clock
                                    .INMODE(5'b10101),  // 5-bit input: INMODE control
                                    .OPMODE(9'b00_000_01_01),  // 9-bit input: Operation mode
                                    // Data inputs: Data Ports
                                    .A(dsp_a_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 30-bit input: A data
                                    .B(dsp_b_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 18-bit input: B data
                                    // .C(C),                           // 48-bit input: C data
                                    // .CARRYIN(CARRYIN),               // 1-bit input: Carry-in
                                    .D(dsp_d_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx+1, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 27-bit input: D data
                                    // Reset/Clock Enable inputs: Reset/Clock Enable Inputs
                                    .CEA1(1'b1),  // 1-bit input: Clock enable for 1st stage AREG
                                    .CEA2(1'b1),  // 1-bit input: Clock enable for 2nd stage AREG
                                    .CEAD(1'b0),  // 1-bit input: Clock enable for ADREG
                                    .CEALUMODE(1'b0),  // 1-bit input: Clock enable for ALUMODE
                                    .CEB1(1'b1),  // 1-bit input: Clock enable for 1st stage BREG
                                    .CEB2(1'b1),  // 1-bit input: Clock enable for 2nd stage BREG
                                    .CEC(1'b0),  // 1-bit input: Clock enable for CREG
                                    .CECARRYIN(1'b0),  // 1-bit input: Clock enable for CARRYINREG
                                    .CECTRL(1'b0),                 // 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
                                    .CED(1'b1),  // 1-bit input: Clock enable for DREG
                                    .CEINMODE(1'b0),  // 1-bit input: Clock enable for INMODEREG
                                    .CEM(1'b1),  // 1-bit input: Clock enable for MREG
                                    .CEP(1'b1),  // 1-bit input: Clock enable for PREG
                                    .RSTA(rst),  // 1-bit input: Reset for AREG
                                    .RSTALLCARRYIN(rst),  // 1-bit input: Reset for CARRYINREG
                                    .RSTALUMODE(1'b0),  // 1-bit input: Reset for ALUMODEREG
                                    .RSTB(rst),  // 1-bit input: Reset for BREG
                                    .RSTC(1'b0),  // 1-bit input: Reset for CREG
                                    .RSTCTRL(1'b0),               // 1-bit input: Reset for OPMODEREG and CARRYINSELREG
                                    .RSTD(1'b0),  // 1-bit input: Reset for DREG and ADREG
                                    .RSTINMODE(1'b0),  // 1-bit input: Reset for INMODEREG
                                    .RSTM(rst),  // 1-bit input: Reset for MREG
                                    .RSTP(rst)  // 1-bit input: Reset for PREG
                                );
                            end
                        else if (a_c_idx==PARAM_A_C-1 && a_i_idx==PARAM_A_I-1 && a_j_idx==PARAM_A_J-1) begin
                                assign dsp_p_out_sep[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = (dsp_p_out[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )][15]) ? (dsp_p_out[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )][33:18] + 1) : dsp_p_out[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )][33:18];
                                assign dsp_p_out_sep[dsp_idx_opt(
                                    a_k_idx, a_hw_idx+1, a_c_idx, a_i_idx, a_j_idx
                                )] = dsp_p_out[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )][15:0];
                                DSP48E2 #(
                                    // Feature Control Attributes: Data Path Selection
                                    .AMULTSEL("AD"),  // Selects A input to multiplier (A, AD)
                                    .A_INPUT("DIRECT"),                // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                    .BMULTSEL("B"),  // Selects B input to multiplier (AD, B)
                                    .B_INPUT("DIRECT"),                // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
                                    .PREADDINSEL("A"),  // Selects input to pre-adder (A, B)
                                    .RND(48'h000000000000),  // Rounding Constant
                                    .USE_MULT("MULTIPLY"),             // Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
                                    .USE_SIMD("ONE48"),  // SIMD selection (FOUR12, ONE48, TWO24)
                                    .USE_WIDEXOR("FALSE"),             // Use the Wide XOR function (FALSE, TRUE)
                                    .XORSIMD("XOR24_48_96"),           // Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
                                    // Pattern Detector Attributes: Pattern Detection Configuration
                                    .AUTORESET_PATDET("NO_RESET"),     // NO_RESET, RESET_MATCH, RESET_NOT_MATCH
                                    .AUTORESET_PRIORITY("RESET"),      // Priority of AUTORESET vs. CEP (CEP, RESET).
                                    .MASK(48'h3fffffffffff),           // 48-bit mask value for pattern detect (1=ignore)
                                    .PATTERN(48'h000000000000),        // 48-bit pattern match for pattern detect
                                    .SEL_MASK("MASK"),  // C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
                                    .SEL_PATTERN("PATTERN"),  // Select pattern value (C, PATTERN)
                                    .USE_PATTERN_DETECT("NO_PATDET"),  // Enable pattern detect (NO_PATDET, PATDET)
                                    // Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
                                    .IS_ALUMODE_INVERTED(4'b0000),     // Optional inversion for ALUMODE
                                    .IS_CARRYIN_INVERTED(1'b0),  // Optional inversion for CARRYIN
                                    .IS_CLK_INVERTED(1'b0),  // Optional inversion for CLK
                                    .IS_INMODE_INVERTED(5'b00000),  // Optional inversion for INMODE
                                    .IS_OPMODE_INVERTED(9'b000000000), // Optional inversion for OPMODE
                                    .IS_RSTALLCARRYIN_INVERTED(1'b0),  // Optional inversion for RSTALLCARRYIN
                                    .IS_RSTALUMODE_INVERTED(1'b0),     // Optional inversion for RSTALUMODE
                                    .IS_RSTA_INVERTED(1'b0),  // Optional inversion for RSTA
                                    .IS_RSTB_INVERTED(1'b0),  // Optional inversion for RSTB
                                    .IS_RSTCTRL_INVERTED(1'b0),  // Optional inversion for RSTCTRL
                                    .IS_RSTC_INVERTED(1'b0),  // Optional inversion for RSTC
                                    .IS_RSTD_INVERTED(1'b0),  // Optional inversion for RSTD
                                    .IS_RSTINMODE_INVERTED(1'b0),      // Optional inversion for RSTINMODE
                                    .IS_RSTM_INVERTED(1'b0),  // Optional inversion for RSTM
                                    .IS_RSTP_INVERTED(1'b0),  // Optional inversion for RSTP
                                    // Register Control Attributes: Pipeline Register Configuration
                                    .ACASCREG(1),                      // Number of pipeline stages between A/ACIN and ACOUT (0-2)
                                    .ADREG(0),  // Pipeline stages for pre-adder (0-1)
                                    .ALUMODEREG(0),  // Pipeline stages for ALUMODE (0-1)
                                    .AREG(1),  // Pipeline stages for A (0-2)
                                    .BCASCREG(1),                      // Number of pipeline stages between B/BCIN and BCOUT (0-2)
                                    .BREG(1),  // Pipeline stages for B (0-2)
                                    .CARRYINREG(1),  // Pipeline stages for CARRYIN (0-1)
                                    .CARRYINSELREG(1),  // Pipeline stages for CARRYINSEL (0-1)
                                    .CREG(1),  // Pipeline stages for C (0-1)
                                    .DREG(1),  // Pipeline stages for D (0-1)
                                    .INMODEREG(0),  // Pipeline stages for INMODE (0-1)
                                    .MREG(1),  // Multiplier pipeline stages (0-1)
                                    .OPMODEREG(0),  // Pipeline stages for OPMODE (0-1)
                                    .PREG(1)  // Number of pipeline stages for P (0-1)
                                ) DSP48E2_inst (
                                    // Cascade outputs: Cascade Ports
                                    // .ACOUT(ACOUT),                   // 30-bit output: A port cascade
                                    // .BCOUT(BCOUT),                   // 18-bit output: B cascade
                                    // .CARRYCASCOUT(CARRYCASCOUT),     // 1-bit output: Cascade carry
                                    // .MULTSIGNOUT(MULTSIGNOUT),       // 1-bit output: Multiplier sign cascade
                                    // .PCOUT(PCOUT),                   // 48-bit output: Cascade output
                                    // Control outputs: Control Inputs/Status Bits
                                    // .OVERFLOW(OVERFLOW),             // 1-bit output: Overflow in add/acc
                                    // .PATTERNBDETECT(PATTERNBDETECT), // 1-bit output: Pattern bar detect
                                    // .PATTERNDETECT(PATTERNDETECT),   // 1-bit output: Pattern detect
                                    // .UNDERFLOW(UNDERFLOW),           // 1-bit output: Underflow in add/acc
                                    // Data outputs: Data Ports
                                    // .CARRYOUT(CARRYOUT),             // 4-bit output: Carry
                                    .P(dsp_p_out[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 48-bit output: Primary data
                                    // .XOROUT(XOROUT),                 // 8-bit output: XOR data
                                    // Cascade inputs: Cascade Ports
                                    // .ACIN(ACIN),                     // 30-bit input: A cascade data
                                    // .BCIN(BCIN),                     // 18-bit input: B cascade
                                    // .CARRYCASCIN(CARRYCASCIN),       // 1-bit input: Cascade carry
                                    // .MULTSIGNIN(MULTSIGNIN),         // 1-bit input: Multiplier sign cascade
                                    .PCIN(dsp_cas_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 48-bit input: P cascade
                                    // Control inputs: Control Inputs/Status Bits
                                    .ALUMODE(4'b0000),  // 4-bit input: ALU control
                                    // .CARRYINSEL(CARRYINSEL),         // 3-bit input: Carry select
                                    .CLK(clk),  // 1-bit input: Clock
                                    .INMODE(5'b10101),  // 5-bit input: INMODE control
                                    .OPMODE(9'b00_001_01_01),  // 9-bit input: Operation mode
                                    // Data inputs: Data Ports
                                    .A(dsp_a_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 30-bit input: A data
                                    .B(dsp_b_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 18-bit input: B data
                                    // .C(C),                           // 48-bit input: C data
                                    // .CARRYIN(CARRYIN),               // 1-bit input: Carry-in
                                    .D(dsp_d_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx+1, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 27-bit input: D data
                                    // Reset/Clock Enable inputs: Reset/Clock Enable Inputs
                                    .CEA1(1'b1),  // 1-bit input: Clock enable for 1st stage AREG
                                    .CEA2(1'b1),  // 1-bit input: Clock enable for 2nd stage AREG
                                    .CEAD(1'b0),  // 1-bit input: Clock enable for ADREG
                                    .CEALUMODE(1'b0),  // 1-bit input: Clock enable for ALUMODE
                                    .CEB1(1'b1),  // 1-bit input: Clock enable for 1st stage BREG
                                    .CEB2(1'b1),  // 1-bit input: Clock enable for 2nd stage BREG
                                    .CEC(1'b0),  // 1-bit input: Clock enable for CREG
                                    .CECARRYIN(1'b0),  // 1-bit input: Clock enable for CARRYINREG
                                    .CECTRL(1'b0),                 // 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
                                    .CED(1'b1),  // 1-bit input: Clock enable for DREG
                                    .CEINMODE(1'b0),  // 1-bit input: Clock enable for INMODEREG
                                    .CEM(1'b1),  // 1-bit input: Clock enable for MREG
                                    .CEP(1'b1),  // 1-bit input: Clock enable for PREG
                                    .RSTA(rst),  // 1-bit input: Reset for AREG
                                    .RSTALLCARRYIN(rst),  // 1-bit input: Reset for CARRYINREG
                                    .RSTALUMODE(1'b0),  // 1-bit input: Reset for ALUMODEREG
                                    .RSTB(rst),  // 1-bit input: Reset for BREG
                                    .RSTC(1'b0),  // 1-bit input: Reset for CREG
                                    .RSTCTRL(1'b0),               // 1-bit input: Reset for OPMODEREG and CARRYINSELREG
                                    .RSTD(1'b0),  // 1-bit input: Reset for DREG and ADREG
                                    .RSTINMODE(1'b0),  // 1-bit input: Reset for INMODEREG
                                    .RSTM(rst),  // 1-bit input: Reset for MREG
                                    .RSTP(rst)  // 1-bit input: Reset for PREG
                                );
                            end else begin
                                DSP48E2 #(
                                    // Feature Control Attributes: Data Path Selection
                                    .AMULTSEL("AD"),  // Selects A input to multiplier (A, AD)
                                    .A_INPUT("DIRECT"),                // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                    .BMULTSEL("B"),  // Selects B input to multiplier (AD, B)
                                    .B_INPUT("DIRECT"),                // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
                                    .PREADDINSEL("A"),  // Selects input to pre-adder (A, B)
                                    .RND(48'h000000000000),  // Rounding Constant
                                    .USE_MULT("MULTIPLY"),             // Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
                                    .USE_SIMD("ONE48"),  // SIMD selection (FOUR12, ONE48, TWO24)
                                    .USE_WIDEXOR("FALSE"),             // Use the Wide XOR function (FALSE, TRUE)
                                    .XORSIMD("XOR24_48_96"),           // Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
                                    // Pattern Detector Attributes: Pattern Detection Configuration
                                    .AUTORESET_PATDET("NO_RESET"),     // NO_RESET, RESET_MATCH, RESET_NOT_MATCH
                                    .AUTORESET_PRIORITY("RESET"),      // Priority of AUTORESET vs. CEP (CEP, RESET).
                                    .MASK(48'h3fffffffffff),           // 48-bit mask value for pattern detect (1=ignore)
                                    .PATTERN(48'h000000000000),        // 48-bit pattern match for pattern detect
                                    .SEL_MASK("MASK"),  // C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
                                    .SEL_PATTERN("PATTERN"),  // Select pattern value (C, PATTERN)
                                    .USE_PATTERN_DETECT("NO_PATDET"),  // Enable pattern detect (NO_PATDET, PATDET)
                                    // Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
                                    .IS_ALUMODE_INVERTED(4'b0000),     // Optional inversion for ALUMODE
                                    .IS_CARRYIN_INVERTED(1'b0),  // Optional inversion for CARRYIN
                                    .IS_CLK_INVERTED(1'b0),  // Optional inversion for CLK
                                    .IS_INMODE_INVERTED(5'b00000),  // Optional inversion for INMODE
                                    .IS_OPMODE_INVERTED(9'b000000000), // Optional inversion for OPMODE
                                    .IS_RSTALLCARRYIN_INVERTED(1'b0),  // Optional inversion for RSTALLCARRYIN
                                    .IS_RSTALUMODE_INVERTED(1'b0),     // Optional inversion for RSTALUMODE
                                    .IS_RSTA_INVERTED(1'b0),  // Optional inversion for RSTA
                                    .IS_RSTB_INVERTED(1'b0),  // Optional inversion for RSTB
                                    .IS_RSTCTRL_INVERTED(1'b0),  // Optional inversion for RSTCTRL
                                    .IS_RSTC_INVERTED(1'b0),  // Optional inversion for RSTC
                                    .IS_RSTD_INVERTED(1'b0),  // Optional inversion for RSTD
                                    .IS_RSTINMODE_INVERTED(1'b0),      // Optional inversion for RSTINMODE
                                    .IS_RSTM_INVERTED(1'b0),  // Optional inversion for RSTM
                                    .IS_RSTP_INVERTED(1'b0),  // Optional inversion for RSTP
                                    // Register Control Attributes: Pipeline Register Configuration
                                    .ACASCREG(1),                      // Number of pipeline stages between A/ACIN and ACOUT (0-2)
                                    .ADREG(0),  // Pipeline stages for pre-adder (0-1)
                                    .ALUMODEREG(0),  // Pipeline stages for ALUMODE (0-1)
                                    .AREG(1),  // Pipeline stages for A (0-2)
                                    .BCASCREG(1),                      // Number of pipeline stages between B/BCIN and BCOUT (0-2)
                                    .BREG(1),  // Pipeline stages for B (0-2)
                                    .CARRYINREG(1),  // Pipeline stages for CARRYIN (0-1)
                                    .CARRYINSELREG(1),  // Pipeline stages for CARRYINSEL (0-1)
                                    .CREG(1),  // Pipeline stages for C (0-1)
                                    .DREG(1),  // Pipeline stages for D (0-1)
                                    .INMODEREG(0),  // Pipeline stages for INMODE (0-1)
                                    .MREG(1),  // Multiplier pipeline stages (0-1)
                                    .OPMODEREG(0),  // Pipeline stages for OPMODE (0-1)
                                    .PREG(1)  // Number of pipeline stages for P (0-1)
                                ) DSP48E2_inst (
                                    // Cascade outputs: Cascade Ports
                                    // .ACOUT(ACOUT),                   // 30-bit output: A port cascade
                                    // .BCOUT(BCOUT),                   // 18-bit output: B cascade
                                    // .CARRYCASCOUT(CARRYCASCOUT),     // 1-bit output: Cascade carry
                                    // .MULTSIGNOUT(MULTSIGNOUT),       // 1-bit output: Multiplier sign cascade
                                    .PCOUT(dsp_pc_out[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 48-bit output: Cascade output
                                    // Control outputs: Control Inputs/Status Bits
                                    // .OVERFLOW(OVERFLOW),             // 1-bit output: Overflow in add/acc
                                    // .PATTERNBDETECT(PATTERNBDETECT), // 1-bit output: Pattern bar detect
                                    // .PATTERNDETECT(PATTERNDETECT),   // 1-bit output: Pattern detect
                                    // .UNDERFLOW(UNDERFLOW),           // 1-bit output: Underflow in add/acc
                                    // Data outputs: Data Ports
                                    // .CARRYOUT(CARRYOUT),             // 4-bit output: Carry
                                    .P(dsp_p_out[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 48-bit output: Primary data
                                    // .XOROUT(XOROUT),                 // 8-bit output: XOR data
                                    // Cascade inputs: Cascade Ports
                                    // .ACIN(ACIN),                     // 30-bit input: A cascade data
                                    // .BCIN(BCIN),                     // 18-bit input: B cascade
                                    // .CARRYCASCIN(CARRYCASCIN),       // 1-bit input: Cascade carry
                                    // .MULTSIGNIN(MULTSIGNIN),         // 1-bit input: Multiplier sign cascade
                                    .PCIN(dsp_cas_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 48-bit input: P cascade
                                    // Control inputs: Control Inputs/Status Bits
                                    .ALUMODE(4'b0000),  // 4-bit input: ALU control
                                    // .CARRYINSEL(CARRYINSEL),         // 3-bit input: Carry select
                                    .CLK(clk),  // 1-bit input: Clock
                                    .INMODE(5'b10101),  // 5-bit input: INMODE control
                                    .OPMODE(9'b00_001_01_01),  // 9-bit input: Operation mode
                                    // Data inputs: Data Ports
                                    .A(dsp_a_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 30-bit input: A data
                                    .B(dsp_b_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 18-bit input: B data
                                    // .C(C),                           // 48-bit input: C data
                                    // .CARRYIN(CARRYIN),               // 1-bit input: Carry-in
                                    .D(dsp_d_in[dsp_idx_opt(
                                        a_k_idx, a_hw_idx+1, a_c_idx, a_i_idx, a_j_idx
                                    )]),  // 27-bit input: D data
                                    // Reset/Clock Enable inputs: Reset/Clock Enable Inputs
                                    .CEA1(1'b1),  // 1-bit input: Clock enable for 1st stage AREG
                                    .CEA2(1'b1),  // 1-bit input: Clock enable for 2nd stage AREG
                                    .CEAD(1'b0),  // 1-bit input: Clock enable for ADREG
                                    .CEALUMODE(1'b0),  // 1-bit input: Clock enable for ALUMODE
                                    .CEB1(1'b1),  // 1-bit input: Clock enable for 1st stage BREG
                                    .CEB2(1'b1),  // 1-bit input: Clock enable for 2nd stage BREG
                                    .CEC(1'b0),  // 1-bit input: Clock enable for CREG
                                    .CECARRYIN(1'b0),  // 1-bit input: Clock enable for CARRYINREG
                                    .CECTRL(1'b0),                 // 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
                                    .CED(1'b1),  // 1-bit input: Clock enable for DREG
                                    .CEINMODE(1'b0),  // 1-bit input: Clock enable for INMODEREG
                                    .CEM(1'b1),  // 1-bit input: Clock enable for MREG
                                    .CEP(1'b1),  // 1-bit input: Clock enable for PREG
                                    .RSTA(rst),  // 1-bit input: Reset for AREG
                                    .RSTALLCARRYIN(rst),  // 1-bit input: Reset for CARRYINREG
                                    .RSTALUMODE(1'b0),  // 1-bit input: Reset for ALUMODEREG
                                    .RSTB(rst),  // 1-bit input: Reset for BREG
                                    .RSTC(1'b0),  // 1-bit input: Reset for CREG
                                    .RSTCTRL(1'b0),               // 1-bit input: Reset for OPMODEREG and CARRYINSELREG
                                    .RSTD(1'b0),  // 1-bit input: Reset for DREG and ADREG
                                    .RSTINMODE(1'b0),  // 1-bit input: Reset for INMODEREG
                                    .RSTM(rst),  // 1-bit input: Reset for MREG
                                    .RSTP(rst)  // 1-bit input: Reset for PREG
                                );
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    // Parallel DSP
`else

    logic [8:0] dsp_opmode;
    logic rst;
    assign rst = ~rst_n;

    logic        [26:0] dsp_a_in     [CU_SIGNAL_NUM-1:0];  // fin << 18
    logic        [17:0] dsp_b_in     [CU_SIGNAL_NUM-1:0];  // w
    logic        [26:0] dsp_d_in     [CU_SIGNAL_NUM-1:0];  // fin
    logic        [44:0] dsp_p_out    [CU_SIGNAL_NUM-1:0];  // 2 results, need to be separated
    logic        [47:0] dsp_cas_in   [CU_SIGNAL_NUM-1:0];  // for cascaded dsp
    logic signed [15:0] dsp_p_out_sep[CU_SIGNAL_NUM-1:0];  // 2 results, need to be separated

    genvar a_k_idx, a_c_idx, a_i_idx, a_j_idx, a_hw_idx;

    logic signed [15:0] adder_in            [PBUF_NUM-1:0][DSP_GROUP_NUM-1:0]; // The total number of adder tree input
    logic signed [15:0] adder_out[PBUF_NUM-1:0];  // output of adder tree
    logic signed [15:0] acc_out             [PBUF_NUM-1:0]; // output of accumulator, one input of fout_exec_adder
    logic signed [15:0] fout_exec_adder_in  [PBUF_NUM-1:0]; // another input of fout_exec_adder (0 or fout_rd_data)

    logic signed [15:0] fout_exec_adder[PBUF_NUM-1:0];  // fout_exec_adder
    assign dsp_opmode = 9'b00_000_01_01;
    generate
        for (a_k_idx = 0; a_k_idx < PARAM_A_K; a_k_idx++) begin
            for (a_hw_idx = 0; a_hw_idx < PARAM_A_H * PARAM_A_W; a_hw_idx++) begin
                for (a_c_idx = 0; a_c_idx < PARAM_A_C; a_c_idx++) begin
                    for (a_i_idx = 0; a_i_idx < PARAM_A_I; a_i_idx++) begin
                        for (a_j_idx = 0; a_j_idx < PARAM_A_J; a_j_idx++) begin
                            assign dsp_cas_in[dsp_idx_opt(
                                a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                            )] = 48'h0000_0000_0000;
                            assign dsp_a_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = {
                                    rf_exec_data[rf_idx_opt(
                                        a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )][RF_DATA_WIDTH-1],
                                    rf_exec_data[rf_idx_opt(a_hw_idx, a_c_idx, a_i_idx, a_j_idx)],
                                    {(18) {1'b0}}
                                };
                            assign dsp_b_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = {
                                    {(18 - RF_DATA_WIDTH) {wbuf_exec_data[wbuf_idx(
                                        a_k_idx, a_c_idx, a_i_idx, a_j_idx
                                    )][WBUF_DATA_WIDTH-1]}},
                                    wbuf_exec_data[wbuf_idx(a_k_idx, a_c_idx, a_i_idx, a_j_idx)]
                                };
                            assign dsp_d_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )] = {
                                    {(27 - RF_DATA_WIDTH) {rf_exec_data[rf_idx_opt(
                                        a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                    )][RF_DATA_WIDTH-1]}},
                                    rf_exec_data[rf_idx_opt(a_hw_idx, a_c_idx, a_i_idx, a_j_idx)]
                                };
                        end
                    end
                end
                for (a_c_idx = 0; a_c_idx < PARAM_A_C; a_c_idx++) begin
                    for (a_i_idx = 0; a_i_idx < PARAM_A_I; a_i_idx++) begin
                        for (a_j_idx = 0; a_j_idx < PARAM_A_J; a_j_idx++) begin
                            assign adder_in[pbuf_idx_opt(
                                a_k_idx, a_hw_idx
                            )][dsp_idx_group(
                                a_c_idx, a_i_idx, a_j_idx
                            )] = dsp_p_out_sep[dsp_idx_opt(
                                a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                            )];
                        end
                    end
                end
                adder_tree #(
                    .DATA_WIDTH(16),
                    .INPUT_NUM (DSP_GROUP_NUM)
                ) adder_tree_inst (
                    clk,
                    rst,
                    1'b1,
                    adder_in[pbuf_idx_opt (a_k_idx, a_hw_idx)],
                    adder_out[pbuf_idx_opt (a_k_idx, a_hw_idx)]
                );
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        acc_out[pbuf_idx_opt(a_k_idx, a_hw_idx)] <= 0;
                    end else if (adder_rst_en) begin
                        acc_out[pbuf_idx_opt(a_k_idx, a_hw_idx)] <=
                            adder_out[pbuf_idx_opt(a_k_idx, a_hw_idx)];
                    end else begin
                        acc_out[pbuf_idx_opt(a_k_idx, a_hw_idx)]
                            <= acc_out[pbuf_idx_opt(a_k_idx, a_hw_idx)] +
                            adder_out[pbuf_idx_opt(a_k_idx, a_hw_idx)];
                    end
                end
                always_ff @(posedge clk) begin
                    if (~rst_n) begin
                        fout_exec_adder_in[pbuf_idx_opt(a_k_idx, a_hw_idx)] <= 0;
                    end else
                        fout_exec_adder_in[pbuf_idx_opt(
                            a_k_idx, a_hw_idx
                        )] <= pbuf_exec_rd_rst_en ? 0 : pbuf_exec_rd_data[pbuf_idx_opt(
                            a_k_idx, a_hw_idx
                        )];
                end
                assign fout_exec_adder[pbuf_idx_opt(
                    a_k_idx, a_hw_idx
                )] = acc_out[pbuf_idx_opt(
                    a_k_idx, a_hw_idx
                )] + fout_exec_adder_in[pbuf_idx_opt(
                    a_k_idx, a_hw_idx
                )];
                assign pbuf_exec_wr_data[pbuf_idx_opt(
                    a_k_idx, a_hw_idx
                )] = fout_exec_adder[pbuf_idx_opt(
                    a_k_idx, a_hw_idx
                )];
            end
        end
    endgenerate

    // DSP gen
    generate
        for (a_k_idx = 0; a_k_idx < PARAM_A_K; a_k_idx++) begin
            for (
                a_hw_idx = 0; a_hw_idx < PARAM_A_H * PARAM_A_W; a_hw_idx = a_hw_idx + 2
            ) begin  // Make sure that PARAM_CU_OW*PARAM_CU_OH is even number
                for (a_c_idx = 0; a_c_idx < PARAM_A_C; a_c_idx++) begin
                    for (a_i_idx = 0; a_i_idx < PARAM_A_I; a_i_idx++) begin
                        for (a_j_idx = 0; a_j_idx < PARAM_A_J; a_j_idx++) begin
                            assign dsp_p_out_sep[dsp_idx_opt(
                                a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                            )] = (dsp_p_out[dsp_idx_opt(
                                a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                            )][15]) ? (dsp_p_out[dsp_idx_opt(
                                a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                            )][33:18] + 1) : dsp_p_out[dsp_idx_opt(
                                a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                            )][33:18];
                            assign dsp_p_out_sep[dsp_idx_opt(
                                a_k_idx, a_hw_idx+1, a_c_idx, a_i_idx, a_j_idx
                            )] = dsp_p_out[dsp_idx_opt(
                                a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                            )][15:0];
                            DSP48E2 #(
                                // Feature Control Attributes: Data Path Selection
                                .AMULTSEL("AD"),  // Selects A input to multiplier (A, AD)
                                .A_INPUT("DIRECT"),                // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
                                .BMULTSEL("B"),  // Selects B input to multiplier (AD, B)
                                .B_INPUT("DIRECT"),                // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
                                .PREADDINSEL("A"),  // Selects input to pre-adder (A, B)
                                .RND(48'h000000000000),  // Rounding Constant
                                .USE_MULT("MULTIPLY"),             // Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
                                .USE_SIMD("ONE48"),  // SIMD selection (FOUR12, ONE48, TWO24)
                                .USE_WIDEXOR("FALSE"),  // Use the Wide XOR function (FALSE, TRUE)
                                .XORSIMD("XOR24_48_96"),           // Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
                                // Pattern Detector Attributes: Pattern Detection Configuration
                                .AUTORESET_PATDET("NO_RESET"),     // NO_RESET, RESET_MATCH, RESET_NOT_MATCH
                                .AUTORESET_PRIORITY("RESET"),      // Priority of AUTORESET vs. CEP (CEP, RESET).
                                .MASK(48'h3fffffffffff),           // 48-bit mask value for pattern detect (1=ignore)
                                .PATTERN(48'h000000000000),        // 48-bit pattern match for pattern detect
                                .SEL_MASK("MASK"),  // C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
                                .SEL_PATTERN("PATTERN"),  // Select pattern value (C, PATTERN)
                                .USE_PATTERN_DETECT("NO_PATDET"),  // Enable pattern detect (NO_PATDET, PATDET)
                                // Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
                                .IS_ALUMODE_INVERTED(4'b0000),  // Optional inversion for ALUMODE
                                .IS_CARRYIN_INVERTED(1'b0),  // Optional inversion for CARRYIN
                                .IS_CLK_INVERTED(1'b0),  // Optional inversion for CLK
                                .IS_INMODE_INVERTED(5'b00000),  // Optional inversion for INMODE
                                .IS_OPMODE_INVERTED(9'b000000000),  // Optional inversion for OPMODE
                                .IS_RSTALLCARRYIN_INVERTED(1'b0),  // Optional inversion for RSTALLCARRYIN
                                .IS_RSTALUMODE_INVERTED(1'b0),  // Optional inversion for RSTALUMODE
                                .IS_RSTA_INVERTED(1'b0),  // Optional inversion for RSTA
                                .IS_RSTB_INVERTED(1'b0),  // Optional inversion for RSTB
                                .IS_RSTCTRL_INVERTED(1'b0),  // Optional inversion for RSTCTRL
                                .IS_RSTC_INVERTED(1'b0),  // Optional inversion for RSTC
                                .IS_RSTD_INVERTED(1'b0),  // Optional inversion for RSTD
                                .IS_RSTINMODE_INVERTED(1'b0),  // Optional inversion for RSTINMODE
                                .IS_RSTM_INVERTED(1'b0),  // Optional inversion for RSTM
                                .IS_RSTP_INVERTED(1'b0),  // Optional inversion for RSTP
                                // Register Control Attributes: Pipeline Register Configuration
                                .ACASCREG(1),                      // Number of pipeline stages between A/ACIN and ACOUT (0-2)
                                .ADREG(0),  // Pipeline stages for pre-adder (0-1)
                                .ALUMODEREG(0),  // Pipeline stages for ALUMODE (0-1)
                                .AREG(1),  // Pipeline stages for A (0-2)
                                .BCASCREG(1),                      // Number of pipeline stages between B/BCIN and BCOUT (0-2)
                                .BREG(1),  // Pipeline stages for B (0-2)
                                .CARRYINREG(1),  // Pipeline stages for CARRYIN (0-1)
                                .CARRYINSELREG(1),  // Pipeline stages for CARRYINSEL (0-1)
                                .CREG(1),  // Pipeline stages for C (0-1)
                                .DREG(1),  // Pipeline stages for D (0-1)
                                .INMODEREG(0),  // Pipeline stages for INMODE (0-1)
                                .MREG(1),  // Multiplier pipeline stages (0-1)
                                .OPMODEREG(0),  // Pipeline stages for OPMODE (0-1)
                                .PREG(1)  // Number of pipeline stages for P (0-1)
                            ) DSP48E2_inst (
                                // Cascade outputs: Cascade Ports
                                // .ACOUT(ACOUT),                   // 30-bit output: A port cascade
                                // .BCOUT(BCOUT),                   // 18-bit output: B cascade
                                // .CARRYCASCOUT(CARRYCASCOUT),     // 1-bit output: Cascade carry
                                // .MULTSIGNOUT(MULTSIGNOUT),       // 1-bit output: Multiplier sign cascade
                                // .PCOUT(PCOUT),                   // 48-bit output: Cascade output
                                // Control outputs: Control Inputs/Status Bits
                                // .OVERFLOW(OVERFLOW),             // 1-bit output: Overflow in add/acc
                                // .PATTERNBDETECT(PATTERNBDETECT), // 1-bit output: Pattern bar detect
                                // .PATTERNDETECT(PATTERNDETECT),   // 1-bit output: Pattern detect
                                // .UNDERFLOW(UNDERFLOW),           // 1-bit output: Underflow in add/acc
                                // Data outputs: Data Ports
                                // .CARRYOUT(CARRYOUT),             // 4-bit output: Carry
                                .P(dsp_p_out[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )]),  // 48-bit output: Primary data
                                // .XOROUT(XOROUT),                 // 8-bit output: XOR data
                                // Cascade inputs: Cascade Ports
                                // .ACIN(ACIN),                     // 30-bit input: A cascade data
                                // .BCIN(BCIN),                     // 18-bit input: B cascade
                                // .CARRYCASCIN(CARRYCASCIN),       // 1-bit input: Cascade carry
                                // .MULTSIGNIN(MULTSIGNIN),         // 1-bit input: Multiplier sign cascade
                                .PCIN(dsp_cas_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )]),  // 48-bit input: P cascade
                                // Control inputs: Control Inputs/Status Bits
                                .ALUMODE(4'b0000),  // 4-bit input: ALU control
                                // .CARRYINSEL(CARRYINSEL),         // 3-bit input: Carry select
                                .CLK(clk),  // 1-bit input: Clock
                                .INMODE(5'b10101),  // 5-bit input: INMODE control
                                .OPMODE(dsp_opmode),  // 9-bit input: Operation mode
                                // Data inputs: Data Ports
                                .A(dsp_a_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )]),  // 30-bit input: A data
                                .B(dsp_b_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                                )]),  // 18-bit input: B data
                                // .C(C),                           // 48-bit input: C data
                                // .CARRYIN(CARRYIN),               // 1-bit input: Carry-in
                                .D(dsp_d_in[dsp_idx_opt(
                                    a_k_idx, a_hw_idx+1, a_c_idx, a_i_idx, a_j_idx
                                )]),  // 27-bit input: D data
                                // Reset/Clock Enable inputs: Reset/Clock Enable Inputs
                                .CEA1(1'b1),  // 1-bit input: Clock enable for 1st stage AREG
                                .CEA2(1'b1),  // 1-bit input: Clock enable for 2nd stage AREG
                                .CEAD(1'b0),  // 1-bit input: Clock enable for ADREG
                                .CEALUMODE(1'b0),  // 1-bit input: Clock enable for ALUMODE
                                .CEB1(1'b1),  // 1-bit input: Clock enable for 1st stage BREG
                                .CEB2(1'b1),  // 1-bit input: Clock enable for 2nd stage BREG
                                .CEC(1'b0),  // 1-bit input: Clock enable for CREG
                                .CECARRYIN(1'b0),  // 1-bit input: Clock enable for CARRYINREG
                                .CECTRL(1'b0),                 // 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
                                .CED(1'b1),  // 1-bit input: Clock enable for DREG
                                .CEINMODE(1'b0),  // 1-bit input: Clock enable for INMODEREG
                                .CEM(1'b1),  // 1-bit input: Clock enable for MREG
                                .CEP(1'b1),  // 1-bit input: Clock enable for PREG
                                .RSTA(rst),  // 1-bit input: Reset for AREG
                                .RSTALLCARRYIN(rst),  // 1-bit input: Reset for CARRYINREG
                                .RSTALUMODE(1'b0),  // 1-bit input: Reset for ALUMODEREG
                                .RSTB(rst),  // 1-bit input: Reset for BREG
                                .RSTC(1'b0),  // 1-bit input: Reset for CREG
                                .RSTCTRL(1'b0),               // 1-bit input: Reset for OPMODEREG and CARRYINSELREG
                                .RSTD(1'b0),  // 1-bit input: Reset for DREG and ADREG
                                .RSTINMODE(1'b0),  // 1-bit input: Reset for INMODEREG
                                .RSTM(rst),  // 1-bit input: Reset for MREG
                                .RSTP(rst)  // 1-bit input: Reset for PREG
                            );
                        end
                    end
                end
            end
        end
    endgenerate

`endif
    /************************************************* MACC *************************************************/

    /************************************************* MAX *************************************************/
    genvar fow, foh;
    generate
        for (foh = 0; foh < PARAM_A_H; foh++) begin
            for (fow = 0; fow < PARAM_A_W; fow++) begin
                always_ff @(posedge clk) begin
                    if (rst) begin
                        maxpool_result[pbuf_idx(0, foh, fow)] <= 0;
                    end else if (comp_type) begin
                        if (rf_exec_data[rf_idx(
                                foh, fow, 0, 0, 0
                            )] > maxpool_result[pbuf_idx(
                                0, foh, fow
                            )][ABUF_DATA_WIDTH-1:0]) begin
                            maxpool_result[pbuf_idx(0, foh, fow)][ABUF_DATA_WIDTH-1:0] <=
                                rf_exec_data[rf_idx(foh, fow, 0, 0, 0)];
                        end
                    end
                end
            end
        end
    endgenerate
    /************************************************* MAX *************************************************/

    // RF
    logic [RF_ADDR_WIDTH-1:0] rf_updt_addr  [RF_NUM_PER_ABUF-1:0];
    logic [RF_ADDR_WIDTH-1:0] rf_updt_addr_r[RF_NUM_PER_ABUF-1:0];

    genvar a_h, a_w, a_i, a_j;
    generate
        for (a_h = 0; a_h < PARAM_A_H; a_h++) begin
            for (a_w = 0; a_w < PARAM_A_W; a_w++) begin
                for (a_i = 0; a_i < PARAM_A_I; a_i++) begin
                    for (a_j = 0; a_j < PARAM_A_J; a_j++) begin
                        // addr counter (+1 every cycle)
                        assign rf_updt_addr[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )] = rf_updt_addr_r[rf_idx_in_abuf(
                            a_h, a_w, a_i, a_j
                        )];
                        always_ff @(posedge clk) begin
                            if (~rst_n) begin
                                rf_updt_addr_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                            end else if (rf_updt_addr_rst) begin
                                rf_updt_addr_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <= 0;
                            end else if (rf_updt_en[rf_idx_in_abuf(a_h, a_w, a_i, a_j)]) begin
                                rf_updt_addr_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] <=
                                    rf_updt_addr_r[rf_idx_in_abuf(a_h, a_w, a_i, a_j)] + 1;
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    generate
        for (a_hw_idx = 0; a_hw_idx < PARAM_A_W * PARAM_A_H; a_hw_idx++) begin
            for (a_c_idx = 0; a_c_idx < PARAM_A_C; a_c_idx++) begin
                for (a_i_idx = 0; a_i_idx < PARAM_A_I; a_i_idx++) begin
                    for (a_j_idx = 0; a_j_idx < PARAM_A_J; a_j_idx++) begin
                        rf rf_inst (
                            .clk(clk),
                            .rst(rst),
                            .updt_en(rf_updt_en[rf_idx_in_abuf_opt(a_hw_idx, a_i_idx, a_j_idx)]),
                            .updt_sel(rf_updt_sel),
                            .updt_addr(rf_updt_addr[rf_idx_in_abuf_opt(
                                a_hw_idx, a_i_idx, a_j_idx
                            )]),
                            .updt_data(rf_updt_data[abuf_idx(a_c_idx)]),
                            .exec_sel(rf_exec_sel),
                            .exec_addr(rf_exec_addr),
                            .exec_data(rf_exec_data_p[rf_idx_opt(
                                a_hw_idx, a_c_idx, a_i_idx, a_j_idx
                            )])
                        );
                        // always_ff @( posedge clk ) begin
                        //     rf_exec_data[rf_idx_opt(a_hw_idx,a_c_idx,a_i_idx,a_j_idx)] <= rf_exec_data_p[rf_idx_opt(a_hw_idx,a_c_idx,a_i_idx,a_j_idx)];
                        // end
                        // rf data delay
                        delay_chain #(
                            .DW (RF_DATA_WIDTH),
                            .LEN(2)
                        ) delay_rf_exec_data (
                            .clk(clk),
                            .rst(rst_n),
                            .en (1'b1),
                            .in (rf_exec_data_p[rf_idx_opt(a_hw_idx, a_c_idx, a_i_idx, a_j_idx)]),
                            .out(rf_exec_data[rf_idx_opt(a_hw_idx, a_c_idx, a_i_idx, a_j_idx)])
                        );
                    end
                end
            end
        end
    endgenerate

endmodule
