#!/usr/bin/env python


"""Provide a command line tool to validate and transform tabular samplesheets."""


import abc
import argparse
import csv
import logging
import sys
import urllib.parse
from collections import Counter
from pathlib import Path, PurePath
import re
from typing import Iterable, List, MutableMapping, Set
from os import PathLike

logger = logging.getLogger()


def make_absolute_path(path: str, base: PathLike = None) -> str:
    """If `path` is a relative path without a scheme, resolve it as a local filesystem path relative to `base`"""
    url = urllib.parse.urlparse(path)
    if url.scheme and url.netloc:
        return path

    in_path = PurePath(path)
    if not in_path.is_absolute() and base is not None:
        return str(PurePath(base) / in_path)

    return str(in_path)


def validate_whitespace(row: MutableMapping[str, str], index: int):
    for k, v in row.items():
        if re.search("^\s+|s+$", v):
            raise AssertionError(
                f"The sample sheet contains leading or trailing whitespaces in for field {k}. "
                "Remove whitespace or enclose with quotes!"
            )


class BaseChecker(metaclass=abc.ABCMeta):
    REQUIRED_COLUMNS: Set[str] = {}

    @classmethod
    def check_headers(cls, headers) -> bool:
        return cls.REQUIRED_COLUMNS.issubset(headers)

    @abc.abstractmethod
    def validate_and_transform(self, row):
        return NotImplemented

    @classmethod
    def output_headers(cls, headers: Iterable[str]) -> List[str]:
        return list(headers)


class RowChecker(BaseChecker):
    """
    Define a service that can validate and transform each given row.

    Attributes:
        modified (list): A list of dicts, where each dict corresponds to a previously
            validated and transformed row. The order of rows is maintained.

    """

    VALID_FORMATS = (
        ".fq.gz",
        ".fastq.gz",
    )

    def __init__(
        self,
        sample_col="sample",
        first_col="fastq_1",
        second_col="fastq_2",
        single_col="single_end",
        **kwargs,
    ):
        """
        Initialize the row checker with the expected column names.

        Args:
            sample_col (str): The name of the column that contains the sample name
                (default "sample").
            first_col (str): The name of the column that contains the first (or only)
                FASTQ file path (default "fastq_1").
            second_col (str): The name of the column that contains the second (if any)
                FASTQ file path (default "fastq_2").
            single_col (str): The name of the new column that will be inserted and
                records whether the sample contains single- or paired-end sequencing
                reads (default "single_end").

        """
        super().__init__(**kwargs)
        self._sample_col = sample_col
        self._first_col = first_col
        self._second_col = second_col
        self._single_col = single_col
        self._seen = set()
        self.modified = []

    def validate_and_transform(self, row):
        """
        Perform all validations on the given row and insert the read pairing status.

        Args:
            row (dict): A mapping from column headers (keys) to elements of that row
                (values).

        """
        self._validate_sample(row)
        self._validate_first(row)
        self._validate_second(row)
        self._validate_pair(row)
        self._seen.add((row[self._sample_col], row[self._first_col]))
        self.modified.append(row)

    def _validate_sample(self, row):
        """Assert that the sample name exists and convert spaces to underscores."""
        if len(row[self._sample_col]) <= 0:
            raise AssertionError("Sample input is required.")
        # Sanitize samples slightly.
        row[self._sample_col] = row[self._sample_col].replace(" ", "_")

    def _validate_first(self, row):
        """Assert that the first FASTQ entry is non-empty and has the right format."""
        if len(row[self._first_col]) <= 0:
            raise AssertionError("At least the first FASTQ file is required.")
        self._validate_fastq_format(row[self._first_col])

    def _validate_second(self, row):
        """Assert that the second FASTQ entry has the right format if it exists."""
        if len(row[self._second_col]) > 0:
            self._validate_fastq_format(row[self._second_col])

    def _validate_pair(self, row):
        """Assert that read pairs have the same file extension. Report pair status."""
        if row[self._first_col] and row[self._second_col]:
            row[self._single_col] = False
            first_col_suffix = Path(row[self._first_col]).suffixes[-2:]
            second_col_suffix = Path(row[self._second_col]).suffixes[-2:]
            if first_col_suffix != second_col_suffix:
                raise AssertionError("FASTQ pairs must have the same file extensions.")
        else:
            row[self._single_col] = True

    def _validate_fastq_format(self, filename):
        """Assert that a given filename has one of the expected FASTQ extensions."""
        if not any(filename.endswith(extension) for extension in self.VALID_FORMATS):
            raise AssertionError(
                f"The FASTQ file has an unrecognized extension: {filename}\n"
                f"It should be one of: {', '.join(self.VALID_FORMATS)}"
            )

    def validate_unique_samples(self):
        """
        Assert that the combination of sample name and FASTQ filename is unique.

        In addition to the validation, also rename all samples to have a suffix of _T{n}, where n is the
        number of times the same sample exist, but with different FASTQ files, e.g., multiple runs per experiment.

        """
        if len(self._seen) != len(self.modified):
            raise AssertionError("The pair of sample name and FASTQ must be unique.")
        seen = Counter()
        for row in self.modified:
            sample = row[self._sample_col]
            seen[sample] += 1
            row[self._sample_col] = f"{sample}_T{seen[sample]}"


