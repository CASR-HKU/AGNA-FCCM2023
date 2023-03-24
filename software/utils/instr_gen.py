import json

import numpy as np


def replace_bit(num, hi, lo=None, v=0) -> np.uint64:
    v = np.uint64(v)
    lo = hi if lo is None else lo
    #     print(f"    {hi:3d}:{lo:3d} <- {v:08x}")
    assert 63 >= hi >= lo >= 0, f"63 >= {hi} >= {lo} >= 0"
    v_max = np.uint64(2**(hi - lo + 1) - 1)
    assert v <= v_max, f"overflow: {v} > {v_max}"
    num &= ~(v_max << np.uint64(lo))
    num |= (v << np.uint64(lo))
    return num


def replace_instr(instr, hi, lo=None, v=0) -> np.ndarray:
    v = np.uint64(v)
    lo = hi if lo is None else lo
    assert 127 >= hi >= lo >= 0, f"127 >= {hi} >= {lo} >= 0"
    assert hi - lo <= 63, f"{hi}-{lo}={hi-lo}>64"
    if hi <= 63:
        instr[0] = replace_bit(instr[0], hi, lo, v)
    elif lo >= 64:
        instr[1] = replace_bit(instr[1], hi - 64, lo - 64, v)
    else:
        v_lo_mask = np.uint64(2**(64 - lo) - 1)
        v_lo = v & v_lo_mask
        instr[0] = replace_bit(instr[0], 63, lo, v_lo)
        v_hi = v >> np.uint64(64 - lo)
        instr[1] = replace_bit(instr[1], hi - 64, 0, v_hi)
    # print(f"{instr[1]:016x}{instr[0]:016x} {hi:3d}:{lo:3d} <- {v:x}")
    return instr


def verify_replace(instr_num):
    instr_arr = np.zeros((instr_num, 2), dtype=np.uint64)
    for instr in instr_arr:
        for _ in range(3):
            hi = np.random.randint(0, 128)
            lo = np.random.randint(max(hi - 63, 0), hi + 1)
            v = np.random.randint(0, 2**min(hi - lo + 1, 32))
            instr = replace_instr(instr, hi, lo, v)


