#include "layout_convert.h"

void verify_constexpr() {
    std::cout << "====== verify constexpr ======" << std::endl;
    std::cout << std::setw(3) << "x" << std::setw(8) << "binary"
              << std::setw(12) << "bit_w(x)" << std::setw(12) << "sel_w(x)"
              << std::endl;
    for (ap_size_t i = 0; i < 16; i++) {
        std::cout << std::dec << std::setw(3) << i << std::setw(8)
                  << i.to_string() << std::setw(12) << const_bit_width(i)
                  << std::setw(12) << const_sel_width(i) << std::endl;
    }
}

int main(int argc, char *argv[]) {
    param_pqfk_t pqfk;
    param_pqfh_t pqfh;
    param_pqfw_t pqfw;
    param_lk_t lk;
    param_lh_t lh;
    param_lw_t lw;
    param_fk_t fk;
    param_fh_t fh;
    param_fw_t fw;
    ap_size_t stk;
    ap_size_t sth;
    ap_size_t stw;
    param_pqh_t pqh;
    param_pqw_t pqw;
    ap_size_t process_num;

    sub_instr_intf_t m_sub_instr_intf("tb_instr_stream");
    input_intf_t m_input_intf("tb_input_stream");
    output_intf_t s_output_intf("tb_output_stream");

    std::cout << "====== argc argv ======" << std::endl;
    for (int i = 0; i < argc; ++i)
        std::cout << i << ": " << argv[i] << std::endl;
    if (argc < 13) {
        // use default args
        pqfk = 8;
        pqfh = 4;
        pqfw = 28;
        lk = 32;
        lh = 16;
        lw = 28;
        fk = 2;
        fh = 2;
        fw = 7;
        stk = 4;
        sth = 4;
        stw = 1;
        pqh = pqfh / fh;
        pqw = pqfw / fw;
        process_num = stk * sth * stw;
    } else if (argc == 13) {
        // use args from argv
        pqfk = argv[1];
        pqfh = argv[2];
        pqfw = argv[3];
        lk = argv[4];
        lh = argv[5];
        lw = argv[6];
        fk = argv[7];
        fh = argv[8];
        fw = argv[9];
        stk = argv[10];
        sth = argv[11];
        stw = argv[12];
    } else {
        std::cout << "Need 12 args: pqf<k,h,w>, l<k,h,w>, f<k,h,w>, st<k,h,w>."
                  << std::endl;
        return -1;
    }
    assert(pqfk >= fk && pqfh >= fh && pqfw >= fw);
    assert(pqfk * stk >= lk && pqfh * sth >= lh && pqfw * stw >= lw);

    pqh = pqfh / fh;
    pqw = pqfw / fw;
    process_num = stk * sth * stw;

#ifdef TESTBENCH_VERIFY_CONSTEXPR
    verify_constexpr();
#endif

    std::cout << "====== parameters ======" << std::endl;
    std::cout << std::dec << "  pq<h,w>:" << pqh << ", " << pqw << std::endl
              << "  pqf<k,h,w>:" << pqfk << ", " << pqfh << ", " << pqfw
              << std::endl
              << "  l<k,h,w>:" << lk << ", " << lh << ", " << lw << std::endl
              << "  f<k,h,w>:" << fk << ", " << fh << ", " << fw << std::endl
              << "  st<k,h,w>:" << stk << ", " << sth << ", " << stw
              << std::endl;

    assert(TRANS_FIFO_DEPTH * PARAM_AH >= pqw);

    // instruction stream
    size_t instr_arr_len = 3 + stk * sth * stw;
    sub_instr_t instr_data_arr[instr_arr_len] = {
        0x0000000000000000, 0x1000000000000000, 0x2000000000000000};
    // set param instructions
    instr_data_arr[0](55, 47) = pqh;          //  9b
    instr_data_arr[0](46, 38) = pqw;          //  9b
    instr_data_arr[0](37, 28) = pqfk;         // 10b
    instr_data_arr[0](17, 9) = pqfh;          //  9b
    instr_data_arr[0](8, 0) = pqfw;           //  9b
    instr_data_arr[1](43, 28) = lk;           // 16b
    instr_data_arr[1](17, 9) = lh;            //  9b
    instr_data_arr[1](8, 0) = lw;             //  9b
    instr_data_arr[2](47, 32) = process_num;  // 16b
    instr_data_arr[2](29, 24) = fk;           //  6b
    instr_data_arr[2](11, 6) = fh;            //  6b
    instr_data_arr[2](5, 0) = fw;             //  6b
    // set process instructions
    for (ap_size_t i_stk = 0; i_stk < stk; i_stk++)
        for (ap_size_t i_sth = 0; i_sth < sth; i_sth++)
            for (ap_size_t i_stw = 0; i_stw < stw; i_stw++) {
                size_t processing_idx = i_stw + i_sth * stw + i_stk * stw * sth;
                instr_data_arr[3 + processing_idx] = 0;
                instr_data_arr[3 + processing_idx][63] = 1;
                instr_data_arr[3 + processing_idx](57, 48) = i_stk;
                instr_data_arr[3 + processing_idx](37, 29) = i_sth;
                instr_data_arr[3 + processing_idx](28, 20) = i_stw;
            }
#ifdef TESTBENCH_VERBOSE_PRINT
    std::cout << "====== instruction stream ======" << std::endl;
#endif
    // write instruction stream
    for (size_t i_instr = 0; i_instr < instr_arr_len; i_instr++) {
        m_sub_instr_intf.write(instr_data_arr[i_instr]);
#ifdef TESTBENCH_VERBOSE_PRINT
        std::cout << "  " << std::dec << std::setw(4) << i_instr << "  "
                  << std::hex
                  << std::setw(instr_data_arr[i_instr].length() / 4 + 2)
                  << instr_data_arr[i_instr] << std::endl;
#endif
    }

    // input data stream
#ifdef TESTBENCH_VERBOSE_PRINT
    std::cout << "====== input data stream ======" << std::endl;
#endif
    for (size_t i_stk = 0; i_stk < stk; i_stk++)
        for (size_t i_sth = 0; i_sth < sth; i_sth++)
            for (size_t i_stw = 0; i_stw < stw; i_stw++)
                for (param_pqfk_t i_pqfk = 0; i_pqfk < pqfk; i_pqfk++)
                    for (param_pqh_t i_pqh = 0; i_pqh < pqh; i_pqh++)
                        for (param_pqw_t i_pqw = 0; i_pqw < pqw; i_pqw++) {
                            input_axis_t input_tmp;
                            input_tmp.data = 0;
                            input_tmp.keep = 0;
                            input_tmp.last = 0;
                            for (param_fh_t i_fh = 0; i_fh < fh; i_fh += 1)
                                for (param_fw_t i_fw = 0; i_fw < fw;
                                     i_fw += 1) {
                                    param_pqfh_t i_pqfh = i_fh + i_pqh * fh;
                                    param_pqfw_t i_pqfw = i_fw + i_pqw * fw;
                                    size_t start_bit = i_fw + i_fh * PARAM_AW;
                                    bool w_valid =
                                        (i_pqfk + i_stk * pqfk < lk) &&
                                        (i_pqfh + i_sth * pqfh < lh) &&
                                        (i_pqfw + i_stw * pqfw < lw);
                                    input_tmp.data(8 * start_bit + 7,
                                                   8 * start_bit) =
                                        w_valid ? (i_pqfh(3, 0), i_pqfw(3, 0))
                                                : 0xFF;
                                    input_tmp.keep[start_bit] = w_valid;
                                }
                            input_tmp.last = (i_pqfk >= pqfk - 1) &&
                                             (i_pqh >= pqh - 1) &&
                                             (i_pqw >= pqw - 1);
                            m_input_intf.write(input_tmp);
#ifdef TESTBENCH_VERBOSE_PRINT
                            std::cout << std::dec << "[" << i_stk << ", "
                                      << i_sth << ", " << i_stw << "]"
                                      << "[" << i_pqfk << ", " << i_pqh << ", "
                                      << i_pqw << "]" << std::hex << ": "
                                      << input_tmp.data << "  "
                                      << input_tmp.keep << "  "
                                      << input_tmp.last << std::endl;
#endif
                        }

                        // start kernel
#ifdef TESTBENCH_VERBOSE_PRINT
    std::cout << "====== kernel start ======" << std::endl;
#endif
    layout_convert(m_sub_instr_intf, m_input_intf, s_output_intf);
#ifdef TESTBENCH_VERBOSE_PRINT
    std::cout << "====== kernel end ======" << std::endl;
#endif

    // print the results
#ifdef TESTBENCH_VERBOSE_PRINT
    std::cout << "====== output data stream ======" << std::endl;
#endif
    for (size_t i_stk = 0; i_stk < stk; i_stk++)
        for (size_t i_sth = 0; i_sth < sth; i_sth++)
            for (size_t i_stw = 0; i_stw < stw; i_stw++) {
                // compute r shape, packet
                param_lk_t lk_beg;  // begin index
                param_lk_t lk_rem;  // remaining word length
                param_pqfk_t rk;    // real shape of tile
                param_lh_t lh_beg;
                param_lh_t lh_rem;
                param_pqfh_t rh;
                param_lw_t lw_beg;
                param_lw_t lw_rem;
                param_pqfw_t rw;
                size_t pkt_num;
                lk_beg = i_stk * pqfk;
                lk_rem = lk - lk_beg;
                rk = lk_rem < pqfk ? (param_pqfk_t)lk_rem : pqfk;
                lh_beg = i_sth * pqfh;
                lh_rem = lh - lh_beg;
                rh = lh_rem < pqfh ? (param_pqfh_t)lh_rem : pqfh;
                lw_beg = i_stw * pqfw;
                lw_rem = lw - lw_beg;
                rw = lw_rem < pqfw ? (param_pqfw_t)lw_rem : pqfw;
                if (rw != lw)
                    pkt_num = rk * rh;
                else if (rh != lh)
                    pkt_num = rk;
                else
                    pkt_num = 1;
                for (size_t i_pkt_num = 0; i_pkt_num < pkt_num; i_pkt_num++) {
                    size_t xfer_cnt = 0;
                    output_axis_t output_tmp;
                    do {
                        output_tmp = s_output_intf.read();
#ifdef TESTBENCH_VERBOSE_PRINT
                        std::cout << std::dec << "[" << i_stk << ", " << i_sth
                                  << ", " << i_stw << "]"
                                  << "[" << i_pkt_num << ", " << xfer_cnt << "]"
                                  << std::hex << ": " << std::setw(34)
                                  << output_tmp.data << "  " << std::setw(6)
                                  << output_tmp.keep << "  " << output_tmp.user
                                  << "  " << output_tmp.last << std::endl;
#endif
                    } while (!output_tmp.last);
                }
            }

    std::cout << "====== finish ======" << std::endl;
    return 0;
}
