#!/usr/bin/env python

import sys
import subprocess
from pathlib import Path
import pkg_resources
import json
import argparse
import ruamel.yaml as yaml


installed_packages = {i.key: i.version for i in pkg_resources.working_set}


def subtool_versions():
    cutadapt_proc = subprocess.run(["cutadapt", "--version"], capture_output=True, text=True)
    fastp_proc = subprocess.run(["fastp", "--version"], capture_output=True, text=True)

    cutadapt_version = cutadapt_proc.stdout.strip("\n")
    fastp_version = fastp_proc.stderr.strip("\n").split(" ")[-1]

    return {"cutadapt_version": cutadapt_version, "fastp_version": fastp_version}


def main(args):
    dep_versions = subtool_versions()
    root = {
        "platform": sys.platform,
        "python": {
            "version": {
                "major": sys.version_info.major,
                "minor": sys.version_info.minor,
                "micro": sys.version_info.micro,
                "releaselevel": sys.version_info.releaselevel,
                "serial": sys.version_info.serial,
            },
            "packages": installed_packages,
        },
        "fastp": {"version": dep_versions["fastp_version"]},
        "cutadapt": {"version": dep_versions["cutadapt_version"]},
    }

    workflow_data = None
    if args.workflow_data is not None and args.workflow_data.exists():
        with open(str(args.workflow_data)) as f:
            workflow_data = json.load(f)

    if workflow_data:
        root = {**root, **workflow_data}

    with open("metadata.json", "w") as f:
        json.dump(root, f, indent=4)

    with open("versions.yml", "w") as f:
        yaml.dump(
            data={
                "args.process_name": {
                    "python": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
                }
            },
            stream=f,
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("--process-name", dest="process_name", type=str)
    parser.add_argument("--workflow-data", dest="workflow_data", type=Path, default=None)
    args = parser.parse_args()

    main(args)