class InstrGen:
    def __init__(self, model_spec: dict) -> None:
        self.nodes = {}
        self.model_spec = model_spec
        self.instr = {
            'shape': (len(self.model_spec['nodes']) * 7, 2),
            'array': None
        }

    def build(self) -> np.ndarray:
        assert self.instr['array'] is not None
        for idx in range(len(self.model_spec['nodes'])):
            node = self.model_spec['nodes'][idx]
            opt_eom = idx == len(self.model_spec['nodes']) - 1
            print(f"opt_eom: {opt_eom}")
            pe_num = self.model_spec['pe_num']
            print(f"pe_num: {pe_num}")
            self.instr['array'][idx * 7:idx * 7 + 7] = self.build_single_node(
                node, opt_eom, pe_num)
        return self.instr['array']

    def verify_single_node(self, node: dict, verbose=False) -> None:
        assert node['schedule'] is not None
        loop_bounds = np.array(node['loop_bounds'])
        assert (loop_bounds >= 1).all()
        schedule = np.array(list(node['schedule'].values()))
        assert (schedule >= 1).all()
        assert (np.prod(schedule, axis=0) >= loop_bounds).all()
        assert all(v >= 1 for v in node['strides'])
        # infer other params
        node['padding_t'] = max(0, node['paddings'][0])
        node['padding_l'] = max(0, node['paddings'][2])
        node['l_ih'] = ((node['loop_bounds'][4] - 1) * node['strides'][0] +
                        node['loop_bounds'][2] - node['paddings'][0] -
                        node['paddings'][1])
        node['l_iw'] = ((node['loop_bounds'][5] - 1) * node['strides'][1] +
                        node['loop_bounds'][3] - node['paddings'][2] -
                        node['paddings'][3])
        node['schd_pq'] = [
            node['schedule']['P'][i] * node['schedule']['Q'][i]
            for i in range(6)
        ]
        node['schd_pqf'] = [
            node['schd_pq'][i] * node['schedule']['F'][i] for i in range(6)
        ]
        node['schd_ts'] = [
            np.ceil(node['loop_bounds'][i] / node['schd_pqf'][i]).astype(int)
            for i in range(6)
        ]
        node['wpb'] = np.ceil(np.prod(node['schd_pq'][:4]) / 4).astype(int)
        node['opt_pqfij'] = node['schd_pqf'][2] * node['schd_pqf'][3]
        node['opt_pqfijc'] = node['opt_pqfij'] * node['schd_pqf'][1]
        node['opt_lih_liw'] = node['l_ih'] * node['l_iw']
        node['opt_lih_liw_pqc'] = node['opt_lih_liw'] * node['schd_pq'][1]
        node['opt_wbuf_btt'] = node['wpb'] * 4 * np.prod(
            node['schedule']['F'][:4]).astype(int)
        node['opt_lh_lw'] = node['loop_bounds'][4] * node['loop_bounds'][5]
        lk_dpws = node['loop_bounds'][0] if node['type'] == 0 else node[
            'loop_bounds'][1]
        act_out_shape = (lk_dpws, node['loop_bounds'][4],
                         node['loop_bounds'][5])
        weight_shape = tuple(node['loop_bounds'][:4])
        act_in_shape = (node['loop_bounds'][1], node['l_ih'], node['l_iw'])
        bn_shape = (lk_dpws, 2)
        res_shape = act_out_shape
        self.nodes[node['name']] = {
            'act_out': {
                'shape': act_out_shape,
                'array': None
            },
            'weight': {
                'shape': weight_shape,
                'array': None
            },
            'act_in': {
                'shape': act_in_shape,
                'array': None
            },
            'bn': {
                'shape': bn_shape,
                'array': None
            },
            'res': {
                'shape': res_shape,
                'array': None
            },
        }
        if verbose:
            print(f"======{node['name']}")
            print(f"loop_bounds: {node['loop_bounds']}")
            print(f"l_i: {node['l_ih']}, {node['l_iw']}")
            print(f"strides: {node['strides']}")
            print(
                f"paddings: {node['paddings']} -> {node['padding_t']}, {node['padding_l']}"
            )
            print(f"schd_t: {node['schedule']['T']}")
            print(f"schd_s: {node['schedule']['S']}")
            print(f"schd_p: {node['schedule']['P']}")
            print(f"schd_q: {node['schedule']['Q']}")
            print(f"schd_f: {node['schedule']['F']}")
            print(f"schd_ts: {node['schd_ts']}")
            print(f"schd_pqf: {node['schd_pqf']}")
            print(f"schd_pq: {node['schd_pq']}")
            print(f"wpb: {node['wpb']}")
            print(f"opt_pqfij: {node['opt_pqfij']}")
            print(f"opt_pqfijc: {node['opt_pqfijc']}")
            print(f"opt_lih_liw: {node['opt_lih_liw']}")
            print(f"opt_lih_liw_pqc: {node['opt_lih_liw_pqc']}")
            print(f"opt_wbuf_btt: {node['opt_wbuf_btt']}")
            print(f"opt_lh_lw: {node['opt_lh_lw']}")
            print(f"act_out_shape: {act_out_shape}")
            print(f"weight_shape: {weight_shape}")
            print(f"act_in_shape: {act_in_shape}")
            print(f"bn_shape: {bn_shape}")
            print(f"res_shape: {res_shape}")

    def print_instr_arr(self):
        for instr in self.instr['array']:
            print(f"{instr[1]:016x}{instr[0]:016x}")

    def build_single_node(self,
                          node: dict,
                          opt_eom=0,
                          pe_num=None) -> np.ndarray:
        instr_arr = np.zeros((7, 2), dtype=np.uint64)
        act_out_base_addr = 0  # self.nodes[node['name']]['act_out']['array'].physical_address
        weight_base_addr = 0  # self.nodes[node['name']]['weight']['array'].physical_address
        act_in_base_addr = 0  # self.nodes[node['name']]['act_in']['array'].physical_address
        bn_base_addr = 0  # self.nodes[node['name']]['bn']['array'].physical_address
        res_base_addr = 0  # self.nodes[node['name']]['res']['array'].physical_address
        # 000
        instr_arr[0] = replace_instr(instr_arr[0], 127, 125, 0)
        instr_arr[0] = replace_instr(instr_arr[0], 121, v=node['use_add'])
        instr_arr[0] = replace_instr(instr_arr[0], 120, v=node['use_bn'])
        instr_arr[0] = replace_instr(instr_arr[0], 119, 118, node['type'])
        instr_arr[0] = replace_instr(instr_arr[0], 117, 115,
                                     node['strides'][0])
        instr_arr[0] = replace_instr(instr_arr[0], 114, 112,
                                     node['strides'][1])
        instr_arr[0] = replace_instr(instr_arr[0], 111, 109, node['padding_t'])
        instr_arr[0] = replace_instr(instr_arr[0], 108, 106, node['padding_l'])
        instr_arr[0] = replace_instr(instr_arr[0], 105, 97, node['l_ih'])
        instr_arr[0] = replace_instr(instr_arr[0], 96, 88, node['l_iw'])
        instr_arr[0] = replace_instr(instr_arr[0], 87, 72,
                                     node['loop_bounds'][0])
        instr_arr[0] = replace_instr(instr_arr[0], 71, 56,
                                     node['loop_bounds'][1])
        instr_arr[0] = replace_instr(instr_arr[0], 55, 52,
                                     node['loop_bounds'][2])
        instr_arr[0] = replace_instr(instr_arr[0], 51, 48,
                                     node['loop_bounds'][3])
        instr_arr[0] = replace_instr(instr_arr[0], 47, 39,
                                     node['loop_bounds'][4])
        instr_arr[0] = replace_instr(instr_arr[0], 38, 30,
                                     node['loop_bounds'][5])
        # 001
        instr_arr[1] = replace_instr(instr_arr[1], 127, 125, 1)
        instr_arr[1] = replace_instr(instr_arr[1], 121, 112,
                                     node['schedule']['P'][0])
        instr_arr[1] = replace_instr(instr_arr[1], 111, 102,
                                     node['schedule']['P'][1])
        instr_arr[1] = replace_instr(instr_arr[1], 101, 98,
                                     node['schedule']['P'][2])
        instr_arr[1] = replace_instr(instr_arr[1], 97, 94,
                                     node['schedule']['P'][3])
        instr_arr[1] = replace_instr(instr_arr[1], 93, 85,
                                     node['schedule']['P'][4])
        instr_arr[1] = replace_instr(instr_arr[1], 84, 76,
                                     node['schedule']['P'][5])
        instr_arr[1] = replace_instr(instr_arr[1], 75, 66,
                                     node['schedule']['Q'][0])
        instr_arr[1] = replace_instr(instr_arr[1], 65, 56,
                                     node['schedule']['Q'][1])
        instr_arr[1] = replace_instr(instr_arr[1], 55, 52,
                                     node['schedule']['Q'][2])
        instr_arr[1] = replace_instr(instr_arr[1], 51, 48,
                                     node['schedule']['Q'][3])
        instr_arr[1] = replace_instr(instr_arr[1], 47, 39,
                                     node['schedule']['Q'][4])
        instr_arr[1] = replace_instr(instr_arr[1], 38, 30,
                                     node['schedule']['Q'][5])
        instr_arr[1] = replace_instr(instr_arr[1], 29, 24,
                                     node['schedule']['F'][0])
        instr_arr[1] = replace_instr(instr_arr[1], 23, 18,
                                     node['schedule']['F'][1])
        instr_arr[1] = replace_instr(instr_arr[1], 17, 15,
                                     node['schedule']['F'][2])
        instr_arr[1] = replace_instr(instr_arr[1], 14, 12,
                                     node['schedule']['F'][3])
        instr_arr[1] = replace_instr(instr_arr[1], 11, 6,
                                     node['schedule']['F'][4])
        instr_arr[1] = replace_instr(instr_arr[1], 5, 0,
                                     node['schedule']['F'][5])
        # 010
        instr_arr[2] = replace_instr(instr_arr[2], 127, 125, 2)
        instr_arr[2] = replace_instr(instr_arr[2], 121, 112,
                                     node['schd_pqf'][0])
        instr_arr[2] = replace_instr(instr_arr[2], 111, 102,
                                     node['schd_pqf'][1])
        instr_arr[2] = replace_instr(instr_arr[2], 101, 98,
                                     node['schd_pqf'][2])
        instr_arr[2] = replace_instr(instr_arr[2], 97, 94, node['schd_pqf'][3])
        instr_arr[2] = replace_instr(instr_arr[2], 93, 85, node['schd_pqf'][4])
        instr_arr[2] = replace_instr(instr_arr[2], 84, 76, node['schd_pqf'][5])
        instr_arr[2] = replace_instr(instr_arr[2], 75, 66, node['schd_pq'][0])
        instr_arr[2] = replace_instr(instr_arr[2], 65, 56, node['schd_pq'][1])
        instr_arr[2] = replace_instr(instr_arr[2], 55, 52, node['schd_pq'][2])
        instr_arr[2] = replace_instr(instr_arr[2], 51, 48, node['schd_pq'][3])
        instr_arr[2] = replace_instr(instr_arr[2], 47, 39, node['schd_pq'][4])
        instr_arr[2] = replace_instr(instr_arr[2], 38, 30, node['schd_pq'][5])
        # 011
        instr_arr[3] = replace_instr(instr_arr[3], 127, 125, 3)
        instr_arr[3] = replace_instr(instr_arr[3], 121, 112,
                                     node['schd_ts'][0])
        instr_arr[3] = replace_instr(instr_arr[3], 111, 102,
                                     node['schd_ts'][1])
        instr_arr[3] = replace_instr(instr_arr[3], 93, 85, node['schd_ts'][4])
        instr_arr[3] = replace_instr(instr_arr[3], 84, 76, node['schd_ts'][5])
        instr_arr[3] = replace_instr(instr_arr[3], 75, 66,
                                     node['schedule']['T'][0])
        instr_arr[3] = replace_instr(instr_arr[3], 65, 56,
                                     node['schedule']['T'][1])
        instr_arr[3] = replace_instr(instr_arr[3], 47, 39,
                                     node['schedule']['T'][4])
        instr_arr[3] = replace_instr(instr_arr[3], 38, 30,
                                     node['schedule']['T'][5])
        instr_arr[3] = replace_instr(instr_arr[3], 29, 24,
                                     node['schedule']['S'][0])
        instr_arr[3] = replace_instr(instr_arr[3], 23, 18,
                                     node['schedule']['S'][1])
        instr_arr[3] = replace_instr(instr_arr[3], 11, 6,
                                     node['schedule']['S'][4])
        instr_arr[3] = replace_instr(instr_arr[3], 5, 0,
                                     node['schedule']['S'][5])
        # 100
        instr_arr[4] = replace_instr(instr_arr[4], 127, 125, 4)
        instr_arr[4] = replace_instr(instr_arr[4], 95, 64, act_out_base_addr)
        instr_arr[4] = replace_instr(instr_arr[4], 63, 32, weight_base_addr)
        instr_arr[4] = replace_instr(instr_arr[4], 31, 0, act_in_base_addr)
        # 101
        instr_arr[5] = replace_instr(instr_arr[5], 127, 125, 5)
        instr_arr[5] = replace_instr(instr_arr[5], 84, 75, node['wpb'])
        instr_arr[5] = replace_instr(instr_arr[5], 70, 64, pe_num)
        instr_arr[5] = replace_instr(instr_arr[5], 63, 32, bn_base_addr)
        instr_arr[5] = replace_instr(instr_arr[5], 31, 0, res_base_addr)
        # 110
        instr_arr[6] = replace_instr(instr_arr[6], 127, 125, 6)
        instr_arr[6] = replace_instr(instr_arr[6], 118, v=opt_eom)
        instr_arr[6] = replace_instr(instr_arr[6], 117, 110, node['opt_pqfij'])
        instr_arr[6] = replace_instr(instr_arr[6], 109, 92, node['opt_pqfijc'])
        instr_arr[6] = replace_instr(instr_arr[6], 91, 64,
                                     node['opt_lih_liw_pqc'])
        instr_arr[6] = replace_instr(instr_arr[6], 63, 36,
                                     node['opt_wbuf_btt'])
        instr_arr[6] = replace_instr(instr_arr[6], 35, 18, node['opt_lih_liw'])
        instr_arr[6] = replace_instr(instr_arr[6], 17, 0, node['opt_lh_lw'])
        return instr_arr

    @staticmethod
    def load(path: str, node_num=None) -> 'InstrGen':
        with open(path, 'r') as f:
            model_spec = json.load(f)
        if node_num is not None:
            if len(model_spec['nodes']) < node_num:
                raise ValueError('node_num is larger than the number of nodes')
            model_spec['nodes'] = model_spec['nodes'][:node_num]
        return InstrGen(model_spec)

    @property
    def model_spec(self) -> dict:
        return self._model_spec

    @model_spec.setter
    def model_spec(self, model_spec: dict) -> None:
        for node in model_spec['nodes']:
            self.verify_single_node(node)
        self._model_spec = model_spec


if __name__ == "__main__":
    ig = InstrGen.load(
        'test/zcu102_128_8-resnet50/agna-zcu102_128_8-resnet50.json')
    node = ig.model_spec['nodes'][0]
    ig.instr['array'] = np.zeros(ig.instr['shape'], dtype=np.uint64)
    instr_arr = ig.build()
    ig.print_instr_arr()
