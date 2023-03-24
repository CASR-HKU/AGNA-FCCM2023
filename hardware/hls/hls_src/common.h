#ifndef __COMMON_H__
#define __COMMON_H__

#include <gmp.h>
#define __gmp_const const
#include <stdint.h>

#include <fstream>
#include <iostream>

#include "ap_axi_sdata.h"
#include "ap_int.h"
#include "hls_burst_maxi.h"
#include "hls_stream.h"
#include "hls_vector.h"
#include "param.h"

#define PRAGMA_SUB(x) _Pragma(#x)
#define DO_PRAGMA(x) PRAGMA_SUB(x)

// flog2(x)
constexpr unsigned flog2(unsigned x) {
    // return x<=1 ? 0 : 1+flog2(x >> 1);
    unsigned result = 0;
    while (x > 1) {
        result++;
        x >>= 1;
    }
    return result;
}

constexpr unsigned const_bit_width(unsigned x) { return flog2(x) + 1; }
constexpr unsigned const_sel_width(unsigned x) {
    return x == 0 ? 0 : const_bit_width(x - 1);
}

#define INSTR_MEM_DEPTH 64
#define DO_INSTR_MEM_PRAGMA(name)                            \
    DO_PRAGMA(HLS interface mode = m_axi port = name depth = \
                  INSTR_MEM_DEPTH offset = off latency = 64 bundle = name)

#define DO_AXILITE_PRAGMA(name) \
    DO_PRAGMA(HLS interface mode = s_axilite port = name)

#define DO_LUTFIFO_PRAGMA(name) \
    DO_PRAGMA(HLS bind_storage variable = name type = fifo impl = lutram)

#ifndef __SYNTHESIS__
// #define TB_VERBOSE_COUT
// #define CORE_CONTROLLER_VERBOSE_COUT
// #define MEM_OP_VERBOSE_COUT
#endif

#define DBUS_DATA_FORMATTER(dbus_data) \
    std::hex << std::setw(dbus_data.length() / 4 + 2) << dbus_data

#define DBUS_XFER_FORMATTER(dbus_xfer)                                  \
    "data: " << DBUS_DATA_FORMATTER(dbus_xfer.data)                     \
             << " keep: " << std::setw(dbus_xfer.keep.length() / 4 + 2) \
             << dbus_xfer.keep << " last: " << std::dec << dbus_xfer.last

#define DBUS_WIDTH PARAM_DBUS_WIDTH
#define DBUS_BLEN (DBUS_WIDTH / 8)
#define DBUS_BLEN_WIDTH 4  // clog2(DBUS_BLEN)
#define DBUS_FIFO_DEPTH 64

typedef ap_uint<DBUS_WIDTH> dbus_data_t;
// dbus axi stream
typedef ap_uint<DBUS_BLEN> dbus_keep_t;
struct dbus_xfer_t {
    dbus_data_t data;  // data
    dbus_keep_t keep;  // keep
    ap_uint<1> last;   // last
};
typedef hls::stream<dbus_xfer_t> dbus_intf_t;
typedef hls::stream<dbus_xfer_t, DBUS_FIFO_DEPTH> dbus_fifo_t;

typedef hls::burst_maxi<dbus_data_t> maxi_mem_t;

#define MEM_ADDR_WIDTH 40
typedef ap_uint<MEM_ADDR_WIDTH> mem_addr_t;

#define BURST_OFFSET_WIDTH (MEM_ADDR_WIDTH - DBUS_BLEN_WIDTH)
typedef ap_uint<BURST_OFFSET_WIDTH> burst_offset_t;

#define MEM_CMD_FIFO_DEPTH 16
struct mem_cmd_xfer_t {
    burst_offset_t offset;  // offset in dbus xfer
    ap_uint<8> length;      // length in dbus xfer
    ap_uint<1> last;        // last
};
#define MEM_CMD_XFER_FORMATTER(mem_cmd)                                     \
    "offset: " << std::hex << std::setw(mem_cmd.offset.length() / 4 + 2)    \
               << mem_cmd.offset << " length: " << std::dec << std::setw(4) \
               << mem_cmd.length << " last: " << mem_cmd.last
typedef hls::stream<mem_cmd_xfer_t> mem_cmd_intf_t;
typedef hls::stream<mem_cmd_xfer_t, MEM_CMD_FIFO_DEPTH> mem_cmd_fifo_t;

#define PE_CMD_FIFO_DEPTH 16
struct pe_cmd_xfer_t {
    burst_offset_t offset;  // offset in dbus xfer
    ap_uint<8> length;      // length in dbus xfer
    ap_uint<1> last;        // last
};
#define PE_CMD_XFER_FORMATTER(pe_cmd)                                      \
    "offset: " << std::hex << std::setw(pe_cmd.offset.length() / 4 + 2)    \
               << pe_cmd.offset << " length: " << std::dec << std::setw(4) \
               << pe_cmd.length << " last: " << pe_cmd.last
typedef hls::stream<pe_cmd_xfer_t> pe_cmd_intf_t;
typedef hls::stream<pe_cmd_xfer_t, PE_CMD_FIFO_DEPTH> pe_cmd_fifo_t;

#define HS1B_FIFO_DEPTH 8
typedef ap_uint<1> hs1b_t;
typedef hls::stream<hs1b_t> hs1b_intf_t;
typedef hls::stream<hs1b_t, HS1B_FIFO_DEPTH> hs1b_fifo_t;

#define INSTR_PER_NODE 7
#define NODE_PER_BURST 2
#define INSTR_PER_BURST (INSTR_PER_NODE * NODE_PER_BURST)
#define GET_INSTR_NUM(x) (INSTR_PER_NODE * x)
#define INSTR_FIFO_DEPTH 16
typedef ap_uint<DBUS_WIDTH> instr_t;
typedef hls::stream<instr_t> instr_intf_t;
typedef hls::stream<instr_t, INSTR_FIFO_DEPTH> instr_fifo_t;

