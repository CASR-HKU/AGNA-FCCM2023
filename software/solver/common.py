import os
import subprocess
import typing

import gpkit
import pyscipopt
from utils.common import list_sum, short_str


class SolverVar:
    def __init__(
        self,
        name,
        lb=None,
        ub=None,
        is_strict=False,
        scope="both",
        vtype="INTEGER",
        strict_ratio=1,
    ) -> None:
        """Initialize a SolverVar.

        Arguments:
            name: Name of the variable.
            lb: Lower bound.
            ub: Upper bound.
            is_strict: True if need to apply strict bound.
            scope: gpkit, scip or both.
            vtype: BINARY, INTEGER, IMPLINT or CONTINUOUS.
            strict_ratio: Ratio of strict bound.
        """
        self.name = name
        self.lb = lb
        self.ub = ub
        self.is_strict = is_strict
        self.scope = scope
        self.vtype = vtype
        self.strict_ratio = strict_ratio

    def __str__(self) -> str:
        return (
            f"{short_str(self.name)}"
            + f" [{str(self.lb):>8},{str(self.ub):>8}]"
            + f" {str(self.is_strict):>8}"
            + f" {self.scope:>8}"
        )

    def suitable(self, relaxed) -> bool:
        "True if suitable for given relaxed"
        return (
            self.scope == "common"
            or (relaxed and self.scope == "gpkit")
            or (not relaxed and self.scope == "scip")
        )

    @property
    def use_in_gpkit(self) -> bool:
        return self.scope in ["both", "gpkit"]

    @property
    def use_in_scip(self) -> bool:
        return self.scope in ["both", "scip"]

    @property
    def name(self) -> str:
        return self._name

    @name.setter
    def name(self, name):
        assert isinstance(name, str)
        self._name = name

    @property
    def lb(self) -> typing.Union[int, float, None]:
        return self._lb

    @lb.setter
    def lb(self, lb):
        assert isinstance(lb, (int, float, type(None)))
        self._lb = lb

    @property
    def ub(self) -> typing.Union[int, float, None]:
        return self._ub

    @ub.setter
    def ub(self, ub):
        assert isinstance(ub, (int, float, type(None)))
        self._ub = ub

    @property
    def is_strict(self) -> bool:
        return self._is_strict

    @is_strict.setter
    def is_strict(self, is_strict):
        assert isinstance(is_strict, bool)
        self._is_strict = is_strict

    @property
    def scope(self) -> str:
        """Scope of variable. gpkit, scip or both."""
        return self._scope

    @scope.setter
    def scope(self, scope):
        assert scope in [
            "gpkit",
            "scip",
            "both",
        ]
        self._scope = scope

    @property
    def vtype(self) -> str:
        """Variable type in scip. BINARY, INTEGER, IMPLINT or CONTINUOUS"""
        return self._vtype

    @vtype.setter
    def vtype(self, vtype):
        assert vtype in ["BINARY", "INTEGER", "IMPLINT", "CONTINUOUS"]
        self._vtype = vtype

    @property
    def strict_ratio(self) -> float:
        return self._strict_ratio

    @strict_ratio.setter
    def strict_ratio(self, strict_ratio):
        self._strict_ratio = strict_ratio


class SolverConstr:
    def __init__(self, name, func, scope="both") -> None:
        self.name = name
        self.func = func
        self.scope = scope

    def __call__(self, gp_vars):
        """Substitude function with given gp_vars."""
        return self.func(gp_vars)

    def __str__(self) -> str:
        scope_str = f"[{self.scope}]".ljust(8)
        return f"{short_str(self.name)} {scope_str}  "

    @property
    def use_in_gpkit(self) -> bool:
        return self.scope in ["both", "gpkit"]

    @property
    def use_in_scip(self) -> bool:
        return self.scope in ["both", "scip"]

    @property
    def name(self) -> str:
        return self._name

    @name.setter
    def name(self, name) -> typing.Any:
        assert isinstance(name, str)
        self._name = name

    @property
    def func(self) -> typing.Callable:
        """Callable function to build constrs."""
        return self._func

    @func.setter
    def func(self, func):
        assert callable(func)
        self._func = func

    @property
    def scope(self) -> str:
        return self._scope

    @scope.setter
    def scope(self, scope):
        assert scope in [
            "both",
            "gpkit",
            "scip",
        ]
        self._scope = scope


def save_gpkit_model(model, path) -> bool:
    """Save gpkit model to path.

    Return True if saved, False if failed.
    """
    try:
        assert isinstance(model, gpkit.Model)
        open(path, "w").write(str(model))
    except Exception as e:
        # logging.exception(e)
        return False
    else:
        return True


def save_gpkit_sol(model, path) -> bool:
    """Save solution of gpkit model to path.

    Return True if saved, False if failed.
    """
    try:
        assert isinstance(model, gpkit.Model)
        open(path, "w").write(model.solution.table())
    except Exception as e:
        # logging.exception(e)
        return False
    else:
        return True


def convert_gpkit_sol2solval(gpkit_sol) -> typing.Dict[str, float]:
    """Convert gpkit_sol to dict of k,v = var_name,var_val."""
    solval = dict([(var.name, val) for var, val in gpkit_sol["variables"].items()])
    return solval


def save_scip_model(model, path) -> bool:
    """Save scip model to path.

    Return True if saved, False if failed.
    """
    try:
        assert isinstance(model, pyscipopt.Model)
        open(path, "w").write("")
        model.writeProblem(path)
    except Exception as e:
        # logging.exception(e)
        return False
    else:
        return True


def solve_scip_model_cmd(model, maxnthreads, timelimits, path_prefix, logger):
    log_path = f"{path_prefix}.log"
    cip_path = f"{path_prefix}.cip"
    sol_path = f"{path_prefix}.sol"
    scip_cmd_list = [
        os.path.join(os.environ["SCIPOPTDIR"], "bin/scip"),
        "-l",
        log_path,
        "-c",
        f"read {cip_path}",
        "-c",
        f"set parallel maxnthreads {maxnthreads}",
        "-c",
        "set write printzeros TRUE",
        "-c",
        f"set limits time {timelimits}",
        "-c",
        "concurrentopt",
        "-c",
        f"write solution {sol_path}",
        "-c",
        "quit",
    ]
    logger.info("Run cmd:\n" + list_sum([cmd + " " for cmd in scip_cmd_list]))
    with open(log_path, "w") as f:
        f.write("")  # clear scip log before run
    try:
        cmpl_p = subprocess.run(scip_cmd_list, timeout=timelimits + 10)
    except subprocess.SubprocessError as e:
        logger.error("SubprocessError: " + str(e))
    if os.path.isfile(sol_path):
        model.readSol(sol_path)
        best_sol = model.getSols()[0]
        if model.checkSol(best_sol):
            best_solval = convert_scip_sol2solval(model, best_sol)
        else:
            best_solval = None
            logger.warning("Solution infeasible.")
    else:
        best_solval = None
        logger.error("Solution not found.")
    return best_solval


def convert_scip_sol2solval(scip_model, scip_sol) -> typing.Dict[str, float]:
    """Convert scip_sol to dict of (var_name, var_val)"""
    solval = dict(
        (var.name, int(round(scip_model.getSolVal(scip_sol, var))))
        for var in scip_model.getVars()
    )
    if not "obj" in solval.keys():
        solval["obj"] = int(round(scip_model.getSolObjVal(scip_sol)))
    return solval
