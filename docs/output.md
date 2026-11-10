# nf-core/pixelator: Output

## Introduction

This document describes the output produced by the pipeline.

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using multiple subcommands
of [`pixelator`](https://github.com/PixelgenTechnologies/pixelator).

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Proximity Network Assay (PNA)

### Pipeline overview

The PNA pipeline consists of the following steps:

- [Edgelist](#edgelist)
- [Aggregate](#aggregate)
- [Graph construction](#graph-construction)
- [Graph collapse](#graph-collapse)
- [Sample Calling](#sample-calling)
- [Denoising](#denoising)
- [Analysis](#analysis)
- [Layout creation](#compute-layouts-for-visualization)
- [Per run report generation](#generate-report-for-all-samples)
- [Pipeline information](#pipeline-information)

The output of the Proximity Network Assay (PNA) pipeline is organized into several directories, each corresponding to a specific step in the pipeline. Below is an overview of the output structure and the files generated at each step:

#### Edgelist

The edgelist step uses `pixelator single-cell-pna edgelist` to build a per-read edgelist directly from the raw FASTQ files,
for both single-end and paired-end data. Reads are matched to the markers of the panel, and reads are dropped
based on their quality, UMI complexity and similarity between the UMI and the pixel binding sequences.

Each FASTQ input (e.g. each lane of a sample) is processed independently. Output files are named after the FASTQ file,
without the extension and without the `R1`/`R2` suffix for paired-end data.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `edgelist`
    - `<fastq-name>.parquet`: Per-read edgelist.
    - `<fastq-name>.report.json`: QC metrics collected by the edgelist step.
    - `<fastq-name>.meta.json`: Command invocation metadata.
    - `<fastq-name>.dropped_reads.parquet`: Reads that did not make it into the edgelist, with the reason they were dropped (only with `--save_pna_edgelist_dropped_reads`).
  - `logs`
    - `<fastq-name>.pixelator-edgelist.log`: pixelator log output.

</details>

#### Aggregate

This step uses the `pixelator single-cell-pna aggregate` command.

The `aggregate` command merges the edgelists of all the FASTQ inputs of a sample (or pool) and collapses them into unique molecules,
computing a read count for each molecule.

The output of this step is used as an edge list input for the graph construction step.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `aggregate`
    - `<sample-id>.parquet`: Edge list of the graph.
    - `<sample-id>.report.json`: QC metrics for the aggregate step.
    - `<sample-id>.meta.json`: Command invocation metadata.

  - `logs`
    - `<sample-id>.pixelator-aggregate.log`: pixelator log output.

</details>

#### Graph construction

This step uses the `pixelator single-cell-pna graph` command. The input is the edge list parquet file generated in the aggregate step.
The graph step will attempt to resolve any multiplet due to erronous edges in the graph, it will then find the connected components
of the graph (i.e. the putative cells) and assign a unique ID to each component.

From this step and onwards, the output file are in PXL format. This is a custom format used by pixelator to make PNA data easier
to work with. Internally it used duckdb to store the data. For more information on the PXL format, please refer to
the [pixelator documentation](https://software.pixelgen.com/pixelator/outputs/pxl-file/).

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `graph`
    - `<sample-id>.graph.pxl`: The pixel file containing all data after resolving multiplets.
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: QC metrics for the graph step.

  - `logs`
    - `<sample-id>.pixelator-graph.log`: pixelator log output.

</details>

#### Graph collapse

This step uses the `pixelator single-cell-pna graph-collapse` command. It collapses likely UMI sequencing errors
in each component of the graph. Since a UMI read error is unlikely to recur, an erroneous UMI typically shows up as a
leaf node in the graph. Each such node is renamed to the nearest node of the same role whose UMI is within a given
Hamming distance, and the corrected graph is saved as a new PXL file.

This step can be skipped with `--skip_graph_collapse`.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `graph-collapse`
    - `<sample-id>.graph-collapse.pxl`: The pixel file containing the data after UMI error correction.
    - `<sample-id>.collapsed_sequences.tsv`: Collapsed UMI sequences, only when `--pna_graph_collapse_report_collapsed_sequences` is set.
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: QC metrics for the graph-collapse step.

  - `logs`
    - `<sample-id>.pixelator-graph-collapse.log`: pixelator log output.

</details>

#### Denoising

This step uses the `pixelator single-cell-pna denoise` command. It will try to find differences between
the well-connected parts of each component graph and the less well-connected parts of the graph. It will
then try to find differences in marker profiles between these two parts of the graph and use these
differences to denoise the graph. This reduces the effect of marker bleed-over due to incorrect cutting
in the graph step.

The denoised graph will be saved as a new PXL file.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `denoise`
    - `<sample-id>.denoise.pxl`: The pixel file containing the denoised data.
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: QC metrics for the graph step.

  - `logs`
    - `<sample-id>.pixelator-denoise.log`: pixelator log output.

</details>

#### Sample Calling

This step uses the `pixelator single-cell-pna sample-calling` command. It takes
the graph PXL file and the sample sheet as input and assigns each component to
the most likely sample in pooled experiments.

Components with sample enrichment below `pna_sample_calling_enrichment_threshold`
(default 10.0) are marked as undetermined and can be saved to a separate output
file. The resulting per-sample dehashed PXL files are then used as input for
the analysis step.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `sample_calling`
    - `<sample-id>.dehashed.pxl`: The pixel file containing the data associated with each samples.
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: QC metrics for the sample calling step.
    - `<pool-id>_undetermined.dehashed.pxl`: The pixel file containing data that could not be associated with any sample. This is only output when `pna_sample_calling_save_undetermined = true`.
    - `<pool-id>_undetermined.meta.json`: Command invocation metadata.
    - `<pool-id>_undetermined.report.json`: QC metrics for the sample calling step.

  - `logs`
    - `<pool-id>.pixelator-sample-calling.log`: pixelator log output.

</details>

> [!NOTE]
> This step is run only for pooled samples, i.e. rows with the `pool` and `hash_index` columns set in the samplesheet.

#### Analysis

This step uses the `pixelator single-cell-pna analysis` command to calculate spatial statistics.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `analysis`
    - `<sample-id>.analysis.dataset.pxl`: PXL file with the analysis results added to it.
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: Statistics for the analysis step.

  - `logs`
    - `<sample-id>.pixelator-analysis.log`: pixelator log output.

</details>

#### Compute layouts for visualization

This step uses the `pixelator single-cell-pna layout` command.

It will generate precomputed layouts that can be used to visualize cells
as part of the downstream analysis. This data will be appended to a PXL file.

This entire step can also be skipped using the `--skip_layout` option.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `layout`
    - `<sample-id>.layout.pxl`: PXL file with the layout results added to it.
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: Statistics for the layout step.

  - `logs`
    - `<sample-id>.pixelator-layout.log`: pixelator log output.

</details>

#### Generate report for all samples

This step uses [pixelator-es](https://github.com/PixelgenTechnologies/pixelatores) to generate a Proxime Experiment Summary
that contains information about all the samples in the run.

It will collect metrics and outputs generated by previous stages and generate a report in HTML format.

More information on the report can be found [here](https://github.com/PixelgenTechnologies/pixelatores).

The output from this step will be placed in the output folder root.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `experiment_summary.html`: Proxiome Experiment Summary report

</details>

#### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Parameters used by the pipeline run: `params.json`.
  - Samplesheet used for the run

</details>

[Nextflow](https://docs.seqera.io/platform-cloud/reports/overview) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.

### Output directory structure

With default parameters, the pixelator pipeline output directory will only include the latest PXL file
generated by the pipeline (with the most "complete" information) and an interactive HTML report summarizing the data for all samples.
The PXL dataset files can be from either the `graph`, `analysis` or `layout` step.

With default parameters, the `<sample-id>.layout.pxl` will be copied to the output directory.

Various flags are available to store intermediate files and are described in the input parameter documentation. Alternatively, you can keep all intermediate files using `--save_all`.

> [!WARNING]
> If the `layout` stage is skipped (using `--skip_layout`), use `--save_pna_<last running step>` to output the latest PXL files.

Below is an example output structure for a pipeline run using the default settings.

- `pipeline_info/`
- `pixelator/`
  - `logs/`
    - `<sample-id>/`:
      - `*.log`

  - `pbmcs_unstimulated.layout.pxl`
  - `pbmcs_unstimulated.qc-report.html`
  - `uropod_control.layout.pxl`
  - `uropod_control.qc-report.html`
