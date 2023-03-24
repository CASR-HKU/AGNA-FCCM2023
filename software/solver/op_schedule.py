from typing import Any
from solver.base_rnr import BaseRnR
from solver.common import SolverVar, SolverConstr
from utils.arch_spec import ArchSpec
from utils.common import agna_level_tuple, agna_dim_tuple, list_prod
from utils.node_param import (
    NodeParam, get_abuf_used_depth_expr, get_node_comm_rd_size_expr, get_node_comm_wr_size_expr, get_rd_cycle_ratio_expr, get_node_comm_act_in_size_expr,
    get_node_comm_act_out_size_expr, get_node_comm_add_size_expr,
    get_node_comm_bn_size_expr, get_node_comm_weight_size_expr,
    get_node_comp_cycle_expr, get_output_shape_expr, get_pbuf_used_depth_expr,
    get_rf_comm_cycle_expr, get_rf_comp_cycle_expr,
    get_rf_used_depth_expr, get_wbuf_used_depth_expr, get_wr_cycle_ratio_expr)
from utils.schedule_param import ScheduleParam

class OperationSchedule(BaseRnR):

    def __init__(
            self,
            arch_spec:ArchSpec,
            node_param:NodeParam,
            path_prefix:str,
            config:dict) -> None:
        super().__init__(path_prefix, config)
        self._arch_spec = arch_spec
        self._node_param = node_param
        self.logger.info(f"Architecture: {dict(self.arch_spec)}")
        self.logger.info(f"Node: {node_param.name}")

    def build_var_list(self) -> list[SolverVar]:
        """Build var_list.
        
        Returns:
            var_list: List of SolverVar.
        """
        var_list = []
        # schedule variables
        for level in agna_level_tuple:
            for dim in agna_dim_tuple:
                var_list.append(SolverVar(
                    f"schd_{level}_{dim}", lb=1, is_strict=True))
        # rf_cycle
        var_list.append(SolverVar('rf_cycle', lb=1))
        # abuf_cycle
        var_list.append(SolverVar('abuf_cycle', lb=1))
        # wbuf_cycle
        var_list.append(SolverVar('wbuf_cycle', lb=1))
        # pe_cycle
        var_list.append(SolverVar('pe_cycle', lb=1))
        # pbuf_cycle
        var_list.append(SolverVar('pbuf_cycle', lb=1))
        # w_ratio
        var_list.append(SolverVar('w_ratio', lb=1, vtype='CONTINUOUS'))
        # in_bound_cycle
        var_list.append(SolverVar('in_bound_cycle', lb=1))
        # out_bound_cycle
        var_list.append(SolverVar('out_bound_cycle', lb=1))
        # objective: node_cycle
        var_list.append(SolverVar('obj', lb=1))
        return var_list

    def build_constr_list(self) -> list[SolverConstr]:
        """Build constr_list.
        
        Returns:
            constr_list: List of SolverConstr.
        """
        constr_list = []
        # self.append_test_constr(constr_list)
        self.append_arch_constr(constr_list)
        self.append_resource_constr(constr_list)
        self.append_node_constr(constr_list)
        self.append_rf_cycle_constr(constr_list)
        self.append_node_cycle_constr(constr_list)
        self.append_obj_constr(constr_list)
        return constr_list
    
    def build_best_solution(self, solval_i: dict) -> None:
        """Build best solution.
        """
        if solval_i is not None:
            schd_dict = {
                f"{level}":
                    tuple(solval_i[f"schd_{level}_{dim}"] for dim in agna_dim_tuple)
                for level in agna_level_tuple}
            self.best_solution = ScheduleParam(schd_dict)

    # def append_test_constr(self, constr_list: list[SolverConstr]):
    #     """Append test constr to constr_list.
    #     """
    #     for level_dim in ['S_K', 'S_W', 'T_W', 'P_I', 'P_J',]:
    #         constr_list.append(SolverConstr(
    #             f"arch_fix_{level_dim}",
    #             lambda var_d, level_dim=level_dim:
    #                 var_d[f"schd_{level_dim}"]==1))
    #     for level_dim in ['S_C', 'S_H', 'T_C', 'P_K', 'P_C', 'P_H', 'P_W',]:
    #         constr_list.append(SolverConstr(
    #             f"arch_fix_{level_dim}",
    #             lambda var_d, level_dim=level_dim:
    #                 var_d[f"schd_{level_dim}"]==2))
    #     for level_dim in ['T_K', 'T_H', 'Q_K', 'Q_H', 'Q_W',]:
    #         constr_list.append(SolverConstr(
    #             f"arch_fix_{level_dim}",
    #             lambda var_d, level_dim=level_dim:
    #                 var_d[f"schd_{level_dim}"]<=5))

    def append_arch_constr(self, constr_list: list[SolverConstr]):
        """Append architecture constr to constr_list.
        """
        # fix schd_[T,S]_[I,J] to 1, for better input reuse
        for level_dim in [ 'S_I', 'T_I', 'S_J', 'T_J',]:
            constr_list.append(SolverConstr(
                f"arch_fix_{level_dim}",
                lambda var_d, level_dim=level_dim:
                    var_d[f"schd_{level_dim}"]==1))
        # fix schd_P_K to 1, for better rf reuse
        constr_list.append(SolverConstr(
            f"arch_fix_P_K",
            lambda var_d: var_d['schd_P_K']==1))
        # fix schd_P_K to 1, for better rf reuse
        constr_list.append(SolverConstr(
            f"arch_fix_TS_K",
            lambda var_d: var_d['schd_T_K']*var_d['schd_S_K']<=1023))
        constr_list.append(SolverConstr(
            f"arch_fix_PQF_K",
            lambda var_d: var_d['schd_P_K']*var_d['schd_Q_K']*var_d['schd_F_K']<=1023))
        constr_list.append(SolverConstr(
            f"arch_fix_TS_C",
            lambda var_d: var_d['schd_T_C']*var_d['schd_S_C']<=1023))
        constr_list.append(SolverConstr(
            f"arch_fix_PQF_C",
            lambda var_d: var_d['schd_P_C']*var_d['schd_Q_C']*var_d['schd_F_C']<=1023))
        # dpws type
        if self.node_param.is_dpws:
            for level in agna_level_tuple:
                constr_list.append(SolverConstr(
                    f"dpws_{level}_K",
                    lambda var_d, level=level: var_d[f"schd_{level}_K"]==1))
            constr_list.append(SolverConstr(
                'dpws_F_C',
                lambda var_d: var_d['schd_F_C']==1))
        # maxpool type
        if self.node_param.is_maxpool:
            constr_list.append(SolverConstr(
                'maxpool_Q_I',
                lambda var_d:
                    var_d['schd_Q_I']==self.node_param.loop_bounds[2]))
            constr_list.append(SolverConstr(
                'maxpool_Q_J',
                lambda var_d:
                    var_d['schd_Q_J']==self.node_param.loop_bounds[3]))

    def append_resource_constr(self, constr_list: list[SolverConstr]):
        """Append hardware resource constr to constr_list.
        """
        # prod(schd_S_*)<=pe_num
        constr_list.append(SolverConstr(
            f"S_le_pe_num",
            lambda var_d:self.get_schd_prod(var_d, 'S')
                <= self.arch_spec.pe_num))
        # schd_F_*<=pe_arch_*
        for idx, dim in enumerate(agna_dim_tuple):
            constr_list.append(SolverConstr(
                f"F_le_A_{dim}",
                lambda var_d, dim=dim, idx=idx: var_d[f"schd_F_{dim}"]
                    <= self.arch_spec.pe_arch[idx]))
        # rf_uti
        constr_list.append(SolverConstr(
            'mem_rf_uti',
            lambda var_d:
                get_rf_used_depth_expr(
                    self.get_schd_var_dict(var_d),
                    self.node_param.strides, 0)
                <= self.arch_spec.rf_depth*1.5,
            scope='gpkit'))
        constr_list.append(SolverConstr(
            'mem_rf_uti',
            lambda var_d:
                get_rf_used_depth_expr(
                    self.get_schd_var_dict(var_d),
                    self.node_param.strides)
                <= self.arch_spec.rf_depth,
            scope='scip'))
        # abuf_uti
        constr_list.append(SolverConstr(
            'mem_abuf_uti',
            lambda var_d:
                get_abuf_used_depth_expr(
                    self.get_schd_var_dict(var_d),
                    # self.node_param.paddings,
                    self.node_param.strides, 0)
                <= self.arch_spec.abuf_depth*1.5,
            scope='gpkit'))
        constr_list.append(SolverConstr(
            'mem_abuf_uti',
            lambda var_d:
                get_abuf_used_depth_expr(
                    self.get_schd_var_dict(var_d),
                    # self.node_param.paddings,
                    self.node_param.strides)
                <= self.arch_spec.abuf_depth,
            scope='scip'))
        # wbuf_uti
        if self.node_param.use_weight:
            constr_list.append(SolverConstr(
                'mem_wbuf_uti',
                lambda var_d:
                    get_wbuf_used_depth_expr(self.get_schd_var_dict(var_d))
                    <= self.arch_spec.wbuf_depth))
        # pbuf_uti
        constr_list.append(SolverConstr(
            'mem_pbuf_uti',
            lambda var_d:
                get_pbuf_used_depth_expr(
                    self.get_schd_var_dict(var_d),
                    self.node_param.type)
                <= self.arch_spec.pbuf_depth))

    def append_node_constr(self, constr_list: list[SolverConstr]):
        """Append constr of each node to constr_list.
        """
        # loop bound
        for idx, dim in enumerate(agna_dim_tuple):
            dim_bound = self.node_param.loop_bounds[idx]
            # prod([levels]_dim)>=dim_bound
            constr_list.append(SolverConstr(
                f"{dim}_lb",
                lambda var_d, dim=dim, bound=dim_bound:
                    self.get_schd_prod(var_d, dims=dim)
                    >= bound))
            # prod([levels]_dim)<=dim_bound+S_d*F_d-1, scip only
            constr_list.append(SolverConstr(
                f"{dim}_ub",
                lambda var_d, dim=dim, bound=dim_bound:
                    self.get_schd_prod(var_d, dims=dim)
                    <= bound + self.get_schd_prod(var_d, ['S','F'], dim) - 1,
                scope='scip'))

    def append_rf_cycle_constr(self, constr_list: list[SolverConstr]):
        """Append cycle constr to constr_list
        """
        # rf_comp_cycle
        constr_list.append(SolverConstr(
            'rf_comp_cycle',
            lambda var_d:
                var_d['rf_cycle']
                >= get_rf_comp_cycle_expr(self.get_schd_var_dict(var_d))))
        # rf_comm_cycle
        constr_list.append(SolverConstr(
            'rf_comm_cycle',
            lambda var_d:
                var_d['rf_cycle']
                >= get_rf_comm_cycle_expr(
                self.get_schd_var_dict(var_d),
                self.node_param.strides, 0),
            scope='gpkit'))
        constr_list.append(SolverConstr(
            'rf_comm_cycle',
            lambda var_d:
                var_d['rf_cycle']
                >= get_rf_comm_cycle_expr(
                self.get_schd_var_dict(var_d),
                self.node_param.strides),
            scope='scip'))
    
    def append_node_cycle_constr(self, constr_list: list[SolverConstr]):
        # abuf_cycle
        constr_list.append(SolverConstr(
            'abuf_cycle',
            lambda var_d:
                var_d['abuf_cycle']
                >= self.get_schd_prod(var_d, 'S', ['C', 'H', 'W'])
                * var_d['schd_F_C']
                * get_abuf_used_depth_expr(
                    self.get_schd_var_dict(var_d),
                    # self.node_param.paddings,
                    self.node_param.strides, 0)
                / self.arch_spec.dbus_width * self.arch_spec.data_width,
            scope='gpkit'))
        constr_list.append(SolverConstr(
            'abuf_cycle',
            lambda var_d:
                var_d['abuf_cycle']
                >= self.get_schd_prod(var_d, 'S', ['C', 'H', 'W'])
                * var_d['schd_F_C']
                * get_abuf_used_depth_expr(
                    self.get_schd_var_dict(var_d),
                    # self.node_param.paddings,
                    self.node_param.strides)
                / self.arch_spec.dbus_width * self.arch_spec.data_width,
            scope='scip'))
        # wbuf_cycle
        if self.node_param.use_weight:
            constr_list.append(SolverConstr(
                'wbuf_cycle',
                lambda var_d:
                    var_d['wbuf_cycle']
                    >= self.get_schd_prod(var_d, 'S', ['K', 'C', 'I', 'J'])
                    * self.get_schd_prod(var_d, 'F', ['K', 'C', 'I', 'J'])
                    * get_wbuf_used_depth_expr(self.get_schd_var_dict(var_d))
                    / self.arch_spec.dbus_width * self.arch_spec.data_width))
        # pe_cycle
        constr_list.append(SolverConstr(
            'pe_cycle',
            lambda var_d:
                var_d['pe_cycle']
                >= self.get_schd_prod(var_d, 'P') * var_d['rf_cycle']))
        # pbuf_cycle, F_HW per xfer
        constr_list.append(SolverConstr(
            'pbuf_cycle',
            lambda var_d:
                var_d['pbuf_cycle']
                >= list_prod(get_output_shape_expr(
                    self.get_schd_var_dict(var_d)['S'],
                    self.node_param.type))
                * list_prod(get_output_shape_expr(
                    self.get_schd_var_dict(var_d)['F'],
                    self.node_param.type))
                * get_pbuf_used_depth_expr(
                    self.get_schd_var_dict(var_d), self.node_param.type)
                / self.get_schd_prod(var_d, 'F', ['H', 'W'])))
        # pbuf_cycle, dbus_width/data_width per xfer
        constr_list.append(SolverConstr(
            'pbuf_cycle',
            lambda var_d:
                var_d['pbuf_cycle']
                >= list_prod(get_output_shape_expr(
                    self.get_schd_var_dict(var_d)['S'],
                    self.node_param.type))
                * list_prod(get_output_shape_expr(
                    self.get_schd_var_dict(var_d)['F'],
                    self.node_param.type))
                * get_pbuf_used_depth_expr(
                    self.get_schd_var_dict(var_d), self.node_param.type)
                / self.arch_spec.dbus_width * self.arch_spec.data_width))

    def append_obj_constr(self, constr_list: list[SolverConstr]):
        """Append objective to constr_list.
        """
        # w_ratio
        constr_list.append(SolverConstr(
            'w_ratio',
            lambda var_d:
                var_d['w_ratio']
                >= self.node_param.loop_bounds[5]
                / self.get_schd_prod(var_d, ['P','Q','F'], 'W')))
        # constr_list.append(SolverConstr(
        #     'w_ratio', lambda var_d: var_d['w_ratio']==1))
        if self.config['force_full_w']:
            # pqf_w>=l_w
            constr_list.append(SolverConstr(
                f"force_full_w",
                lambda var_d:
                    self.get_schd_prod(var_d, ['P','Q','F'], 'W')
                    >=self.node_param.loop_bounds[5]))
        # in_bound_cycle
        constr_list.append(SolverConstr(
            'in_bound_cycle',
            lambda var_d:
                var_d['in_bound_cycle']
                >= var_d['abuf_cycle']*var_d['w_ratio']+var_d['wbuf_cycle']))
        constr_list.append(SolverConstr(
            'in_bound_cycle',
            lambda var_d:
                var_d['in_bound_cycle'] >= var_d['pe_cycle']))
        #out_bound_cycle
        constr_list.append(SolverConstr(
            'out_bound_cycle',
            lambda var_d:
                var_d['out_bound_cycle'] >= var_d['pbuf_cycle']*var_d['w_ratio']))
        constr_list.append(SolverConstr(
            'out_bound_cycle',
            lambda var_d:
                var_d['out_bound_cycle'] >= var_d['in_bound_cycle']))
        if self.node_param.is_dpws:
            constr_list.append(SolverConstr(
                'obj',
                lambda var_d:
                    var_d['obj']
                    >= self.get_schd_prod(var_d, 'T', ['K', 'C', 'H', 'W'])
                    * var_d['out_bound_cycle']))
        else:
            constr_list.append(SolverConstr(
                'obj',
                lambda var_d:
                    var_d['obj']
                    >= self.get_schd_prod(var_d, 'T', ['K', 'C', 'H', 'W'])
                    * var_d['in_bound_cycle']
                    + self.get_schd_prod(var_d, 'T', ['K', 'H', 'W'])
                    * var_d['out_bound_cycle']))

    def get_schd_var_dict(self, var_d: dict) -> dict:
        """Return a dict of schd Variable for expr substitution.
        """
        return {
            level: tuple(var_d[f"schd_{level}_{dim}"] for dim in agna_dim_tuple)
            for level in agna_level_tuple}

    def get_schd_prod(
            self,
            var_d: dict,
            levels: list = agna_level_tuple,
            dims: list = agna_dim_tuple) -> Any:
        """list_prod(var_d[f"schd_[levels]_[dims]"])
        levels and dims can be single str or list of str.
        """
        return list_prod(
            [var_d[f"schd_{level}_{dim}"]
                for level in levels for dim in dims])

    def get_node_comp_cycle(self, var_d):
        return get_node_comp_cycle_expr(
            self.get_schd_var_dict(var_d),
            var_d['rf_cycle'])

    def get_node_comm_cycle(self, var_d, bias):
        return (
            self.get_node_comm_rd_cycle(var_d, bias)
            + self.get_node_comm_wr_cycle(var_d))

    def get_node_comm_rd_cycle(self, var_d, bias):
        return (
            get_node_comm_rd_size_expr(
                self.get_schd_var_dict(var_d),
                self.node_param.type,
                self.node_param.strides,
                self.node_param.use_bn,
                self.node_param.use_weight,
                self.node_param.use_add, bias)
            * var_d['rd_cycle_ratio']
            * self.arch_spec.data_width
            / self.arch_spec.dbus_width
            )
    
    def get_node_comm_wr_cycle(self, var_d):
        return (
            # get_node_comm_wr_size_expr(
            #     self.get_schd_var_dict(var_d),
            #     self.node_param.type)
            get_node_comm_wr_size_expr(
                self.get_schd_var_dict(var_d),
                self.node_param.type)
            * var_d['wr_cycle_ratio']
            * self.arch_spec.data_width
            / self.arch_spec.dbus_width)


    @property
    def arch_spec(self) -> ArchSpec:
        """Arch spec.
        """
        return self._arch_spec
    
    @property
    def node_param(self) -> NodeParam:
        """Node param.
        """
        return self._node_param

    # @property
    # def best_solution(self) -> ScheduleParam:
    #     """Get best solution.
    #     """
    #     return self._best_solution
    # @best_solution.setter
    # def best_solution(self, best_solution: Any) -> None:
    #     self.logger.error('Set in OpSchedule.')
    #     self._best_solution = best_solution

    @BaseRnR.default_config.getter
    def default_config(self) -> dict:
        dc = super().default_config.copy()
        dc.update({
            'force_full_w': False,
            'max_of_2': False,
        })
        return dc
