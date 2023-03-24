#include "core_controller.h"
#include "instr_tb.h"

void read_res_instr(node_param_t node_param, hs_1b_intf_t &s_res_instr) {
    std::cout << "read_res_instr" << std::endl;
    s_res_instr.set_name("res");
    sub_instr_t res_instr = s_res_instr.read();
    std::cout << std::hex << std::setw(18) << res_instr << std::endl;
}

void read_mem_param_instr(node_param_t node_param,
                          sub_instr_intf_t &s_mem_param_instr) {
    std::cout << "read_mem_param_instr" << std::endl;
    s_mem_param_instr.set_name("mem_param");
    for (int i = 0; i < 8; i++) {
        sub_instr_t mem_param_instr = s_mem_param_instr.read();
        std::cout << std::hex << std::setw(18) << mem_param_instr << std::endl;
    }
}

void read_mm2s_instr(node_param_t node_param, sub_instr_intf_t &s_mm2s_instr) {
    read_mem_param_instr(node_param, s_mm2s_instr);
    if (node_param.bn_en) {
        std::cout << "read_mm2s_instr.bn" << std::endl;
        s_mm2s_instr.set_name("bn");
        sub_instr_t mm2s_bn_instr = s_mm2s_instr.read();
        std::cout << std::hex << std::setw(18) << mm2s_bn_instr << std::endl;
    }
    int act_in_num = 0;
    int weight_num = 0;
    int res_num = 0;
    for (ap_uint<10> tk = 0; tk < node_param.t_k; tk++)
        for (ap_uint<9> th = 0; th < node_param.t_h; th++)
            for (ap_uint<9> tw = 0; tw < node_param.t_w; tw++)
                for (ap_uint<10> tc = 0; tc < node_param.t_c; tc++) {
                    ap_uint<6> s_k = tk == node_param.t_k - 1
                                         ? node_param.s_k_last
                                         : node_param.s_k;
                    ap_uint<6> s_c = tc == node_param.t_c - 1
                                         ? node_param.s_c_last
                                         : node_param.s_c;
                    ap_uint<6> s_h = th == node_param.t_h - 1
                                         ? node_param.s_h_last
                                         : node_param.s_h;
                    ap_uint<6> s_w = tw == node_param.t_w - 1
                                         ? node_param.s_w_last
                                         : node_param.s_w;
                    ap_uint<6> s_k_dpws = tk == node_param.t_k - 1
                                              ? node_param.s_k_dpws_last
                                              : node_param.s_k_dpws;
                    std::cout << "read_mm2s_instr.act_in" << std::endl;
                    s_mm2s_instr.set_name("act_in");
                    for (ap_uint<6> sc = 0; sc < s_c; sc++)
                        for (ap_uint<6> sh = 0; sh < s_h; sh++)
                            for (ap_uint<6> sw = 0; sw < s_w; sw++) {
                                sub_instr_t mm2s_act_in_instr =
                                    s_mm2s_instr.read();
                                act_in_num++;
                                std::cout << std::hex << std::setw(18)
                                          << mm2s_act_in_instr
                                          << " eom=" << mm2s_act_in_instr[60]
                                          << " sel=" << mm2s_act_in_instr[59]
                                          << " eos=" << mm2s_act_in_instr[58]
                                          << std::endl;
                            }
                    std::cout << "read_mm2s_instr.weight" << std::endl;
                    s_mm2s_instr.set_name("w");
                    if (node_param.use_w) {
                        for (ap_uint<6> sk = 0; sk < s_k; sk++)
                            for (ap_uint<6> sc = 0; sc < s_c; sc++) {
                                sub_instr_t mm2s_w_instr = s_mm2s_instr.read();
                                weight_num++;
                                std::cout
                                    << std::hex << std::setw(18) << mm2s_w_instr
                                    << " eom=" << mm2s_w_instr[60]
                                    << " sel=" << mm2s_w_instr[59]
                                    << " eos=" << mm2s_w_instr[58] << std::endl;
                            }
                    }
                    std::cout << "read_mm2s_instr.res" << std::endl;
                    s_mm2s_instr.set_name("res");
                    if (node_param.res_en && tc == node_param.t_c - 1) {
                        for (ap_uint<6> sk_dpws = 0; sk_dpws < s_k_dpws;
                             sk_dpws++)
                            for (ap_uint<6> sh = 0; sh < s_h; sh++)
                                for (ap_uint<6> sw = 0; sw < s_w; sw++) {
                                    sub_instr_t mm2s_res_instr =
                                        s_mm2s_instr.read();
                                    res_num++;
                                    std::cout << std::hex << std::setw(18)
                                              << mm2s_res_instr << std::endl;
                                }
                    }
                }
    std::cout << "act_in_num=" << std::dec << act_in_num << std::endl;
    std::cout << "weight_num=" << std::dec << weight_num << std::endl;
    std::cout << "res_num=" << std::dec << res_num << std::endl;
}

