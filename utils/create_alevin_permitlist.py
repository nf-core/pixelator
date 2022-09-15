#!/usr/bin/env python3

#!/usr/bin/env python3
__version__ = "0.1.0"

import argparse
from typing import Dict
from collections import defaultdict
from dataclasses import dataclass
import enum
import functools
import itertools
import multiprocessing
from os import PathLike
from typing import List, Mapping
import pandas as pd
from pathlib import Path
import scipy.io
import numpy as np
import sys
from xopen import xopen


import logging


logging_format = "{levelname}: {message}"
logging.basicConfig(stream = sys.stdout,
                    filemode = "w",
                    format = logging_format,
                    style = '{',
                    level = logging.DEBUG)


logger = logging.getLogger("splitseq-demux")


class BarcodeType(enum.Enum):
    OLIGO_DT = 'T'
    RANDOM_HEXAMER = 'H'
    LIGATION = 'L'


@dataclass(frozen=True, slots=True)
class BarcodeInfo:
    sequence: str
    uid: str
    well: str
    type_: str



class SplitSeqKit(enum.Enum):
    WT = 0
    WT_MINI = 1
    WT_MEGA = 2

    def __str__(self) -> str:
        return self.name

    @staticmethod
    def from_string(s):
        try:
            return SplitSeqKit[s]
        except KeyError:
            raise ValueError("Invalid kit, options are: WT, WT_MINI, WT_MEGA")


class SplitSeqKitError(KeyError):
    pass



class SPLITSeqBarcodeInfo:
    DATA_FILES: Mapping[SplitSeqKit, str] = {
        SplitSeqKit.WT: ["bc_data_v2.csv", "bc_data_v1.csv"],
        SplitSeqKit.WT_MINI: ["bc_data_n24_v4.csv", "bc_data_v1.csv"],
        SplitSeqKit.WT_MEGA: ["bc_data_n192_v4.csv", "bc_data_v1.csv"]
    }

    def __init__(self, kit: SplitSeqKit, data_path: PathLike):
        self.data_path = Path(str(data_path))

        # Parse the kit value
        if not isinstance(kit, SplitSeqKit):
            self.kit = SplitSeqKit.from_string(kit)

        self._round1_file, self._ligation_file = self.DATA_FILES[kit]

        # Load the data files into dataframes
        self._round1_data = pd.read_csv(self.data_path / self._round1_file)
        self._ligation_data = pd.read_csv(self.data_path / self._ligation_file)

        # Create lookup dictionaries
        self._sequence_lookup = dict(
            itertools.chain(
                zip(self._round1_data.sequence, self._round1_data.iloc),
                zip(self._ligation_data.sequence, self._ligation_data.iloc)
            )
        )

    def from_sequence(self, sequence: str):
        return self._sequence_lookup.get(sequence)

    def whitelist(self) -> np.ndarray:
        round1_oligoDTs = self._round1_data.loc[self._round1_data.type == "T", "sequence"]
        whitelist = np.ndarray(shape=(len(self._ligation_data) ** 2) * len(round1_oligoDTs), dtype='<U24')
        idx = 0
        for bc2, bc3 in itertools.product(self._ligation_data.sequence, repeat=2):
            for bc1 in round1_oligoDTs:
                whitelist[idx] = f"{bc3}{bc2}{bc1}"
                idx += 1

        return whitelist



class PathCheckAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string) -> None:
        if isinstance(values, list):
            for v in values:
                v = Path(v).absolute()
                if not v.exists():
                    raise FileNotFoundError(f"Specified file: {v!s} does not exists")
        else:
            if not Path(values).absolute().exists():
                raise FileNotFoundError(f"Specified file: {values!s} does not exists")

        setattr(namespace, self.dest, values)



def main(args):
    bcinfo = SPLITSeqBarcodeInfo(args.kit, args.data)
    whitelist = bcinfo.whitelist()
    np.savetxt(args.output, whitelist, delimiter='\n', fmt='%s')


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--kit',
        required=True,
        type=SplitSeqKit.from_string, choices=list(SplitSeqKit),
        help="ParseBiosciences kit name"
    )
    parser.add_argument('--data',
        required=True,
        type=Path, action=PathCheckAction,
        help="Location of barcode data files"
    )
    parser.add_argument('--output',
        required=True,
        type=Path,
        help="Output file"
    )

    args = parser.parse_args()
    main(args)
