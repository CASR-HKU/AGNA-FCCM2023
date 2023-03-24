#ifndef __INSTR_TB_H__
#define __INSTR_TB_H__

#define TB_NODE_NUM 2
#define TB_PE_NUM 12

void infer_param(node_param_t &node_param) {
    node_param.pqf_k = node_param.p_k * node_param.q_k * node_param.f_k;
    node_param.pqf_c = node_param.p_c * node_param.q_c * node_param.f_c;
    node_param.pqf_i = node_param.p_i * node_param.q_i * node_param.f_i;
    node_param.pqf_j = node_param.p_j * node_param.q_j * node_param.f_j;
    node_param.pqf_h = node_param.p_h * node_param.q_h * node_param.f_h;
    node_param.pqf_w = node_param.p_w * node_param.q_w * node_param.f_w;
    node_param.pq_k = node_param.p_k * node_param.q_k;
    node_param.pq_c = node_param.p_c * node_param.q_c;
    node_param.pq_i = node_param.p_i * node_param.q_i;
    node_param.pq_j = node_param.p_j * node_param.q_j;
    node_param.pq_h = node_param.p_h * node_param.q_h;
    node_param.pq_w = node_param.p_w * node_param.q_w;
    node_param.ts_k =
        (node_param.l_k + node_param.pqf_k - 1) / node_param.pqf_k;
    node_param.ts_c =
        (node_param.l_c + node_param.pqf_c - 1) / node_param.pqf_c;
    node_param.ts_h =
        (node_param.l_h + node_param.pqf_h - 1) / node_param.pqf_h;
    node_param.ts_w =
        (node_param.l_w + node_param.pqf_w - 1) / node_param.pqf_w;

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
    node_param.l_k_dpws = node_param.is_dpws ? node_param.l_c : node_param.l_k;
    node_param.p_k_dpws = node_param.is_dpws ? node_param.p_c : node_param.p_k;
    node_param.q_k_dpws = node_param.is_dpws ? node_param.q_c : node_param.q_k;
    node_param.f_k_dpws = node_param.is_dpws ? node_param.f_c : node_param.f_k;
    node_param.pqf_k_dpws =
        node_param.is_dpws ? node_param.pqf_c : node_param.pqf_k;
    node_param.pq_k_dpws =
        node_param.is_dpws ? node_param.pq_c : node_param.pq_k;
    node_param.ts_k_dpws =
        node_param.is_dpws ? node_param.ts_c : node_param.ts_k;
    node_param.t_k_dpws = node_param.is_dpws ? node_param.t_c : node_param.t_k;
    node_param.s_k_dpws = node_param.is_dpws ? node_param.s_c : node_param.s_k;
    node_param.s_k_dpws_last =
        node_param.is_dpws ? node_param.s_c_last : node_param.s_k_last;
    node_param.lc_tile_num =
        node_param.ts_k_dpws * node_param.ts_h * node_param.ts_w;
    node_param.pqf_ih =
        (node_param.pqf_h - 1) * node_param.str_h + node_param.pqf_i;
    node_param.pqf_iw =
        (node_param.pqf_w - 1) * node_param.str_w + node_param.pqf_j;

    node_param.wpb = ((node_param.pq_k * node_param.pq_c * node_param.pq_i *
                           node_param.pq_j +
                       3) /
                      4);
    node_param.pe_num = TB_PE_NUM;
    node_param.opt_eom = 0;
    node_param.opt_pqfij = node_param.pqf_i * node_param.pqf_j;
    node_param.opt_pqfijc =
        node_param.pqf_i * node_param.pqf_j * node_param.pqf_c;
    node_param.opt_lih_liw_pqc =
        node_param.l_ih * node_param.l_iw * node_param.pq_c;
    node_param.opt_wbuf_btt = node_param.wpb * 4 * node_param.f_k *
                              node_param.f_c * node_param.f_i * node_param.f_j;
    node_param.opt_lih_liw = node_param.l_ih * node_param.l_iw;
    node_param.opt_lh_lw = node_param.l_h * node_param.l_w;
};

