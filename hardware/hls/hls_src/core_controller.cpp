#include "core_controller.h"

void decode_core_instr(ap_uint<32> node_num, instr_intf_t &core_instr,
                       node_param_intf_t &node_param_res,
                       node_param_intf_t &node_param_mm2s,
                       node_param_intf_t &node_param_s2mm,
                       node_param_intf_t &node_param_pe_updt,
                       node_param_intf_t &node_param_pe_exec,
                       node_param_intf_t &node_param_pe_wb,
                       node_param_intf_t &node_param_lc) {
node_loop:
    for (int i = 0; i < node_num; i++) {
        node_param_t node_param;
    instr_loop:
        for (size_t i = 0; i < INSTR_PER_NODE; i++) {
#pragma HLS pipeline II = 1
            instr_t instr_tmp = core_instr.read();
            ap_uint<3> ptype = instr_tmp(127, 125);
            switch (ptype) {
                case 0:  // 000
                    node_param.res_en = instr_tmp[121];
                    node_param.bn_en = instr_tmp[120];
                    node_param.l_type = instr_tmp(119, 118);
                    node_param.str_h = instr_tmp(117, 115);
                    node_param.str_w = instr_tmp(114, 112);
                    node_param.l_pad_t = instr_tmp(111, 109);
                    node_param.l_pad_l = instr_tmp(108, 106);
                    node_param.l_ih = instr_tmp(105, 97);
                    node_param.l_iw = instr_tmp(96, 88);
                    node_param.l_k = instr_tmp(87, 72);
                    node_param.l_c = instr_tmp(71, 56);
                    node_param.l_i = instr_tmp(55, 52);
                    node_param.l_j = instr_tmp(51, 48);
                    node_param.l_h = instr_tmp(47, 39);
                    node_param.l_w = instr_tmp(38, 30);
                    break;
                case 1:  // 001
                    node_param.p_k = instr_tmp(121, 112);
                    node_param.p_c = instr_tmp(111, 102);
                    node_param.p_i = instr_tmp(101, 98);
                    node_param.p_j = instr_tmp(97, 94);
                    node_param.p_h = instr_tmp(93, 85);
                    node_param.p_w = instr_tmp(84, 76);
                    node_param.q_k = instr_tmp(75, 66);
                    node_param.q_c = instr_tmp(65, 56);
                    node_param.q_i = instr_tmp(55, 52);
                    node_param.q_j = instr_tmp(51, 48);
                    node_param.q_h = instr_tmp(47, 39);
                    node_param.q_w = instr_tmp(38, 30);
                    node_param.f_k = instr_tmp(29, 24);
                    node_param.f_c = instr_tmp(23, 18);
                    node_param.f_i = instr_tmp(17, 15);
                    node_param.f_j = instr_tmp(14, 12);
                    node_param.f_h = instr_tmp(11, 6);
                    node_param.f_w = instr_tmp(5, 0);
                    break;
                case 2:  // 010
                    node_param.pqf_k = instr_tmp(121, 112);
                    node_param.pqf_c = instr_tmp(111, 102);
                    node_param.pqf_i = instr_tmp(101, 98);
                    node_param.pqf_j = instr_tmp(97, 94);
                    node_param.pqf_h = instr_tmp(93, 85);
                    node_param.pqf_w = instr_tmp(84, 76);
                    node_param.pq_k = instr_tmp(75, 66);
                    node_param.pq_c = instr_tmp(65, 56);
                    node_param.pq_i = instr_tmp(55, 52);
                    node_param.pq_j = instr_tmp(51, 48);
                    node_param.pq_h = instr_tmp(47, 39);
                    node_param.pq_w = instr_tmp(38, 30);
                    break;
                case 3:  // 011
                    node_param.ts_k = instr_tmp(121, 112);
                    node_param.ts_c = instr_tmp(111, 102);
                    node_param.ts_h = instr_tmp(93, 85);
                    node_param.ts_w = instr_tmp(84, 76);
                    node_param.t_k = instr_tmp(75, 66);
                    node_param.t_c = instr_tmp(65, 56);
                    node_param.t_h = instr_tmp(47, 39);
                    node_param.t_w = instr_tmp(38, 30);
                    node_param.s_k = instr_tmp(29, 24);
                    node_param.s_c = instr_tmp(23, 18);
                    node_param.s_h = instr_tmp(11, 6);
                    node_param.s_w = instr_tmp(5, 0);
                    break;
                case 4:  // 100
                    node_param.act_out_base_addr = instr_tmp(95, 64);
                    node_param.weight_base_addr = instr_tmp(63, 32);
                    node_param.act_in_base_addr = instr_tmp(31, 0);
                    break;
                case 5:  // 101
                    node_param.wpb = instr_tmp(84, 75);
                    node_param.pe_num = instr_tmp(70, 64);
                    node_param.bn_base_addr = instr_tmp(63, 32);
                    node_param.res_base_addr = instr_tmp(31, 0);
                    break;
                case 6:  // 110
                    node_param.opt_eom = instr_tmp[118];
                    node_param.opt_pqfij = instr_tmp(117, 110);
                    node_param.opt_pqfijc = instr_tmp(109, 92);
                    node_param.opt_lih_liw_pqc = instr_tmp(91, 64);
                    node_param.opt_wbuf_btt = instr_tmp(63, 36);
                    node_param.opt_lih_liw = instr_tmp(35, 18);
                    node_param.opt_lh_lw = instr_tmp(17, 0);
                    break;
            }
        }
        // compute additional param
        node_param.s_k_last =
            node_param.t_k * node_param.s_k <= node_param.ts_k
                ? node_param.s_k
                : (ap_uint<6>)(node_param.ts_k -
                               (node_param.t_k - 1) * node_param.s_k);
        node_param.s_c_last =
            node_param.t_c * node_param.s_c <= node_param.ts_c
                ? node_param.s_c
                : (ap_uint<6>)(node_param.ts_c -
                               (node_param.t_c - 1) * node_param.s_c);
        node_param.s_h_last =
            node_param.t_h * node_param.s_h <= node_param.ts_h
                ? node_param.s_h
                : (ap_uint<6>)(node_param.ts_h -
                               (node_param.t_h - 1) * node_param.s_h);
        node_param.s_w_last =
            node_param.t_w * node_param.s_w <= node_param.ts_w
                ? node_param.s_w
                : (ap_uint<6>)(node_param.ts_w -
                               (node_param.t_w - 1) * node_param.s_w);
        node_param.use_w = (node_param.l_type <= 1);
        node_param.is_dpws = (node_param.l_type != 0);
        node_param.l_k_dpws =
            node_param.is_dpws ? node_param.l_c : node_param.l_k;
        node_param.p_k_dpws =
            node_param.is_dpws ? node_param.p_c : node_param.p_k;
        node_param.q_k_dpws =
            node_param.is_dpws ? node_param.q_c : node_param.q_k;
        node_param.f_k_dpws =
            node_param.is_dpws ? node_param.f_c : node_param.f_k;
        node_param.pqf_k_dpws =
            node_param.is_dpws ? node_param.pqf_c : node_param.pqf_k;
        node_param.pq_k_dpws =
            node_param.is_dpws ? node_param.pq_c : node_param.pq_k;
        node_param.ts_k_dpws =
            node_param.is_dpws ? node_param.ts_c : node_param.ts_k;
        node_param.t_k_dpws =
            node_param.is_dpws ? node_param.t_c : node_param.t_k;
        node_param.s_k_dpws =
            node_param.is_dpws ? node_param.s_c : node_param.s_k;
        node_param.s_k_dpws_last =
            node_param.is_dpws ? node_param.s_c_last : node_param.s_k_last;
        node_param.lc_tile_num =
            node_param.ts_k_dpws * node_param.ts_h * node_param.ts_w;
        node_param.pqf_ih =
            (node_param.pqf_h - 1) * node_param.str_h + node_param.pqf_i;
        node_param.pqf_iw =
            (node_param.pqf_w - 1) * node_param.str_w + node_param.pqf_j;

        // duplicate
        node_param_res.write(node_param);
        node_param_mm2s.write(node_param);
        node_param_s2mm.write(node_param);
        node_param_pe_updt.write(node_param);
        node_param_pe_exec.write(node_param);
        node_param_pe_wb.write(node_param);
        node_param_lc.write(node_param);

#ifdef CORE_CONTROLLER_VERBOSE_COUT
        std::cout
            << "==========================================="
               "================="
            << std::endl
            << "decode_core_instr()" << std::endl
            << std::dec << "l_type: " << node_param.l_type << std::endl
            << "strides: (" << node_param.str_h << ", " << node_param.str_w
            << ")" << std::endl
            << "padding: (" << node_param.l_pad_t << ", " << node_param.l_pad_l
            << ")" << std::endl
            << "l: (" << node_param.l_k << ", " << node_param.l_c << ", "
            << node_param.l_i << ", " << node_param.l_j << ", "
            << node_param.l_h << ", " << node_param.l_w << ")" << std::endl
            << "l_i<h,w>: (" << node_param.l_ih << ", " << node_param.l_iw
            << ")" << std::endl
            << "t: (" << node_param.t_k << ", " << node_param.t_c << ", "
            << node_param.t_h << ", " << node_param.t_w << ")" << std::endl
            << "s: (" << node_param.s_k << ", " << node_param.s_c << ", "
            << node_param.s_h << ", " << node_param.s_w << ")" << std::endl
            << "ts: (" << node_param.ts_k << ", " << node_param.ts_c << ", "
            << node_param.ts_h << ", " << node_param.ts_w << ")" << std::endl
            << "p: (" << node_param.p_k << ", " << node_param.p_c << ", "
            << node_param.p_i << ", " << node_param.p_j << ", "
            << node_param.p_h << ", " << node_param.p_w << ")" << std::endl
            << "q: (" << node_param.q_k << ", " << node_param.q_c << ", "
            << node_param.q_i << ", " << node_param.q_j << ", "
            << node_param.q_h << ", " << node_param.q_w << ")" << std::endl
            << "f: (" << node_param.f_k << ", " << node_param.f_c << ", "
            << node_param.f_i << ", " << node_param.f_j << ", "
            << node_param.f_h << ", " << node_param.f_w << ")" << std::endl
            << "pqf: (" << node_param.pqf_k << ", " << node_param.pqf_c << ", "
            << node_param.pqf_i << ", " << node_param.pqf_j << ", "
            << node_param.pqf_h << ", " << node_param.pqf_w << ")" << std::endl
            << "pqf_i<h,w>: (" << node_param.pqf_ih << ", " << node_param.pqf_iw
            << ")" << std::endl
            << "pq: (" << node_param.pq_k << ", " << node_param.pq_c << ", "
            << node_param.pq_i << ", " << node_param.pq_j << ", "
            << node_param.pq_h << ", " << node_param.pq_w << ")" << std::endl
            << "s_last: (" << node_param.s_k_last << ", " << node_param.s_c_last
            << ", " << node_param.s_h_last << ", " << node_param.s_w_last << ")"
            << std::endl
            << "s_k_dpws_last:" << node_param.s_k_dpws_last << std::endl
            << "wpb: " << node_param.wpb << std::endl
            << "pe_num: " << node_param.pe_num << std::endl
            << std::hex << "act_out_base_addr: " << node_param.act_out_base_addr
            << std::endl
            << "weight_base_addr: " << node_param.weight_base_addr << std::endl
            << "act_in_base_addr: " << node_param.act_in_base_addr << std::endl
            << "bn_base_addr: " << node_param.bn_base_addr << std::endl
            << "res_base_addr: " << node_param.res_base_addr << std::endl
            << std::dec << "opt_eom: " << node_param.opt_eom << std::endl
            << "opt_pqfij: " << node_param.opt_pqfij << std::endl
            << "opt_pqfijc: " << node_param.opt_pqfijc << std::endl
            << "opt_lih_liw_pqc: " << node_param.opt_lih_liw_pqc << std::endl
            << "opt_wbuf_btt: " << node_param.opt_wbuf_btt << std::endl
            << "opt_lih_liw: " << node_param.opt_lih_liw << std::endl
            << "opt_lh_lw: " << node_param.opt_lh_lw << std::endl;
#endif
    }
}

