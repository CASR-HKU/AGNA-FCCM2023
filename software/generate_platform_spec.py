import logging
from utils.common import add_filehdlr, init_root_logger, rm_filehdlr
from utils.platform_spec import PlatformSpec

pltfm_dict_list = [
    {
        "name": "ultra96_128_8",
        "max_dsp": 360,
        "max_bram": 432,
        "frequency": 250,
        "dbus_width": 128,
        "data_width": 8,
    },
    {
        "name": "zcu102_128_8",
        "max_dsp": 2520,
        "max_bram": 1824,
        "frequency": 250,
        "dbus_width": 128,
        "data_width": 8,
    },
    {
        "name": "zcu102_256_8",
        "max_dsp": 2520,
        "max_bram": 1824,
        "frequency": 250,
        "dbus_width": 256,
        "data_width": 8,
    },
    {
        "name": "u200_512_8",
        "max_dsp": 5880,
        "max_bram": 3600,
        "frequency": 250,
        "dbus_width": 512,
        "data_width": 8,
    },
    {
        "name": "ultra96_128_16",
        "max_dsp": 360,
        "max_bram": 432,
        "frequency": 250,
        "dbus_width": 128,
        "data_width": 16,
    },
    {
        "name": "zcu102_128_16",
        "max_dsp": 2520,
        "max_bram": 1824,
        "frequency": 250,
        "dbus_width": 128,
        "data_width": 16,
    },
    {
        "name": "zcu102_256_16",
        "max_dsp": 2520,
        "max_bram": 1824,
        "frequency": 250,
        "dbus_width": 256,
        "data_width": 16,
    },
    {
        "name": "u200_512_16",
        "max_dsp": 5880,
        "max_bram": 3600,
        "frequency": 250,
        "dbus_width": 512,
        "data_width": 16,
    },
]


def main():
    init_root_logger()
    fh = add_filehdlr("results/generate_platform_spec.log")
    for pltfm_dict in pltfm_dict_list:
        pltfm_spec = PlatformSpec(pltfm_dict)
        pltfm_spec.summary()
        pltfm_spec.save(f"spec/platforms/{pltfm_spec.name}.json")
    rm_filehdlr(fh)


if __name__ == "__main__":
    main()