node_param_t get_node_param_test_conv1() {
    node_param_t node_param;
    node_param.bn_en = 0;
    node_param.res_en = 1;
    node_param.l_type = 0;
    node_param.str_h = 1;
    node_param.str_w = 1;
    node_param.l_pad_t = 0;
    node_param.l_pad_l = 0;
    node_param.l_ih = 28;
    node_param.l_iw = 28;
    node_param.l_k = 32;
    node_param.l_c = 16;
    node_param.l_i = 1;
    node_param.l_j = 1;
    node_param.l_h = 28;
    node_param.l_w = 28;
    node_param.t_k = 2;
    node_param.t_c = 2;
    node_param.t_h = 1;
    node_param.t_w = 1;
    node_param.s_k = 2;
    node_param.s_c = 2;
    node_param.s_h = 2;
    node_param.s_w = 1;
    node_param.p_k = 2;
    node_param.p_c = 1;
    node_param.p_i = 1;
    node_param.p_j = 1;
    node_param.p_h = 2;
    node_param.p_w = 2;
    node_param.q_k = 4;
    node_param.q_c = 1;
    node_param.q_i = 1;
    node_param.q_j = 1;
    node_param.q_h = 2;
    node_param.q_w = 2;
    node_param.f_k = 1;
    node_param.f_c = 4;
    node_param.f_i = 1;
    node_param.f_j = 1;
    node_param.f_h = 4;
    node_param.f_w = 7;
    node_param.act_out_base_addr = 0x1000;
    node_param.weight_base_addr = 0x2000;
    node_param.act_in_base_addr = 0x3000;
    node_param.bn_base_addr = 0x4000;
    node_param.res_base_addr = 0;
    infer_param(node_param);
    return node_param;
};

node_param_t get_node_param_test_conv2() {
    node_param_t node_param;
    node_param.bn_en = 0;
    node_param.res_en = 0;
    node_param.l_type = 0;
    node_param.str_h = 1;
    node_param.str_w = 1;
    node_param.l_pad_t = 0;
    node_param.l_pad_l = 0;
    node_param.l_ih = 28;
    node_param.l_iw = 28;
    node_param.l_k = 16;
    node_param.l_c = 8;
    node_param.l_i = 1;
    node_param.l_j = 1;
    node_param.l_h = 28;
    node_param.l_w = 28;
    node_param.t_k = 1;
    node_param.t_c = 1;
    node_param.t_h = 1;
    node_param.t_w = 1;
    node_param.s_k = 2;
    node_param.s_c = 2;
    node_param.s_h = 2;
    node_param.s_w = 1;
    node_param.p_k = 2;
    node_param.p_c = 1;
    node_param.p_i = 1;
    node_param.p_j = 1;
    node_param.p_h = 2;
    node_param.p_w = 2;
    node_param.q_k = 4;
    node_param.q_c = 1;
    node_param.q_i = 1;
    node_param.q_j = 1;
    node_param.q_h = 2;
    node_param.q_w = 2;
    node_param.f_k = 1;
    node_param.f_c = 4;
    node_param.f_i = 1;
    node_param.f_j = 1;
    node_param.f_h = 4;
    node_param.f_w = 7;
    node_param.act_out_base_addr = 0x1000;
    node_param.weight_base_addr = 0x2000;
    node_param.act_in_base_addr = 0x3000;
    node_param.bn_base_addr = 0x4000;
    node_param.res_base_addr = 0;
    infer_param(node_param);
    return node_param;
};

