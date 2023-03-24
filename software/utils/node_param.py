import math
from typing import Any
from utils.arch_spec import ArchSpec
from utils.base_param import BaseParam
from utils.common import agna_level_tuple, list_prod, short_str
from utils.platform_spec import PlatformSpec
from utils.schedule_param import ScheduleParam


class NodeParam(BaseParam):

    def __init__(self, params: dict) -> None:
        """Initialize NodeParam.
        """
        super().__init__(params)
        # only used for topology analysis:
        self.layer_name_list = []
        self.add_layer_name = None
    
    
    @property
    def layer_name_list(self) -> list[str]:
        """Get layer_name_list. Auxiliary for topology analysis in ModelParser.
        """
        return self._layer_name_list
    @layer_name_list.setter
    def layer_name_list(self, layer_name_list: list[str]) -> None:
        self._layer_name_list = layer_name_list
    
    @property
    def add_layer_name(self) -> str:
        """Get add_layer_name. Auxiliary for topology analysis in ModelParser.
        """
        return self._add_layer_name
    @add_layer_name.setter
    def add_layer_name(self, add_layer_name: str) -> None:
        self._add_layer_name = add_layer_name

    def __eq__(self, other: Any) -> bool:
        """Evaluate equality.
        """
        if not isinstance(other, NodeParam):
            return False
        else:
            other_dict = dict(other)
            self_dict = dict(self)
            return (
                self_dict['type'] == other_dict['type']
                and self_dict['loop_bounds'] == other_dict['loop_bounds']
                and self_dict['strides'] == other_dict['strides']
                and self_dict['paddings'] == other_dict['paddings']
                and self_dict['use_bn'] == other_dict['use_bn']
                and self_dict['use_add'] == other_dict['use_add']
                and self_dict['use_act'] == other_dict['use_act']
            )

    @staticmethod
    def get_csv_header() -> tuple:
        return (
            NodeParam.get_param_keys()
            + NodeParam.get_perf_keys())

    def get_csv_row(
            self,
            arch_spec: ArchSpec = None) -> tuple:
        """Evluate and return csv_row.
        """
        csv_dict = dict(self)
        csv_dict.update(self.eval_perf(arch_spec))
        return tuple(csv_dict[key] for key in self.get_csv_header())

    @staticmethod
    def get_header() -> str:
        """Get header.
        """
        return (
            'name'.ljust(30)
            + 'input_source'.ljust(30)
            + 'add_source'.ljust(30)
            + 'type'.ljust(8)
            + 'loop_bounds'.ljust(30)
            + 'strides'.ljust(10)
            + 'paddings'.ljust(20)
            + 'use_bn'.ljust(8)
            + 'use_add'.ljust(8)
            + 'use_act'.ljust(8)
            + 'input_shape'.ljust(20)
            + 'weight_shape'.ljust(20)
            + 'output_shape'.ljust(20)
            + 'bn_shape'.ljust(12)
            + 'schedule'
        )

    def __str__(self) -> str:
        return (
            short_str(self.name).ljust(30)
            + short_str(self.input_source).ljust(30)
            + short_str(self.add_source).ljust(30)
            + str(self.type).ljust(8)
            + str(self.loop_bounds).ljust(30)
            + str(self.strides).ljust(10)
            + str(self.paddings).ljust(20)
            + str(self.use_bn).ljust(8)
            + str(self.use_add).ljust(8)
            + str(self.use_act).ljust(8)
            + str(self.input_shape).ljust(20)
            + str(self.weight_shape).ljust(20)
            + str(self.output_shape).ljust(20)
            + str(self.bn_shape).ljust(12)
            + str(self.schedule)
        )
    
    @staticmethod
    def get_perf_keys() -> tuple:
        return (
            'l_param', 'ts_param',
            'theo_comp_cycle', 'theo_comm_rd_cycle', 'theo_comm_wr_cycle',
            'theo_cycle',
            'rf_comp_cycle', 'rf_comm_cycle', 'rf_cycle', 'rf_used_depth',
            'abuf_used_depth', 'wbuf_used_depth', 'pbuf_used_depth',
            'rd_packet_len', 'wr_packet_len',
            'T_KCHW', 'T_KHW',
            'abuf_cycle', 'wbuf_cycle', 'pe_cycle', 'pbuf_cycle', 
            'in_bound_cycle', 'out_bound_cycle',
            'schd_updt_cycle', 'schd_wb_cycle', 'schd_cycle')

    def eval_perf(self, arch_spec: ArchSpec = None) -> dict:
        perf_dict = dict.fromkeys(self.get_perf_keys())
        if arch_spec:
            # theo cycle
            perf_dict['theo_comp_cycle'] = int(
                list_prod(self.loop_bounds) / (arch_spec.total_dsp_num*(1+(arch_spec.data_width==8))))
            theo_comm_rd_size = (
                list_prod(self.input_shape)
                + (list_prod(self.weight_shape) if self.use_weight else 0)
                + (list_prod(self.output_shape) if self.use_add else 0)
                + (list_prod(self.bn_shape) if self.use_bn else 0))
            theo_comm_wr_size = list_prod(self.output_shape)
            perf_dict['theo_comm_rd_cycle'] = int(
                theo_comm_rd_size
                * arch_spec.data_width
                / arch_spec.dbus_width)
            perf_dict['theo_comm_wr_cycle'] = int(
                theo_comm_wr_size
                * arch_spec.data_width
                / arch_spec.dbus_width)
            perf_dict['theo_cycle'] = max(
                perf_dict['theo_comp_cycle'],
                perf_dict['theo_comm_rd_cycle'],
                perf_dict['theo_comm_wr_cycle'])
            if self.schedule:
                schd_dict = dict(self.schedule)
                idx = 1 if self.is_dpws else 0
                # l_param
                perf_dict['l_param'] = self.input_shape[1:] + self.loop_bounds
                # ts_param
                perf_dict['ts_param'] = tuple(
                    math.ceil(self.loop_bounds[d]/self.schedule.PQF[d])
                    for d in range(6))
                # rf cycle
                rf_comp_cycle = get_rf_comp_cycle_expr(schd_dict)
                rf_comm_cycle = get_rf_comm_cycle_expr(schd_dict, self.strides)
                rf_cycle = max(rf_comp_cycle, rf_comm_cycle)
                perf_dict['rf_comp_cycle'] = rf_comp_cycle
                perf_dict['rf_comm_cycle'] = rf_comm_cycle
                perf_dict['rf_cycle'] = rf_cycle
                # rf_used_depth
                perf_dict['rf_used_depth'] = get_rf_used_depth_expr(schd_dict, self.strides)
                # buf_used_depth
                perf_dict['abuf_used_depth'] = get_abuf_used_depth_expr(schd_dict, self.strides)
                perf_dict['wbuf_used_depth'] = get_wbuf_used_depth_expr(schd_dict)
                perf_dict['pbuf_used_depth'] = get_pbuf_used_depth_expr(schd_dict, self.type)
                # schd cycle
                perf_dict['rd_packet_len'] = self.rd_packet_len
                perf_dict['wr_packet_len'] = self.wr_packet_len
                # useful schd prod
                perf_dict['T_KCHW'] = self.schedule.T[0]*self.schedule.T[1]*self.schedule.T[4]*self.schedule.T[5]
                perf_dict['T_KHW'] = self.schedule.T[0]*self.schedule.T[4]*self.schedule.T[5]
                # new schd cycle
                abuf_cycle = math.ceil(
                    self.schedule.S[1]*self.schedule.S[4]*self.schedule.S[5]  # S_CHW
                    * self.schedule.F[1]  # F_C
                    * get_abuf_used_depth_expr(schd_dict, self.strides)
                    * arch_spec.data_width
                    / arch_spec.dbus_width)
                if self.use_weight:
                    wbuf_cycle = math.ceil(
                        self.schedule.S[0]*self.schedule.S[1]
                        * self.schedule.S[2]*self.schedule.S[3]  # S_KCIJ
                        * self.schedule.F[0]*self.schedule.F[1]
                        * self.schedule.F[2]*self.schedule.F[3]  # F_KCIJ
                        * get_wbuf_used_depth_expr(schd_dict)
                        * arch_spec.data_width
                        / arch_spec.dbus_width)
                else:
                    wbuf_cycle = 0
                pe_cycle = list_prod(self.schedule.P) * rf_cycle
                pbuf_rd_width = min(
                    self.schedule.F[4]*self.schedule.F[5],
                    arch_spec.dbus_width / arch_spec.data_width)
                pbuf_cycle = math.ceil(
                    self.schedule.S[idx]*self.schedule.S[4]*self.schedule.S[5]
                    * self.schedule.PQF[idx]*self.schedule.PQF[4]*self.schedule.PQF[5]
                    / pbuf_rd_width)
                in_bound_cycle = max(abuf_cycle+wbuf_cycle, pe_cycle)
                out_bound_cycle = max(in_bound_cycle, pbuf_cycle)
                if self.is_dpws:
                    schd_updt_cycle = (abuf_cycle+wbuf_cycle)*perf_dict['T_KCHW']
                    schd_wb_cycle = pbuf_cycle*perf_dict['T_KCHW']
                    schd_cycle = out_bound_cycle*perf_dict['T_KCHW']
                else:
                    schd_updt_cycle = (abuf_cycle+wbuf_cycle)*perf_dict['T_KCHW']
                    schd_wb_cycle = pbuf_cycle*perf_dict['T_KHW']
                    schd_cycle = (
                        self.schedule.T[1]*in_bound_cycle + pbuf_cycle
                        + (self.schedule.T[0]*self.schedule.T[4]*self.schedule.T[5]-1)
                        * ((self.schedule.T[1]-1)*in_bound_cycle + out_bound_cycle))
                perf_dict['abuf_cycle'] = abuf_cycle
                perf_dict['wbuf_cycle'] = wbuf_cycle
                perf_dict['pe_cycle'] = pe_cycle
                perf_dict['pbuf_cycle'] = pbuf_cycle
                perf_dict['in_bound_cycle'] = in_bound_cycle
                perf_dict['out_bound_cycle'] = out_bound_cycle
                perf_dict['schd_updt_cycle'] = schd_updt_cycle
                perf_dict['schd_wb_cycle'] = schd_wb_cycle
                perf_dict['schd_cycle'] = schd_cycle
        return perf_dict

    def set_extra_paddings(self, paddings: tuple) -> None:
        """Set extra paddings.
        """
        new_paddings = tuple(self.paddings[i] + paddings[i] for i in range(4))
        self._paddings = new_paddings

    def set_use_bn(self, use_bn: bool) -> None:
        """Set use_bn.
        """
        self._use_bn = use_bn
    
    def set_use_add(self, use_add: bool) -> None:
        """Set use_add.
        """
        self._use_add = use_add
    
    def set_use_act(self, use_act: bool) -> None:
        """Set use_act.
        """
        self._use_act = use_act

    def set_input_source(self, input_source: str) -> None:
        """Set input_source.
        """
        self._input_source = input_source

    def set_add_source(self, add_source: str) -> None:
        """Set add_source.
        """
        self._add_source = add_source

    def set_schedule(self, schedule: ScheduleParam) -> None:
        """Set schedule.
        """
        self._schedule = schedule

    @property
    def is_dpws(self) -> bool:
        """Type is dpws (type>=1).
        """
        return self.type>=1

    @property
    def is_pool(self) -> bool:
        """Type is pool (type>=2).
        """
        return self.type>=2

    @property
    def is_maxpool(self) -> bool:
        """Type is maxpool (type==3).
        """
        return self.type==3

    @property
    def use_weight(self) -> bool:
        """Node use weight (type<=1).
        """
        return self.type<=1

    @property
    def input_shape(self) -> tuple:
        """ Input shape.
        """
        padded_shape = get_input_shape_expr(self.loop_bounds, self.strides)
        return (
            padded_shape[0],
            padded_shape[1] - self.paddings[0] - self.paddings[1],
            padded_shape[2] - self.paddings[2] - self.paddings[3])
    
    @property
    def weight_shape(self) -> tuple:
        """ Weight shape.
        """
        return get_weight_shape_expr(self.loop_bounds)
    
    @property
    def output_shape(self) -> tuple:
        """ Output shape.
        """
        return get_output_shape_expr(self.loop_bounds, self.type)
    
    @property
    def bn_shape(self) -> tuple:
        """ Batchnorm shape.
        """
        return get_bn_shape_expr(self.loop_bounds, self.type)

    # @property
    # def burst_len_k(self) -> int:
    #     """Burst length on K.
    #     """
    #     if self.schedule:
    #         idx = 1 if self.is_dpws else 0
    #         len_k = min(
    #             self.schedule.P[idx] * self.schedule.Q[idx] * self.schedule.F[idx],
    #             self.loop_bounds[idx])
    #         return len_k
    #     else:
    #         return 0

    # @property
    # def burst_len_c(self) -> int:
    #     """Burst length on C.
    #     """
    #     if self.schedule:
    #         len_h = min(
    #             self.schedule.P[1] * self.schedule.Q[1] * self.schedule.F[1],
    #             self.loop_bounds[1])
    #         return len_h
    #     else:
    #         return 0

    # @property
    # def burst_len_h(self) -> int:
    #     """Burst length on H.
    #     """
    #     if self.schedule:
    #         len_h = min(
    #             self.schedule.P[4] * self.schedule.Q[4] * self.schedule.F[4],
    #             self.loop_bounds[4])
    #         return len_h
    #     else:
    #         return 0

    # @property
    # def burst_len_w(self) -> int:
    #     """Burst length on W.
    #     """
    #     if self.schedule:
    #         len_w = min(
    #             self.schedule.P[5] * self.schedule.Q[5] * self.schedule.F[5],
    #             self.loop_bounds[5])
    #         return len_w
    #     else:
    #         return 0
    
    # @property
    # def burst_len(self) -> int:
    #     """Burst length.
    #     """
    #     return self.burst_len_k*self.burst_len_h*self.burst_len_w

    @property
    def rd_cycle_ratio(self) -> int:
        """Read cycle ratio.
        """
        return get_rd_cycle_ratio_expr(self.rd_packet_len)

    @property
    def rd_packet_len(self) -> int:
        """Read packet length.
        """
        pqf_shape = get_input_shape_expr(self.schedule.PQF, self.strides)
        pkt_len = (
            pqf_shape[2] if self.schedule.TS[5]>1  # ts_w > 1
            else pqf_shape[1]*self.output_shape[2] if self.schedule.TS[4]>1  # ts_h > 1
            else pqf_shape[0]*self.output_shape[1]*self.output_shape[2]
            )
        return pkt_len

    @property
    def rd_packet_num(self) -> int:
        """Read packet number.
        """
        pqf_shape = get_input_shape_expr(self.schedule.PQF, self.strides)
        pkt_num = (
            pqf_shape[0]*pqf_shape[1] if self.schedule.TS[5]>1  # ts_w > 1
            else pqf_shape[0] if self.schedule.TS[4]>1  # ts_h > 1
            else 1
            )
        return pkt_num

    @property
    def wr_cycle_ratio(self) -> int:
        """Write cycle ratio.
        """
        return get_wr_cycle_ratio_expr(self.wr_packet_len)

    @property
    def wr_packet_len(self) -> int:
        """Write packet length.
        """
        pqf_shape = get_output_shape_expr(self.schedule.PQF, self.type)
        pkt_len = (
            pqf_shape[2] if self.schedule.TS[5]>1  # ts_w > 1
            else pqf_shape[1]*self.output_shape[2] if self.schedule.TS[4]>1  # ts_h > 1
            else pqf_shape[0]*self.output_shape[1]*self.output_shape[2]
            )
        return pkt_len

    @property
    def wr_packet_num(self) -> int:
        """Write packet number.
        """
        pqf_shape = get_output_shape_expr(self.schedule.PQF, self.type)
        pkt_num = (
            pqf_shape[0]*pqf_shape[1] if self.schedule.TS[5]>1  # ts_w > 1
            else pqf_shape[0] if self.schedule.TS[4]>1  # ts_h > 1
            else 1
            )
        return pkt_num

    @staticmethod
    def get_param_keys() -> tuple[str]:
        """A tuple of dictionary keys. All required when save.
        """
        return ('name', 'unique_cnt', 'same_as', 'input_source', 'add_source',
            'type', 'loop_bounds', 'strides', 'paddings',
            'use_bn', 'use_add', 'use_act', 'schedule',)

    @BaseParam.params.setter
    def params(self, params: dict) -> None:
        new_params = {}
        new_params.update(params)
        new_params.setdefault('unique_cnt', 1)
        new_params.setdefault('same_as')
        new_params.setdefault('input_source')
        new_params.setdefault('add_source')
        new_params.setdefault('schedule')
        for k in ['loop_bounds', 'strides', 'paddings']:
            new_params[k] = tuple(new_params[k])
        if isinstance(new_params['schedule'], dict):
            new_params['schedule'] = ScheduleParam(new_params['schedule'])
        BaseParam.params.fset(self, new_params)

    @property
    def name(self) -> str:
        """ Name of the node.
        """
        return self._name

    @property
    def unique_cnt(self) -> int:
        """Get unique_cnt.
        """
        return self._unique_cnt
    @unique_cnt.setter
    def unique_cnt(self, unique_cnt: int) -> None:
        self._unique_cnt = unique_cnt

    @property
    def same_as(self) -> str:
        """Get same_as.
        """
        return self._same_as
    @same_as.setter
    def same_as(self, same_as: str) -> None:
        self._same_as = same_as

    @property
    def input_source(self) -> 'str | None':
        """Input source node name.
        """
        return self._input_source

    @property
    def add_source(self) -> 'str | None':
        """Add source node name.
        """
        return self._add_source

    @property
    def type(self) -> int:
        """ Computation type.
        0: conv, dense
        1: depthconv
        2: avgpool
        3: maxpool
        """
        return self._type

    @property
    def loop_bounds(self) -> tuple:
        """ Loop bounds, tuple(K, C, I, J, H, W).
        """
        return self._loop_bounds

    @property
    def strides(self) -> tuple:
        """ Strides, tuple(stride_h, stride_w).
        """
        return self._strides

    @property
    def paddings(self) -> tuple:
        """ Paddings, tuple(t[op], b[ottom], l[eft], r[ight]).
        """
        return self._paddings

    @property
    def use_bn(self) -> bool:
        """ Whether use batchnorm.
        """
        return self._use_bn

    @property
    def use_add(self) -> bool:
        """ Whether use residual add.
        """
        return self._use_add

    @property
    def use_act(self) -> bool:
        """ Whether use activation.
        """
        return self._use_act

    @property
    def schedule(self) -> 'ScheduleParam | None':
        """Schedule param.
        """
        return self._schedule


