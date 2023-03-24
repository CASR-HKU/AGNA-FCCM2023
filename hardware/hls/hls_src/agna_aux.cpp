#include "agna_aux.h"

void agna_aux(instr_t *mem, mem_addr_t instr_base_addr, uint32_t node_num,
              instr_intf_t &core_instr) {
#pragma HLS interface mode = m_axi port = mem depth = 64 offset = \
    off latency = 64 bundle = aux max_read_burst_length =         \
        7 num_read_outstanding = 1
#pragma HLS interface mode = ap_none port = instr_base_addr
#pragma HLS interface mode = ap_none port = node_num name = instr_num
#pragma HLS interface mode = ap_fifo port = core_instr
    uint32_t addr = instr_base_addr >> DBUS_BLEN_WIDTH;
    for (uint32_t i = 0; i < node_num * INSTR_PER_NODE; i++) {
        core_instr.write(mem[addr + i]);
    }
}
