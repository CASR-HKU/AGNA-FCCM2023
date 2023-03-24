import gpkit
import logging
from solver.common import SolverConstr, SolverVar
from solver.common import save_gpkit_model, save_gpkit_sol, convert_gpkit_sol2solval


class MyGPKITSolver:
    def __init__(self, var_list: list[SolverVar], constr_list: list[SolverConstr]):
        """Build constraint list and variable dict."""
        self._logger = logging.getLogger(self.__class__.__name__)
        self.var_list = var_list
        self.constr_list = constr_list

    def build(self, path_prefix: str) -> None:
        """Build gpkit model and save model to path.

        Arguments:
            path: Path to save solution.
        """
        self.logger.info("Start build")
        self.build_model()
        save_status = save_gpkit_model(self.model, path_prefix + "_gpkit.model")
        self.logger.info(f"gpkit_model saved: {save_status}")

    def solve(self, path_prefix: str) -> dict:
        """Solve gpkit model and save solution to path.

        Arguments:
            path: Path to save solution.
        Returns:
            solval: Dict of solution.
        """
        self.logger.info("Start solve")
        # solve
        try:
            gpkit_sol = self.model.solve(verbosity=2)
        except Exception as e:
            self.logger.exception(e)
            raise RuntimeError
        save_status = save_gpkit_sol(self.model, path_prefix + "_gpkit.sol")
        self.logger.info(f"gpkit_sol saved: {save_status}")
        # convert
        solval = convert_gpkit_sol2solval(gpkit_sol)
        self.logger.info(f"Optimize done with obj = {solval['obj']}")
        return solval

    def check(self, solval: dict) -> None:
        """Check violation of solval in self.constr_list and write to debug.

        Arguments:
            solval: Dict of solution.
        """
        for constr_info in self.constr_list:
            if constr_info.use_in_gpkit:
                violate = not constr_info(solval)
                if violate:
                    self.logger.debug(str(constr_info))

    def build_model(self) -> None:
        """Build gpkit model."""
        # build and add vars
        gpkit_vars = self.build_vars()
        # build var bound
        gpkit_bounds = self.build_bounds(gpkit_vars)
        # build constrs
        gpkit_constrs = self.build_constrs(gpkit_vars)
        # build model
        self.model = gpkit.Model(gpkit_vars["obj"], gpkit_bounds + gpkit_constrs)
        # self.model = gpkit.Model(gpkit_vars['obj'], Bounded(gpkit_bounds + gpkit_constrs))

    def build_vars(self) -> dict:
        """Build variables for model based on var_list.

        Returns:
            gpkit_vars: Dict of gpkit.Variable.
        """
        gpkit_vars = {}
        for var in self.var_list:
            if var.use_in_gpkit:
                self.logger.debug(var)
                gpkit_vars[var.name] = gpkit.Variable(name=var.name)
        return gpkit_vars

    def build_bounds(self, gpkit_vars) -> list:
        """Set variable bound for gpkit model.

        Arguments:
            gpkit_vars: Dict of gpkit.Variable
        Returns:
            gpkit_bounds: List of expr.
        """
        gpkit_bounds = []
        for var in self.var_list:
            if var.use_in_gpkit:
                if var.lb is not None:
                    gpkit_bounds.append(gpkit_vars[var.name] >= var.lb)
                if var.ub is not None:
                    gpkit_bounds.append(gpkit_vars[var.name] <= var.ub)
        return gpkit_bounds

    def build_constrs(self, gpkit_vars) -> list:
        """Build constraints for model based on self.constr_list.

        Arguments:
            gpkit_vars: Dict of gpkit.Variable
        Returns:
            gpkit_constrs: List of expr.
        """
        gpkit_constrs = []
        for constr in self.constr_list:
            if constr.use_in_gpkit:
                constr_expr = constr(gpkit_vars)
                self.logger.debug(str(constr) + str(constr_expr))
                gpkit_constrs.append(constr_expr)
        return gpkit_constrs

    @property
    def logger(self) -> logging.Logger:
        """Get logger."""
        return self._logger

    @property
    def model(self) -> gpkit.Model:
        return self._model

    @model.setter
    def model(self, model):
        assert isinstance(model, gpkit.Model)
        self._model = model

    @property
    def var_list(self) -> list[SolverVar]:
        return self._var_list

    @var_list.setter
    def var_list(self, var_list):
        self._var_list = var_list

    @property
    def constr_list(self) -> list[SolverConstr]:
        return self._constr_list

    @constr_list.setter
    def constr_list(self, constr_list):
        self._constr_list = constr_list
