import json
import logging
import os
import re
from typing_extensions import Self

class MyJSONEncoder(json.JSONEncoder):

    def default(self, o):
        if isinstance(o, BaseParam):
            return dict(o)
        else:
            return super().default(o)

class BaseParam:
    """Base class for other param classes.
    """

    def __init__(self, params: dict) -> None:
        """Initialize BaseParam.

        Arguments:
            params: A dictionary of parameters.
        """
        self._logger = logging.getLogger(self.__class__.__name__)
        self.params = params

    def __iter__(self) -> iter:
        for k in self.get_param_keys():
            yield k, getattr(self, k)

    def save(self, path: str) -> None:
        with open(path, 'w') as f:
            str_tmp = json.dumps(self, indent=4, cls=MyJSONEncoder)
            # remove indent in list[int]
            str_tmp = re.sub(r"\n\s*(\d+,?)", r"\g<1> ", str_tmp)
            str_tmp = re.sub(r"(\d+)\s\n\s+\]", r"\g<1>]", str_tmp)
            f.write(str_tmp)
        self.logger.info(f"Saved to {path}")

    @classmethod
    def load(cls, path: str) -> Self:
        if os.path.exists(path):
            with open(path, 'r') as f:
                params = json.load(f)
            return cls(params)
        else:
            return None

    def summary(self) -> None:
        self.logger.info(f"Basic summary: {dict(self)}")

    @property
    def logger(self) -> logging.Logger:
        """Get logger.
        """
        return self._logger

    @staticmethod
    def get_param_keys() -> tuple[str]:
        """A tuple of required keys.
        """
        raise NotImplementedError

    @property
    def params(self) -> dict:
        """Param dict.
        """
        return self._params
    @params.setter
    def params(self, params: dict) -> None:
        for k in self.get_param_keys():
            if k in params:
                setattr(self, f"_{k}", params[k])
            else:
                self.logger.error(f"{k} is not in params: {params}")
                raise KeyError(f"{k} is not in params: {params}")
        self._params = params

    @property
    def name(self) -> str:
        """Platform name.
        """
        return self._name
