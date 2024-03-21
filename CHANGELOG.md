# nf-core/pixelator: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [UNRELEASED] - YYYY-MM-DD

### Enhancements & fixes

- `collapse` and `graph` step now output parquet files
- Update `process_medium` label to use 32 GiB of memory by default
- Fix a warning from an unused parameter from the nf-core template

### Software dependencies

| Dependency  | Old version | New version |
| ----------- | ----------- | ----------- |
| `pixelator` | 0.15.2      | 0.16.2      |

> **NB:** Dependency has been **updated** if both old and new version information is present.
>
> **NB:** Dependency has been **added** if just the new version information is present.
>
> **NB:** Dependency has been **removed** if new version information isn't present.

## [[1.0.3](https://github.com/nf-core/pixelator/releases/tag/1.0.3)] - 2024-01-19

### Enhancements & fixes

- [[PR #74](https://github.com/nf-core/pixelator/pull/74)] - Template update for nf-core/tools v2.11
- [[e196431](https://github.com/nf-core/pixelator/commit/e196431842b039cbf5c299c7a3e568f6a3e30e33)] - Workaround a tool issue by removing `docker.runOptions` user and group flags
- [[PR #76](https://github.com/nf-core/pixelator/pull/76)] - Use `adapterqc` output as main output of PIXELATOR_QC
- [[PR #77](https://github.com/nf-core/pixelator/pull/77)] - Fix some style issues in nextflow_schema.json

## [[1.0.2](https://github.com/nf-core/pixelator/releases/tag/1.0.2)] - 2023-11-20

### Enhancements & fixes

- [[PR #70](https://github.com/nf-core/pixelator/pull/70)] - Fix loading of absolute paths and urls in input samplesheet

## [[1.0.1](https://github.com/nf-core/pixelator/releases/tag/1.0.1)] - 2023-10-27

### Enhancements & fixes

- [[PR #66](https://github.com/nf-core/pixelator/pull/66)] - Add a warning and workaround for singularity & apptainer
- Cleanup some linting warnings
- Update docker image in RENAME_READS to match the singularity container

### Software dependencies

| Dependency  | Old version | New version |
| ----------- | ----------- | ----------- |
| `pixelator` | 0.15.0      | 0.15.2      |

> **NB:** Dependency has been **updated** if both old and new version information is present.
>
> **NB:** Dependency has been **added** if just the new version information is present.
>
> **NB:** Dependency has been **removed** if new version information isn't present.

## [[1.0.0](https://github.com/nf-core/pixelator/releases/tag/1.0.0)] - 2023-10-17

Initial release of nf-core/pixelator.
