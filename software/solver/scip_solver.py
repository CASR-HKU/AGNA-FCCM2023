from unicodedata import name
import pyscipopt
import logging
from solver.common import SolverConstr, SolverVar
from solver.common import save_scip_model, solve_scip_model_cmd

class MySCIPSolver():

    def __init__(
            self,
            var_list:list[SolverVar],
            constr_list:list[SolverConstr]):
        """Build constraint list and variable dict.
        """
        self._logger = logging.getLogger(self.__class__.__name__)
        self.var_list = var_list
        self.constr_list = constr_list

    def build(self, path_prefix: str) -> None:
        """Build scip model and save model to path.
        
        Arguments:
            path_prefix: path_prefix to save solution.
        """
        self.logger.info("Start build")
        self.build_model()
        save_status = save_scip_model(self.model, path_prefix+'_scip.cip')
        self.logger.info(f"scip_model saved: {save_status}")

    def solve(self, maxnthreads : int, timelimits : int, path_prefix: str) -> dict:
        """Solve scip model and save solution to path.
        
        Arguments:
            maxnthreads: Max number of threads.
            timelimits: Time limit.
            path_prefix: path_prefix to save solution.
        Returns:
            solval: Dict of solution.
        """
        self.logger.info("Start solve")
        # solve
        solval = solve_scip_model_cmd(self.model, maxnthreads, timelimits, path_prefix+'_scip', self.logger)
        if solval is None:
            self.logger.info("No solution")
        else:
            self.logger.info(f"Optimize done with obj = {solval['obj']}")
        return solval

    def check(self, solval: dict) -> None:
        """Check violation of solval in self.constr_list and write to debug.
        
        Arguments:
            solval: Dict of solution.
        """
        for constr_info in self.constr_list:
            if constr_info.use_in_scip:
                violate = not constr_info(solval)
                if violate:
                    self.logger.debug(str(constr_info))

    def build_model(self) -> None:
        """Build scip model.
        """
        # build model
        scip_model = pyscipopt.Model()
        # build and add vars
        scip_vars = self.build_vars(scip_model)
        # build constrs
        scip_constrs = self.build_constrs(scip_model, scip_vars)
        # set objective
        scip_model.setObjective(scip_vars['obj'])
        self.model = scip_model

    def build_vars(self, scip_model: pyscipopt.Model) -> dict:
        """Build variables for model based on var_list.
        
        Arguments:
            scip_model: scip model.
        Returns:
            scip_vars: Dict of scip.Variable.
        """
        scip_vars = {}
        for var in self.var_list:
            if  var.use_in_scip:
                self.logger.debug(var)
                scip_vars[var.name] = scip_model.addVar(
                    name=var.name, vtype=var.vtype, lb=var.lb, ub=var.ub)
        return scip_vars

    def build_constrs(self, scip_model: pyscipopt.Model, scip_vars) -> list:
        """Build constraints for model based on self.constr_list.
        
        Arguments:
            scip_model: scip model.
            scip_vars: Dict of scip.Variable
        Returns:
            scip_constrs: List of expr.
        """
        scip_constrs = []
        for constr in self.constr_list:
            if  constr.use_in_scip:
                constr_expr = constr(scip_vars)
                self.logger.debug(str(constr) + str(constr_expr))
                scip_model.addCons(constr_expr, name=constr.name)
        return scip_constrs

    @property
    def logger(self) -> logging.Logger:
        """Get logger.
        """
        return self._logger
    
    @property
    def model(self) -> pyscipopt.Model:
        return self._model
    @model.setter
    def model(self, model):
        assert isinstance(model, pyscipopt.Model)
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