void split_param(node_param_t &node_param, node_param_t &node_param_res,
                 node_param_t &node_param_mm2s, node_param_t &node_param_s2mm,
                 node_param_t &node_param_pe_updt,
                 node_param_t &node_param_pe_exec,
                 node_param_t &node_param_pe_wb, node_param_t &node_param_lc) {
    node_param_res = node_param;
    node_param_mm2s = node_param;
    node_param_s2mm = node_param;
    node_param_pe_updt = node_param;
    node_param_pe_exec = node_param;
    node_param_pe_wb = node_param;
    node_param_lc = node_param;
}

void gen_mem_param_instr(node_param_t node_param,
                         sub_instr_intf_t &m_mem_param_instr) {
    sub_instr_t mem_param_instr;
    // instr_type: 0000
    mem_param_instr(63, 60) = ap_uint<4>("0000", 2);
    mem_param_instr(59, 56) = node_param.pqf_i;
    mem_param_instr(55, 47) = node_param.pqf_ih;
    mem_param_instr(46, 38) = node_param.pqf_iw;
    mem_param_instr(37, 28) = node_param.pqf_k_dpws;
    mem_param_instr(27, 18) = node_param.pqf_c;
    mem_param_instr(17, 9) = node_param.pqf_h;
    mem_param_instr(8, 0) = node_param.pqf_w;
    m_mem_param_instr.write(mem_param_instr);
    // instr_type: 0001
    mem_param_instr(63, 60) = ap_uint<4>("0001", 2);
    mem_param_instr(59, 56) = node_param.pqf_j;
    mem_param_instr(55, 47) = node_param.l_ih;
    mem_param_instr(46, 38) = node_param.l_iw;
    mem_param_instr(37, 34) = 0;  // rsvd
    mem_param_instr(33, 18) = node_param.l_k_dpws;
    mem_param_instr(17, 9) = node_param.l_h;
    mem_param_instr(8, 0) = node_param.l_w;
    m_mem_param_instr.write(mem_param_instr);
    // instr_type: 0010
    mem_param_instr(63, 60) = ap_uint<4>("0010", 2);
    mem_param_instr(59, 58) = 0;  // rsvd
    mem_param_instr(57, 42) = node_param.l_c;
    mem_param_instr(41, 39) = node_param.l_pad_t;
    mem_param_instr(38, 36) = node_param.l_pad_l;
    mem_param_instr(35, 33) = node_param.str_h;
    mem_param_instr(32, 30) = node_param.str_w;
    mem_param_instr(29, 24) = node_param.f_k;
    mem_param_instr(23, 18) = node_param.f_c;
    mem_param_instr(17, 15) = node_param.f_i;
    mem_param_instr(14, 12) = node_param.f_j;
    mem_param_instr(11, 6) = node_param.f_h;
    mem_param_instr(5, 0) = node_param.f_w;
    m_mem_param_instr.write(mem_param_instr);
    // instr_type: 0011
    mem_param_instr(63, 60) = ap_uint<4>("0011", 2);
    mem_param_instr(59, 50) = node_param.pq_c;
    mem_param_instr(49, 32) = node_param.opt_lh_lw;
    mem_param_instr(31, 0) = node_param.act_in_base_addr;
    m_mem_param_instr.write(mem_param_instr);
    // instr_type: 0100
    mem_param_instr(63, 60) = ap_uint<4>("0100", 2);
    mem_param_instr(59, 50) = node_param.wpb;
    mem_param_instr(49, 32) = node_param.opt_lih_liw;
    mem_param_instr(31, 0) = node_param.weight_base_addr;
    m_mem_param_instr.write(mem_param_instr);
    // instr_type: 0101
    mem_param_instr(63, 60) = ap_uint<4>("0101", 2);
    mem_param_instr(59, 32) = node_param.opt_wbuf_btt;
    mem_param_instr(31, 0) = node_param.res_base_addr;
    m_mem_param_instr.write(mem_param_instr);
    // instr_type: 0110
    mem_param_instr(63, 60) = ap_uint<4>("0110", 2);
    mem_param_instr(59, 32) = node_param.opt_lih_liw_pqc;
    mem_param_instr(31, 0) = node_param.bn_base_addr;
    m_mem_param_instr.write(mem_param_instr);
    // instr_type: 0111
    mem_param_instr(63, 60) = ap_uint<4>("0111", 2);
    mem_param_instr[59] = 0;  // rsvd
    mem_param_instr[58] = node_param.opt_eom;
    mem_param_instr(57, 50) = node_param.opt_pqfij;
    mem_param_instr(49, 32) = node_param.opt_pqfijc;
    mem_param_instr(31, 0) = node_param.act_out_base_addr;
    m_mem_param_instr.write(mem_param_instr);
    // #ifdef CORE_CONTROLLER_VERBOSE_COUT
    //     std::cout
    //         << "============================================================"
    //         << std::endl
    //         << "gen_mem_param_instr()" << std::endl
    //         << "============================================================"
    //         << std::endl;
    // #endif
}

