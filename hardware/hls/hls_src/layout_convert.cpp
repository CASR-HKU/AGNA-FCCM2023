#include "layout_convert.h"

process_instr_struct_t decode_process_instr(
    param_instr_struct_t param_instr, ap_uint<1> last_process,
    sub_instr_intf_t &s_sub_instr_intf) {
    sub_instr_t sub_instr_tmp;
    process_instr_struct_t process_instr;
    param_stk_t stk;
    param_sth_t sth;
    param_stw_t stw;
    param_lk_t lk_beg;  // begin index
    param_lk_t lk_rem;  // remaining word length
    param_pqfk_t rk;    // real shape of tile
    param_lh_t lh_beg;
    param_lh_t lh_rem;
    param_pqfh_t rh;
    param_lw_t lw_beg;
    param_lw_t lw_rem;
    param_pqfw_t rw;
    // decode from procees_instr
    sub_instr_tmp = s_sub_instr_intf.read();
    stk = sub_instr_tmp(57, 48);  // 10b
    sth = sub_instr_tmp(37, 29);  //  9b
    stw = sub_instr_tmp(28, 20);  //  9b
    // compute real shape of tile
    lk_beg = stk * param_instr.pqfk;
    lk_rem = param_instr.lk - lk_beg;
    rk = lk_rem < param_instr.pqfk ? (param_pqfk_t)lk_rem : param_instr.pqfk;
    lh_beg = sth * param_instr.pqfh;
    lh_rem = param_instr.lh - lh_beg;
    rh = lh_rem < param_instr.pqfh ? (param_pqfh_t)lh_rem : param_instr.pqfh;
    lw_beg = stw * param_instr.pqfw;
    lw_rem = param_instr.lw - lw_beg;
    rw = lw_rem < param_instr.pqfw ? (param_pqfw_t)lw_rem : param_instr.pqfw;
    // compute packet parameters
    if (rw != param_instr.lw) {
        process_instr.pkt_num = rk * rh;
        process_instr.pkt_blen = rw * DATA_BLEN;
    } else if (rh != param_instr.lh) {
        process_instr.pkt_num = rk;
        process_instr.pkt_blen = rh * rw * DATA_BLEN;
    } else {
        process_instr.pkt_num = 1;
        process_instr.pkt_blen = rk * rh * rw * DATA_BLEN;
    }
    process_instr.pkt_bgap = (output_data_bsel_t)  // truncate sign bit
        (-process_instr.pkt_blen(OUTPUT_DATA_BSEL_WIDTH - 1, 0));
    process_instr.xfer_num = process_instr.pkt_num *
                             (process_instr.pkt_blen + process_instr.pkt_bgap) /
                             OUTPUT_DATA_BLEN;
    // copy others from param_instr
    process_instr.pqw = param_instr.pqw;
    process_instr.pqfk_pqh = param_instr.pqfk_pqh;
    process_instr.wr_sel_vec = param_instr.wr_sel_vec;
    process_instr.eol = last_process;
#ifdef KERNEL_BASIC_PRINT
    std::cout << std::dec << "decode_process_instr()" << std::endl
              << "  st<k,h,w>:" << stk << ", " << sth << ", " << stw
              << std::endl
              << "  l<k,h,w>_beg:" << lk_beg << ", " << lh_beg << ", " << lw_beg
              << std::endl
              << "  l<k,h,w>_rem:" << lk_rem << ", " << lh_rem << ", " << lw_rem
              << std::endl
              << "  r_<k,h,w>:" << rk << ", " << rh << ", " << rw << std::endl
              << "  pkt_num:" << process_instr.pkt_num
              << "  pkt_blen:" << process_instr.pkt_blen
              << "  pkt_bgap:" << process_instr.pkt_bgap
              << "  xfer_num:" << process_instr.xfer_num << std::endl
              << "  pqw:" << process_instr.pqw
              << "  pqfk_pqh:" << process_instr.pqfk_pqh << "  wr_sel_vec:";
    for (ah_sel_t ah_i = 0; ah_i < PARAM_AH; ah_i++) {
        std::cout << process_instr.wr_sel_vec[ah_i];
        if (ah_i == PARAM_AH - 1)
            std::cout << std::endl;
        else
            std::cout << ", ";
    }
#endif
    return process_instr;
}

