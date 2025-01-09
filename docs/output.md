# nf-core/pixelator: Output

## Introduction

This document describes the output produced by the pipeline.
The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using multiple subcommands
of [`pixelator`](https://github.com/PixelgenTechnologies/pixelator).

The pipeline consists of the following steps:

- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution
- [Preprocessing](#Preprocessing)
- [Quality control](#quality-control)
- [Demultiplexing](#demultiplexing)
- [Duplicate removal and error correction](#duplicate-removal-and-error-correction)
- [Compute connected components](#compute-connected-components)
- [Filtering, annotation, cell-calling](#cell-calling-filtering-and-annotation)
- [Downstream analysis](#downstream-analysis)
- [Generate layouts for visualization](#compute-layouts-for-visualization)
- [Generate reports](#generate-reports)

### Preprocessing

The preprocessing step uses `pixelator single-cell amplicon` to create full-length amplicon sequences from both single-end and paired-end data.
It returns a single FASTQ file per sample containing fixed length amplicons.
This step will also calculate Q30 quality scores for different regions of the library.

These amplicon FASTQ files are intermediate and by default not placed in the output folder with the final files delivered to users.
Set `--save_amplicon_reads` or `--save_all` to enable publishing of these files to:

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `amplicon`

    - `<sample-id>.merged.fastq.gz`:
      Combine R1 and R2 reads into full amplicon reads and calculate Q30 scores for the amplicon regions.
    - `<sample-id>.report.json`: Q30 metrics of the amplicon.
    - `<sample-id>.meta.json`: Command invocation metadata.

  - `logs`
    - `<sample-id>.pixelator-amplicon.log`: pixelator log output.

</details>

### Quality control

Quality control is performed using `pixelator single-cell preqc` and `pixelator single-cell adapterqc`.

The preqc step performs QC and quality filtering of the raw sequencing data using [Fastp](https://github.com/OpenGene/fastp) internally.
It generates a QC report in HTML and JSON formats. It saves processed reads as well as reads that were
discarded (i.e. were too short, had too many Ns, or too low quality, etc.). Internally `preqc`

The `adapterqc` stage checks for the presence and correctness of the pixel binding sequences,
using [Cutadapt](https://cutadapt.readthedocs.io/en/stable/) internally.
It also generates a QC report in JSON format. It saves processed reads as well as discarded reads (i.e. reads that did not have a match for both pixel binding sequences).

These processed and discarded FASTQ reads are intermediate and by default not placed in the output folder with the final files delivered to users.
Set `--save_qc_passed_reads` and/or `--save_qc_passed_reads` to enable publishing of these files.
Alternatively, set `--save_all` to keep all intermediary outputs of all steps.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `preqc`

    - `<sample-id>.processed.fastq.gz`: Processed reads.
    - `<sample-id>.failed.fastq.gz`: Discarded reads.
    - `<sample-id>.report.json`: Fastp json report.
    - `<sample-id>.qc-report.html`: Fastp html report.
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

The `pixelator single-cell demux` command assigns each read to a marker (with a certain barcode) file. It also generates QC report in
JSON format. It saves processed reads (one file per antibody) as well as discarded reads (in a different file) with no match to the
given barcodes/antibodies.

These processed and discarded FASTQ reads are intermediate and by default not placed in the output folder with the final files delivered to users.
Set `--save_demux_failed_reads` and/or `--save_demux_processed_reads` to enable publishing of these files.
Alternatively, set `--save_all` to keep all intermediary outputs of all steps.

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

This step uses the `pixelator single-cell collapse` command.

The `collapse` command quantifies molecules by performing error correction and detecting PCR duplicates.
This is achieved using the unique pixel identifier and unique molecular identifier sequences to check for uniqueness, collapse and compute a read count.
The command generates a QC report in JSON format.
Errors are allowed when collapsing reads if `--algorithm` is set to `adjacency` (this is the default option).

The output format of this command is a parquet file containing deduplicated and error-corrected molecules.

The collapsed reads are intermediate and by default not placed in the output folder with the final files delivered to users.
Set `--save_collapsed_reads` to enable publishing of these files.
Alternatively, set `--save_all` to keep all intermediary outputs of all steps.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `collapse`

    - `<sample-id>.collapsed.parquet`: Edge list of the graph.
    - `<sample-id>.report.json`: Statistics for the collapse step.
    - `<sample-id>.meta.json`: Command invocation metadata.

  - `logs`
    - `<sample-id>.pixelator-collapse.log`: pixelator log output.

</details>

### Compute connected components

This step uses the `pixelator single-cell graph` command.
The input is the edge list parquet file generated in the collapse step.
The molecules from edge list are filtered by count (`--graph_min_count`) to form the edges of the connected components of the graph.
When graphs are computed and identified, their ID names are added back to the edge list in a column called "component".

The graph command has the option to recover components (technical multiplets) into smaller
components using community detection to find and remove problematic edges
(see `--multiplet_recovery`). These new component IDs are then stored in the "component" column.

The edge list is intermediate and by default not placed in the output folder with the final files delivered to users.
Set `--save_edgelist` to enable publishing of these file.

Alternatively, set `--save_all` to keep all intermediary outputs of all steps.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `graph`

    - `<sample-id>.edgelist.parquet`:
      Edge list dataframe after recovering technical multiplets.
    - `<sample-id>.components_recovered.csv`:
      List of new components recovered (when using `--multiple-recovery`)
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: Metrics with useful information about the clustering.
    - `*.meta.json`: Command invocation metadata.

  - `logs`
    - `<sample-id>.pixelator-cluster.log`: pixelator log output.

</details>

### Cell-calling, filtering, and annotation

This step uses the `pixelator single-cell annotate` command.

The annotate command takes as input the molecule list file generated in the graph command. It parses, and filters the
molecules grouped by "component" ID to find putative cells, and it will generate a PXL file containing the edges of the graphs in an edge list, and an
(AnnData object)[https://anndata.readthedocs.io/en/latest/] as well as some useful metadata.

Some summary statistics before filtering are stored in `raw_components_metrics.csv.gz`.
This file is not included in the output folder by default, but can be included by passing `--save_raw_component_metrics`.

By default, the PXL file after annotate will not be saved to the results directory unless `--skip_analysis` and `--skip_layout` is passed.
Set `--save_annotate_dataset` to include these files.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `annotate`
    - `<sample-id>.annotate.dataset.pxl`: The annotated PXL dataset,
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.raw_components_metrics.csv.gz`
    - `<sample-id>.report.json`: Statistics for the analysis step.
  - `logs`
    - `<sample-id>.pixelator-annotate.log`: pixelator log output.
    </details>

### Downstream analysis

This step uses the `pixelator single-cell analysis` command.
Downstream analyses are performed on the PXL file generated by the previous stage.
The results of the analysis are added to the PXL file produced in this stage.

Currently, the following analyses are performed:

- polarization scores (enable with `--compute_polarization`)
- co-localization scores (enable with `--compute_colocalization`)

Each analysis can be disabled by using respectively `--compute_polarization false` or `--compute_colocalization false`.
This entire step can also be skipped using the `--skip_analysis` option.

By default, the PXL file after analysis will not be saved to the results directory unless `--skip_layout` is passed.
Set `--save_analysis_dataset` to include these files.

Alternatively, set `--save_all` to keep all intermediary outputs of all steps.

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

### Compute layouts for visualization

This step uses the `pixelator single-cell layout` command.
It will generate precomputed layouts that can be used to visualize cells
as part of the downstream analysis. This data will be appended to a PXL file.

This entire step can also be skipped using the `--skip_layout` option.

Set `--save_all` to keep all intermediary outputs of all steps.

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `layout`

    - `<sample-id>.layout.dataset.pxl`: PXL file with the layout results added to it.
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: Statistics for the layout step.

  - `logs`
    - `<sample-id>.pixelator-layout.log`: pixelator log output.

</details>

### Generate reports

This step uses the `pixelator single-cell report` command.
This step will collect metrics and outputs generated by previous stages
and generate a report in HTML format for each sample.

This step can be skipped using the `--skip_report` option.

More information on the report can be found in the [pixelator documentation](https://software.pixelgen.com/pixelator/outputs/qc-report/)

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
  - Metadata file with software versions, environment information and pipeline configuration for debugging: `metadata.json`
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.

## Output directory structure

With default parameters, the pixelator pipeline output directory will only include the latest PXL file
generated by the pipeline (with the most "complete" information) and an interactive HTML report per sample.
The PXL dataset files can be from either the `annotate`, `analysis` or `layout` step.

With default parameters, the `<sample-id>.layout.datasets.pxl` will be copied to the output directory.
If the `layout` stage is skipped (using `--skip_layout`) the `<sample-id>.analysis.datasets.pxl` files will be included and
if the `analysis` stage is skipped (using `--skip_analysis`) the `<sample-id>.annotate.datasets.pxl` will be copied.

Various flags are available to store intermediate files and are described in the input parameter documentation. Alternatively, you can keep all intermediate files using `--save_all`.

Below is an example output structure for a pipeline run using the default settings.

- `pipeline_info/`
- `pixelator/`

  - `logs/`

    - `<sample-id>/`:
      - `*.log`

  - `pbmcs_unstimulated.layout.dataset.pxl`
  - `pbmcs_unstimulated.qc-report.html`
  - `uropod_control.layout.dataset.pxl`
  - `uropod_control.qc-report.html`
