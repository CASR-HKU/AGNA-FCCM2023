import tensorflow as tf
import keras
import logging
from parser.model_parser import ModelParser
from utils.common import add_filehdlr, init_root_logger
from utils.model_spec import ModelSpec

tf.config.set_visible_devices(tf.config.list_physical_devices("CPU")[0])

model_name_list = [
    "alexnet",
    "mbnetv2",
    "mbnetv2_192",
    "resnet50",
    "vgg16",
    "yolov2_416",
    "yolov2_448",
]


def generate(model_name, save=True):
    model = keras.models.load_model(f"models/{model_name}")
    mp = ModelParser(model)
    ms = mp.parse()
    if save:
        ms.save(f"spec/models/{model_name}.json")
        ms = ModelSpec.load(f"spec/models/{model_name}.json")
    ms.summary()


def main():
    for model_name in model_name_list:
        generate(model_name)


if __name__ == "__main__":
    init_root_logger()
    fh = add_filehdlr("results/generate_model_spec.log")
    main()