void wr_trans_fifo_arr(param_instr_struct_t param_instr,
                       input_intf_t &s_input_intf,
                       trans_stream_arr_t &m_trans_stream_arr) {
#ifdef KERNEL_BASIC_PRINT
    std::cout << "wr_trans_fifo_arr()" << std::endl;
#endif
wr_trans_kh_loop:
    for (ap_size_t pqfk_pqh_i = 0; pqfk_pqh_i < param_instr.pqfk_pqh;
         pqfk_pqh_i++) {
        trans_sel_vec_t wr_sel_vec_tmp = param_instr.wr_sel_vec;
    wr_trans_w_loop:
        for (param_pqw_t pqw_i = 0; pqw_i < param_instr.pqw; pqw_i++) {
#pragma HLS pipeline II = 1
#ifdef KERNEL_VERBOSE_PRINT
            std::cout << std::dec << "  pqfk_pqh_i:" << std::setw(3)
                      << pqfk_pqh_i << "  pqw_i:" << std::setw(3) << pqw_i;
#endif
            input_axis_t input_tmp = s_input_intf.read();
        wr_trans_unrolled_ah_loop:
            for (ah_sel_t ah_i = 0; ah_i < PARAM_AH; ah_i++) {
#pragma HLS unroll
                trans_struct_t trans_tmp;
                trans_blen_t trans_blen_tmp = 0;
            wr_trans_unrolled_aw_loop:
                for (aw_sel_t aw_i = 0; aw_i < PARAM_AW; aw_i++) {
#pragma HLS unroll
                    // for 16b, only verify low byte, than times 2
                    trans_blen_tmp +=
                        input_tmp.keep[(aw_i + PARAM_AW * ah_i) * DATA_BLEN] *
                        DATA_BLEN;
                }
                trans_tmp.data = input_tmp.data(
                    TRANS_DATA_WIDTH * ah_i + TRANS_DATA_WIDTH - 1,
                    TRANS_DATA_WIDTH * ah_i);
                trans_tmp.blen = trans_blen_tmp;
                m_trans_stream_arr[ah_i][wr_sel_vec_tmp[ah_i]].write(trans_tmp);
#ifdef KERNEL_VERBOSE_PRINT
                std::cout << "  trans_arr[" << std::dec << std::setw(3) << ah_i
                          << std::setw(3) << wr_sel_vec_tmp[ah_i] << "]"
                          << "  "
                          << std::setw(std::ceil(trans_tmp.data.length() / 4) +
                                       2)
                          << std::hex << trans_tmp.data << "  " << std::dec
                          << trans_tmp.blen;
                if (ah_i == PARAM_AH - 1) std::cout << std::endl;
#endif
                if (wr_sel_vec_tmp[ah_i] == PARAM_AH - 1)
                    wr_sel_vec_tmp[ah_i] = 0;
                else
                    wr_sel_vec_tmp[ah_i]++;
            }
        }
    }
}

void generate_rd_trans_sel(param_instr_struct_t param_instr,
                           trans_sel_vec_stream_t &m_rd_sel_vec_stream) {
#ifdef KERNEL_BASIC_PRINT
    std::cout << "generate_rd_trans_sel()" << std::endl;
#endif
rd_sel_kh_loop:
    for (ap_size_t pqfk_pqh_i = 0; pqfk_pqh_i < param_instr.pqfk_pqh;
         pqfk_pqh_i++) {
        param_pqfw_t pqfw_base = 0;
    rd_sel_w_loop:
        for (param_pqw_t pqw_i = 0; pqw_i < param_instr.pqw; pqw_i++) {
#pragma HLS pipeline II = 1
            trans_sel_vec_t rd_sel_vec_tmp;
#ifdef KERNEL_VERBOSE_PRINT
            std::cout << std::dec << "  pqfw_base:" << std::setw(3) << pqfw_base
                      << "  rd_sel_vec_tmp:";
#endif
        rd_sel_unrolled_ah_loop:
            for (ah_sel_t ah_i = 0; ah_i < PARAM_AH; ah_i++) {
#pragma HLS unroll
                // TODO: remove division
                rd_sel_vec_tmp[ah_i] = (pqfw_base + ah_i) / param_instr.pqw;
#ifdef KERNEL_VERBOSE_PRINT
                std::cout << std::dec << std::setw(3) << rd_sel_vec_tmp[ah_i];
                if (ah_i == PARAM_AH - 1) std::cout << std::endl;
#endif
            }
            pqfw_base += PARAM_AH;
            m_rd_sel_vec_stream.write(rd_sel_vec_tmp);
        }
    }
}

