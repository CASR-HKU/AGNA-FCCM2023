import argparse
import os
import time
from typing import List

from formulation.arch_search import ArchSearch
from formulation.op_schedule import OpSchedule
from utils.agna_common import AGNAConfig
from utils.my_logger import init_root_logger, get_logger
from utils.model_spec import ModelSpec
from utils.platform_spec import PlatformSpec


class AGNA:
    platform: PlatformSpec
    model_list: List[ModelSpec]
    path: str

    def __init__(
        self, platform: PlatformSpec, model_list: List[ModelSpec], path: str
    ) -> None:
        self.platform = platform
        self.model_list = model_list
        self.path = path
        if not os.path.isdir(self.path):
            os.mkdir(self.path)

    def run(self) -> None:
        self.run_arch_search()
        # self.run_op_schedule()

    def run_arch_search(self) -> None:
        dflt_config = AGNAConfig()
        dflt_config.save(os.path.join(self.path, "as-config.json"))
        as_i = ArchSearch("as", self.path, self.platform, self.model_list, dflt_config)
        as_i.solve()
        if as_i.result is not None:
            as_i.result.save(os.path.join(self.path, "as-result.json"))

    def run_op_schedule(self) -> None:
        for model in self.model_list:
            for node in model.unique_node_iter():
                os_i = OpSchedule("os", self.path)
                os_i.solve()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", type=str, default="zcu102_128_8")
    parser.add_argument("--model", type=str, default="resnet50")
    parser.add_argument("--output_dir", type=str, default="")
    args = parser.parse_args()
    pltfm_name = args.platform
    model_name = args.model
    output_dir = args.output_dir
    if not output_dir:  # output_dir not specified
        time_str = time.strftime("%m%d-%H%M%S", time.localtime())
        output_dir = f"results/{pltfm_name}-{model_name}"
    # create output_dir
    if not os.path.isdir(output_dir):
        os.makedirs(output_dir)

    pltfm_spec = PlatformSpec.load(f"spec/platforms/{pltfm_name}.json")
    model_spec = ModelSpec.load(f"spec/models/{model_name}.json")

    _ = init_root_logger(os.path.join(output_dir, f"agna.log"))
    agna = AGNA(pltfm_spec, [model_spec], output_dir)
    agna.run()


if __name__ == "__main__":
    main()
