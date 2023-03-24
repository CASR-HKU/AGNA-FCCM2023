from utils.base_param import BaseParam

class PlatformSpec(BaseParam):
    
    @staticmethod
    def get_param_keys() -> tuple[str]:
        """A tuple of dictionary keys. All required when save.
        """
        return (
            'name', 'max_dsp', 'max_bram', 'frequency',
            'dbus_width', 'data_width',)

    @property
    def name(self) -> str:
        """Platform name.
        """
        return self._name
    
    @property
    def max_dsp(self) -> int:
        """Maximum number of DSP.
        """
        return self._max_dsp
    
    @property
    def max_bram(self) -> int:
        """Maximum number of BRAM.
        """
        return self._max_bram
    
    @property
    def frequency(self) -> int:
        """Target frequency(MHz).
        """
        return self._frequency
    
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
