#ifndef __LAYOUT_CONVERT_H__
#define __LAYOUT_CONVERT_H__

#include <gmp.h>
#define __gmp_const const

#include <cmath>
#include <iomanip>
#include <iostream>

#include "common.h"

#ifndef __SYNTHESIS__
#define KERNEL_BASIC_PRINT
#define KERNEL_VERBOSE_PRINT
#define TESTBENCH_VERBOSE_PRINT
#define TESTBENCH_VERIFY_CONSTEXPR
#endif

// local parameters
#define PARAM_AH_WIDTH (flog2(PARAM_AH) + 1)
#define PARAM_AW_WIDTH (flog2(PARAM_AW) + 1)
#define OUTPUT_VEC_LEN 3  // TODO: verification
#define OUTPUT_VEC_SEL_WIDTH \
    (const_sel_width(OUTPUT_VEC_LEN))  // == const_sel_width(OUTPUT_VEC_LEN)

// misc parameters
#define DATA_BLEN (PARAM_DATA_WIDTH / 8)

#define INPUT_DATA_WIDTH (PARAM_AH * PARAM_AW * PARAM_DATA_WIDTH)
#define INPUT_DATA_BLEN (INPUT_DATA_WIDTH / 8)

#define TRANS_DATA_WIDTH (PARAM_AW * PARAM_DATA_WIDTH)
#define TRANS_DATA_BLEN (TRANS_DATA_WIDTH / 8)
#define TRANS_DATA_BLEN_WIDTH (const_bit_width(TRANS_DATA_BLEN))
#define TRANS_FIFO_DEPTH 64  // related to pqw, will be verified in testbench

#define INTER2_DATA_WIDTH INPUT_DATA_WIDTH
#define INTER2_DATA_BLEN (INTER2_DATA_WIDTH / 8)
#define INTER2_DATA_BLEN_WIDTH (const_bit_width(INTER2_DATA_BLEN))

#define OUTPUT_DATA_WIDTH PARAM_DBUS_WIDTH

#define DVEC_DATA_WIDTH (OUTPUT_DATA_WIDTH * OUTPUT_VEC_LEN)
#define DVEC_DATA_BLEN (DVEC_DATA_WIDTH / 8)

#define OUTPUT_DATA_BLEN (OUTPUT_DATA_WIDTH / 8)
#define OUTPUT_DATA_BSEL_WIDTH (const_sel_width(OUTPUT_DATA_BLEN))

// misc type define
typedef ap_uint<16> ap_size_t;
typedef ap_uint<PARAM_AH_WIDTH> ah_sel_t;
typedef ap_uint<PARAM_AW_WIDTH> aw_sel_t;
typedef ap_uint<OUTPUT_DATA_BSEL_WIDTH> output_data_bsel_t;
typedef hls::vector<ah_sel_t, PARAM_AH> trans_sel_vec_t;
typedef ap_uint<TRANS_DATA_BLEN_WIDTH> trans_blen_t;
typedef ap_uint<INTER2_DATA_BLEN_WIDTH> inter2_blen_t;
typedef ap_uint<DVEC_DATA_WIDTH> dvec_t;
typedef ap_uint<DVEC_DATA_BLEN> dvec_blen_t;
typedef ap_uint<OUTPUT_VEC_SEL_WIDTH> output_vec_sel_t;

typedef ap_uint<10> param_pqfk_t;
typedef ap_uint<9> param_pqfh_t;
typedef ap_uint<9> param_pqfw_t;
typedef ap_uint<9> param_pqh_t;
typedef ap_uint<9> param_pqw_t;
typedef ap_uint<16> param_lk_t;
typedef ap_uint<9> param_lh_t;
typedef ap_uint<9> param_lw_t;
typedef ap_uint<6> param_fk_t;
typedef ap_uint<6> param_fh_t;
typedef ap_uint<6> param_fw_t;
typedef struct param_instr_struct_t {
    param_pqfk_t pqfk;
    param_pqfh_t pqfh;
    param_pqfw_t pqfw;
    param_pqh_t pqh;
    param_pqw_t pqw;
    ap_size_t pqfk_pqh;
    trans_sel_vec_t wr_sel_vec;
    param_lk_t lk;
    param_lh_t lh;
    param_lw_t lw;
    param_fk_t fk;
    param_fh_t fh;
    param_fw_t fw;
    ap_size_t process_num;
} param_instr_struct_t;
typedef ap_uint<10> param_stk_t;
typedef ap_uint<9> param_sth_t;
typedef ap_uint<9> param_stw_t;
typedef struct process_instr_struct_t {
    ap_size_t pkt_num;            // total packet number
    ap_size_t pkt_blen;           // byte len per packet
    output_data_bsel_t pkt_bgap;  // byte gap to fill pkt_blen to full xfer len
    ap_size_t xfer_num;           // totoal xfer number
    param_pqw_t pqw;
    ap_size_t pqfk_pqh;
    trans_sel_vec_t wr_sel_vec;
    ap_uint<1> eol;
} process_instr_struct_t;

// input related type
typedef ap_uint<INPUT_DATA_WIDTH> input_data_t;
typedef hls::axis<input_data_t, 0, 0, 0> input_axis_t;
typedef hls::stream<input_axis_t> input_intf_t;

// output related type
typedef ap_uint<OUTPUT_DATA_WIDTH> output_data_t;
typedef hls::axis<output_data_t, 1, 0, 0> output_axis_t;
typedef hls::stream<output_axis_t> output_intf_t;

// trans related type
typedef ap_uint<TRANS_DATA_WIDTH> trans_data_t;
typedef struct trans_struct_t {
    trans_data_t data;
    trans_blen_t blen;
} trans_struct_t;
typedef hls::stream<trans_struct_t> trans_stream_t;
typedef trans_stream_t trans_stream_arr_t[PARAM_AH][PARAM_AH];

// tras_sel related type
typedef hls::stream<trans_sel_vec_t> trans_sel_vec_stream_t;

// inter1 related type
typedef struct inter1_struct_t {
    hls::vector<trans_struct_t, PARAM_AH> trans_vec;
    bool last;
} inter1_struct_t;
typedef hls::stream<inter1_struct_t> inter1_stream_t;

// inter2 related type
typedef struct inter2_struct_t {
    ap_uint<INPUT_DATA_WIDTH> data;
    inter2_blen_t blen;
    bool last;
} inter2_struct_t;
typedef hls::stream<inter2_struct_t> inter2_stream_t;

// output_vec related type
typedef struct output_struct_t {
    output_data_t data;
    ap_uint<OUTPUT_DATA_BLEN> keep;
    bool last;
} output_struct_t;
typedef hls::stream<output_struct_t> output_stream_t;
typedef output_stream_t output_stream_vec_t[OUTPUT_VEC_LEN];

void layout_convert(sub_instr_intf_t &s_instr_intf, input_intf_t &s_input_intf,
                    output_intf_t &m_output_intf);

#endif
