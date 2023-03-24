from solver.base_rnr import BaseRnR
from solver.common import SolverVar, SolverConstr
from solver.gpkit_solver import MyGPKITSolver
from solver.scip_solver import MySCIPSolver
from utils.arch_spec import (
    ArchSpec,
    get_packed_dsp_num_expr,
    get_total_bram_num_expr,
    get_total_dsp_num_expr,
)
from utils.common import agna_dim_tuple, list_prod, list_sum
from utils.model_spec import ModelSpec
from utils.perf_eval import PlatformPerf
from utils.platform_spec import PlatformSpec


class ArchSearch(BaseRnR):
    def __init__(
        self,
        pltfm_spec: PlatformSpec,
        model_spec_list: list[ModelSpec],
        path_prefix: str,
        config: dict,
    ) -> None:
        super().__init__(path_prefix, config)
        self._pltfm_spec = pltfm_spec
        self._model_spec_list = model_spec_list
        self.logger.info(f"Platform: {self.pltfm_spec.name}")
        self.logger.info(f"Models: {[ms.name for ms in self.model_spec_list]}")

    def build_var_list(self) -> list[SolverVar]:
        """Build var_list.

        Returns:
            var_list: List of SolverVar.
        """
        var_list = []
        # A_X, architecture
        for dim in agna_dim_tuple:
            var_list.append(SolverVar(f"A_{dim}", lb=1, is_strict=True))
        # packed_dsp_num
        var_list.append(SolverVar("packed_dsp_num", lb=1))
        # pe_num
        var_list.append(SolverVar("pe_num", lb=1))
        for ms in self.model_spec_list:
            for node in ms.unique_nodes:
                model_node = f"{ms.name}_{node.name}"
                for dim in agna_dim_tuple:
                    # cycle on each dim
                    var_list.append(SolverVar(f"{model_node}_cycle_{dim}", lb=1))
                    # S on each dim
                    var_list.append(
                        SolverVar(f"{model_node}_S_{dim}", lb=1, is_strict=False)
                    )
                # node cycle
                var_list.append(SolverVar(f"{model_node}_cycle", lb=1))
        var_list.append(SolverVar("obj", lb=1))
        return var_list

    def build_constr_list(self) -> list[SolverConstr]:
        """Build constr_list.

        Returns:
            constr_list: List of SolverConstr.
        """
        constr_list = []
        self.append_arch_constr(constr_list)
        self.append_resource_constr(constr_list)
        self.append_node_constr(constr_list)
        self.append_obj_constr(constr_list)
        return constr_list

    def build_best_solution(self, solval_i: dict) -> None:
        """Build best result."""
        arch_dict = {
            "pe_arch": tuple(int(solval_i["A_" + dim]) for dim in agna_dim_tuple),
            "pe_num": int(solval_i["pe_num"]),
            "buf_arch": self.config["buf_arch"],
            "rf_arch": self.config["rf_arch"],
            "dbus_width": self.pltfm_spec.dbus_width,
            "data_width": self.pltfm_spec.data_width,
        }
        self.best_solution = ArchSpec(arch_dict)

    def append_arch_constr(self, constr_list: list[SolverConstr]):
        """Append architecture constr to constr_list."""
        # A_I <= A_J
        constr_list.append(
            SolverConstr("arch_I_le_J", lambda var_d: var_d["A_I"] <= var_d["A_J"])
        )
        # A_H <= A_W
        constr_list.append(
            SolverConstr("arch_H_le_W", lambda var_d: var_d["A_H"] <= var_d["A_W"])
        )
        # A_H * A_W <= 32
        constr_list.append(
            SolverConstr("arch_HW", lambda var_d: var_d["A_H"] * var_d["A_W"] <= 32)
        )
        constr_list.append(SolverConstr("arch_PE", lambda var_d: var_d["pe_num"] >= 16))
        constr_list.append(
            SolverConstr("arch_PE", lambda var_d: var_d["pe_num"] <= 128)
        )
        # constr_list.append(SolverConstr(
        #     'dsp_num',
        #     lambda var_d: var_d['A_K']*var_d['A_C']*var_d['A_I']*var_d['A_J']*var_d['A_H']*var_d['A_W']<=128))

    def append_resource_constr(self, constr_list: list[SolverConstr]):
        """Append hardware resource constr to constr_list."""
        # packed_dsp_num constr
        constr_list.append(
            SolverConstr(
                "packed_dsp_num",
                lambda var_d: get_packed_dsp_num_expr(
                    [var_d[f"A_{dim}"] for dim in agna_dim_tuple],
                    self.config["pack_dsp"],
                )
                <= var_d["packed_dsp_num"],
            )
        )
        # total_dsp_num constr
        constr_list.append(
            SolverConstr(
                "total_dsp_num",
                lambda var_d: get_total_dsp_num_expr(
                    [var_d[f"A_{dim}"] for dim in agna_dim_tuple],
                    var_d["packed_dsp_num"],
                    var_d["pe_num"],
                )
                <= self.pltfm_spec.max_dsp * 0.9,
            )
        )
        # total_bram_num constr
        constr_list.append(
            SolverConstr(
                "total_bram_num",
                lambda var_d: get_total_bram_num_expr(
                    [var_d[f"A_{dim}"] for dim in agna_dim_tuple],
                    var_d["pe_num"],
                    self.config["buf_arch"],
                )
                <= self.pltfm_spec.max_bram * 0.9,
            )
        )

    def append_node_constr(self, constr_list: list[SolverConstr]):
        """Append constr of each node to constr_list."""
        for ms in self.model_spec_list:
            for node in ms.unique_nodes:
                model_node = f"{ms.name}_{node.name}"
                c_key = f"{model_node}_cycle"
                s_key = f"{model_node}_S"
                for idx, dim in enumerate(agna_dim_tuple):
                    cd_key = f"{c_key}_{dim}"
                    sd_key = f"{s_key}_{dim}"
                    ad_key = f"A_{dim}"
                    # loop bound
                    bound = node.loop_bounds[idx]
                    # K C dim in dpws node
                    if node.is_dpws and dim in ["K", "C"]:
                        # node_cycle_d*node_S_d>=node_L_d
                        constr_list.append(
                            SolverConstr(
                                f"{model_node}_{dim}_lb",
                                lambda var_d, cdk=cd_key, sdk=sd_key, lb=bound: var_d[
                                    cdk
                                ]
                                * var_d[sdk]
                                >= lb,
                            )
                        )
                        constr_list.append(
                            SolverConstr(
                                f"{model_node}_{dim}_ub",
                                lambda var_d, cdk=cd_key, sdk=sd_key, lb=bound: var_d[
                                    cdk
                                ]
                                * var_d[sdk]
                                <= lb + var_d[sdk] - 1,
                                scope="scip",
                            )
                        )  # maybe too tight
                    # others
                    else:
                        # node_cycle_d*node_S_d*A_d>=node_L_d
                        constr_list.append(
                            SolverConstr(
                                f"{model_node}_{dim}_lb",
                                lambda var_d, cdk=cd_key, sdk=sd_key, adk=ad_key, lb=bound: var_d[
                                    cdk
                                ]
                                * var_d[sdk]
                                * var_d[adk]
                                >= lb,
                            )
                        )
                        # # A_d*cycle_d<=L_d+A_d-1, scip only
                        constr_list.append(
                            SolverConstr(
                                f"{model_node}_{dim}_ub",
                                lambda var_d, cdk=cd_key, sdk=sd_key, adk=ad_key, lb=bound: var_d[
                                    cdk
                                ]
                                * var_d[sdk]
                                * var_d[adk]
                                <= lb + var_d[sdk] * var_d[adk] - 1,
                                scope="scip",
                            )
                        )  # maybe too tight
                # consider S
                if self.config["consider_s"]:
                    # prod(node_S_d)<=pe_num
                    constr_list.append(
                        SolverConstr(
                            f"{model_node}_S_constr",
                            lambda var_d, sk=s_key: list_prod(
                                [var_d[f"{sk}_{dim}"] for dim in agna_dim_tuple]
                            )
                            <= var_d["pe_num"],
                        )
                    )
                    # node_cycle==prod(node_cycle_d)
                    constr_list.append(
                        SolverConstr(
                            f"{model_node}_comp_cycle",
                            lambda var_d, ck=c_key: var_d[ck]
                            == list_prod(
                                [var_d[f"{ck}_{dim}"] for dim in agna_dim_tuple]
                            ),
                        )
                    )
                # ignore S
                else:
                    for dim in agna_dim_tuple:
                        sd_key = f"{s_key}_{dim}"
                        # node_S_d=1
                        constr_list.append(
                            SolverConstr(
                                f"{model_node}_{dim}_S_constr",
                                lambda var_d, sdk=sd_key: var_d[sdk] == 1,
                            )
                        )
                    # node_cycle>=prod(node_cycle_d)/pe_num
                    constr_list.append(
                        SolverConstr(
                            f"{model_node}_comp_cycle",
                            lambda var_d, ck=c_key: var_d[ck]
                            >= list_prod(
                                [var_d[f"{ck}_{dim}"] for dim in agna_dim_tuple]
                            )
                            / var_d["pe_num"],
                        )
                    )
                if not self.config["ignore_comm"]:
                    pltfm_perf = PlatformPerf(self.pltfm_spec, node).evaluate()
                    # pltfm_perf = node.eval_platform(self.pltfm_spec)
                    if self.config["max_of_2"]:
                        comm_cycle = pltfm_perf["theo_comm_cycle"]
                    else:
                        comm_cycle = max(
                            pltfm_perf["theo_comm_rd_cycle"],
                            pltfm_perf["theo_comm_wr_cycle"],
                        )
                    # node_cycle>=comm_cycle
                    constr_list.append(
                        SolverConstr(
                            f"{model_node}_comm_cycle",
                            lambda var_d, ck=c_key, cc=comm_cycle: var_d[ck] >= cc,
                        )
                    )

    def append_obj_constr(self, constr_list: list[SolverConstr]):
        """Append objective to constr_list."""
        # gpkit does not support Monomial == Posynomial
        constr_list.append(
            SolverConstr(
                f"objective",
                lambda var_d: var_d["obj"]
                >= list_prod(
                    [
                        list_sum(
                            [
                                var_d[f"{ms.name}_{node.name}_cycle"] * node.unique_cnt
                                for node in ms.unique_nodes
                            ]
                        )
                        for ms in self.model_spec_list
                    ]
                ),
                scope="gpkit",
            )
        )
        constr_list.append(
            SolverConstr(
                f"objective",
                lambda var_d: var_d["obj"]
                == list_prod(
                    [
                        list_sum(
                            [
                                var_d[f"{ms.name}_{node.name}_cycle"] * node.unique_cnt
                                for node in ms.unique_nodes
                            ]
                        )
                        for ms in self.model_spec_list
                    ]
                ),
                scope="scip",
            )
        )

    @property
    def pltfm_spec(self) -> PlatformSpec:
        """Platform spec."""
        return self._pltfm_spec

    @property
    def model_spec_list(self) -> list[ModelSpec]:
        """A list of ModelSpec."""
        return self._model_spec_list

    # @property
    # def best_solution(self) -> ArchSpec:
    #     """Get best solution.
    #     """
    #     return self._best_solution

    @BaseRnR.default_config.getter
    def default_config(self) -> dict:
        dc = super().default_config.copy()
        dc.update(
            {
                "consider_s": False,
                "buf_arch": [2, 2, 1],
                "rf_arch": 1024,
                "pack_dsp": False,
                "ignore_comm": False,
                "max_of_2": False,
            }
        )
        return dc