class PixelatorRowChecker(RowChecker):
    DEFAULT_GROUP = "default"
    REQUIRED_COLUMNS = {"sample", "design", "fastq_1", "fastq_2"}

    def __init__(
        self,
        sample_col="sample",
        first_col="fastq_1",
        second_col="fastq_2",
        single_col="single_end",
        design_col="design",
        panel_col="panel",
        group_col="group",
        samplesheet_path=None,
        **kwargs,
    ):
        super().__init__(
            sample_col=sample_col, first_col=first_col, second_col=second_col, single_col=single_col, **kwargs
        )

        self._design_col = design_col
        self._samplesheet_path = samplesheet_path
        self._base_dir = PurePath(self._samplesheet_path).parent if self._samplesheet_path else None
        self._panel_col = panel_col
        self._group_col = group_col

    @classmethod
    def output_headers(cls, headers: Iterable[str]) -> List[str]:
        headers = list(headers)
        if not "group" in headers:
            headers.insert(1, "group")

        headers.insert(1, "single_end")
        return headers

    def _validate_design(self, row):
        """Assert that the design column exists and has supported values."""
        if len(row[self._design_col]) <= 0:
            raise AssertionError(f"The {self._design_col} field is required.")

    def _validate_panelfile(self, row):
        """Assert that the panel column exists and has supported values."""
        if len(row[self._panel_col]) <= 0:
            raise AssertionError(f"The {self._panel_col} field is required.")

    def _resolve_relative_paths(self, row):
        first = make_absolute_path(row[self._first_col], self._base_dir)
        second = make_absolute_path(row[self._second_col], self._base_dir)
        panel = make_absolute_path(row[self._panel_col], self._base_dir)

        row[self._first_col] = first
        row[self._second_col] = second
        row[self._panel_col] = panel

    def _validate_group(self, row):
        if not self._group_col in row:
            row[self._group_col] = self.DEFAULT_GROUP

    def validate_and_transform(self, row):
        """
        Perform all validations on the given row and insert the read pairing status.

        Args:
            row (dict): A mapping from column headers (keys) to elements of that row
                (values).

        """
        self._validate_sample(row)
        self._validate_first(row)
        self._validate_second(row)
        self._validate_pair(row)
        self._resolve_relative_paths(row)
        self._seen.add((row[self._sample_col], row[self._first_col]))
        self.modified.append(row)


class PixelatorAggregateRowChecker(BaseChecker):
    """
    Define a service that can validate and transform each given row.

    Attributes:
        modified (list): A list of dicts, where each dict corresponds to a previously
            validated and transformed row. The order of rows is maintained.

    """

    REQUIRED_COLUMNS = {"sample", "group", "matrix"}

    VALID_FORMATS = (
        ".h5ad",
        ".h5ad.gz",
    )

    def __init__(
        self,
        sample_col="sample",
        group_col="group",
        matrix_col="matrix",
        samplesheet_path=None,
        **kwargs,
    ):
        """
        Initialize the row checker with the expected column names.

        Args:
            sample_col (str): The name of the column that contains the sample name
                (default "sample").
            group_col (str): The name of the column that contains the group
                assignment
            second_col (str): The name of the column that contains the matrix file
                in .h5ad or .h5ad.gz format
        """
        self._sample_col = sample_col
        self._group_col = group_col
        self._matrix_col = matrix_col
        self._samplesheet_path = samplesheet_path
        self._base_dir = PurePath(self._samplesheet_path).parent
        self._seen = set()
        self.modified = []

    @classmethod
    def output_headers(cls, headers: Iterable[str]) -> List[str]:
        headers = list(headers)
        if not "group" in headers:
            headers.insert(1, "group")

        return headers

    def validate_and_transform(self, row):
        """
        Perform all validations on the given row and insert the read pairing status.

        Args:
            row (dict): A mapping from column headers (keys) to elements of that row
                (values).

        """
        self._validate_sample(row)
        self._validate_group(row)
        self._validate_matrix(row)
        self._seen.add(row[self._sample_col])
        self.modified.append(row)

    def _validate_sample(self, row):
        """Assert that the sample name exists and convert spaces to underscores."""
        if len(row[self._sample_col]) <= 0:
            raise AssertionError("Sample input is required.")
        # Sanitize samples slightly.
        row[self._sample_col] = row[self._sample_col].replace(" ", "_")

    def _validate_group(self, row):
        """Assert that the group entry is non-empty."""
        if len(row[self._group_col]) <= 0:
            raise AssertionError("The group field is required")

    def _validate_matrix(self, row):
        """Assert that the second FASTQ entry has the right format if it exists."""
        if len(row[self._matrix_col]) <= 0:
            raise AssertionError("The matrix field is required")

        self._validate_h5ad_format(row[self._matrix_col])
        matrix_path = make_absolute_path(row[self._matrix_col], self._base_dir)

        row[self._matrix_col] = matrix_path

    def _validate_h5ad_format(self, filename):
        """Assert that a given filename has one of the expected H5AD extensions."""

        if not any(filename.endswith(extension) for extension in self.VALID_FORMATS):
            raise AssertionError(
                f"The matrix file has an unrecognized extension: {filename}\n"
                f"It should be one of: {', '.join(self.VALID_FORMATS)}"
            )

    def validate_unique_samples(self):
        """
        Assert that the combination of sample name and FASTQ filename is unique.
        """
        if len(self._seen) != len(self.modified):
            raise AssertionError("The sample name must be unique.")