def get_input_shape_expr(
        loop_bounds: tuple,
        strides: tuple,
        bias: int = -1) -> tuple:
    """Get shape of input act from loop_bounds.

    Arguments:
        loop_bounds: tuple of 6 int or Variable.
        strides: tuple of 2 int.
    Returns:
        (c, ih, iw)
    """
    in_h = (loop_bounds[4] + bias) * strides[0] + loop_bounds[2]
    in_w = (loop_bounds[5] + bias) * strides[1] + loop_bounds[3]
    return (loop_bounds[1], in_h, in_w)

def get_weight_shape_expr(loop_bounds: tuple) -> tuple:
    """Get shape of weight from loop_bounds.

    Arguments:
        loop_bounds: tuple of 6 int or Variable.
    Returns:
        (k, c, i, j)
    """
    return tuple(loop_bounds[:4])

def get_output_shape_expr(loop_bounds: tuple, ntype: int) -> tuple:
    """Get shape of output act from loop_bounds.

    Arguments:
        loop_bounds: tuple of 6 int or Variable.
        ntype: node type, int.
    Returns:
        (k|c, h, w)
    """
    return (
        (loop_bounds[0] if ntype==0 else loop_bounds[1],)
        + tuple(loop_bounds[4:6]))

def get_bn_shape_expr(loop_bounds: tuple, ntype: int) -> tuple:
    """Get shape of bn from loop_bounds.

    Arguments:
        loop_bounds: tuple of 6 int or Variable.
        ntype: node type, int.
    Returns:
        (k|c, 2)
    """
    return ((loop_bounds[0] if ntype==0 else loop_bounds[1]), 2)