void build_single_instr(instr_t *instr_arr, node_param_t node_param) {
    instr_t instr;
    // 000
    instr = 0;
    instr(127, 125) = ap_uint<3>("000", 2);
    instr[121] = node_param.res_en;
    instr[120] = node_param.bn_en;
    instr(119, 118) = node_param.l_type;
    instr(117, 115) = node_param.str_h;
    instr(114, 112) = node_param.str_w;
    instr(111, 109) = node_param.l_pad_t;
    instr(108, 106) = node_param.l_pad_l;
    instr(105, 97) = node_param.l_ih;
    instr(96, 88) = node_param.l_iw;
    instr(87, 72) = node_param.l_k;
    instr(71, 56) = node_param.l_c;
    instr(55, 52) = node_param.l_i;
    instr(51, 48) = node_param.l_j;
    instr(47, 39) = node_param.l_h;
    instr(38, 30) = node_param.l_w;
    instr_arr[0] = instr;
    // 001
    instr = 0;
    instr(127, 125) = ap_uint<3>("001", 2);
    instr(121, 112) = node_param.p_k;
    instr(111, 102) = node_param.p_c;
    instr(101, 98) = node_param.p_i;
    instr(97, 94) = node_param.p_j;
    instr(93, 85) = node_param.p_h;
    instr(84, 76) = node_param.p_w;
    instr(75, 66) = node_param.q_k;
    instr(65, 56) = node_param.q_c;
    instr(55, 52) = node_param.q_i;
    instr(51, 48) = node_param.q_j;
    instr(47, 39) = node_param.q_h;
    instr(38, 30) = node_param.q_w;
    instr(29, 24) = node_param.f_k;
    instr(23, 18) = node_param.f_c;
    instr(17, 15) = node_param.f_i;
    instr(14, 12) = node_param.f_j;
    instr(11, 6) = node_param.f_h;
    instr(5, 0) = node_param.f_w;
    instr_arr[1] = instr;
    // 010
    instr = 0;
    instr(127, 125) = ap_uint<3>("010", 2);
    instr(121, 112) = node_param.pqf_k;
    instr(111, 102) = node_param.pqf_c;
    instr(101, 98) = node_param.pqf_i;
    instr(97, 94) = node_param.pqf_j;
    instr(93, 85) = node_param.pqf_h;
    instr(84, 76) = node_param.pqf_w;
    instr(75, 66) = node_param.pq_k;
    instr(65, 56) = node_param.pq_c;
    instr(55, 52) = node_param.pq_i;
    instr(51, 48) = node_param.pq_j;
    instr(47, 39) = node_param.pq_h;
    instr(38, 30) = node_param.pq_w;
    instr_arr[2] = instr;
    // 011
    instr = 0;
    instr(127, 125) = ap_uint<3>("011", 2);
    instr(121, 112) = node_param.ts_k;
    instr(111, 102) = node_param.ts_c;
    instr(93, 85) = node_param.ts_h;
    instr(84, 76) = node_param.ts_w;
    instr(75, 66) = node_param.t_k;
    instr(65, 56) = node_param.t_c;
    instr(47, 39) = node_param.t_h;
    instr(38, 30) = node_param.t_w;
    instr(29, 24) = node_param.s_k;
    instr(23, 18) = node_param.s_c;
    instr(11, 6) = node_param.s_h;
    instr(5, 0) = node_param.s_w;
    instr_arr[3] = instr;
    // 100
    instr = 0;
    instr(127, 125) = ap_uint<3>("100", 2);
    instr(95, 64) = node_param.act_out_base_addr;
    instr(63, 32) = node_param.weight_base_addr;
    instr(31, 0) = node_param.act_in_base_addr;
    instr_arr[4] = instr;
    // 101
    instr = 0;
    instr(127, 125) = ap_uint<3>("101", 2);
    instr(84, 75) = node_param.wpb;
    instr(70, 64) = node_param.pe_num;
    instr(63, 32) = node_param.bn_base_addr;
    instr(31, 0) = node_param.res_base_addr;
    instr_arr[5] = instr;
    // 110
    instr = 0;
    instr(127, 125) = ap_uint<3>("110", 2);
    instr[118] = node_param.opt_eom;
    instr(117, 110) = node_param.opt_pqfij;
    instr(109, 92) = node_param.opt_pqfijc;
    instr(91, 64) = node_param.opt_lih_liw_pqc;
    instr(63, 36) = node_param.opt_wbuf_btt;
    instr(35, 18) = node_param.opt_lih_liw;
    instr(17, 0) = node_param.opt_lh_lw;
    instr_arr[6] = instr;
};

void build_node_param_arr(node_param_t *node_param_arr) {
    node_param_arr[0] = get_node_param_test_conv1();
    node_param_arr[1] = get_node_param_test_conv2();
    node_param_arr[1].opt_eom = 1;
};

void build_core_instr(node_param_t *node_param_arr, instr_t *instr_arr) {
    build_node_param_arr(node_param_arr);
    for (int i = 0; i < TB_NODE_NUM; i++) {
        build_single_instr(instr_arr + i * INSTR_PER_NODE, node_param_arr[i]);
    }
};

#endif
