#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
from typing import Any, Dict
import textwrap


DEFAULT_SCHEMA_PATH = Path(__file__).parents[1] / "nextflow_schema.json"


GROUPS = {
    "preqc_options",
    "adapterqc_options",
    "demux_options",
    "collapse_options",
    "graph_options",
    "annotate_options",
    "analysis_options",
    "report_options",
}


def print_intro():
    print(
        """
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##     nf-core/pixelator parameter file
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##     This is an example params-file.yaml for the `-params-file` option of
##     nf-core/pixelator.
##     Uncomment lines with a single '#' if you want to pass the parameter.
## ----------------------------------------------------------------------------------------
"""
    )


def render_params_file(schema: Dict[str, Any]):
    definitions = schema["definitions"]
    for definition_key, definition in definitions.items():
        if definition_key not in GROUPS:
            continue

        comment = definition.get("description", definition_key)
        properties = definition["properties"]

        print(
            f"""
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##     {comment}
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
"""
        )

        for prop_key, prop in properties.items():
            default_value = prop.get("default", None)

            if isinstance(default_value, bool):
                default_value = str(default_value).lower()

            if default_value is None:
                default_value = "null"

            description_lines = textwrap.wrap(f"## {prop.get('description', '')}")

            print("## ------------------------------------------------------------------------------------------")
            print("\n## ".join(description_lines))
            print("## ------------------------------------------------------------------------------------------")
            print(f"""# {prop_key}: {default_value}\n""")

    return


def main(args):
    schema_file = args.schema
    with schema_file.open("r") as f:
        schema = json.load(f)

    print_intro()
    render_params_file(schema)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA_PATH)

    args = parser.parse_args()
    main(args)