void rd_trans_fifo_arr(param_instr_struct_t param_instr,
                       trans_sel_vec_stream_t &s_rd_sel_vec_stream,
                       trans_stream_arr_t &s_trans_stream_arr,
                       inter1_stream_t &m_inter1_stream) {
#ifdef KERNEL_BASIC_PRINT
    std::cout << "rd_trans_fifo_arr()" << std::endl;
#endif
rd_trans_kh_loop:
    for (ap_size_t pqfk_pqh_i = 0; pqfk_pqh_i < param_instr.pqfk_pqh;
         pqfk_pqh_i++) {
    rd_trans_w_loop:
        for (param_pqw_t pqw_i = 0; pqw_i < param_instr.pqw; pqw_i++) {
#pragma HLS pipeline II = 1
            trans_sel_vec_t rd_sel_vec_tmp = s_rd_sel_vec_stream.read();
            inter1_struct_t inter1_tmp;
#ifdef KERNEL_VERBOSE_PRINT
            std::cout << std::dec << "  pqfk_pqh_i:" << std::setw(3)
                      << pqfk_pqh_i << "  pqw_i:" << std::setw(3) << pqw_i;
#endif
        rd_trans_unrolled_ah_loop:
            for (ah_sel_t ah_i = 0; ah_i < PARAM_AH; ah_i++) {
#pragma HLS unroll
                inter1_tmp.trans_vec[ah_i] =
                    s_trans_stream_arr[rd_sel_vec_tmp[ah_i]][ah_i].read();
#ifdef KERNEL_VERBOSE_PRINT
                std::cout << "  trans_arr[" << std::dec << std::setw(3)
                          << rd_sel_vec_tmp[ah_i] << std::setw(3) << ah_i
                          << "]";
                if (ah_i == PARAM_AH - 1) std::cout << std::endl;
#endif
            }
            inter1_tmp.last = (pqfk_pqh_i == param_instr.pqfk_pqh - 1) &&
                              (pqw_i == param_instr.pqw - 1);
            m_inter1_stream.write(inter1_tmp);
        }
    }
}

void compress_inter(inter1_stream_t &s_inter1_stream,
                    inter2_stream_t &m_inter2_stream) {
    inter1_struct_t inter1_tmp;
    inter2_struct_t inter2_tmp;
#ifdef KERNEL_BASIC_PRINT
    std::cout << "compress_inter()" << std::endl;
#endif
compress_inter_while_loop:
    while (1) {
#pragma HLS pipeline II = 1
        inter1_tmp = s_inter1_stream.read();
        inter2_tmp.data = 0;
        inter2_tmp.blen = 0;
        inter2_tmp.last = inter1_tmp.last;
    compress_inter_unrolled_ah_loop:
        for (ah_sel_t ah_i = 0; ah_i < PARAM_AH; ah_i++) {
#pragma HLS unroll
            trans_blen_t len_tmp;
            len_tmp = inter1_tmp.trans_vec[ah_i].blen;
            if (len_tmp > 0) {
                inter2_tmp.data(
                    (inter2_tmp.blen + len_tmp) * PARAM_DATA_WIDTH - 1,
                    inter2_tmp.blen * PARAM_DATA_WIDTH) =
                    inter1_tmp.trans_vec[ah_i].data(
                        len_tmp * PARAM_DATA_WIDTH - 1, 0);
                inter2_tmp.blen += len_tmp;
            }
        }
#ifdef KERNEL_VERBOSE_PRINT
        std::cout << std::hex << "  "
                  << std::setw(std::ceil(inter2_tmp.data.length() / 4) + 2)
                  << inter2_tmp.data << std::dec << "  " << inter2_tmp.blen
                  << "  " << inter2_tmp.last << std::endl;
#endif
        m_inter2_stream.write(inter2_tmp);
        if (inter2_tmp.last) break;
    }
}

