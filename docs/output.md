# PixelgenTechnologies/nf-core-pixelator: Output

## Introduction

This document describes the output produced by the pipeline.
The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using multiple subcommands of the [`pixelator`](https://github.com/PixelgenTechnologies/pixelator) tool.

- [`pixelator concatenate`](#pixelator-concatenate)(Optional) - Concatenate paired end data
- [`pixelator preqc`](#pixelator-preqc) - Read QC and filtering
- [`pixelator adapterqc`](#pixelator-adapterqc) - Check for correctness of PBS1/2 sequences
- [`pixelator demux`](#pixelator-demux) - Assign a marker (barcode) to each read
- [`pixelator collapse`](#pixelator-collapse) - Error correction, duplicate removal, compute read counts
- [`pixelator cluster`](#pixelator-cluster) - Compute undirected graphs and basic size filtering
- [`pixelator analysis`](#pixelator-analysis) - Downstream analysis for each cell
- [`pixelator annotate`](#pixelator-annotate) - Filter, annotate and call cells on samples
- [`pixelator aggregate`](#pixelator-aggregate) - Aggregate results
- [`pixelator report`](#pixelator-report) - Report generation

### pixelator concatenate

// TODO: High level description of concatenate step and output files

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `concatenate`
    - `<sample-id>.merged.fastq.gz`:
      Combine R1 and R2 reads into full amplicon reads and calculate Q30 scores for the amplicon regions.
    - `<sample-id>.report.json`: Q30 metrics of the amplicon.
    - `<sample-id>.meta.json`: Command invocation metadata.
- `logs`
  - \*pixelator-concatenate.log`: pixelator log output.

</details>

### pixelator qc

// TODO: High level description of QC step and output files

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `preqc`
    - `<sample-id>.processed.fastq.gz`: Processed reads.
    - `<sample-id>.failed.fastq.gz`: Discarded reads.
    - `<sample-id>.report.json`: Fastp json report.
    - `<sample-id>.meta.json`: Command invocation metadata.
  - `adapterqc`
    - `<sample-id>.processed.fastq.gz`: Processed reads.
    - `<sample-id>.failed.fastq.gz`: Discarded reads.
    - `<sample-id>.report.json`: Cutadapt json report.
    - `<sample-id>.meta.json`: Command invocation metadata.

- `logs` - `*pixelator-preqc.log`: pixelator log output.

</details>

### pixelator demux

// TODO: High level description of demux step and output files

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `demux`
    - `<sample-id>.processed-<antibody_name>.fastq.gz`: Reads demultiplexed per antibody.
    - `<sample-id>.failed.fastq.gz`: Discarded reads that do not match an antibody barcode.
    - `<sample-id>.report.json`: Cutadapt json report.
    - `<sample-id>.meta.json`: Command invocation metadata.

- `logs`
  - `*pixelator-demultiplex.log`: pixelator log output.

</details>

### pixelator collapse

// TODO: High level description of collapse step and output files

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `adapterqc`
    - `<sample-id>.collapsed.csv.gz`: Edgelist of the graph.
    - `<sample-id>.report.json`: Statistics for the collapse step.
    - `<sample-id>.meta.json`: Command invocation metadata.

- `logs`
  - `*pixelator-collapse.log`: pixelator log output.

</details>

### pixelator graph

// TODO: High level description of graph step and output files

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `cluster`
    - `<sample-id>.components_recovered.csv`
    - `<sample-id>.edgelist.csv.gz`
    - `<sample-id>.raw_edgelist.csv.gz`
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`
    - `*.meta.json`: Command invocation metadata.

- `logs`
  - `*pixelator-cluster.log`: pixelator log output.

</details>

### pixelator annotate

// TODO: High level description of annotate step and output files

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `annotate`
    - `<sample-id>.dataset.pxl`
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.rank_vs_size.png`
    - `<sample-id>.raw_components_metrics.csv`
    - `<sample-id>.report.json`
    - `<sample-id>.umap.png`

- `logs`
  - `*pixelator-annotate.log`: pixelator log output.
  </details>

### pixelator analysis

// TODO: High level description of analysis step and output files

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `analysis`
    - `<sample-id>.dataset.pxl`
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`

- `logs`
  - `*pixelator-analysis.log`: pixelator log output.

</details>

### pixelator report

// TODO: High level description of report step and output files

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `report`
    - `<sample-id>_report.html`
- `logs`
  - `*pixelator-report.log`: Pixelator report log output.

</details>

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Metadata file with software versions, environment information and pipeline configuration for debugging: 'metadata.json'

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
