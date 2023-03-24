from typing import Any
from utils.arch_spec import ArchSpec
from utils.common import list_prod
from utils.node_param import NodeParam
from utils.platform_spec import PlatformSpec

class PlatformPerf:
    """Evaluate performance of `NodeParam` on `PlatformSpec`.
    """
    
    def __init__(self, pltfm_spec: PlatformSpec, node_param: NodeParam) -> None:
        self._pltfm_spec = pltfm_spec
        self._node_param = node_param

    def evaluate(self) -> dict:
        """Evaluate.
        """
        perf_dict = {}
        theo_comm_rd_size = (
            list_prod(self.node_param.input_shape)
            + (
                list_prod(self.node_param.weight_shape)
                if self.node_param.use_weight
                else 0)
            + (
                list_prod(self.node_param.output_shape)
                if self.node_param.use_add
                else 0)
            + (
                list_prod(self.node_param.bn_shape)
                if self.node_param.use_bn
                else 0))
        theo_comm_wr_size = list_prod(self.node_param.output_shape)
        theo_comm_size = theo_comm_rd_size + theo_comm_wr_size
        perf_dict['theo_comm_rd_size'] = theo_comm_rd_size
        perf_dict['theo_comm_wr_size'] = theo_comm_wr_size
        perf_dict['theo_comm_size'] = theo_comm_size
        perf_dict['theo_comm_cycle'] = (
            theo_comm_size
            * self.pltfm_spec.data_width
            / self.pltfm_spec.dbus_width)
        perf_dict['theo_comm_rd_cycle'] = (
            theo_comm_rd_size
            * self.pltfm_spec.data_width
            / self.pltfm_spec.dbus_width)
        perf_dict['theo_comm_wr_cycle'] = (
            theo_comm_wr_size
            * self.pltfm_spec.data_width
            / self.pltfm_spec.dbus_width)
        return perf_dict
    
    @property
    def pltfm_spec(self) -> PlatformSpec:
        return self._pltfm_spec
    
    @property
    def node_param(self) -> NodeParam:
        return self._node_param


class ArchPerf:
    """Evaluate performance of `NodeParam` on `ArchSpec`.
    """
    
    def __init__(self, arch_spec: ArchSpec, node_param: NodeParam) -> None:
        self._arch_spec = arch_spec
        self._node_param = node_param
    
    def evaluate(self) -> dict:
        """Evaluate.
        """
        perf_dict = {}
        perf_dict['rd_cycle_ratio'] = self.node_param.rd_cycle_ratio
        perf_dict['wr_cycle_ratio'] = self.node_param.wr_cycle_ratio
        
        return perf_dict

    def get_input_act_shape(self, loop_bounds: tuple[Any]) -> tuple[Any]:
        """Get the shape of input act from loop_bounds"""
        pass

    @property
    def arch_spec(self) -> ArchSpec:
        return self._arch_spec
    
    @property
    def node_param(self) -> NodeParam:
        return self._node_param