def read_head(handle, num_lines=10):
    """Read the specified number of lines from the current position in the file."""
    lines = []
    for idx, line in enumerate(handle):
        if idx == num_lines:
            break
        lines.append(line)
    return "".join(lines)


def sniff_format(handle):
    """
    Detect the tabular format.

    Args:
        handle (text file): A handle to a `text file`_ object. The read position is
        expected to be at the beginning (index 0).

    Returns:
        csv.Dialect: The detected tabular format.

    .. _text file:
        https://docs.python.org/3/glossary.html#term-text-file

    """
    peek = read_head(handle)
    handle.seek(0)
    sniffer = csv.Sniffer()
    if not sniffer.has_header(peek):
        logger.critical("The given sample sheet does not appear to contain a header.")
        sys.exit(1)
    dialect = sniffer.sniff(peek)
    return dialect


def check_samplesheet(file_in, file_out, checker: BaseChecker):
    """
    Check that the tabular samplesheet has the structure expected by nf-core pipelines.

    Validate the general shape of the table, expected columns, and each row. Also add
    an additional column which records whether one or two FASTQ reads were found.

    Args:
        file_in (pathlib.Path): The given tabular samplesheet. The format can be either
            CSV, TSV, or any other format automatically recognized by ``csv.Sniffer``.
        file_out (pathlib.Path): Where the validated and transformed samplesheet should
            be created; always in CSV format.
    """
    # See https://docs.python.org/3.9/library/csv.html#id3 to read up on `newline=""`.
    with file_in.open(newline="") as in_handle:
        reader = csv.DictReader(in_handle, dialect=sniff_format(in_handle))

        # Validate the existence of the expected header columns.
        if not checker.check_headers(reader.fieldnames):
            req_cols = ", ".join(checker.REQUIRED_COLUMNS)
            logger.critical(f"The sample sheet **must** contain these column headers: {req_cols}.")
            sys.exit(1)

        for i, row in enumerate(reader):
            try:
                validate_whitespace(row, i)
                checker.validate_and_transform(row)
            except AssertionError as error:
                logger.critical(f"{str(error)} On line {i + 2}.")
                sys.exit(1)

        checker.validate_unique_samples()

    header = checker.output_headers(reader.fieldnames)

    # See https://docs.python.org/3.9/library/csv.html#id3 to read up on `newline=""`.
    with file_out.open(mode="w", newline="") as out_handle:
        writer = csv.DictWriter(out_handle, header, delimiter=",")
        writer.writeheader()
        for row in checker.modified:
            writer.writerow(row)


def parse_args(argv=None):
    """Define and immediately parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Validate and transform a tabular samplesheet.",
        epilog="Example: python check_samplesheet.py samplesheet.csv samplesheet.valid.csv",
    )
    parser.add_argument(
        "file_in",
        metavar="FILE_IN",
        type=Path,
        help="Tabular input samplesheet in CSV or TSV format.",
    )
    parser.add_argument(
        "file_out",
        metavar="FILE_OUT",
        type=Path,
        help="Transformed output samplesheet in CSV format.",
    )
    parser.add_argument(
        "--samplesheet-path",
        metavar="PATH",
        type=PurePath,
        help="Local or remote location of the samplesheet",
    )
    parser.add_argument(
        "--mode",
        metavar="SampleSheetType",
        type=str,
        choices=("main", "aggregate"),
        default="main",
        help="Type of samplesheet (default: main)",
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="The desired log level (default WARNING).",
        choices=("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"),
        default="WARNING",
    )
    return parser.parse_args(argv)


def main(argv=None):
    """Coordinate argument parsing and program execution."""
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")

    if not args.file_in.is_file():
        logger.error(f"The given input file {args.file_in} was not found!")
        sys.exit(2)
    args.file_out.parent.mkdir(parents=True, exist_ok=True)

    checker = None
    if args.mode == "main":
        checker = PixelatorRowChecker(samplesheet_path=args.samplesheet_path)
    elif args.mode == "aggregate":
        checker = PixelatorAggregateRowChecker(samplesheet_path=args.samplesheet_path)
    else:
        logger.error(f"The given samplesheet mode {args.mode} is invalid!")
        sys.exit(2)

    check_samplesheet(args.file_in, args.file_out, checker)


if __name__ == "__main__":
    sys.exit(main())