#define SUB_INSTR_WIDTH 64
#define SUB_INSTR_FIFO_DEPTH 16
typedef ap_uint<SUB_INSTR_WIDTH> sub_instr_t;
typedef hls::stream<sub_instr_t> sub_instr_intf_t;
typedef hls::stream<sub_instr_t, SUB_INSTR_FIFO_DEPTH> sub_instr_fifo_t;

#define DEBUG_BURST_LEN 16

#define STS_WIDTH 8
typedef ap_uint<STS_WIDTH> sts_data_t;
struct sts_xfer_t {
    sts_data_t data;
    ap_uint<1> last;
};
typedef hls::stream<sts_xfer_t> sts_intf_t;

typedef hls::stream<ap_uint<1>> hs_1b_intf_t;
typedef hls::stream<ap_uint<1>, 4> hs_1b_fifo_t;

#define DTAG_WIDTH 64
#define DTAG_FIFO_DEPTH 4
typedef ap_uint<DTAG_WIDTH> dtag_data_t;
struct dtag_xfer_t {
    dtag_data_t data;
    ap_uint<1> last;
};
typedef hls::stream<dtag_xfer_t> dtag_intf_t;
typedef hls::stream<dtag_xfer_t, DTAG_FIFO_DEPTH> dtag_fifo_t;

struct node_param_t {
    // 000
    ap_uint<1> bn_en;
    ap_uint<1> res_en;
    ap_uint<2> l_type;
    ap_uint<3> str_h;
    ap_uint<3> str_w;
    ap_uint<3> l_pad_t;
    ap_uint<3> l_pad_l;
    ap_uint<9> l_ih;
    ap_uint<9> l_iw;
    ap_uint<16> l_k;
    ap_uint<16> l_c;
    ap_uint<4> l_i;
    ap_uint<4> l_j;
    ap_uint<9> l_h;
    ap_uint<9> l_w;
    // 001
    ap_uint<10> p_k;
    ap_uint<10> p_c;
    ap_uint<4> p_i;
    ap_uint<4> p_j;
    ap_uint<9> p_h;
    ap_uint<9> p_w;
    ap_uint<10> q_k;
    ap_uint<10> q_c;
    ap_uint<4> q_i;
    ap_uint<4> q_j;
    ap_uint<9> q_h;
    ap_uint<9> q_w;
    ap_uint<6> f_k;
    ap_uint<6> f_c;
    ap_uint<3> f_i;
    ap_uint<3> f_j;
    ap_uint<6> f_h;
    ap_uint<6> f_w;
    // 010
    ap_uint<10> pqf_k;
    ap_uint<10> pqf_c;
    ap_uint<4> pqf_i;
    ap_uint<4> pqf_j;
    ap_uint<9> pqf_h;
    ap_uint<9> pqf_w;
    ap_uint<10> pq_k;
    ap_uint<10> pq_c;
    ap_uint<4> pq_i;
    ap_uint<4> pq_j;
    ap_uint<9> pq_h;
    ap_uint<9> pq_w;
    // 011
    ap_uint<10> ts_k;
    ap_uint<10> ts_c;
    ap_uint<9> ts_h;
    ap_uint<9> ts_w;
    ap_uint<10> t_k;
    ap_uint<10> t_c;
    ap_uint<9> t_h;
    ap_uint<9> t_w;
    ap_uint<6> s_k;
    ap_uint<6> s_c;
    ap_uint<6> s_h;
    ap_uint<6> s_w;
    // 100
    ap_uint<32> act_out_base_addr;
    ap_uint<32> weight_base_addr;
    ap_uint<32> act_in_base_addr;
    // 101
    ap_uint<10> wpb;
    ap_uint<7> pe_num;
    ap_uint<32> bn_base_addr;
    ap_uint<32> res_base_addr;
    // 110
    ap_uint<1> opt_eom;
    ap_uint<8> opt_pqfij;
    ap_uint<18> opt_pqfijc;
    ap_uint<28> opt_lih_liw_pqc;
    ap_uint<28> opt_wbuf_btt;
    ap_uint<18> opt_lih_liw;
    ap_uint<18> opt_lh_lw;
    // additional param
    ap_uint<6> s_k_last;
    ap_uint<6> s_c_last;
    ap_uint<6> s_h_last;
    ap_uint<6> s_w_last;
    ap_uint<1> is_dpws;
    ap_uint<1> use_w;
    ap_uint<16> l_k_dpws;
    ap_uint<10> p_k_dpws;
    ap_uint<10> q_k_dpws;
    ap_uint<6> f_k_dpws;
    ap_uint<10> pqf_k_dpws;
    ap_uint<10> pq_k_dpws;
    ap_uint<10> ts_k_dpws;
    ap_uint<10> t_k_dpws;
    ap_uint<6> s_k_dpws;
    ap_uint<6> s_k_dpws_last;
    ap_uint<16> lc_tile_num;
    ap_uint<9> pqf_ih;
    ap_uint<9> pqf_iw;
};
typedef hls::stream<node_param_t> node_param_intf_t;
typedef hls::stream<node_param_t, 2> node_param_fifo_t;

struct mem_param_t {
    ap_uint<2> d_type;
    ap_uint<1> eol;
    ap_uint<1> sel;
    ap_uint<1> eos;
    ap_uint<10> tsk;
    ap_uint<10> tsc;
    ap_uint<9> tsh;
    ap_uint<9> tsw;
    ap_uint<10> sk;
    ap_uint<10> sc;
    ap_uint<9> sh;
    ap_uint<9> sw;
};

#endif
