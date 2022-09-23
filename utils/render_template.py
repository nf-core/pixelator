#!/usr/bin/env python

from ast import arg
from pydoc import apropos
import jinja2
import json
import sys
from pathlib import Path
import argparse
from slugify import slugify


def render_params(template_file: Path, schema: dict):
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(template_file.parent))
    env.filters["slugify"] = slugify

    rendered = env.get_template(template_file.name).render(schema=schema)
    return rendered


def main(args):
    template_file = args.template
    schema_file = args.schema
    with schema_file.open("r") as f:
        schema = json.load(f)

    out = render_params(template_file, schema)
    print(out)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("schema", type=Path)
    parser.add_argument("template", type=Path)

    args = parser.parse_args()
    main(args)