def get_rf_used_depth_expr(
        schd_dict: dict[tuple], 
        strides: tuple,
        bias: int = -1) -> Any:
    """Get the depth of used RF.
    
    Arguments:
        schd_dict: dict of (tuple of 6 int or Variable).
    """
    # build loop_bounds with all Q
    loop_bounds = schd_dict['Q']
    return list_prod(get_input_shape_expr(loop_bounds, strides, bias))

def get_abuf_used_depth_expr(
        schd_dict: dict[tuple],
        # paddings: tuple,
        strides: tuple,
        bias: int = -1) -> Any:
    """Get the depth of used ABUF.
    
    Arguments:
        schd_dict: dict of (tuple of 6 int or Variable).
    """
    # build loop_bounds with all PQ and [I,J,H,W] in F
    loop_bounds = [schd_dict['P'][d]*schd_dict['Q'][d] for d in range(6)]
    for d in range(2, 6):
        loop_bounds[d] *= schd_dict['F'][d]
    input_shape = get_input_shape_expr(loop_bounds, strides, bias)
    return list_prod(input_shape)

def get_wbuf_used_depth_expr(schd_dict: dict[tuple]) -> Any:
    """Get the depth of used WBUF.
    
    Arguments:
        schd_dict: dict of (tuple of 6 int or Variable).
    """
    # build loop_bounds with all PQ
    loop_bounds = [schd_dict['P'][d]*schd_dict['Q'][d] for d in range(6)]
    return list_prod(get_weight_shape_expr(loop_bounds))

