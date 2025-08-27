# nf-core/pixelator: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [[2.1.0](https://github.com/nf-core/pixelator/releases/tag/x.x.x)] - YYYY-MM-DD

### Enhancements & fixes

- Template update for nf-core/tools v3.3.2
- Add a denoise step to the PNA workflow, that cleans data between the graph and analysis steps.
- Move to using quay.io as the container source, to avoid issues with users needing to
  login to access the Github Container Registry.
- Fix the PNA report not being generated.
- Add the `experiment_summary` step which generates the Proximity Experiment Summary report.

### Parameters

| Old parameter | New parameter                                |
| ------------- | -------------------------------------------- |
|               | `--skip_denoise`                             |
|               | `--save_pna_denoise_pixelfile`               |
|               | `--pna_denoise_run_one_core_graph_denoising` |
|               | `--pna_denoise_pval_threshold`               |
|               | `--pna_denoise_inflate_factor`               |
|               | `--pna_denoise_inflate_factor`               |

> [!NOTE]
> Parameter has been **updated** if both old and new parameter information is present.
> Parameter has been **added** if just the new parameter information is present.
> Parameter has been **removed** if new parameter information isn't present.

### Software dependencies

| Dependency    | Old version | New version |
| ------------- | ----------- | ----------- |
| `pixelator`   | 0.20.1      | 0.21.2      |
| `pixelatorES` |             | 0.4.3       |

> [!NOTE]
> Dependency has been **updated** if both old and new parameter information is present.
> Dependency has been **added** if just the new parameter information is present.
> Dependency has been **removed** if new parameter information isn't present.

## [[2.0.0](https://github.com/nf-core/pixelator/releases/tag/2.0.0)] - 2024-05-27

This release is a major update of the nf-core/pixelator pipeline. It brings in support for the
Proximity Network Analysis (PNA) workflow in addition to the Molecular Pixelation (MPX) workflow.
Any run of the pipeline will now run the appropriate workflow depending on which design is specified in the input samplesheet.

### Enhancements & fixes

