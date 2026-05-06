# nf-core/pixelator: Output

## Introduction

This document describes the output produced by the pipeline.

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using multiple subcommands
of [`pixelator`](https://github.com/PixelgenTechnologies/pixelator).

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Proximity Network Assay (PNA)

### Pipeline overview

The PNA pipeline consists of the following steps:

- [Amplicon](#amplicon)
- [Demultiplexing](#demultiplexing)
- [Molecule collapsing and error correction](#molecule-collapsing-and-error-correction)
- [Graph construction](#graph-construction)
- [Denoising](#denoising)
- [Analysis](#analysis)
- [Layout creation](#compute-layouts-for-visualization)
- [Per sample report generation](#generate-reports-per-sample)
- [Per run run report generation](#generate-report-for-all-samples)
- [Pipeline information](#pipeline-information)

The output of the Proximity Network Assay (PNA) pipeline is organized into several directories, each corresponding to a specific step in the pipeline. Below is an overview of the output structure and the files generated at each step:

#### Amplicon

The amplicon step uses `pixelator single-cell-pna amplicon` to create full-length amplicon sequences from both single-end and paired-end data.
It will also filter reads based on the presence of the pixel binding sequences and the quality of the reads.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `amplicon`
    - `<sample-id>.amplizon.fq.zst`: Combine R1 and R2 reads into full amplicon reads.
    - `<sample-id>.report.json`: QC metrics collected by the amplicon step.
    - `<sample-id>.meta.json`: Command invocation metadata.
  - `logs`
    - `<sample-id>.pixelator-amplicon.log`: pixelator log output.

</details>

#### Demultiplexing

The `pixelator single-cell-pna demux` command assigns each read to a marker groups, and saves these to parquet files for further processing by
the collapse command. It also generates QC report in JSON format. Discarded reads (i.e. reads that did not have a match
to any marker in the panel) are saved to a separate `<sample-id>.demux.failed.zst` file.

In the parquet files the molecules from each amplicon are stored in a byte array format, to allow for fast processing
in the collapse step.

These processed and discarded FASTQ reads are intermediate and by default not placed in the output folder with the final files delivered to users.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `demux`
    - `<sample-id>.demux.failed.fq.zst`: Discarded reads that do not match a marker.
    - `<sample-id>.demux.m1.part_000.parquet`: Marker 1 reads in parquet format.
    - `<sample-id>.demux.m2.part_000.parquet`: Marker 2 reads in parquet format.
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: QC metrics for the demux step.

  - `logs`
    - `<sample-id>.pixelator-demultiplex.log`: pixelator log output.

</details>

#### Molecule collapsing and error correction

This step uses the `pixelator single-cell-pna collapse` command.

The `collapse` command quantifies molecules by performing error correction and detecting duplicate molecules.
It uses a the unique molecular identifier sequences to check for uniqueness (while allowing for sequencing errors),
and it will then collapse and compute a read count for each molecule.

The output of this step is then used as an edge list input for the graph construction step.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `collapse`
    - `<sample-id>.collapse.parquet`: Edge list of the graph.
    - `<sample-id>.report.json`: QC metrics for the collapse step.
    - `<sample-id>.meta.json`: Command invocation metadata.

  - `logs`
    - `<sample-id>.pixelator-collapse.log`: pixelator log output.

</details>

#### Graph construction

This step uses the `pixelator single-cell-pna graph` command. The input is the edge list parquet file generated in the collapse step.
The graph step will attempt to resolve any multiplet due to erronous edges in the graph, it will then find the connected components
of the graph (i.e. the putative cells) and assign a unique ID to each component.

From this step and onwards, the output file are in PXL format. This is a custom format used by pixelator to make PNA data easier
to work with. Internally it used duckdb to store the data. For more information on the PXL format, please refer to
the [pixelator documentation](https://software.pixelgen.com/pixelator/outputs/pxl-format/).

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

### Denoising

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

### Analysis

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

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.

### Output directory structure

With default parameters, the pixelator pipeline output directory will only include the latest PXL file
generated by the pipeline (with the most "complete" information) and an interactive HTML report per sample.
The PXL dataset files can be from either the `graph`, `analysis` or `layout` step.

With default parameters, the `<sample-id>.layout.pxl` will be copied to the output directory.
If the `layout` stage is skipped (using `--skip_layout`) the `<sample-id>.analysis.pxl` files will be included and
if the `analysis` stage is skipped (using `--skip_analysis`) the `<sample-id>.graph.pxl` will be copied.

Various flags are available to store intermediate files and are described in the input parameter documentation. Alternatively, you can keep all intermediate files using `--save_all`.

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
