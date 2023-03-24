#ifndef __CORE_CONTROLLER_H__
#define __CORE_CONTROLLER_H__

#include "common.h"

void core_controller(ap_uint<32> instr_num, instr_intf_t &s_core_instr,
                     hs_1b_intf_t &s_done_instr, hs_1b_intf_t &m_res_instr,
                     sub_instr_intf_t &m_mm2s_instr,
                     sub_instr_intf_t &m_s2mm_instr,
                     sub_instr_intf_t &m_pe_updt_instr,
                     sub_instr_intf_t &m_pe_exec_instr,
                     sub_instr_intf_t &m_pe_wb_instr,
                     sub_instr_intf_t &m_lc_instr);

#endif