void gen_mem_tile_instr(mem_param_t mem_param,
                        sub_instr_intf_t &m_mem_tile_instr) {
    sub_instr_t mem_tile_instr = 0;
    mem_tile_instr[63] = 1;  // itype = 1 for tile_instr
    mem_tile_instr(62, 61) = mem_param.d_type;
    mem_tile_instr[60] = mem_param.eol;
    mem_tile_instr[59] = mem_param.sel;
    mem_tile_instr[58] = mem_param.eos;
    mem_tile_instr(57, 48) = mem_param.tsk;
    mem_tile_instr(47, 38) = mem_param.tsc;
    mem_tile_instr(37, 29) = mem_param.tsh;
    mem_tile_instr(28, 20) = mem_param.tsw;
    mem_tile_instr(19, 14) = mem_param.sk;
    mem_tile_instr(13, 8) = mem_param.sc;
    mem_tile_instr(7, 4) = mem_param.sh;
    mem_tile_instr(3, 0) = mem_param.sw;
    m_mem_tile_instr.write(mem_tile_instr);
}

void gen_res_instr(ap_uint<32> node_num, node_param_intf_t &s_node_param,
                   hs_1b_intf_t &m_res_instr) {
node_loop:
    for (int i = 0; i < node_num; i++) {
        node_param_t node_param = s_node_param.read();
        m_res_instr.write(node_param.res_en);
    }
}

