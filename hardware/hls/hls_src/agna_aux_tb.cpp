#include "agna_aux.h"
#include "instr_tb.h"

int main(int argc, char *argv[]) {
    instr_t instr_mem[INSTR_PER_NODE] = {0};
    uint32_t instr_base_addr = 0;
    uint32_t node_num = 1;
    instr_intf_t core_instr_intf;

    build_single_instr(instr_mem, get_node_param_test_conv1());

    agna_aux(instr_mem, instr_base_addr, node_num, core_instr_intf);

    std::cout << "core_instr_intf:" << std::endl;
    for (uint32_t i = 0; i < node_num * INSTR_PER_NODE; i++) {
        instr_t instr_tmp = core_instr_intf.read();
        std::cout << std::hex
                  << "data: " << std::setw(instr_tmp.length() / 4 + 2)
                  << instr_tmp << std::endl;
    }
    assert(core_instr_intf.empty());
    return 0;
}
