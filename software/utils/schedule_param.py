from functools import reduce
from utils.base_param import BaseParam
from utils.common import agna_level_tuple, list_sum

class ScheduleParam(BaseParam):

    def __str__(self) -> str:
        return list_sum(
            reduce(
                lambda s1, s2: f"{s1} {s2}",
                (getattr(self, k) for k in self.get_param_keys())))

    def __repr__(self) -> str:
        return list_sum(
            reduce(
                lambda s1, s2: f"{s1} {s2}",
                (getattr(self, k) for k in self.get_param_keys())))

    @property
    def TS(self) -> tuple:
        return tuple(self.T[d]*self.S[d] for d in range(6))

    @property
    def PQF(self) -> tuple:
        return tuple(self.P[d]*self.Q[d]*self.F[d] for d in range(6))

    @staticmethod
    def get_param_keys() -> tuple[str]:
        """A tuple of required keys.
        """
        return agna_level_tuple

    @BaseParam.params.setter
    def params(self, params: dict) -> None:
        new_params = {}
        for k in self.get_param_keys():
            new_params[k] = tuple(params[k])
        BaseParam.params.fset(self, new_params)

    @property
    def T(self) -> tuple:
        """ Schedule param on T level, tuple(T_<K, C, I, J, H, W>).
        """
        return self._T

    @property
    def S(self) -> tuple:
        """ Schedule param on S level, tuple(S_<K, C, I, J, H, W>).
        """
        return self._S

    @property
    def P(self) -> tuple:
        """ Schedule param on P level, tuple(P_<K, C, I, J, H, W>).
        """
        return self._P

    @property
    def Q(self) -> tuple:
        """ Schedule param on Q level, tuple(Q_<K, C, I, J, H, W>).
        """
        return self._Q

    @property
    def F(self) -> tuple:
        """ Schedule param on F level, tuple(F_<K, C, I, J, H, W>).
        """
        return self._F
