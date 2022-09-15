#!/usr/bin/env python

# TODO nf-core: Update the script to check the samplesheet
# This script is based on the example at: https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv

import os
import sys
import errno
import argparse


VALID_DESIGNS = ["D12", "D12PE", "D19", "D21PE"]
INPUT_HEADER = ["sample", "design", "barcodes", "fastq_1", "fastq_2"]
OUTPUT_HEADER = ["sample", "single_end", "fastq_1", "fastq_2", "design", "barcodes"]


def parse_args(args=None):
    Description = "Reformat nf-core/pixelator samplesheet file and check its contents."
    Epilog = "Example usage: python check_samplesheet.py <FILE_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("FILE_IN", help="Input samplesheet file.")
    parser.add_argument("FILE_OUT", help="Output file.")
    return parser.parse_args(args)


def make_dir(path):
    if len(path) > 0:
        try:
            os.makedirs(path)
        except OSError as exception:
            if exception.errno != errno.EEXIST:
                raise exception


def validate_design(design: str) -> bool:
    return design in VALID_DESIGNS


def print_error(error, context="Line", context_str=""):
    error_str = "ERROR: Please check samplesheet -> {}".format(error)
    if context != "" and context_str != "":
        error_str = "ERROR: Please check samplesheet -> {}\n{}: '{}'".format(
            error, context.strip(), context_str.strip()
        )
    print(error_str)
    sys.exit(1)


# TODO nf-core: Update the check_samplesheet function
def check_samplesheet(file_in, file_out, sep='\t'):
    """
    This function checks that the samplesheet follows the following structure:

    SAMPLEID	DESIGN	BARCODES	R1	R2
    test_data	D12PE	D12_v1	tests/data/test_data_R1.fastq.gz	tests/data/test_data_R2.fastq.gz

    // TODO: Update example
    For an example see:
    https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv
    """


    sample_mapping_dict = {}
    with open(file_in, "r") as fin:

        ## Check header
        MIN_COLS = 2
        # TODO nf-core: Update the column names for the input samplesheet
        header = [x.strip('"').lower() for x in fin.readline().strip().split(sep)]

        if header[: len(INPUT_HEADER)] != INPUT_HEADER:
            print("ERROR: Please check samplesheet header -> {} != {}".format(sep.join(header), sep.join(INPUT_HEADER)))
            sys.exit(1)

        ## Check sample entries
        for line in fin:
            lspl = [x.strip().strip('"') for x in line.strip().split(sep)]

            # Check valid number of columns per row
            if len(lspl) < len(INPUT_HEADER):
                print_error(
                    "Invalid number of columns (minimum = {})!".format(len(INPUT_HEADER)),
                    "Line",
                    line,
                )
            num_cols = len([x for x in lspl if x])
            if num_cols < MIN_COLS:
                print_error(
                    "Invalid number of populated columns (minimum = {})!".format(MIN_COLS),
                    "Line",
                    line,
                )

            ## Check sample name entries
            sample, design, barcodes, fastq_1, fastq_2 = lspl[: len(INPUT_HEADER)]
            sample = sample.replace(" ", "_")
            if not sample:
                print_error("Sample entry has not been specified!", "Line", line)

            ## Check FastQ file extension
            for fastq in [fastq_1, fastq_2]:
                if fastq:
                    if fastq.find(" ") != -1:
                        print_error("FastQ file contains spaces!", "Line", line)
                    if not fastq.endswith(".fastq.gz") and not fastq.endswith(".fq.gz"):
                        print_error(
                            "FastQ file does not have extension '.fastq.gz' or '.fq.gz'!",
                            "Line",
                            line,
                        )

            ## Auto-detect paired-end/single-end
            sample_info = []  ## [single_end, fastq_1, fastq_2]
            if sample and fastq_1 and fastq_2:  ## Paired-end short reads
                sample_info = ["0", fastq_1, fastq_2]
            elif sample and fastq_1 and not fastq_2:  ## Single-end short reads
                sample_info = ["1", fastq_1, fastq_2]
            else:
                print_error("Invalid combination of columns provided!", "Line", line)

            sample_info += [design, barcodes]

            ## Check design
            if not validate_design(design):
                print_error("Invalid design provided!", "Line", line)

            ## Create sample mapping dictionary = { sample: [ single_end, fastq_1, fastq_2, design, barcodes ] }
            if sample not in sample_mapping_dict:
                sample_mapping_dict[sample] = [sample_info]
            else:
                if sample_info in sample_mapping_dict[sample]:
                    print_error("Samplesheet contains duplicate rows!", "Line", line)
                else:
                    sample_mapping_dict[sample].append(sample_info)

    ## Write validated samplesheet with appropriate columns
    if len(sample_mapping_dict) > 0:
        out_dir = os.path.dirname(file_out)
        make_dir(out_dir)

        with open(file_out, "w") as fout:
            fout.write(sep.join(OUTPUT_HEADER) + "\n")
            for sample in sorted(sample_mapping_dict.keys()):

                ## Check that multiple runs of the same sample are of the same datatype
                if not all(x[0] == sample_mapping_dict[sample][0][0] for x in sample_mapping_dict[sample]):
                    print_error("Multiple runs of a sample must be of the same datatype!", "Sample: {}".format(sample))

                if len(sample_mapping_dict[sample]) != 1:
                    print_error("Multiple rows with same sample identified!", "Sample: {}".format(sample))

                val = sample_mapping_dict[sample][0]
                fout.write(sep.join([sample] + val) + "\n")

                # for idx, val in enumerate(sample_mapping_dict[sample]):
                #     fout.write(sep.join(["{}_T{}".format(sample, idx + 1)] + val) + "\n")
    else:
        print_error("No entries to process!", "Samplesheet: {}".format(file_in))


def main(args=None):
    args = parse_args(args)
    check_samplesheet(args.FILE_IN, args.FILE_OUT)


if __name__ == "__main__":
    sys.exit(main())
