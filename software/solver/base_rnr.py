import logging
import os
from typing import Any

import numpy as np
from solver.common import SolverConstr, SolverVar

from solver.gpkit_solver import MyGPKITSolver
from solver.scip_solver import MySCIPSolver


class BaseRnR:
    """Base class for relaxtion and rounding."""

    def __init__(self, path_prefix: str, config: dict, best_solution=None) -> None:
        """Initialize BaseRnR."""
        self._logger = logging.getLogger(self.__class__.__name__)
        self.path_prefix = path_prefix
        self.best_solution = best_solution
        self.config = config
        self.logger.info(f"Path prefix: {path_prefix}")
        for k, v in self.config.items():
            self.logger.info(f"Config['{k}']: {v}")

    def optimize(self) -> None:
        """Optimize problem."""
        # build and solve relaxation problem
        var_list = self.build_var_list()
        constr_list = self.build_constr_list()
        solver_r = MyGPKITSolver(var_list, constr_list)
        solver_r.build(self.path_prefix)
        solval_r = solver_r.solve(self.path_prefix)
        self.logger.debug(f"Relaxation solution: {solval_r}")
        # build and solve integer problem
        self.append_strict_bound(var_list, solval_r)
        solver_i = MySCIPSolver(var_list, constr_list)
        solver_i.build(self.path_prefix)
        solval_i = solver_i.solve(
            self.config["maxnthreads"], self.config["timelimits"], self.path_prefix
        )
        self.logger.debug(f"Integer solution: {solval_i}")
        # build best ArchSpec
        if solval_i is not None:
            self.build_best_solution(solval_i)
        else:
            self.best_solution = None

    def append_strict_bound(self, var_list: list[SolverVar], bound_center):
        self.logger.info("Append strict bound.")
        for var in var_list:
            if var.is_strict:
                center_tmp = bound_center[var.name]
                isclose = self.config["use_close"] and np.isclose(
                    center_tmp, round(center_tmp)
                )
                range_tmp = (
                    self.config["bound_range"] * var.strict_ratio / 2
                    if isclose
                    else self.config["bound_range"] * var.strict_ratio
                )
                origin_lb = var.lb
                strict_lb = (
                    round(center_tmp - range_tmp)
                    if self.config["add_bound"]
                    else round(center_tmp / range_tmp)
                )
                new_lb = strict_lb if origin_lb is None else max(strict_lb, origin_lb)
                var.lb = new_lb
                self.logger.debug(f"{var.name} lb: {origin_lb} -> {new_lb}")
                origin_ub = var.ub
                strict_ub = (
                    round(center_tmp + range_tmp)
                    if self.config["add_bound"]
                    else round(center_tmp * range_tmp)
                )
                new_ub = strict_ub if origin_ub is None else min(strict_ub, origin_ub)
                var.ub = new_ub
                self.logger.debug(f"{var.name} ub: {origin_ub} -> {new_ub}")

    def build_var_list(self) -> list[SolverVar]:
        """Build variable list.

        Returns:
            var_list: List of SolverVar.
        """
        self.logger.error("build_var_list() not implemented.")
        raise NotImplementedError()

    def build_constr_list(self) -> list[SolverConstr]:
        """Build constraint list.

        Returns:
            constr_list: List of SolverConstr.
        """
        self.logger.error("build_var_list() not implemented.")
        raise NotImplementedError()

    def build_best_solution(self, solval_i: dict) -> None:
        """Build best result.

        Arguments:
            solval_i: Solution value of integer problem.
        """
        self.logger.error("build_var_list() not implemented.")
        raise NotImplementedError()

    @property
    def logger(self) -> logging.Logger:
        """Get logger."""
        return self._logger

    @property
    def path_prefix(self) -> str:
        """Path prefix."""
        return self._path_prefix

    @path_prefix.setter
    def path_prefix(self, path_prefix: str) -> None:
        try:
            open(path_prefix + ".test", "w").write("")
            os.remove(path_prefix + ".test")
        except Exception as e:
            self.logger.error(f"Invalid path_prefix: {path_prefix}")
            raise ValueError(f"Invalid path_prefix: {path_prefix}") from e
        self._path_prefix = path_prefix

    @property
    def best_solution(self) -> Any:
        """Get best solution."""
        return self._best_solution

    @best_solution.setter
    def best_solution(self, best_solution: Any) -> None:
        self._best_solution = best_solution

    @property
    def default_config(self) -> dict:
        return {
            "bound_range": np.e,
            "add_bound": False,
            "bound_space": None,
            "use_close": True,
            "maxnthreads": 6,
            "timelimits": 300,
        }

    @property
    def config(self) -> dict:
        """Config dict."""
        return self._config

    @config.setter
    def config(self, config: dict) -> None:
        new_config = self.default_config.copy()
        for k, v in config.items():
            if k in new_config:
                new_config[k] = v
            else:
                self.logger.error(f"Unknown config key: {k}")
        self._config = new_config