void gen_mm2s_instr(ap_uint<32> node_num, node_param_intf_t &s_node_param,
                    sub_instr_intf_t &m_mm2s_instr) {
    bool sel = 0;
node_loop:
    for (int i = 0; i < node_num; i++) {
        node_param_t node_param = s_node_param.read();
        gen_mem_param_instr(node_param, m_mm2s_instr);
        if (node_param.bn_en) {
            // bn
            mem_param_t bn_param;
            bn_param.d_type = ap_uint<2>("11", 2);
            gen_mem_tile_instr(bn_param, m_mm2s_instr);
        }
    tk_loop:
        for (ap_uint<10> tk = 0; tk < node_param.t_k; tk++)
        th_loop:
            for (ap_uint<9> th = 0; th < node_param.t_h; th++)
            tw_loop:
                for (ap_uint<9> tw = 0; tw < node_param.t_w; tw++)
                tc_loop:
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
                    act_sc_loop:
                        for (ap_uint<6> sc = 0; sc < s_c; sc++)
                        act_sh_loop:
                            for (ap_uint<6> sh = 0; sh < s_h; sh++)
                            act_sw_loop:
                                for (ap_uint<6> sw = 0; sw < s_w; sw++) {
#pragma HLS pipeline II = 1
                                    // act_in
                                    mem_param_t act_in_param;
                                    act_in_param.d_type = ap_uint<2>("00", 2);
                                    act_in_param.eos =
                                        ((node_param.use_w == 0) &&
                                         (sc == s_c - 1) && (sh == s_h - 1) &&
                                         (sw == s_w - 1));
                                    act_in_param.eol =
                                        ((tk == node_param.t_k - 1) &&
                                         (th == node_param.t_h - 1) &&
                                         (tw == node_param.t_w - 1) &&
                                         (tc == node_param.t_c - 1) &&
                                         act_in_param.eos);
                                    act_in_param.sel = sel;
                                    act_in_param.tsk = 0;
                                    act_in_param.tsc = tc * node_param.s_c + sc;
                                    act_in_param.tsh = th * node_param.s_h + sh;
                                    act_in_param.tsw = tw * node_param.s_w + sw;
                                    act_in_param.sk = 0;
                                    act_in_param.sc = sc;
                                    act_in_param.sh = sh;
                                    act_in_param.sw = sw;
                                    gen_mem_tile_instr(act_in_param,
                                                       m_mm2s_instr);
#ifdef CORE_CONTROLLER_VERBOSE_COUT
                                    if (act_in_param.tsc >= node_param.ts_c ||
                                        act_in_param.tsh >= node_param.ts_h ||
                                        act_in_param.tsw >= node_param.ts_w)
                                        std::cout
                                            << "tsc, tsh, tsw overflow."
                                            << std::endl
                                            << "tc, th, tw  " << tc << ", "
                                            << th << ", " << tw << std::endl
                                            << "sc, sh, sw " << sc << ", " << sh
                                            << ", " << sw << std::endl;
#endif
                                }
                        if (node_param.use_w) {
                        w_sk_loop:
                            for (ap_uint<6> sk = 0; sk < s_k; sk++)
                            w_sc_loop:
                                for (ap_uint<6> sc = 0; sc < s_c; sc++) {
#pragma HLS pipeline II = 1
                                    // weight
                                    mem_param_t weight_param;
                                    weight_param.d_type = ap_uint<2>("01", 2);
                                    weight_param.eos =
                                        ((sk == s_k - 1) && (sc == s_c - 1));
                                    weight_param.eol =
                                        ((tk == node_param.t_k - 1) &&
                                         (th == node_param.t_h - 1) &&
                                         (tw == node_param.t_w - 1) &&
                                         (tc == node_param.t_c - 1) &&
                                         weight_param.eos);
                                    weight_param.sel = sel;
                                    weight_param.tsk = tk * node_param.s_k + sk;
                                    weight_param.tsc = tc * node_param.s_c + sc;
                                    weight_param.tsh = 0;
                                    weight_param.tsw = 0;
                                    weight_param.sk = sk;
                                    weight_param.sc = sc;
                                    weight_param.sh = 0;
                                    weight_param.sw = 0;
                                    gen_mem_tile_instr(weight_param,
                                                       m_mm2s_instr);
#ifdef CORE_CONTROLLER_VERBOSE_COUT
                                    if (weight_param.tsk >= node_param.ts_k ||
                                        weight_param.tsc >= node_param.ts_c)
                                        std::cout
                                            << "tsk, tsc overflow." << std::endl
                                            << "tk, tc: " << tk << ", " << tc
                                            << std::endl
                                            << "sk, sc: " << sk << ", " << sc
                                            << std::endl;
#endif
                                }
                        }
                        sel = !sel;
                        if (node_param.res_en && tc == node_param.t_c - 1) {
                        res_sk_dpws_loop:
                            for (ap_uint<6> sk_dpws = 0; sk_dpws < s_k_dpws;
                                 sk_dpws++)
                            res_sh_loop:
                                for (ap_uint<6> sh = 0; sh < s_h; sh++)
                                res_sw_loop:
                                    for (ap_uint<6> sw = 0; sw < s_w; sw++) {
#pragma HLS pipeline II = 1
                                        // res
                                        mem_param_t res_param;
                                        res_param.d_type = ap_uint<2>("10", 2);
                                        res_param.eol = 0;
                                        res_param.sel = 0;
                                        res_param.eos = 0;
                                        res_param.tsk =
                                            tk * node_param.s_k_dpws + sk_dpws;
                                        res_param.tsc = 0;
                                        res_param.tsh =
                                            th * node_param.s_h + sh;
                                        res_param.tsw =
                                            tw * node_param.s_w + sw;
                                        res_param.sk = 0;
                                        res_param.sc = 0;
                                        res_param.sh = 0;
                                        res_param.sw = 0;
                                        gen_mem_tile_instr(res_param,
                                                           m_mm2s_instr);
#ifdef CORE_CONTROLLER_VERBOSE_COUT
                                        if (res_param.tsk >= node_param.ts_k ||
                                            res_param.tsh >= node_param.ts_h ||
                                            res_param.tsw >= node_param.ts_w)
                                            std::cout
                                                << "sk_dpws, tsh, tsw overflow."
                                                << std::endl
                                                << "tk, th, tw: " << tk << ", "
                                                << th << ", " << tw << std::endl
                                                << "sk_dpws, sh, sw: "
                                                << sk_dpws << ", " << sh << ", "
                                                << sw << std::endl;
#endif
                                    }
                        }
                    }
    }
}