def get_pbuf_used_depth_expr(schd_dict: dict[tuple], ntype: int) -> Any:
    """Get the depth of used PBUF.
    
    Arguments:
        schd_dict: dict of (tuple of 6 int or Variable).
        ntype: node type, int.
    """
    # build loop_bounds with all PQ
    loop_bounds = [schd_dict['P'][d]*schd_dict['Q'][d] for d in range(6)]
    return list_prod(get_output_shape_expr(loop_bounds, ntype))

def get_rf_comp_cycle_expr(schd_dict: dict[tuple]) -> Any:
    """Get the comp cycle of RF(Q level).
    
    Arguments:
        schd_dict: dict of (tuple of 6 int or Variable).
    """
    return list_prod(schd_dict['Q'])

def get_rf_comm_cycle_expr(
        schd_dict: dict[tuple],
        strides: tuple,
        bias: int = -1) -> Any:
    """Get the comm cycle of RF(Q level).
    
    Arguments:
        schd_dict: dict of (tuple of 6 int or Variable).
    """
    # build loop_bounds with all Q and [I,J,H,W] in F
    loop_bounds = [schd_dict['Q'][d] for d in range(6)]
    for d in range(2, 6):
        loop_bounds[d] *= schd_dict['F'][d]
    return list_prod(get_input_shape_expr(loop_bounds, strides, bias))