void generate_packet(process_instr_struct_t process_instr,
                     inter2_stream_t &s_inter2_stream,
                     output_stream_vec_t &m_output_stream_vec) {
#ifdef KERNEL_BASIC_PRINT
    std::cout << "generate_packet()" << std::endl;
#endif
    inter2_struct_t inter2_tmp;
    ap_size_t pkt_byte_cnt = 0;
    ap_size_t pkt_cnt = 0;
    ap_size_t dvec_beg_idx = 0;
    ap_size_t dvec_nxt_idx = 0;
    hls::vector<output_struct_t, OUTPUT_VEC_LEN> output_vec_tmp;
generate_packet_while_loop:
    while (1) {
#pragma HLS pipeline II = 1
        bool new_pkt = false;
        ap_size_t gap_len = 0;  // len before gap region
        inter2_tmp = s_inter2_stream.read();
#ifdef KERNEL_VERBOSE_PRINT
        std::cout << std::hex << "  inter2.data:"
                  << std::setw(std::ceil(inter2_tmp.data.length() / 4) + 2)
                  << inter2_tmp.data << std::dec << "  blen:" << inter2_tmp.blen
                  << "  last:" << inter2_tmp.last << std::endl;
#endif
        if (inter2_tmp.blen > 0) {
            // count packet byte
            pkt_byte_cnt += inter2_tmp.blen;
            if (pkt_byte_cnt >= process_instr.pkt_blen) {
                new_pkt = true;
                pkt_byte_cnt -= process_instr.pkt_blen;
                pkt_cnt++;
                gap_len = inter2_tmp.blen - pkt_byte_cnt;
            }
#ifdef KERNEL_VERBOSE_PRINT
            std::cout << std::dec << "  pkt_cnt:" << std::setw(3) << pkt_cnt
                      << "  pkt_byte_cnt:" << std::setw(4) << pkt_byte_cnt
                      << "  gap_len:" << std::setw(3) << gap_len
                      << "  new_pkt:" << std::setw(2) << new_pkt << std::endl;
#endif
            // count dvec index
            dvec_beg_idx = dvec_nxt_idx;
            dvec_nxt_idx += inter2_tmp.blen;
            if (new_pkt) dvec_nxt_idx += process_instr.pkt_bgap;
            if (dvec_nxt_idx >= OUTPUT_DATA_BLEN * OUTPUT_VEC_LEN)
                dvec_nxt_idx -= OUTPUT_DATA_BLEN * OUTPUT_VEC_LEN;
#ifdef KERNEL_VERBOSE_PRINT
            std::cout << std::dec << "  dvec_beg_idx:" << std::setw(4)
                      << dvec_beg_idx << "  dvec_nxt_idx:" << std::setw(4)
                      << dvec_nxt_idx << std::endl;
#endif
            // move data to dvec
            dvec_t dvec_data = 0;
            dvec_blen_t dvec_data_keep = 0;
            dvec_blen_t dvec_data_last = 0;
            dvec_blen_t dvec_data_valid = 0;
            if (new_pkt) {
                if (gap_len != 0) {
                    dvec_data(gap_len * 8 - 1, 0) =
                        inter2_tmp.data(gap_len * 8 - 1, 0);
                    dvec_data_keep(gap_len - 1, 0) = -1;
                }
                if (process_instr.pkt_bgap != 0) {
                    dvec_data((gap_len + process_instr.pkt_bgap) * 8 - 1,
                              gap_len * 8) = 0;
                    dvec_data_keep(gap_len + process_instr.pkt_bgap - 1,
                                   gap_len) = 0;
                }
                if (pkt_byte_cnt != 0) {
                    dvec_data(
                        (inter2_tmp.blen + process_instr.pkt_bgap) * 8 - 1,
                        (gap_len + process_instr.pkt_bgap) * 8) =
                        inter2_tmp.data(inter2_tmp.blen * 8 - 1, gap_len * 8);
                    dvec_data_keep(inter2_tmp.blen + process_instr.pkt_bgap - 1,
                                   gap_len + process_instr.pkt_bgap) = -1;
                }
                dvec_data_last[gap_len + process_instr.pkt_bgap - 1] = 1;
                dvec_data_valid(inter2_tmp.blen + process_instr.pkt_bgap - 1,
                                0) = -1;
            } else {
                dvec_data(inter2_tmp.blen * 8 - 1, 0) =
                    inter2_tmp.data(inter2_tmp.blen * 8 - 1, 0);
                dvec_data_keep(inter2_tmp.blen - 1, 0) = -1;
                dvec_data_valid(inter2_tmp.blen - 1, 0) = -1;
            }
#ifdef KERNEL_VERBOSE_PRINT
            std::cout << "  dvec.data:"
                      << std::setw(std::ceil(dvec_data.length() / 4) + 2)
                      << std::hex << dvec_data << "  keep:"
                      << std::setw(std::ceil(dvec_data_keep.length()) + 2)
                      << dvec_data_keep.to_string() << "  last:"
                      << std::setw(std::ceil(dvec_data_last.length()) + 2)
                      << dvec_data_last.to_string() << "  valid:"
                      << std::setw(std::ceil(dvec_data_valid.length()) + 2)
                      << dvec_data_valid.to_string() << std::endl;
#endif
            // rotate to begin pos
            dvec_data.lrotate(dvec_beg_idx * PARAM_DATA_WIDTH);
            dvec_data_keep.lrotate(dvec_beg_idx);
            dvec_data_last.lrotate(dvec_beg_idx);
            dvec_data_valid.lrotate(dvec_beg_idx);
#ifdef KERNEL_VERBOSE_PRINT
            std::cout << std::hex << "  rota.data:"
                      << std::setw(std::ceil(dvec_data.length() / 4) + 2)
                      << dvec_data << "  keep:"
                      << std::setw(std::ceil(dvec_data_keep.length()) + 2)
                      << dvec_data_keep.to_string() << "  last:"
                      << std::setw(std::ceil(dvec_data_last.length()) + 2)
                      << dvec_data_last.to_string() << "  valid:"
                      << std::setw(std::ceil(dvec_data_valid.length()) + 2)
                      << dvec_data_valid.to_string() << std::endl;
#endif
            // move valid byte in dvec to output_vec_tmp
        generate_packet_unrolled_output_vec_loop:
            for (output_vec_sel_t output_vec_sel_i = 0;
                 output_vec_sel_i < OUTPUT_VEC_LEN; output_vec_sel_i++) {
#pragma HLS unroll
            generate_packet_unrolled_output_data_byte_loop:
                for (ap_uint<16> output_data_byte_sel_i = 0;
                     output_data_byte_sel_i < OUTPUT_DATA_BLEN;
                     output_data_byte_sel_i++) {
#pragma HLS unroll
                    ap_uint<16> dvec_byte_sel =
                        output_data_byte_sel_i +
                        output_vec_sel_i * OUTPUT_DATA_BLEN;
                    if (dvec_data_valid[dvec_byte_sel]) {
                        output_vec_tmp[output_vec_sel_i].data(
                            output_data_byte_sel_i * 8 + 7,
                            output_data_byte_sel_i * 8) =
                            dvec_data(dvec_byte_sel * 8 + 7, dvec_byte_sel * 8);
                        output_vec_tmp[output_vec_sel_i]
                            .keep[output_data_byte_sel_i] =
                            dvec_data_keep[dvec_byte_sel];
                    }
                }
                output_vec_tmp[output_vec_sel_i].last =
                    dvec_data_last[(output_vec_sel_i + 1) * OUTPUT_DATA_BLEN -
                                   1];
#ifdef KERNEL_VERBOSE_PRINT
                std::cout
                    << std::dec << "  output_vec_tmp[" << output_vec_sel_i
                    << "]:"
                    << "  data:"
                    << std::setw(
                           std::ceil(
                               output_vec_tmp[output_vec_sel_i].data.length() /
                               4) +
                           2)
                    << std::hex << output_vec_tmp[output_vec_sel_i].data
                    << "  keep:"
                    << std::setw(
                           std::ceil(
                               output_vec_tmp[output_vec_sel_i].keep.length()) +
                           2)
                    << output_vec_tmp[output_vec_sel_i].keep.to_string()
                    << "  last:" << output_vec_tmp[output_vec_sel_i].last
                    << "  valid:"
                    << dvec_data_valid[(output_vec_sel_i + 1) *
                                           OUTPUT_DATA_BLEN -
                                       1]
                           .to_string()
                    << std::endl;
#endif
                // write if last byte is valid
                if (dvec_data_valid[(output_vec_sel_i + 1) * OUTPUT_DATA_BLEN -
                                    1]) {
                    m_output_stream_vec[output_vec_sel_i].write(
                        output_vec_tmp[output_vec_sel_i]);
                    output_vec_tmp[output_vec_sel_i].data = 0;
                    output_vec_tmp[output_vec_sel_i].keep = 0;
                }
            }
        }
        if (inter2_tmp.last) break;
    }
}