void gen_s2mm_instr(ap_uint<32> node_num, node_param_intf_t &s_node_param,
                    sub_instr_intf_t &m_s2mm_instr) {
node_loop:
    for (int i = 0; i < node_num; i++) {
        node_param_t node_param = s_node_param.read();
        gen_mem_param_instr(node_param, m_s2mm_instr);
    tk_dpws_loop:
        for (ap_uint<10> tk_dpws = 0; tk_dpws < node_param.t_k_dpws; tk_dpws++)
        th_loop:
            for (ap_uint<9> th = 0; th < node_param.t_h; th++)
            tw_loop:
                for (ap_uint<9> tw = 0; tw < node_param.t_w; tw++) {
                    ap_uint<6> s_k_dpws = tk_dpws == node_param.t_k_dpws - 1
                                              ? node_param.s_k_dpws_last
                                              : node_param.s_k_dpws;
                    ap_uint<6> s_h = th == node_param.t_h - 1
                                         ? node_param.s_h_last
                                         : node_param.s_h;
                    ap_uint<6> s_w = tw == node_param.t_w - 1
                                         ? node_param.s_w_last
                                         : node_param.s_w;
#ifdef CORE_CONTROLLER_VERBOSE_COUT
                    std::cout << "current tk_dpws, th, tw: " << tk_dpws << ", "
                              << th << ", " << tw << std::endl
                              << " next ts_k_dpws, ts_h, ts_w: "
                              << (tk_dpws + 1) * node_param.s_k_dpws << ", "
                              << (th + 1) * node_param.s_h << ", "
                              << (tw + 1) * node_param.s_w << std::endl
                              << " max ts_k_dpws, ts_h, ts_w: "
                              << node_param.ts_k_dpws << ", " << node_param.ts_h
                              << ", " << node_param.ts_w << std::endl
                              << "this s_k_dpws, s_h, s_w: " << s_k_dpws << ", "
                              << s_h << ", " << s_w << std::endl;
#endif
                sk_dpws_loop:
                    for (ap_uint<6> sk_dpws = 0; sk_dpws < s_k_dpws; sk_dpws++)
                    sh_loop:
                        for (ap_uint<6> sh = 0; sh < s_h; sh++)
                        sw_loop:
                            for (ap_uint<6> sw = 0; sw < s_w; sw++) {
#pragma HLS pipeline II = 1
                                mem_param_t act_out_param;
                                // act_out
                                act_out_param.d_type = ap_uint<2>("00", 2);
                                act_out_param.eos =
                                    ((sk_dpws == s_k_dpws - 1) &&
                                     (sh == s_h - 1) && (sw == s_w - 1));
                                act_out_param.eol =
                                    ((tk_dpws == node_param.t_k_dpws - 1) &&
                                     (th == node_param.t_h - 1) &&
                                     (tw == node_param.t_w - 1) &&
                                     act_out_param.eos);
                                act_out_param.sel = 0;
                                act_out_param.tsk =
                                    tk_dpws * node_param.s_k_dpws + sk_dpws;
                                act_out_param.tsc = 0;
                                act_out_param.tsh = th * node_param.s_h + sh;
                                act_out_param.tsw = tw * node_param.s_w + sw;
                                act_out_param.sk = sk_dpws;
                                act_out_param.sc = 0;
                                act_out_param.sh = sh;
                                act_out_param.sw = sw;
                                gen_mem_tile_instr(act_out_param, m_s2mm_instr);
#ifdef CORE_CONTROLLER_VERBOSE_COUT
                                if (act_out_param.tsk >= node_param.ts_k_dpws ||
                                    act_out_param.tsh >= node_param.ts_h ||
                                    act_out_param.tsw >= node_param.ts_w)
                                    std::cout << "s2mm: tsk, tsh, tsw overflow."
                                              << std::endl
                                              << "tsk, tsh, tsw: "
                                              << act_out_param.tsk << ", "
                                              << act_out_param.tsh << ", "
                                              << act_out_param.tsw << std::endl
                                              << "tk_dpws, th, tw: " << tk_dpws
                                              << ", " << th << ", " << tw
                                              << std::endl
                                              << "sk_dpws, sh, sw: " << sk_dpws
                                              << ", " << sh << ", " << sw
                                              << std::endl;
#endif
                            }
                }
    }
}

