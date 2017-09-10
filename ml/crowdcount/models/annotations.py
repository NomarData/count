from crowdcount.models.paths import datasets
import attr
import csv
import json
import numpy as np
import os
import sklearn.model_selection as sk


__all__ = ["groundtruth", "Annotations", "from_turk"]


@attr.s
class Annotations():
    table = attr.ib(default=attr.Factory(dict))

    def get(self, path):
        return self.table[path][:]

    def paths(self):
        return self.table.keys()

    def reload(self):
        """
        Reload annotations stored in data/annotations
        """
        self.table = self._load()
        return self

    def train_test_split(self):
        """
        Take x% from each data source to have consistent distribution
        across training and test. Retrieves from self.paths() to ensure
        we have annotations for said file.
        """

        train, test = [], []
        for ds in datasets():
            paths = [p for p in self.paths() if p.startswith("data/{}".format(ds))]  # e.g. data/ucf
            traintmp, testtmp = sk.train_test_split(sorted(paths), test_size=0.1, random_state=0)
            train.extend(traintmp)
            test.extend(testtmp)

        return train, test

    def _load(self):
        dic = {}
        paths = ["data/annotations/{}.json".format(v) for v in datasets()]
        for path in paths:
            if os.path.isfile(path):
                with open(path) as infile:
                    dic.update(json.load(infile))
            else:
                print("Warning: {} not found".format(path))

        return {k: np.asarray(v) for k, v in dic.items()}


groundtruth = Annotations().reload()


def from_turk(path):
    dic = {}
    with open(path) as infile:
        reader = csv.DictReader(infile)
        for row in reader:
            path = _turk_url_to_key(row["Input.image_url"])
            points = _turk_points_to_annotations(row["Answer.annotation_data"])
            dic[path] = points
    return dic


def _turk_url_to_key(s3url):
    return s3url.replace("https://s3.amazonaws.com/dimroc-public", "data")


def _turk_points_to_annotations(payload):
    return [[v['left'], v['top']] for v in json.loads(payload)]