void merge_output_vec(process_instr_struct_t process_instr,
                      output_stream_vec_t &s_output_stream_vec,
                      output_intf_t &m_output_intf) {
#ifdef KERNEL_BASIC_PRINT
    std::cout << "merge_output_vec()" << std::endl;
#endif
    output_vec_sel_t output_vec_sel_i = 0;
merge_xfer_loop:
    for (ap_uint<16> xfer_i = 0; xfer_i < process_instr.xfer_num; xfer_i++) {
#pragma HLS pipeline II = 1
        output_struct_t output_tmp =
            s_output_stream_vec[output_vec_sel_i].read();
#ifdef KERNEL_VERBOSE_PRINT
        std::cout << std::dec << "  xfer_i:" << std::setw(3) << xfer_i
                  << "  output_vec_sel_i:" << std::setw(3) << output_vec_sel_i
                  << "  data:"
                  << std::setw(std::ceil(output_tmp.data.length() / 4) + 2)
                  << std::hex << output_tmp.data << "  keep:"
                  << std::setw(std::ceil(output_tmp.keep.length()) + 2)
                  << output_tmp.keep.to_string() << "  last:" << output_tmp.last
                  << std::endl;
#endif
        output_vec_sel_i++;
        if (output_vec_sel_i == OUTPUT_VEC_LEN) output_vec_sel_i = 0;
        output_axis_t output_axis_tmp;
        output_axis_tmp.data = output_tmp.data;
        output_axis_tmp.keep = output_tmp.keep;
        output_axis_tmp.user =
            process_instr.eol && xfer_i == process_instr.xfer_num - 1;
        output_axis_tmp.last = output_tmp.last;
        m_output_intf.write(output_axis_tmp);
    }
}