void read_s2mm_instr(node_param_t node_param, sub_instr_intf_t &s_s2mm_instr) {
    read_mem_param_instr(node_param, s_s2mm_instr);
    std::cout << "read_s2mm_instr.act_out" << std::endl;
    s_s2mm_instr.set_name("act_out");
    int act_out_num = 0;
    for (ap_uint<10> tk_dpws = 0; tk_dpws < node_param.t_k_dpws; tk_dpws++)
        for (ap_uint<9> th = 0; th < node_param.t_h; th++)
            for (ap_uint<9> tw = 0; tw < node_param.t_w; tw++) {
                ap_uint<6> s_k_dpws = tk_dpws == node_param.t_k_dpws - 1
                                          ? node_param.s_k_dpws_last
                                          : node_param.s_k_dpws;
                ap_uint<6> s_h = th == node_param.t_h - 1 ? node_param.s_h_last
                                                          : node_param.s_h;
                ap_uint<6> s_w = tw == node_param.t_w - 1 ? node_param.s_w_last
                                                          : node_param.s_w;
                for (ap_uint<6> sk_dpws = 0; sk_dpws < s_k_dpws; sk_dpws++)
                    for (ap_uint<6> sh = 0; sh < s_h; sh++)
                        for (ap_uint<6> sw = 0; sw < s_w; sw++) {
                            sub_instr_t s2mm_act_out_instr =
                                s_s2mm_instr.read();
                            act_out_num++;
                            std::cout << std::hex << std::setw(18)
                                      << s2mm_act_out_instr
                                      << " eom=" << s2mm_act_out_instr[60]
                                      << " sel=" << s2mm_act_out_instr[59]
                                      << " eos=" << s2mm_act_out_instr[58]
                                      << std::endl;
                        }
            }
    std::cout << "act_out_num=" << std::dec << act_out_num << std::endl;
}

void read_pe_conf_instr(node_param_t node_param,
                        sub_instr_intf_t &s_pe_conf_instr) {
    for (int i = 0; i < 6; i++) {
        sub_instr_t pe_conf_instr = s_pe_conf_instr.read();
#ifdef TB_VERBOSE_COUT
        std::cout << std::hex << std::setw(18) << pe_conf_instr << std::endl;
#endif
    }
}

void read_pe_idx_instr(node_param_t node_param,
                       sub_instr_intf_t &s_pe_idx_instr) {
    for (int i = 0; i < node_param.pe_num; i++) {
        sub_instr_t pe_idx_instr = s_pe_idx_instr.read();
#ifdef TB_VERBOSE_COUT
        std::cout << std::hex << std::setw(18) << pe_idx_instr << std::endl;
#endif
    }
}

void read_pe_updt_instr(node_param_t node_param,
                        sub_instr_intf_t &s_pe_updt_instr) {
    std::cout << "read_pe_updt_instr" << std::endl;
    s_pe_updt_instr.set_name("pe_updt");
    read_pe_idx_instr(node_param, s_pe_updt_instr);
}

void read_pe_exec_instr(node_param_t node_param,
                        sub_instr_intf_t &s_pe_exec_instr) {
    std::cout << "read_pe_exec_instr" << std::endl;
    s_pe_exec_instr.set_name("pe_exec");
    read_pe_idx_instr(node_param, s_pe_exec_instr);
    read_pe_conf_instr(node_param, s_pe_exec_instr);
    int pe_exec_num = 0;
    for (ap_uint<10> tk = 0; tk < node_param.t_k; tk++)
        for (ap_uint<9> th = 0; th < node_param.t_h; th++)
            for (ap_uint<9> tw = 0; tw < node_param.t_w; tw++)
                for (ap_uint<10> tc = 0; tc < node_param.t_c; tc++) {
                    sub_instr_t pe_exec_instr = s_pe_exec_instr.read();
                    pe_exec_num++;
#ifdef TB_VERBOSE_COUT
                    std::cout << std::hex << std::setw(18) << pe_exec_instr
                              << std::endl;
#endif
                }
    std::cout << "pe_exec_num=" << std::dec << pe_exec_num << std::endl;
}

void read_pe_wb_instr(node_param_t node_param,
                      sub_instr_intf_t &s_pe_wb_instr) {
    std::cout << "read_pe_wb_instr" << std::endl;
    s_pe_wb_instr.set_name("pe_wb");
    read_pe_idx_instr(node_param, s_pe_wb_instr);
    read_pe_conf_instr(node_param, s_pe_wb_instr);
    int pe_wb_num = 0;
    for (ap_uint<10> tk_dpws = 0; tk_dpws < node_param.t_k_dpws; tk_dpws++)
        for (ap_uint<9> th = 0; th < node_param.t_h; th++)
            for (ap_uint<9> tw = 0; tw < node_param.t_w; tw++) {
                ap_uint<6> s_k_dpws = tk_dpws == node_param.t_k_dpws - 1
                                          ? node_param.s_k_dpws_last
                                          : node_param.s_k_dpws;
                ap_uint<6> s_h = th == node_param.t_h - 1 ? node_param.s_h_last
                                                          : node_param.s_h;
                ap_uint<6> s_w = tw == node_param.t_w - 1 ? node_param.s_w_last
                                                          : node_param.s_w;
                for (ap_uint<6> sk_dpws = 0; sk_dpws < s_k_dpws; sk_dpws++)
                    for (ap_uint<6> sh = 0; sh < s_h; sh++)
                        for (ap_uint<6> sw = 0; sw < s_w; sw++) {
                            sub_instr_t pe_wb_instr = s_pe_wb_instr.read();
                            pe_wb_num++;
#ifdef TB_VERBOSE_COUT
                            std::cout << std::hex << std::setw(18)
                                      << pe_wb_instr << std::endl;
#endif
                        }
            }
    std::cout << "pe_wb_num=" << std::dec << pe_wb_num << std::endl;
}

