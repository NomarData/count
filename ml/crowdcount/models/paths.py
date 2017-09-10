from inflection import camelize
from random import randint, choice
import glob
import os
import re


def datapath(path):
    """
    Support local paths: data/ucf/1.jpg
    Or floyd paths: /data/ucf/1.jpg
    """
    if 'FLOYD' in os.environ:
        return os.path.join("/", path)
    else:
        return path


def output(p=''):
    if 'FLOYD' in os.environ:
        return os.path.join("/output", p)
    else:
        return os.path.join("tmp", p)


def datasets():
    yield from ['ucf', 'mall', 'shakecam']


def get(dataset):
    class_name = "{}Path".format(camelize(dataset))
    return globals()[class_name]()


class UcfPath:
    def path(self, index=None):
        if not index:
            index = randint(1, 50)
        return datapath("data/ucf/{}.jpg".format(index))


class MallPath:
    def path(self, index=None):
        if not index:
            index = randint(1, 2000)
        return datapath("data/mall/frames/seq_00{:04}.jpg".format(index))


class ShakecamPath:
    def path(self, index=None):
        if not index:
            index = self.randindex()
        return datapath("data/shakecam/shakeshack-{}.jpg".format(index))

    def randindex(self):
        path = choice(glob.glob(datapath("data/shakecam/shakeshack-*.jpg")))
        return int(re.match(r".*shakeshack-(\d+)\.", path).group(1))
