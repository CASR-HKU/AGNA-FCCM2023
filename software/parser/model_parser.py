import logging

import keras
from parser.layer_parser import LayerParser
from utils.model_spec import ModelSpec
from utils.node_param import NodeParam


class ModelParser:
    """Model parser.
    """

    def __init__(self, model: keras.Model) -> None:
        self._logger = logging.getLogger(self.__class__.__name__)
        self._model = model
        self.logger.info(f"init ModelParser({model.name})")
        pass

    @property
    def logger(self) -> logging.Logger:
        """Get logger.
        """
        return self._logger

    def parse(self) -> ModelSpec:
        """Parse the model and return a ModelSpec.
        """
        ms_param = {'name': self.model.name}
        ms = ModelSpec(ms_param)
        # extract nodes
        for layer in self.model.layers:
            base_lp = LayerParser(layer)
            # mark input layer
            if base_lp.is_input:
                layer.parsed_by_agna = True
            # create node for each compute layer
            if base_lp.is_comp:
                param_dict = base_lp.get_comp_param()
                node_param = NodeParam(param_dict)
                self.logger.debug(f"Create node: {node_param}.")
                # find padding layer in inbound layers
                for inb_layer in base_lp.get_inbound_layers():
                    inb_lp = LayerParser(inb_layer)
                    if inb_lp.is_padding:
                        padding_param = inb_lp.get_padding_param()
                        node_param.set_extra_paddings(padding_param)
                        node_param.layer_name_list.append(inb_layer.name)
                        self.logger.debug('  padding: '.ljust(16) + str(inb_lp))
                        inb_layer.parsed_by_agna = True
                        break
                # mark compute layer
                node_param.layer_name_list.append(layer.name)
                layer.parsed_by_agna = True
                self.logger.debug('  compute: '.ljust(16) + str(base_lp))
                # find bn layer in outbound layers
                for otb_layer in base_lp.get_outbound_layers():
                    otb_lp = LayerParser(otb_layer)
                    if otb_lp.is_bn:
                        node_param.set_use_bn(True)
                        node_param.layer_name_list.append(otb_layer.name)
                        self.logger.debug('  bn: '.ljust(16) + str(otb_lp))
                        otb_layer.parsed_by_agna = True
                        base_lp = otb_lp
                        break
                # find add layer in outbound layers
                for otb_layer in base_lp.get_outbound_layers():
                    otb_lp = LayerParser(otb_layer)
                    if otb_lp.is_add:
                        # only add when all inbound layers are parsed
                        if (all(hasattr(inb_otb_layer, 'parsed_by_agna')
                                for inb_otb_layer
                                in otb_lp.get_inbound_layers())):
                            node_param.set_use_add(True)
                            node_param.layer_name_list.append(otb_layer.name)
                            node_param.add_layer_name = otb_layer.name
                            self.logger.debug('  add: '.ljust(16) + str(otb_lp))
                            otb_layer.parsed_by_agna = True
                            base_lp = otb_lp
                        break
                # find act layer in outbound layers
                for otb_layer in base_lp.get_outbound_layers():
                    otb_lp = LayerParser(otb_layer)
                    if otb_lp.is_act:
                        node_param.set_use_act(True)
                        node_param.layer_name_list.append(otb_layer.name)
                        self.logger.debug('  act: '.ljust(16) + str(otb_lp))
                        otb_layer.parsed_by_agna = True
                        base_lp = otb_lp
                        break
                ms.nodes.append(node_param)
        # warnning on unparsed layers
        for layer in self.model.layers:
            if not hasattr(layer, 'parsed_by_agna'):
                self.logger.warning(f"{layer.name}({layer.__class__.__name__})"
                + f" is not parsed.")
        # analyze topology
        for node in ms.nodes:
            # find input source
            base_layer = self.model.get_layer(node.layer_name_list[0])
            base_lp = LayerParser(base_layer)
            if len(base_lp.get_inbound_layers())!=1:
                self.logger.error(f"Layer {base_layer.name}"
                + f"({base_layer.__class__.__name__}) in node {node.name}"
                + f" has multiple inbound layers.")
            for tmp_node in ms.nodes:
                if (base_lp.get_inbound_layers()[0].name
                        in tmp_node.layer_name_list):
                    node.set_input_source(tmp_node.name)
                    break
            else:
                self.logger.warning(f"Node {node.name} has no input source.")
            # find add source
            if node.use_add:
                base_layer = self.model.get_layer(node.add_layer_name)
                base_lp = LayerParser(base_layer)
                for tmp_node in ms.nodes:
                    if tmp_node is node:
                        continue
                    if (base_lp.get_inbound_layers()[0].name
                            in tmp_node.layer_name_list):
                        node.set_add_source(tmp_node.name)
                        break
                else:
                    self.logger.error(f"Node {node.name} has no add source.")
        # count unique
        for idx, node in enumerate(ms.nodes):
            if node.unique_cnt==1:
                for other_node in ms.nodes[idx+1:]:
                    if node==other_node:
                        node.unique_cnt += 1
                        other_node.unique_cnt -= 1
                        other_node.same_as = node.name
        return ms

    @property
    def model(self) -> keras.Model:
        """Get model.
        """
        return self._model
