# PixelgenTechnologies/nf-core-pixelator: Output

## Introduction

This document describes the output produced by the pipeline.
The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using multiple subcommands
of [`pixelator`](https://github.com/PixelgenTechnologies/pixelator).

The pipeline consists of the following steps:

- [Preprocessing](#Preprocessing)
- [Quality control](#quality-control)
- [Demultiplexing](#demultiplexing)
- [Duplicate removal and error correction](#duplicate-removal-and-error-correction)
- [Compute connected components](#compute-connected-components)
- [Filtering, annotation, cell-calling](#filtering-annotation-cell-calling)
- [Downstream analysis](#downstream-analysis)
- [Generate reports](#generate-reports)

### Preprocessing

The preprocessing step uses `pixelator single-cell concatenate` to create a full amplicon sequence from both single-end and paired-end data.
It returns a single fastq per sample containing fixed length amplicons.
This step will also calculate Q30 quality scores for different regions of the library.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `concatenate`

    - `<sample-id>.merged.fastq.gz`:
      Combine R1 and R2 reads into full amplicon reads and calculate Q30 scores for the amplicon regions.
    - `<sample-id>.report.json`: Q30 metrics of the amplicon.
    - `<sample-id>.meta.json`: Command invocation metadata.

  - `logs`
    - `<sample-id>.pixelator-concatenate.log`: pixelator log output.

</details>

### Quality control

Quality control is performed using `pixelator single-cell preqc` and `pixelator single-cell adapterqc`.
`preqc` used `fastp` internally. `adapterqc` will use `cutadapt` internally.

The preqc stage performs QC and quality filtering of the raw sequencing data. It also generates a QC report in HTML and JSON formats. It saves processed reads as well as reads that were discarded (too short. too many Ns , too low quality, ...).

The `adapterqc` stage performs a sanity check on the presence and correctness of the PBS1/2 sequences. It also generates a QC report in JSON format. It saves processed reads as well as discarded reads (no match to PBS1/2).

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

  - `logs`
    - `<sample-id>.pixelator-preqc.log`: pixelator log output.

</details>

### Demultiplexing

The `demux` command assigns a marker (barcode) to each read. It also generates QC report in JSON format. It saves processed reads (one per antibody) as well as discarded reads (no match to given barcodes/antibodies). This file contains the antibodies present in the data as well as their sequences and it needs the following columns:

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `demux`

    - `<sample-id>.processed-<antibody_name>.fastq.gz`: Reads demultiplexed per antibody.
    - `<sample-id>.failed.fastq.gz`: Discarded reads that do not match an antibody barcode.
    - `<sample-id>.report.json`: Cutadapt json report.
    - `<sample-id>.meta.json`: Command invocation metadata.

  - `logs`
    - `<sample-id>.pixelator-demultiplex.log`: pixelator log output.

</details>

### Duplicate removal and error correction

This step used the `pixelator single-cell collapse` command.
The collapse command removes duplicates and performs error correction. This is achieved using the UPI and UMI sequences to check for uniqueness, collapse and compute a read count. The command generates a QC report in JSON format. Errors are allowed when collapsing reads using different collapsing algorithms (`--algorithm`).
The output format of this command is an edge list in CSV format.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `collapse`

    - `<sample-id>.collapsed.csv.gz`: Edgelist of the graph.
    - `<sample-id>.report.json`: Statistics for the collapse step.
    - `<sample-id>.meta.json`: Command invocation metadata.

  - `logs`
    - `<sample-id>.pixelator-collapse.log`: pixelator log output.

</details>

### Compute connected components

This step uses the `pixelator single-cell graph` command.
The input is the edge list dataframe (CSV) generated in the collapse step and after filtering it
by count (`--graph_min_count`), the connected components of the graph (graphs) are computed and
added to the edge list in a column called "component".

The graph command has the option to recover components (technical multiplets) into smaller
components using community detection to detect and remove problematic edges.
(See `--multiplet_recovery`). The information to keep track of the original and
new (recovered) components is stored in a file (components_recovered.csv).

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `graph`

    - `<sample-id>.edgelist.csv.gz`:
      Edge list dataframe (CSV) after recovering technical multiplets.
    - `<sample-id>.raw_edgelist.csv.gz`:
      Raw edge list dataframe in csv format before recovering technical multiplets.
    - `<sample-id>.components_recovered.csv`:
      List of new components recovered (when using `--multiple-recovery`)
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: Metrics with useful information about the clustering.
    - `*.meta.json`: Command invocation metadata.

  - `logs`
    - `<sample-id>.pixelator-cluster.log`: pixelator log output.

</details>

### Filtering, annotation, cell-calling

This step uses the `pixelator single-cell annotate` command.

The annotate command takes as input the edge list (CSV) file generated in the graph command.
The edge list is converted to an AnnData object, the command then performs filtering, annotation and
cell calling of the components.

The DataFrame contained in a pxl file will have the same dimension as in the antibody panel so any
missing antibody will be filled with 0's.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `annotate`

    - `<sample-id>.dataset.pxl`
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.rank_vs_size.png`
    - `<sample-id>.raw_components_metrics.csv`
    - `<sample-id>.report.json`: Statistics for the analysis step.
    - `<sample-id>.umap.png`

  - `logs` - `<sample-id>.pixelator-annotate.log`: pixelator log output.
  </details>

### Downstream analysis

This step uses the `pixelator single-cell analysis` command.
Downstream analysis is performed on the `PixelDataset` in PXL format generated by the previous stage.

Currently, the following analysis can be performed (if enabled):

- polarization scores (all the statistics in a dataframe) (enable with --compute_polarization)
- co-localization scores (all pair-wise scores in a dataframe) (enable with --compute_colocalization)

This step can be skipped using the `--skip_analysis` option.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `analysis`

    - `<sample-id>.dataset.pxl`: PixelDataset updated with analysis results.
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: Statistics for the analysis step.

  - `logs`
    - `<sample-id>.pixelator-analysis.log`: pixelator log output.

</details>

### Generate reports

This step uses the `pixelator single-cell report` command.
This step will collect metrics and outputs generated by previous stages
and generate a report in HTML format for each sample.

This step can be skipped using the `--skip_report` option.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `report`
    - `<sample-id>_report.html`: Pixelator summary report.
  - `logs`
    - `<sample-id>.pixelator-report.log`: Pixelator log output.

</details>

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Metadata file with software versions, environment information and pipeline configuration for debugging: `metadata.json`

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