void gen_pe_idx_instr(node_param_t node_param,
                      sub_instr_intf_t &m_pe_idx_instr) {
    sub_instr_t pe_idx_instr;
    bool pe_idle = false;
    ap_uint<6> sk = 0;
    ap_uint<6> sc = 0;
    ap_uint<6> sh = 0;
    ap_uint<6> sw = 0;
pe_idx_loop:
    for (ap_uint<6> pe_idx = 0; pe_idx < node_param.pe_num; pe_idx++) {
#pragma HLS pipeline II = 1
        // instr_type: 0111
        pe_idx_instr(63, 60) = ap_uint<4>("0111", 2);
        pe_idx_instr[59] = pe_idx == node_param.pe_num - 1;  // last conf
        pe_idx_instr(58, 27) = 0;                            // rsvd
        pe_idx_instr(26, 21) = pe_idx;
        pe_idx_instr[20] = pe_idle;
        pe_idx_instr(19, 14) = sk;
        pe_idx_instr(13, 8) = sc;
        pe_idx_instr(7, 4) = sh;
        pe_idx_instr(3, 0) = sw;
        m_pe_idx_instr.write(pe_idx_instr);
        if (!pe_idle) {
            sw = sw + 1;
            sh = sw == node_param.s_w ? (ap_uint<6>)(sh + 1) : sh;
            sc = sh == node_param.s_h ? (ap_uint<6>)(sc + 1) : sc;
            sk = sc == node_param.s_c ? (ap_uint<6>)(sk + 1) : sk;
            pe_idle = sk == node_param.s_k;
            sw = sw == node_param.s_w ? (ap_uint<6>)(0) : sw;
            sh = sh == node_param.s_h ? (ap_uint<6>)(0) : sh;
            sc = sc == node_param.s_c ? (ap_uint<6>)(0) : sc;
            sk = sk == node_param.s_k ? (ap_uint<6>)(0) : sk;
        }
    }
}

void gen_pe_conf_instr(node_param_t node_param,
                       sub_instr_intf_t &m_pe_conf_instr) {
    sub_instr_t pe_conf_instr;
    // instr_type: 0000
    pe_conf_instr(63, 60) = ap_uint<4>("0000", 2);
    pe_conf_instr(59, 53) = 0;  // rsvd
    pe_conf_instr[52] = node_param.opt_eom;
    pe_conf_instr(51, 49) = node_param.str_h;
    pe_conf_instr(48, 46) = node_param.str_w;
    pe_conf_instr(45, 36) = node_param.f_k;
    pe_conf_instr(35, 26) = node_param.f_c;
    pe_conf_instr(25, 22) = node_param.f_i;
    pe_conf_instr(21, 18) = node_param.f_j;
    pe_conf_instr(17, 9) = node_param.f_h;
    pe_conf_instr(8, 0) = node_param.f_w;
    m_pe_conf_instr.write(pe_conf_instr);
    // instr_type: 0001
    pe_conf_instr(63, 60) = ap_uint<4>("0001", 2);
    pe_conf_instr(59, 46) = 0;  // rsvd
    pe_conf_instr(45, 36) = node_param.q_k;
    pe_conf_instr(35, 26) = node_param.q_c;
    pe_conf_instr(25, 22) = node_param.q_i;
    pe_conf_instr(21, 18) = node_param.q_j;
    pe_conf_instr(17, 9) = node_param.q_h;
    pe_conf_instr(8, 0) = node_param.q_w;
    m_pe_conf_instr.write(pe_conf_instr);
    // instr_type: 0010
    pe_conf_instr(63, 60) = ap_uint<4>("0010", 2);
    pe_conf_instr(59, 46) = 0;  // rsvd
    pe_conf_instr(45, 36) = node_param.p_k;
    pe_conf_instr(35, 26) = node_param.p_c;
    pe_conf_instr(25, 22) = node_param.p_i;
    pe_conf_instr(21, 18) = node_param.p_j;
    pe_conf_instr(17, 9) = node_param.p_h;
    pe_conf_instr(8, 0) = node_param.p_w;
    m_pe_conf_instr.write(pe_conf_instr);
    // instr_type: 0011
    pe_conf_instr(63, 60) = ap_uint<4>("0011", 2);
    pe_conf_instr(55, 46) = 0;  // rsvd
    pe_conf_instr(45, 36) = node_param.pq_k_dpws;
    pe_conf_instr(35, 26) = node_param.pq_c;
    pe_conf_instr(25, 22) = node_param.pq_i;
    pe_conf_instr(21, 18) = node_param.pq_j;
    pe_conf_instr(17, 9) = node_param.pq_h;
    pe_conf_instr(8, 0) = node_param.pq_w;
    m_pe_conf_instr.write(pe_conf_instr);
    // instr_type: 0100
    pe_conf_instr(63, 60) = ap_uint<4>("0100", 2);
    pe_conf_instr(59, 46) = 0;  // rsvd
    pe_conf_instr(45, 36) = node_param.pqf_k_dpws;
    pe_conf_instr(35, 26) = node_param.pqf_c;
    pe_conf_instr(25, 22) = node_param.pqf_i;
    pe_conf_instr(21, 18) = node_param.pqf_j;
    pe_conf_instr(17, 9) = node_param.pqf_h;
    pe_conf_instr(8, 0) = node_param.pqf_w;
    m_pe_conf_instr.write(pe_conf_instr);
    // instr_type: 0101
    pe_conf_instr(63, 60) = ap_uint<4>("0101", 2);
    pe_conf_instr(59, 56) = 0;  // rsvd
    pe_conf_instr(55, 52) = node_param.l_type;
    pe_conf_instr(51, 36) = node_param.l_k_dpws;
    pe_conf_instr(35, 18) = 0;  // rsvd
    pe_conf_instr(17, 9) = node_param.l_h;
    pe_conf_instr(8, 0) = node_param.l_w;
    m_pe_conf_instr.write(pe_conf_instr);
}

void gen_pe_updt_instr(ap_uint<32> node_num, node_param_intf_t &s_node_param,
                       sub_instr_intf_t &m_pe_updt_instr) {
node_loop:
    for (int i = 0; i < node_num; i++) {
        node_param_t node_param = s_node_param.read();
        gen_pe_idx_instr(node_param, m_pe_updt_instr);
    }
}