def get_node_comp_cycle_expr(schd_dict: dict[tuple], rf_cycle: Any) -> Any:
    """Get the comp cycle of the node.
    
    Arguments:
        schd_dict: dict of (tuple of 6 int or Variable).
        rf_cycle: the comp cycle of RF(Q level).
    """
    return (
        list_prod(schd_dict['T'])
        * list_prod(schd_dict['P'])
        * rf_cycle)

def get_rd_cycle_ratio_expr(burst_len: int) -> Any:
    return 1 + 1/(0.037266*burst_len)

def get_node_comm_rd_size_expr(
        schd_dict: dict[tuple],
        ntype: int,
        strides: tuple,
        use_bn: bool,
        use_weight: bool,
        use_add: bool,
        bias: int = -1) -> Any:
    """Get the comm rd size of the node.
    
    Arguments:
        schd_dict: dict of (tuple of 6 int or Variable).
    """
    return (
        get_node_comm_act_in_size_expr(schd_dict, strides, bias)
        + get_node_comm_bn_size_expr(schd_dict, ntype, use_bn)
        + get_node_comm_weight_size_expr(schd_dict, use_weight)
        + get_node_comm_add_size_expr(schd_dict, ntype, use_add))

def get_wr_cycle_ratio_expr(burst_len: int) -> Any:
    return 1 + 1/(0.024725*burst_len)