- [[PR #131](https://github.com/nf-core/pixelator/pull/131)] - Update to pixelator 0.20.1, and add PNA workflows
- [[PR #132](https://github.com/nf-core/pixelator/pull/132)] - Template update for nf-core/tools v3.2.1
- [[PR #133](https://github.com/nf-core/pixelator/pull/133)] - Documentation updates

### Parameters

| Old parameter | New parameter                                               |
| ------------- | ----------------------------------------------------------- |
|               | `--save_pna_demux_parquet`                                  |
|               | `--save_pna_demux_passed_reads`                             |
|               | `--save_pna_demux_failed_reads`                             |
|               | `--save_pna_collapsed_reads`                                |
|               | `--save_pna_graph_pixelfile`                                |
|               | `--save_pna_analysis_pixelfile`                             |
|               | `--save_json`                                               |
|               | `--pna_amplicon_mismatches`                                 |
|               | `--pna_amplicon_remove_polyg`                               |
|               | `--pna_amplicon_quality_cutoff`                             |
|               | `--pna_demux_mismatches`                                    |
|               | `--pna_demux_output_chunk_reads`                            |
|               | `--pna_demux_output_max_chunks`                             |
|               | `--pna_demux_strategy`                                      |
|               | `--pna_collapse_mismatches`                                 |
|               | `--pna_collapse_algorithm`                                  |
|               | `--pna_graph_multiplet_recovery`                            |
|               | `--pna_graph_leiden_iterations`                             |
|               | `--pna_graph_initial_stage_leiden_resolution`               |
|               | `--pna_graph_refinement_stage_leiden_resolution`            |
|               | `--pna_graph_min_count`                                     |
|               | `--pna_graph_min_component_size_in_refinement`              |
|               | `--pna_graph_max_refinement_recursion_depth`                |
|               | `--pna_graph_initial_stage_max_edges_to_remove`             |
|               | `--pna_graph_refinement_stage_max_edges_to_remove`          |
|               | `--pna_graph_initial_stage_max_edges_to_remove_relative`    |
|               | `--pna_graph_refinement_stage_max_edges_to_remove_relative` |
|               | `--pna_graph_graph_min_component_size_to_prune`             |
|               | `--pna_graph_component_size_min_threshold`                  |
|               | `--pna_analysis_compute_proximity`                          |
|               | `--pna_analysis_proximity_nbr_of_permutations`              |
|               | `--pna_analysis_compute_k_cores`                            |
|               | `--pna_analysis_compute_svd_var_explained`                  |
|               | `--pna_analysis_svd_nbr_of_pivots`                          |
|               | `--pna_layout_no_node_marker_counts`                        |
|               | `--pna_layout_layout_algorithm`                             |
|               | `--pna_layout_pmds_pivots`                                  |
|               | `--pna_layout_wpmds_k`                                      |

> [!NOTE]
> Parameter has been **updated** if both old and new parameter information is present.
> Parameter has been **added** if just the new parameter information is present.
> Parameter has been **removed** if new parameter information isn't present.

### Software dependencies

| Dependency  | Old version | New version |
| ----------- | ----------- | ----------- |
| `pixelator` | 0.19.0      | 0.20.1      |

> [!NOTE]
> Dependency has been **updated** if both old and new parameter information is present.
> Dependency has been **added** if just the new parameter information is present.
> Dependency has been **removed** if new parameter information isn't present.

## [[1.4.0](https://github.com/nf-core/pixelator/releases/tag/1.4.0)] - 2024-01-22

### Enhancements & fixes

- [[PR #111](https://github.com/nf-core/pixelator/pull/111)] - Template update for nf-core/tools v3.0.2
- [[PR #112](https://github.com/nf-core/pixelator/pull/112)] - Add graph refinement options for pixelator 0.19
- [[PR #113](https://github.com/nf-core/pixelator/pull/113)] - Fix validation issues after nf-core/tools v3.0.2 update
- [[PR #114](https://github.com/nf-core/pixelator/pull/114)] - Remove `--save_recovered_components` options for graph outputs
- [[PR #115](https://github.com/nf-core/pixelator/pull/115)] - Update containers for pixelator 0.19
- [[PR #116](https://github.com/nf-core/pixelator/pull/116)] - Bump version to 1.4
- [[PR #117](https://github.com/nf-core/pixelator/pull/117)] - Template update for nf-core/tools v3.1.0
- [[PR #118](https://github.com/nf-core/pixelator/pull/118)] - Update metromap, bump conda versions
- [[PR #120](https://github.com/nf-core/pixelator/pull/120)] - Add process_long to AMPLICON and COLLAPSE steps
- [[PR #122](https://github.com/nf-core/pixelator/pull/122)] - Template update for nf-core/tools v3.1.1
- [[PR #124](https://github.com/nf-core/pixelator/pull/124)] - Add manifest.contributors metadata to nextflow.config
- [[PR #125](https://github.com/nf-core/pixelator/pull/125)] - Use environment.yml files for all conda process directives
- [[PR #123](https://github.com/nf-core/pixelator/pull/123)] - Add nf-test tests for local modules and subworkflows

### Parameters

| Old parameter                        | New parameter                            |
| ------------------------------------ | ---------------------------------------- |
|                                      | `--help_full`                            |
|                                      | `--show_hidden`                          |
| `--validationFailUnrecognisedParams` |                                          |
| `--validationLenientMode`            |                                          |
| `--validationSchemaIgnoreParams`     |                                          |
| `--validationShowHiddenParams`       |                                          |
| `--leiden_iterations`                | `--graph_max_refinement_recursion_depth` |
|                                      | `--graph_max_edges_to_split`             |
|                                      | `--graph_max_edges_to_split`             |
| `--save_recovered_components`        |                                          |

> [!NOTE]
> Parameter has been **updated** if both old and new parameter information is present.
> Parameter has been **added** if just the new parameter information is present.
> Parameter has been **removed** if new parameter information isn't present.

### Software dependencies

| Dependency  | Old version | New version |
| ----------- | ----------- | ----------- |
| `pixelator` | 0.18.2      | 0.19.0      |

> [!NOTE]
> Dependency has been **updated** if both old and new parameter information is present.
> Dependency has been **added** if just the new parameter information is present.
> Dependency has been **removed** if new parameter information isn't present.

## [[1.3.1](https://github.com/nf-core/pixelator/releases/tag/1.3.1)] - 2024-07-31

### Enhancements & fixes

- [[PR #107](https://github.com/nf-core/pixelator/pull/107)] - Fix conda version tag to use pixelator 0.18.2

## [[1.3.0](https://github.com/nf-core/pixelator/releases/tag/1.3.0)] - 2024-07-17

### Enhancements & fixes

- [[PR #97](https://github.com/nf-core/pixelator/pull/97)] - Update citations
- [[PR #96](https://github.com/nf-core/pixelator/pull/96)] - Make all ext.args assignments closures
- [[PR #98](https://github.com/nf-core/pixelator/pull/98)] - Update metromap to include layout step
- [[PR #99](https://github.com/nf-core/pixelator/pull/99)] - Update README to include layout step
- [[PR #100](https://github.com/nf-core/pixelator/pull/100)] - Use R1/R2 suffixes in amplicon input fastq file renaming
- [[PR #101](https://github.com/nf-core/pixelator/pull/101)] - Fix validation issue when using panel_file instead of panel
- [[PR #102](https://github.com/nf-core/pixelator/pull/101)] - Restructure output directory
- [[PR #103](https://github.com/nf-core/pixelator/pull/103)] - Make rate-diff the default transformation method when computing colocalization
- [[PR #104](https://github.com/nf-core/pixelator/pull/104)] - Update to pixelator 0.18.1
- [[PR #106](https://github.com/nf-core/pixelator/pull/106)] - Update to pixelator 0.18.2

### Software dependencies

| Dependency  | Old version | New version |
| ----------- | ----------- | ----------- |
| `pixelator` | 0.17.1      | 0.18.2      |

> [!NOTE]
> Dependency has been **updated** if both old and new version information is present.
> Dependency has been **added** if just the new version information is present.
> Dependency has been **removed** if new version information isn't present.

## [[1.2.0](https://github.com/nf-core/pixelator/releases/tag/1.2.0)] - 2024-05-28

### Enhancements & fixes

- [[PR #89](https://github.com/nf-core/pixelator/pull/89)] - Template update for nf-core/tools v2.14.1
- [[PR #90](https://github.com/nf-core/pixelator/pull/90)] - Update pixelator to 0.17.1
- [[PR #90](https://github.com/nf-core/pixelator/pull/90)] - Add `pixelator single-cell layout` command
- [[PR #90](https://github.com/nf-core/pixelator/pull/90)] - The `graph` and `annotate` steps are now using `process_high` as their resource tags
- [[PR #91](https://github.com/nf-core/pixelator/pull/91)] - Set `process_high` to use 64GB of RAM and `process_high_memory` to use 128GB of RAM
- [[PR #92](https://github.com/nf-core/pixelator/pull/92)] - Minor touch-ups to the documentation
- [[PR #93](https://github.com/nf-core/pixelator/pull/93)] - Merge RENAME_READS functionality into PIXELATOR_AMPLICON

### Software dependencies

| Dependency  | Old version | New version |
| ----------- | ----------- | ----------- |
| `pixelator` | 0.16.2      | 0.17.1      |

> **NB:** Dependency has been **updated** if both old and new version information is present.
>
> **NB:** Dependency has been **added** if just the new version information is present.
>
> **NB:** Dependency has been **removed** if new version information isn't present.

## [[1.1.0](https://github.com/nf-core/pixelator/releases/tag/1.1.0)] - 2024-03-29

### Enhancements & fixes

- [[PR #83](https://github.com/nf-core/pixelator/pull/83)] - Template update for nf-core/tools v2.13
- [[PR #84](https://github.com/nf-core/pixelator/pull/84)] - Update pixelator to 0.16.2, collapse`and`graph` step now return parquet files
- [[PR #85](https://github.com/nf-core/pixelator/pull/85)] - Remove a workaround for container issues, silence some warnings, update default resources

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