void gen_pe_exec_instr(ap_uint<32> node_num, node_param_intf_t &s_node_param,
                       sub_instr_intf_t &m_pe_exec_instr) {
node_loop:
    for (int i = 0; i < node_num; i++) {
        node_param_t node_param = s_node_param.read();
        gen_pe_idx_instr(node_param, m_pe_exec_instr);
        gen_pe_conf_instr(node_param, m_pe_exec_instr);
    tk_loop:
        for (ap_uint<10> tk = 0; tk < node_param.t_k; tk++)
        th_loop:
            for (ap_uint<9> th = 0; th < node_param.t_h; th++)
            tw_loop:
                for (ap_uint<9> tw = 0; tw < node_param.t_w; tw++)
                tc_loop:
                    for (ap_uint<10> tc = 0; tc < node_param.t_c; tc++) {
#pragma HLS pipeline II = 1
                        ap_uint<6> sk =
                            (tk + 1) * node_param.s_k <= node_param.ts_k
                                ? node_param.s_k
                                : (ap_uint<6>)((tk + 1) * node_param.s_k -
                                               node_param.ts_k);
                        ap_uint<6> sc =
                            (tc + 1) * node_param.s_c <= node_param.ts_c
                                ? node_param.s_c
                                : (ap_uint<6>)((tc + 1) * node_param.s_c -
                                               node_param.ts_c);
                        ap_uint<6> sh =
                            (th + 1) * node_param.s_h <= node_param.ts_h
                                ? node_param.s_h
                                : (ap_uint<6>)((th + 1) * node_param.s_h -
                                               node_param.ts_h);
                        ap_uint<6> sw =
                            (tw + 1) * node_param.s_w <= node_param.ts_w
                                ? node_param.s_w
                                : (ap_uint<6>)((tw + 1) * node_param.s_w -
                                               node_param.ts_w);
                        sub_instr_t pe_exec_instr;
                        pe_exec_instr(63, 61) = ap_uint<3>("100", 2);
                        pe_exec_instr[60] = (  // eol
                            tk == node_param.t_k - 1 &&
                            th == node_param.t_h - 1 &&
                            tw == node_param.t_w - 1 &&
                            tc == node_param.t_c - 1);
                        pe_exec_instr[59] = tc == 0;
                        pe_exec_instr[58] =
                            node_param.is_dpws ? 1 : (tc == node_param.t_c - 1);
                        pe_exec_instr(57, 20) = 0;  // rsvd
                        pe_exec_instr(19, 14) = sk;
                        pe_exec_instr(13, 8) = sc;
                        pe_exec_instr(7, 4) = sh;
                        pe_exec_instr(3, 0) = sw;
                        m_pe_exec_instr.write(pe_exec_instr);
                        // std::cout << "tk/t_k: " << tk << "/" <<
                        // node_param.t_k
                        //           << " th/t_h: " << th << "/" <<
                        //           node_param.t_h
                        //           << " tw/t_w: " << tw << "/" <<
                        //           node_param.t_w
                        //           << " tc/t_c: " << tc << "/" <<
                        //           node_param.t_c
                        //           << " eol: " << pe_exec_instr[60] <<
                        //           std::endl;
                    }
    }
}

