import argparse
import json
import os
import re


def generate_param_header(arch, tpl_file, output_file):
    # load template
    with open(tpl_file, "r") as f:
        tpl = f.read()
    tpl = re.sub("\$PARAM_PE_NUM\$", str(arch["pe_num"]), tpl)
    for i, s in enumerate(["K", "C", "I", "J", "H", "W"]):
        tpl = re.sub(f"\$PARAM_A{s}\$", str(arch["pe_arch"][i]), tpl)
    tpl = re.sub("\$PARAM_DATA_WIDTH\$", str(arch["data_width"]), tpl)
    tpl = re.sub("\$PARAM_DBUS_WIDTH\$", str(arch["dbus_width"]), tpl)
    tpl = re.sub("\$HW_CONFIG_INT8_MACC_OPT\$", "", tpl)
    # tpl = re.sub("\$HW_CONFIG_INT8_MACC_OPT\$", "// ", tpl)
    # write
    with open(output_file, "w") as f:
        f.write(tpl)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("arch_file", type=str)
    parser.add_argument("-t", "--target_dir", type=str, default="../hardware")
    args = parser.parse_args()
    print(args.arch_file, args.target_dir)
    # load arch json
    with open(args.arch_file, "r") as f:
        arch = json.load(f)

    # generate c header
    c_param_path = os.path.join(args.target_dir, "hls/hls_src/param.h")
    generate_param_header(arch, c_param_path + ".tpl", c_param_path)
    sv_param_path = os.path.join(args.target_dir, "rtl/param.sv")
    generate_param_header(arch, sv_param_path + ".tpl", sv_param_path)


if __name__ == "__main__":
    main()
