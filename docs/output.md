# PixelgenTechnologies/nf-core-pixelator: Output

## Introduction

This document describes the output produced by the pipeline.
The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using multiple subcommands of the [`pixelator`](https://github.com/PixelgenTechnologies/pixelator) tool.

- [`pixelator concatenate`](#pixelator-concatenate)(Optional) - Concatenate paired end data
- [`pixelator preqc`](#pixelator-preqc)) - Read QC and filtering
- [`pixelator adapterqc`](#pixelator-adapterqc)) - Check correctness/presence of PBS1/2 sequences
- [`pixelator demux`](#pixelator-demux)) - Assign a marker (barcode) to each read
- [`pixelator collapse`](#pixelator-collapse)) - Error correction, duplicate removal, compute read counts
- [`pixelator cluster`](#pixelator-cluster)) - Compute undirected graphs and basic size filtering
- [`pixelator analysis`](#pixelator-analysis)) - Downstream analysis for each cell
- [`pixelator annotate`](#pixelator-annotate)) - Filter, annotate and call cells on samples
- [`pixelator aggregate`](#pixelator-aggregate)) - Aggregate results
- [`pixelator report`](#pixelator-report)) - Report generation

### pixelator concatenate

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `concatenate`
    - `*merged.fastq.gz`: Concatenated R1 and R2 reads.
  - `/logs` - `*pixelator-concatenate.log`: Pixelator concatenate log output.
  </details>

### pixelator preqc

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `preqc`
    - `*processed.fastq.gz`: Processed reads.
    - `*failed.fastq.gz`: Discarded reads.
    - `*report.html`: Fastp html report.
    - `*report.json`: Fastp json report.
  - `/logs` - `*pixelator-preqc.log`: Pixelator preqc log output.
  </details>

### pixelator adapterqc

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `adapterqc`
    - `*processed.fastq.gz`: Processed reads.
    - `*failed.fastq.gz`: Discarded reads.
    - `*report.json`: Cutadapt json report.
  - `/logs` - `*pixelator-adapterqc.log`: Pixelator adapterqc log output.
  </details>

### pixelator demux

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `adapterqc`
    - `*processed-*-.fastq.gz`: Reads demultiplexed per antibody.
    - `*report.json`: Cutadapt json report.
  - `/logs` - `*pixelator-demultiplex.log`: Pixelator adapterqc log output.
  </details>

### pixelator collapse

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `adapterqc`
    - `*.collapse.csv`: Edge list matrix.
    - `*collapse.json`: Statistics.
  - `/logs` - `*pixelator-collapse.log`: Pixelator collapse log output.
  </details>

### pixelator cluster

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `cluster`
    - `<sample-id>.components_recovered.csv`
    - `<sample-id>.data_summary.png`
    - `<sample-id>.raw_anndata.h5ad`
    - `<sample-id>.raw_antibody_metrics.csv`
    - `<sample-id>.raw_antibody_metrics.png`
    - `<sample-id>.raw_components_antibody.csv`
    - `<sample-id>.raw_components_dist.png`
    - `<sample-id>.raw_components_metrics.csv`
    - `<sample-id>.raw_pixel_data.csv`
    - `<sample-id>.report.json`
  - `/logs` - `*pixelator-cluster.log`: Pixelator cluster log output.
  </details>

### pixelator annotate

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `annotate`
  - `<sample-id>.data_summary.png`
  - `<sample-id>.filtered_anndata.h5ad`
  - `<sample-id>.filtered_antibody_metrics.csv`
  - `<sample-id>.filtered_antibody_metrics.png`
  - `<sample-id>.filtered_components_antibody.csv`
  - `<sample-id>.filtered_components_dist.png`
  - `<sample-id>.filtered_components_metrics.csv`
  - `<sample-id>.filtered_pixel_data.csv`
  - `<sample-id>.report.json`
  - `/logs` - `*pixelator-annotate.log`: Pixelator cluster log output.
  </details>

### pixelator analysis

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `analysis`
    - `<sample-name>.anndata.h5ad`
    - `<sample-name>.polarization_boxplot.png`
    - `<sample-name>.polarization_heatmap.png`
    - `<sample-name>.polarization_matrix.csv`
    - `<sample-name>.report.json`
  - `/logs` - `*pixelator-analysis.log`: Pixelator analysis log output.

</details>

### pixelator aggregate

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `aggregate`
    - `<sample-name>.merged_anndata.h5ad`: Anndata object with aggregated data of multiple samples
  - `/logs` - `*pixelator-report.log`: Pixelator report log output.
  </details>

### pixelator report

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `reports/report`
    - `antibody_counts.html`:
    - `clusters_dist.html`:
    - `report.html`:
    - `summary_stats.html`:
  - `/logs` - `*pixelator-report.log`: Pixelator report log output.
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