void gen_pe_wb_instr(ap_uint<32> node_num, node_param_intf_t &s_node_param,
                     sub_instr_intf_t &m_pe_wb_instr) {
node_loop:
    for (int i = 0; i < node_num; i++) {
        node_param_t node_param = s_node_param.read();
        gen_pe_idx_instr(node_param, m_pe_wb_instr);
        gen_pe_conf_instr(node_param, m_pe_wb_instr);
    tk_dpws_loop:
        for (ap_uint<10> tk_dpws = 0; tk_dpws < node_param.t_k_dpws; tk_dpws++)
        th_loop:
            for (ap_uint<9> th = 0; th < node_param.t_h; th++)
            tw_loop:
                for (ap_uint<9> tw = 0; tw < node_param.t_w; tw++) {
                    ap_uint<6> s_k_dpws = tk_dpws == node_param.t_k_dpws - 1
                                              ? node_param.s_k_dpws_last
                                              : node_param.s_k_dpws;
                    ap_uint<6> s_h = th == node_param.t_h - 1
                                         ? node_param.s_h_last
                                         : node_param.s_h;
                    ap_uint<6> s_w = tw == node_param.t_w - 1
                                         ? node_param.s_w_last
                                         : node_param.s_w;
                sk_dpws_loop:
                    for (ap_uint<6> sk_dpws = 0; sk_dpws < s_k_dpws; sk_dpws++)
                    sh_loop:
                        for (ap_uint<6> sh = 0; sh < s_h; sh++)
                        sw_loop:
                            for (ap_uint<6> sw = 0; sw < s_w; sw++) {
#pragma HLS pipeline II = 1
                                sub_instr_t pe_wb_instr;
                                pe_wb_instr(63, 60) = ap_uint<4>("1000", 2);
                                pe_wb_instr[58] = (  // eos
                                    sk_dpws == s_k_dpws - 1 && sh == s_h - 1 &&
                                    sw == s_w - 1);
                                pe_wb_instr[59] = (  // eol
                                    tk_dpws == node_param.t_k_dpws - 1 &&
                                    th == node_param.t_h - 1 &&
                                    tw == node_param.t_w - 1 &&
                                    pe_wb_instr[58]);
                                pe_wb_instr(57, 48) =
                                    tk_dpws * node_param.s_k_dpws + sk_dpws;
                                pe_wb_instr(47, 38) = 0;  // rsvd
                                pe_wb_instr(37, 29) = th * node_param.s_h + sh;
                                pe_wb_instr(28, 20) = tw * node_param.s_w + sw;
                                pe_wb_instr(19, 14) = sk_dpws;
                                pe_wb_instr(13, 8) = 0;  // rsvd
                                pe_wb_instr(7, 4) = sh;
                                pe_wb_instr(3, 0) = sw;
                                m_pe_wb_instr.write(pe_wb_instr);
                            }
                }
    }
}
void gen_lc_instr(ap_uint<32> node_num, node_param_intf_t &s_node_param,
                  sub_instr_intf_t &m_lc_instr) {
node_loop:
    for (int i = 0; i < node_num; i++) {
        node_param_t node_param = s_node_param.read();
        sub_instr_t lc_param_instr;
        // 0000
        lc_param_instr(63, 60) = ap_uint<4>("0000", 2);
        lc_param_instr(59, 56) = 0;  // rsvd
        lc_param_instr(55, 47) = node_param.pq_h;
        lc_param_instr(46, 38) = node_param.pq_w;
        lc_param_instr(37, 28) = node_param.pqf_k_dpws;
        lc_param_instr(27, 18) = 0;  // rsvd
        lc_param_instr(17, 9) = node_param.pqf_h;
        lc_param_instr(8, 0) = node_param.pqf_w;
        m_lc_instr.write(lc_param_instr);
        // 0001
        lc_param_instr(63, 60) = ap_uint<4>("0001", 2);
        lc_param_instr(59, 44) = 0;  // rsvd
        lc_param_instr(43, 28) = node_param.l_k_dpws;
        lc_param_instr(27, 18) = 0;  // rsvd
        lc_param_instr(17, 9) = node_param.l_h;
        lc_param_instr(8, 0) = node_param.l_w;
        m_lc_instr.write(lc_param_instr);
        // 0010
        lc_param_instr(63, 60) = ap_uint<4>("0010", 2);
        lc_param_instr(59, 46) = 0;  // rsvd
        lc_param_instr(47, 32) = node_param.lc_tile_num;
        lc_param_instr(29, 24) = node_param.f_k;
        lc_param_instr(23, 12) = 0;  // rsvd
        lc_param_instr(11, 6) = node_param.f_h;
        lc_param_instr(5, 0) = node_param.f_w;
        m_lc_instr.write(lc_param_instr);
    tk_dpws_loop:
        for (ap_uint<10> tk_dpws = 0; tk_dpws < node_param.t_k_dpws; tk_dpws++)
        th_loop:
            for (ap_uint<9> th = 0; th < node_param.t_h; th++)
            tw_loop:
                for (ap_uint<9> tw = 0; tw < node_param.t_w; tw++) {
                    ap_uint<6> s_k_dpws = tk_dpws == node_param.t_k_dpws - 1
                                              ? node_param.s_k_dpws_last
                                              : node_param.s_k_dpws;
                    ap_uint<6> s_h = th == node_param.t_h - 1
                                         ? node_param.s_h_last
                                         : node_param.s_h;
                    ap_uint<6> s_w = tw == node_param.t_w - 1
                                         ? node_param.s_w_last
                                         : node_param.s_w;
                sk_dpws_loop:
                    for (ap_uint<6> sk_dpws = 0; sk_dpws < s_k_dpws; sk_dpws++)
                    sh_loop:
                        for (ap_uint<6> sh = 0; sh < s_h; sh++)
                        sw_loop:
                            for (ap_uint<6> sw = 0; sw < s_w; sw++) {
#pragma HLS pipeline II = 1
                                mem_param_t lc_param;
                                // act_out
                                lc_param.d_type = ap_uint<2>("00", 2);
                                lc_param.eos = 0;
                                lc_param.eol = 0;
                                lc_param.sel = 0;
                                lc_param.tsk =
                                    tk_dpws * node_param.s_k_dpws + sk_dpws;
                                lc_param.tsc = 0;
                                lc_param.tsh = th * node_param.s_h + sh;
                                lc_param.tsw = tw * node_param.s_w + sw;
                                lc_param.sk = 0;
                                lc_param.sc = 0;
                                lc_param.sh = 0;
                                lc_param.sw = 0;
                                gen_mem_tile_instr(lc_param, m_lc_instr);
#ifdef CORE_CONTROLLER_VERBOSE_COUT
                                if (lc_param.tsk >= node_param.ts_k_dpws ||
                                    lc_param.tsh >= node_param.ts_h ||
                                    lc_param.tsw >= node_param.ts_w)
                                    std::cout << "lc: tsk, tsh, tsw overflow."
                                              << std::endl
                                              << "tk_dpws, th, tw: " << tk_dpws
                                              << ", " << th << ", " << tw
                                              << std::endl
                                              << "sk_dpws, sh, sw: " << sk_dpws
                                              << ", " << sh << ", " << sw
                                              << std::endl;
#endif
                            }
                }
    }
}

void node_sync(ap_uint<32> node_num, hs_1b_intf_t &s_done_instr) {
node_loop:
    for (int i = 0; i < node_num; i++) {
        ap_uint<1> hs;
    done_hs_loop:
        do {
            hs = s_done_instr.read();
        } while (hs != 1);
#ifdef CORE_CONTROLLER_VERBOSE_COUT
        std::cout << "node_sync: " << hs << std::endl;
#endif
    }
}

void core_controller(ap_uint<32> node_num, instr_intf_t &s_core_instr,
                     hs_1b_intf_t &s_done_instr, hs_1b_intf_t &m_res_instr,
                     sub_instr_intf_t &m_mm2s_instr,
                     sub_instr_intf_t &m_s2mm_instr,
                     sub_instr_intf_t &m_pe_updt_instr,
                     sub_instr_intf_t &m_pe_exec_instr,
                     sub_instr_intf_t &m_pe_wb_instr,
                     sub_instr_intf_t &m_lc_instr) {
#pragma HLS interface ap_none port = node_num name = "instr_num"
#pragma HLS dataflow
    node_param_fifo_t node_param_res, node_param_mm2s, node_param_s2mm,
        node_param_pe_updt, node_param_pe_exec, node_param_pe_wb, node_param_lc;
    decode_core_instr(node_num, s_core_instr, node_param_res, node_param_mm2s,
                      node_param_s2mm, node_param_pe_updt, node_param_pe_exec,
                      node_param_pe_wb, node_param_lc);
    gen_res_instr(node_num, node_param_res, m_res_instr);
    gen_mm2s_instr(node_num, node_param_mm2s, m_mm2s_instr);
    gen_s2mm_instr(node_num, node_param_s2mm, m_s2mm_instr);
    gen_pe_updt_instr(node_num, node_param_pe_updt, m_pe_updt_instr);
    gen_pe_exec_instr(node_num, node_param_pe_exec, m_pe_exec_instr);
    gen_pe_wb_instr(node_num, node_param_pe_wb, m_pe_wb_instr);
    gen_lc_instr(node_num, node_param_lc, m_lc_instr);
    node_sync(node_num, s_done_instr);
}