param_instr_struct_t decode_param_instr(sub_instr_intf_t &s_sub_instr_intf) {
    param_instr_struct_t param_instr;
    sub_instr_t sub_instr_tmp;
    // decode itype=0
    sub_instr_tmp = s_sub_instr_intf.read();
    param_instr.pqh = sub_instr_tmp(55, 47);                    //  9b
    param_instr.pqw = sub_instr_tmp(46, 38);                    //  9b
    param_instr.pqfk = sub_instr_tmp(37, 28);                   // 10b
    param_instr.pqfh = sub_instr_tmp(17, 9);                    //  9b
    param_instr.pqfw = sub_instr_tmp(8, 0);                     //  9b
    param_instr.pqfk_pqh = param_instr.pqfk * param_instr.pqh;  // 16b
    for (ah_sel_t ah_i = 0; ah_i < PARAM_AH; ah_i++) {
#pragma HLS unroll
        param_instr.wr_sel_vec[ah_i] = param_instr.pqw * ah_i % PARAM_AH;
    }
    // decode itype=1
    sub_instr_tmp = s_sub_instr_intf.read();
    param_instr.lk = sub_instr_tmp(43, 28);  // 16b
    param_instr.lh = sub_instr_tmp(17, 9);   //  9b
    param_instr.lw = sub_instr_tmp(8, 0);    //  9b
    // decode itype=2
    sub_instr_tmp = s_sub_instr_intf.read();
    param_instr.process_num = sub_instr_tmp(47, 32);  // 16b
    param_instr.fk = sub_instr_tmp(29, 24);           //  6b
    param_instr.fh = sub_instr_tmp(11, 6);            //  6b
    param_instr.fw = sub_instr_tmp(5, 0);             //  6b
#ifdef KERNEL_BASIC_PRINT
    std::cout << std::dec << "decode_param_instr()" << std::endl
              << "  pq<h,w>:" << param_instr.pqh << ", " << param_instr.pqw
              << std::endl
              << "  pqf<k,h,w>:" << param_instr.pqfk << ", " << param_instr.pqfh
              << ", " << param_instr.pqfw << std::endl
              << "  l<k,h,w>:" << param_instr.lk << ", " << param_instr.lh
              << ", " << param_instr.lw << std::endl
              << "  f<k,h,w>:" << param_instr.fk << ", " << param_instr.fh
              << ", " << param_instr.fw << std::endl
              << "  process_num:" << param_instr.process_num << std::endl;
#endif
    return param_instr;
}