def get_node_comm_wr_size_expr(
        schd_dict: dict[tuple],
        ntype: int) -> Any:
    """Get the comm rd size of the node.
    
    Arguments:
        schd_dict: dict of (tuple of 6 int or Variable).
    """
    return get_node_comm_act_out_size_expr(schd_dict ,ntype)

def get_node_comm_act_in_size_expr(
        schd_dict: dict[tuple],
        strides: tuple,
        bias: int = -1) -> Any:
    return (
        get_abuf_used_depth_expr(schd_dict, strides, bias)  # single abuf
        * schd_dict['F'][1]  # num of abuf, F_C
        * list_prod(schd_dict['T'])
        * list_prod(schd_dict['S'][d] for d in [1,4,5])  # S_CHW
        )

def get_node_comm_bn_size_expr(
        schd_dict: dict[tuple],
        ntype: int,
        use_bn: bool) -> Any:
    tspqf_bounds = [
        list_prod(schd_dict[l][d] for l in agna_level_tuple)
        for d in range(6)]
    return (
        list_prod(get_bn_shape_expr(tspqf_bounds, ntype))
        if use_bn else 0)

def get_node_comm_weight_size_expr(
        schd_dict: dict[tuple],
        use_w: bool) -> Any:
    return (
        (
            get_wbuf_used_depth_expr(schd_dict)  # single wbuf
            * list_prod(get_weight_shape_expr(schd_dict['F']))  # num of wbuf F_KCIJ
            * list_prod(schd_dict['T'])
            * list_prod(get_weight_shape_expr(schd_dict['S']))  # S_KCIJ
            )
        if use_w else 0)

def get_node_comm_add_size_expr(
        schd_dict: dict[tuple],
        ntype: int,
        use_add: bool) -> Any:
    return (
        get_node_comm_act_out_size_expr(schd_dict, ntype)  # act out size
        if use_add else 0)

def get_node_comm_act_out_size_expr(
        schd_dict: dict[tuple],
        ntype: int) -> Any:
    return (
        get_pbuf_used_depth_expr(schd_dict, ntype)  # single pbuf
        * list_prod(get_output_shape_expr(schd_dict['F'], ntype))  # num of pbuf F_(K|C)HW
        * list_prod(get_output_shape_expr(schd_dict['T'], ntype))
        * list_prod(get_output_shape_expr(schd_dict['S'], ntype))  # S_(K|C)HW
        )
