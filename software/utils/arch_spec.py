from typing import Any
from utils.base_param import BaseParam
from utils.common import list_prod


class ArchSpec(BaseParam):

    def summary(self) -> None:
        base_dict = dict(self)
        base_dict.update({
            'total_dsp_num': self.total_dsp_num,
            'total_bram_num': self.total_bram_num,
            'rf_depth': self.rf_depth,
            'abuf_depth': self.abuf_depth,
            'wbuf_depth': self.wbuf_depth,
            'pbuf_depth': self.pbuf_depth,
        })
        self.logger.info(f"Summary of ArchSpec:{base_dict}")

    @property
    def packed_dsp_num(self) -> int:
        """Number of packed DSPs.
        """
        return int(get_packed_dsp_num_expr(
            self.pe_arch, self.data_width==8))

    @property
    def total_dsp_num(self) -> int:
        return int(get_total_dsp_num_expr(
            self.pe_arch, self.packed_dsp_num, self.pe_num))

    @property
    def total_bram_num(self) -> int:
        return get_total_bram_num_expr(
            self.pe_arch, self.pe_num, self.buf_arch)

    @property
    def rf_depth(self) -> int:
        return self.rf_arch//2//self.data_width
    
    @property
    def abuf_depth(self) -> int:
        return self.buf_arch[0]*16384//2//self.data_width
    
    @property
    def wbuf_depth(self) -> int:
        return self.buf_arch[1]*16384//2//self.data_width
    
    @property
    def pbuf_depth(self) -> int:
        return self.buf_arch[2]*16384//2//(self.data_width*2)

    @staticmethod
    def get_param_keys() -> tuple[str]:
        """A tuple of dictionary keys. All required when save.
        """
        return (
            'pe_arch', 'pe_num', 'buf_arch', 'rf_arch',
            'dbus_width', 'data_width')
    
    @BaseParam.params.setter
    def params(self, params: dict) -> None:
        new_params = {}
        new_params.update(params)
        for k in ['pe_arch', 'buf_arch']:
            new_params[k] = tuple(new_params[k])
        BaseParam.params.fset(self, new_params)

    @property
    def pe_arch(self) -> tuple[int]:
        """PE architecture.
        """
        return self._pe_arch
    
    @property
    def pe_num(self) -> int:
        """Number of PE.
        """
        return self._pe_num
    
    @property
    def buf_arch(self) -> tuple[int]:
        """Buffer config.
        """
        return self._buf_arch
    
    @property
    def rf_arch(self) -> int:
        """RF config.
        """
        return self._rf_arch
    
    @property
    def dbus_width(self) -> int:
        """Data bus width(bit).
        """
        return self._dbus_width

    @property
    def data_width(self) -> int:
        """Data width(bit).
        """
        return self._data_width

def get_packed_dsp_num_expr(pe_arch: tuple, pack_dsp: bool) -> Any:
    """Get the expression of number of packed DSPs.

    Arguments:
        pe_arch: tuple of 6 int or Variable.
        pack_dsp: pack DSP or not.
    """
    if pack_dsp:
        packed_dsp_num = pe_arch[4]*pe_arch[5]/2
    else:
        packed_dsp_num = pe_arch[4]*pe_arch[5]
    return packed_dsp_num

def get_total_dsp_num_expr(
        pe_arch: tuple,
        packed_dsp_num: Any,
        pe_num: Any) -> Any:
    """Get the expression of total number of DSPs.

    Arguments:
        pe_arch: tuple of 6 int or Variable.
        dsp_per_pe: int or Variable.
        pe_num: int or Variable.
    """
    return (
        list_prod(pe_arch[:4]) * packed_dsp_num  # dsp_per_pe
        * pe_num  # pe_num
        + 32  # overhead
    )

def get_total_bram_num_expr(
        pe_arch: tuple,
        pe_num: Any,
        buf_arch: tuple) -> Any:
    """Get the expression of total number of BRAMs.

    Arguments:
        pe_arch: tuple of 6 int or Variable.
        pe_num: int or Variable.
        buf_arch: tuple of 3 int.
    """
    bram_num_abuf = buf_arch[0]*pe_arch[1]
    bram_num_wbuf = buf_arch[1]*list_prod(pe_arch[:4])
    bram_num_pbuf = buf_arch[2]*list_prod([pe_arch[d] for d in [0,4,5]])
    return (
        (bram_num_abuf + bram_num_wbuf + bram_num_pbuf)  # bram_per_pe
        * pe_num  # pe_num
        + 89  # overhead
    )

