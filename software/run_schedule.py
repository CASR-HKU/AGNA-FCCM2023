import argparse
import os
import time

from agna import AGNA
from utils.common import add_filehdlr, init_root_logger, rm_filehdlr
from utils.model_spec import ModelSpec
from utils.platform_spec import PlatformSpec


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", type=str, default="zcu102_128_8")
    parser.add_argument("--model", type=str, default="resnet50")
    parser.add_argument("--sim_only", action="store_true")
    parser.add_argument("--update_only", action="store_true")
    parser.add_argument("--output_dir", type=str, default="")
    args = parser.parse_args()
    pltfm_name = args.platform
    model_name = args.model
    sim_only = args.sim_only
    update_only = args.update_only
    output_dir = args.output_dir
    if not output_dir:  # output_dir not specified
        time_str = time.strftime("%m%d-%H%M%S", time.localtime())
        output_dir = f"results/{pltfm_name}-{model_name}"
    # create output_dir
    if not os.path.isdir(output_dir):
        os.makedirs(output_dir)

    pltfm_spec = PlatformSpec.load(f"spec/platforms/{pltfm_name}.json")
    model_spec = ModelSpec.load(f"spec/models/{model_name}.json")

    init_root_logger()
    agna = AGNA(pltfm_spec, [model_spec], output_dir)
    if sim_only:
        agna.simulate()
        return
    if update_only:
        agna.update_csv()
        agna.update_json()
        return
    log_path = os.path.join(output_dir, "agna.log")
    fh = add_filehdlr(log_path, False)
    agna.run()
    agna.simulate()
    agna.update_csv()
    agna.update_json()
    rm_filehdlr(fh)


if __name__ == "__main__":
    main()
