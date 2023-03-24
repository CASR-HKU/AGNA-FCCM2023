import logging

import keras
from utils.common import short_str


class LayerParser:
    """Layer parser.
    """

    def __init__(self, layer: keras.layers.Layer) -> None:
        self._logger = logging.getLogger(self.__class__.__name__)
        self._layer = layer

    def __str__(self) -> str:
        return ((short_str(self.layer.name)
            + short_str(f"({self.layer.__class__.__name__})")).ljust(60)
            + str(self.layer.get_config()))

    @property
    def logger(self) -> logging.Logger:
        """Get logger.
        """
        return self._logger
    
    def get_inbound_layers(self) -> list[keras.layers.Layer]:
        """Return the list of inbound layers.
        """
        inbound_layers = self.layer.inbound_nodes[0].inbound_layers
        # convert single layer to list
        if isinstance(inbound_layers, keras.layers.Layer):
            inbound_layers = [inbound_layers]
        return inbound_layers
    
    def get_outbound_layers(self) -> list[keras.layers.Layer]:
        """Return the list of outbound layers.
        """
        outbound_layers = [otb_node.layer
            for otb_node in self.layer.outbound_nodes]
        # convert single layer to list
        if isinstance(outbound_layers, keras.layers.Layer):
            outbound_layers = [outbound_layers]
        return outbound_layers

    def get_comp_param(self) -> dict:
        """Return the dict of computation parameters.
        """
        assert self.is_comp
        param_dict = {}
        param_dict['name'] = self.layer.name
        param_dict['type'] = self.comp_type
        # NHWC format
        in_ch = self.layer.input_shape[-1]
        out_ch = self.layer.output_shape[-1]
        channels = ((out_ch if not self.is_dpws else 1), in_ch)
        in_hw = (self.layer.input_shape[1:3] if len(self.layer.input_shape)==4
            else (1, 1))
        w_ij = (getattr(self.layer, 'kernel_size', None)
            or getattr(self.layer, 'pool_size', None)
            or in_hw)
        out_hw = (
            self.layer.output_shape[1:3]if len(self.layer.output_shape)==4
            else (1, 1))
        strides = getattr(self.layer, 'strides', (1,1))
        gap_hw = tuple((out_hw[i]-1)*strides[i]+w_ij[i]-in_hw[i]
            for i in range(2))
        pad_t = gap_hw[0]//2
        pad_b = gap_hw[0]-pad_t
        pad_l = gap_hw[1]//2
        pad_r = gap_hw[1]-pad_l
        # loop_bounds
        param_dict['loop_bounds'] = channels + w_ij + out_hw
        # strides
        param_dict['strides'] = strides
        # paddings
        param_dict['paddings'] = (pad_t, pad_b, pad_l, pad_r)
        # other config
        param_dict['use_bn'] = getattr(self.layer, 'use_bias', False)
        param_dict['use_add'] = False
        param_dict['use_act'] = False
        # input shape
        param_dict['input_shape'] = (in_ch,) + in_hw
        # weight shape
        param_dict['weight_shape'] = channels + w_ij
        # output shape
        param_dict['output_shape'] = (out_ch,) + out_hw
        # bn shape
        param_dict['bn_shape'] = (out_ch, 2)
        return param_dict

    def get_padding_param(self) -> tuple:
        """Return the padding parameter, (pad_t, pad_b, pad_l, pad_r).
        """
        assert self.is_padding
        padding = self.layer.padding
        # same pad for all
        if isinstance(padding, int):
            padding_param = (padding, padding, padding, padding)
        # (pad_h, pad_w)
        elif isinstance(padding, tuple) and isinstance(padding[0], int):
            padding_param = (padding[0], padding[0], padding[1], padding[1])
        # (pad_t, pad_b), (pad_l, pad_r)
        elif (isinstance(padding, tuple)
                and isinstance(padding[0], tuple)
                and isinstance(padding[0][0], int)):
            padding_param = padding[0]+padding[1]
        else:
            self.logger.error(f"Unknown padding: {padding}")
            raise ValueError(f"Unknown padding: {padding}")
        return padding_param

    @property
    def layer(self) -> keras.layers.Layer:
        """Get layer.
        """
        return self._layer

    @property
    def comp_type(self) -> int:
        """Computation type.
        0: conv, dense
        1: dpwsconv
        2: avgpool
        3: maxpool
        -1: others
        """
        if isinstance(self.layer, self.ltype_comp0):
            return 0
        elif isinstance(self.layer, self.ltype_comp1):
            return 1
        elif isinstance(self.layer, self.ltype_comp2):
            return 2
        elif isinstance(self.layer, self.ltype_comp3):
            return 3
        else:
            self.logger.error(f"Unknown computation layer:"
                + f" {self.layer}({self.layer.__class__.__name__})")
            return -1

    @property
    def is_input(self) -> bool:
        """Is input layer.
        """
        return isinstance(self.layer, keras.layers.InputLayer)

    @property
    def is_comp(self) -> bool:
        """Is computation layer.
        """
        return isinstance(self.layer,
            self.ltype_comp0 + self.ltype_comp1
                + self.ltype_comp2 + self.ltype_comp3)
    
    @property
    def is_dpws(self) -> bool:
        """Is depthwise separable computation layer.
        """
        return isinstance(self.layer,
            self.ltype_comp1 + self.ltype_comp2 + self.ltype_comp3)

    @property
    def is_glbpool(self) -> bool:
        """Is global pooling layer.
        """
        return isinstance(self.layer, self.ltype_glbpool)

    @property
    def is_padding(self) -> bool:
        """Is padding layer.
        """
        return isinstance(self.layer, self.ltype_padding)

    @property
    def is_bn(self) -> bool:
        """Is batchnorm layer.
        """
        return isinstance(self.layer, self.ltype_bn)
    
    @property
    def is_add(self) -> bool:
        """Is add layer.
        """
        return isinstance(self.layer, self.ltype_add)
    
    @property
    def is_act(self) -> bool:
        """Is activation layer.
        """
        return isinstance(self.layer, self.ltype_act)

    @property
    def ltype_comp0(self) -> tuple:
        """Tuple of compute layer type 0.
        Conv2D, Dense.
        """
        return (
            keras.layers.Conv2D,
            keras.layers.Dense,
        )
    
    @property
    def ltype_comp1(self) -> tuple:
        """Tuple of compute layer type 1. 
        epthwiseConv2D.
        """
        return (
            keras.layers.DepthwiseConv2D,
        )

    @property
    def ltype_comp2(self) -> tuple:
        """Tuple of compute layer type 2.
        AveragePooling2D, GlobalAveragePooling2D.
        """
        return (
            keras.layers.AveragePooling2D,
            keras.layers.GlobalAveragePooling2D,
        )
    
    @property
    def ltype_comp3(self) -> tuple:
        """Tuple of compute layer type 3.
        MaxPooling2D, GlobalMaxPooling2D.
        """
        return (
            keras.layers.MaxPooling2D,
            keras.layers.GlobalMaxPooling2D,
        )

    @property
    def ltype_glbpool(self) -> tuple:
        """Tuple of global pooling layer.
        GlobalAveragePooling2D, GlobalMaxPooling2D.
        """
        return (
            keras.layers.GlobalAveragePooling2D,
            keras.layers.GlobalMaxPooling2D,
        )

    @property
    def ltype_padding(self) -> tuple:
        """Tuple of padding layer type.
        """
        return (
            keras.layers.ZeroPadding2D,
        )
    
    @property
    def ltype_bn(self) -> tuple:
        """Tuple of batchnorm layer type.
        """
        return (
            keras.layers.BatchNormalization,
        )

    @property
    def ltype_add(self) -> tuple:
        """Tuple of add layer type.
        """
        return (
            keras.layers.Add,
        )

    @property
    def ltype_act(self) -> tuple:
        """Tuple of activation layer type.
        """
        return (
            keras.layers.Activation,
            keras.layers.ReLU,
            keras.layers.LeakyReLU,
        )