void process_kernel(param_instr_struct_t param_instr,
                    sub_instr_intf_t &s_sub_instr_intf,
                    input_intf_t &s_input_intf, output_intf_t &m_output_intf) {
process_kernel_loop:
    for (ap_size_t process_i = 0; process_i < param_instr.process_num;
         process_i++) {
#pragma HLS dataflow
        ap_uint<1> last_process = process_i == param_instr.process_num - 1;
        process_instr_struct_t process_instr;
        trans_sel_vec_stream_t rd_sel_vec_fifo;
        trans_stream_arr_t trans_fifo_arr;
        DO_PRAGMA(HLS stream variable = trans_fifo_arr type = fifo depth =
                      TRANS_FIFO_DEPTH)
#pragma HLS bind_storage variable = trans_fifo_arr type = fifo impl = lutram
        inter1_stream_t inter1_fifo;
        inter2_stream_t inter2_fifo;
        output_stream_vec_t output_fifo_vec;
        process_instr =
            decode_process_instr(param_instr, last_process, s_sub_instr_intf);
        wr_trans_fifo_arr(param_instr, s_input_intf, trans_fifo_arr);
        generate_rd_trans_sel(param_instr, rd_sel_vec_fifo);
        rd_trans_fifo_arr(param_instr, rd_sel_vec_fifo, trans_fifo_arr,
                          inter1_fifo);
        compress_inter(inter1_fifo, inter2_fifo);
        generate_packet(process_instr, inter2_fifo, output_fifo_vec);
        merge_output_vec(process_instr, output_fifo_vec, m_output_intf);
    }
}

void layout_convert(sub_instr_intf_t &s_sub_instr_intf,
                    input_intf_t &s_input_intf, output_intf_t &m_output_intf) {
#pragma HLS interface mode = ap_fifo port = s_sub_instr_intf name = \
    s_axis_lc_instr
#pragma HLS interface mode = axis port = s_input_intf name = s_axis_pe2lc
#pragma HLS interface mode = axis port = m_output_intf name = m_axis_dbus

    // decode param_instr
    param_instr_struct_t param_instr = decode_param_instr(s_sub_instr_intf);
    process_kernel(param_instr, s_sub_instr_intf, s_input_intf, m_output_intf);
}
