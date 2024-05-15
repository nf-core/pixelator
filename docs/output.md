# nf-core/pixelator: Output

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
- [Filtering, annotation, cell-calling](#cell-calling-filtering-and-annotation)
- [Downstream analysis](#downstream-analysis)
- [Generate reports](#generate-reports)

### Preprocessing

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

The preprocessing step uses `pixelator single-cell amplicon` to create full-length amplicon sequences from both single-end and paired-end data.
It returns a single fastq file per sample containing fixed length amplicons.
This step will also calculate Q30 quality scores for different regions of the library.

### Quality control

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

Quality control is performed using `pixelator single-cell preqc` and `pixelator single-cell adapterqc`.

The preqc stage performs QC and quality filtering of the raw sequencing data.
It also generates a QC report in HTML and JSON formats. It saves processed reads as well as reads that were
discarded (i.e. were too short, had too many Ns, or too low quality, etc.). Internally `preqc`
uses [Fastp](https://github.com/OpenGene/fastp), and `adapterqc`
uses [Cutadapt](https://cutadapt.readthedocs.io/en/stable/).

The `adapterqc` stage checks for the presence and correctness of the pixel binding sequences. It also generates a QC report in JSON format. It saves processed reads as well as discarded reads (i.e. reads that did not have a match for both pixel binding sequences).

### Demultiplexing

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

The `pixelator single-cell demux` command assigns a marker (barcode) to each read. It also generates QC report in
JSON format. It saves processed reads (one per antibody) as well as discarded reads with no match to the
given barcodes/antibodies.

### Duplicate removal and error correction

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `collapse`

    - `<sample-id>.collapsed.parquet`: Edgelist of the graph.
    - `<sample-id>.report.json`: Statistics for the collapse step.
    - `<sample-id>.meta.json`: Command invocation metadata.

  - `logs`
    - `<sample-id>.pixelator-collapse.log`: pixelator log output.

</details>

This step uses the `pixelator single-cell collapse` command.

The `collapse` command removes duplicate reads and performs error correction.
This is achieved using the unique pixel identifier and unique molecular identifier sequences to check for
uniqueness, collapse and compute a read count. The command generates a QC report in JSON format.
Errors are allowed when collapsing reads if `--algorithm` is set to `adjacency` (this is the default option).

The output format of this command is an edge list in CSV format.

### Compute connected components

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

This step uses the `pixelator single-cell graph` command.
The input is the edge list dataframe (CSV) generated in the collapse step and after filtering it
by count (`--graph_min_count`), the connected components of the graph (graphs) are computed and
added to the edge list in a column called "component".

The graph command has the option to recover components (technical multiplets) into smaller
components using community detection to find and remove problematic edges.
(See `--multiplet_recovery`). The information to keep track of the original and
newly recovered components are stored in a file (components_recovered.csv).

### Cell-calling, filtering, and annotation

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
  - `logs`
    - `<sample-id>.pixelator-annotate.log`: pixelator log output.
    </details>

This step uses the `pixelator single-cell annotate` command.

The annotate command takes as input the edge list (CSV) file generated in the graph command. It parses, and filters the
edgelist to find putative cells, and it will generate a pxl file containing the edgelist, and an
(AnnData object)[https://anndata.readthedocs.io/en/latest/] as well as some useful metadata.

### Downstream analysis

<details markdown="1">
<summary>Output files</summary>

- `pixelator`

  - `analysis`

    - `<sample-id>.dataset.pxl`: PXL file with the analysis results added to it.
    - `<sample-id>.meta.json`: Command invocation metadata.
    - `<sample-id>.report.json`: Statistics for the analysis step.

  - `logs`
    - `<sample-id>.pixelator-analysis.log`: pixelator log output.

</details>

This step uses the `pixelator single-cell analysis` command.
Downstream analysis is performed on the `pxl` file generated by the previous stage.
The results of the analysis is added to the pxl file.

Currently, the following analysis are performed:

- polarization scores (enable with `--compute_polarization`)
- co-localization scores (enable with `--compute_colocalization`)

Each analysis can be disabled by using respectively `--compute_polarization false` or `--compute_colocalization false`.
This entire step can also be skipped using the `--skip_analysis` option.

### Generate reports

<details markdown="1">
<summary>Output files</summary>

- `pixelator`
  - `report`
    - `<sample-id>_report.html`: Pixelator summary report.
  - `logs`
    - `<sample-id>.pixelator-report.log`: Pixelator log output.

</details>

This step uses the `pixelator single-cell report` command.
This step will collect metrics and outputs generated by previous stages
and generate a report in HTML format for each sample.

This step can be skipped using the `--skip_report` option.

More information on the report can be found in the [pixelator documentation](https://software.pixelgen.com/pixelator/outputs/web-report/)

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Metadata file with software versions, environment information and pipeline configuration for debugging: `metadata.json`
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