void read_lc_instr(node_param_t node_param, sub_instr_intf_t &s_lc_instr) {
    std::cout << "read_lc_instr" << std::endl;
    s_lc_instr.set_name("lc");
    for (int i = 0; i < 3; i++) {
        sub_instr_t lc_instr = s_lc_instr.read();
#ifdef TB_VERBOSE_COUT
        std::cout << std::hex << std::setw(18) << lc_instr << std::endl;
#endif
    }
    int lc_num = 0;
    for (ap_uint<10> tk_dpws = 0; tk_dpws < node_param.t_k_dpws; tk_dpws++)
        for (ap_uint<9> th = 0; th < node_param.t_h; th++)
            for (ap_uint<9> tw = 0; tw < node_param.t_w; tw++) {
                ap_uint<6> s_k_dpws = tk_dpws == node_param.t_k_dpws - 1
                                          ? node_param.s_k_dpws_last
                                          : node_param.s_k_dpws;
                ap_uint<6> s_h = th == node_param.t_h - 1 ? node_param.s_h_last
                                                          : node_param.s_h;
                ap_uint<6> s_w = tw == node_param.t_w - 1 ? node_param.s_w_last
                                                          : node_param.s_w;
                for (ap_uint<6> sk_dpws = 0; sk_dpws < s_k_dpws; sk_dpws++)
                    for (ap_uint<6> sh = 0; sh < s_h; sh++)
                        for (ap_uint<6> sw = 0; sw < s_w; sw++) {
                            sub_instr_t lc_instr = s_lc_instr.read();
#ifdef TB_VERBOSE_COUT
                            std::cout << std::hex << std::setw(18) << lc_instr
                                      << std::endl;
#endif
                            lc_num++;
                        }
            }
    std::cout << "lc_num=" << std::dec << lc_num << std::endl;
}

int main(int argc, char *argv[]) {
    node_param_t node_param_arr[TB_NODE_NUM];
    instr_t instr_arr[TB_NODE_NUM * INSTR_PER_NODE];

    ap_uint<1> res_en;

    instr_fifo_t m_core_instr;
    hs_1b_fifo_t i_done_instr, i_res_instr;
    sub_instr_fifo_t i_mm2s_instr, i_s2mm_instr, i_pe_updt_instr,
        i_pe_exec_instr, i_pe_wb_instr, i_lc_instr;

    build_core_instr(node_param_arr, instr_arr);

    for (int i = 0; i < TB_NODE_NUM * INSTR_PER_NODE; i++) {
        m_core_instr.write(instr_arr[i]);
        std::cout << "instr_arr[" << std::setw(2) << i << "]: " << std::hex
                  << instr_arr[i] << std::endl;
    }
    for (int i = 0; i < TB_NODE_NUM; i++) {
        for (int j = 0; j < 600; j++) {
            i_done_instr.write(j == 599);
        }
    }

    core_controller(TB_NODE_NUM, m_core_instr, i_done_instr, i_res_instr,
                    i_mm2s_instr, i_s2mm_instr, i_pe_updt_instr,
                    i_pe_exec_instr, i_pe_wb_instr, i_lc_instr);

    for (int i = 0; i < TB_NODE_NUM; i++) {
        std::cout << "========== node_param[" << i
                  << "] ==========" << std::endl;
        node_param_t node_param = node_param_arr[i];
        read_res_instr(node_param, i_res_instr);
        read_mm2s_instr(node_param, i_mm2s_instr);
        read_s2mm_instr(node_param, i_s2mm_instr);
        read_pe_updt_instr(node_param, i_pe_updt_instr);
        read_pe_exec_instr(node_param, i_pe_exec_instr);
        read_pe_wb_instr(node_param, i_pe_wb_instr);
        read_lc_instr(node_param, i_lc_instr);
    }
    assert(i_res_instr.empty());
    assert(i_mm2s_instr.empty());
    assert(i_s2mm_instr.empty());
    assert(i_pe_updt_instr.empty());
    assert(i_pe_exec_instr.empty());
    assert(i_pe_wb_instr.empty());
    assert(i_lc_instr.empty());
    return 0;
}
