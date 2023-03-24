from utils.base_param import BaseParam
from utils.node_param import NodeParam


class ModelSpec(BaseParam):
    def summary(self) -> None:
        self.logger.info(f"Summary of {self.name}:")
        self.logger.info(NodeParam.get_header())
        for node in self.nodes:
            self.logger.info(str(node))

    def get_node(self, name: str) -> NodeParam:
        for node in self.nodes:
            if node.name == name:
                return node
        return None

    @property
    def unique_nodes(self) -> list[NodeParam]:
        """Get unique nodes.
        """
        unique_nodes = []
        for node in self.nodes:
            if node.unique_cnt >= 1:
                unique_nodes.append(node)
        return unique_nodes

    @staticmethod
    def get_param_keys() -> tuple[str]:
        """A tuple of dictionary keys. All required when save.
        """
        return (
            'name',
            'pe_num',
            'nodes',
        )

    @BaseParam.params.setter
    def params(self, params: dict) -> None:
        new_params = {}
        new_params.update(params)
        new_params.setdefault('pe_num', 0)
        new_params.setdefault('nodes', [])
        for idx, node in enumerate(new_params['nodes']):
            new_params['nodes'][idx] = (node if isinstance(node, NodeParam)
                                        else NodeParam(node))
        BaseParam.params.fset(self, new_params)

    @property
    def name(self) -> str:
        """Model name.
        """
        return self._name

    @property
    def pe_num(self) -> int:
        """Number of PEs.
        """
        return self._pe_num

    @pe_num.setter
    def pe_num(self, pe_num: int) -> None:
        self._pe_num = pe_num

    @property
    def nodes(self) -> list[NodeParam]:
        """A list of NodeParam.
        """
        return self._nodes
