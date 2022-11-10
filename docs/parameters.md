# Parameters

## On this page

- 1. [Input/output options](#inputoutput-options)
- 2. [QC/Filtering/Trimming options](#qcfilteringtrimming-options)
- 3. [Adapter QC Options](#adapter-qc-options)
- 4. [Demux options](#demux-options)
- 5. [Collapse options](#collapse-options)
- 6. [Options for pixelator cluster command.](#options-for-pixelator-cluster-command)
- 7. [Options for pixelator analysis command.](#options-for-pixelator-analysis-command)
- 8. [Options for pixelator report command.](#options-for-pixelator-report-command)
- 9. [Institutional config options](#institutional-config-options)
- 10. [Max job request options](#max-job-request-options)
- 11. [Global options](#global-options)
- 12. [Generic options](#generic-options)

## Parameters

<a name="inputoutput-options"/>
## <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/terminal.svg" width=32 height=32 />    Input/output options

Define where the pipeline should find input data and save output data.### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/file-csv.svg" width=16 height=16 /> `--input`

**Type:** string

Path to comma-separated file containing information about the samples in the experiment.
You will need to create a design file with information about the samples in your experiment before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 3 columns, and a header row. See [usage docs](https://nf-co.re/pixelator/usage#samplesheet-input).

---

### `--mode`

**Type:** string
**Options:** [main|aggregate]
**Default:** main

Mode to run the pipeline in [default: main]

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/folder-open.svg" width=16 height=16 /> `--outdir`

**Type:** string
**Default:** ./results

The output directory where the results will be saved. You have to use absolute paths to storage on Cloud infrastructure.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/envelope.svg" width=16 height=16 /> `--email`

**Type:** string

Email address for completion summary.
Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits. If set in your user config file (`~/.nextflow/config`) then you don't need to specify this on the command line for every run.

<a name="qcfilteringtrimming-options"/>
## <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/terminal.svg" width=32 height=32 />    QC/Filtering/Trimming options

### `--trim_front`

**Type:** integer

Trim N bases from the front of the reads

---

### `--trim_tail`

**Type:** integer

Trim N bases from the tail of the reads

---

### `--max_length`

**Type:** integer

The maximum length (bases) of a read (longer reads will be trimmed off). If you set this argument it will overrrule the value from the chosen design

---

### `--min_length`

**Type:** integer

The minimum length (bases) of a read (shorter reads will be discarded). If you set this argument it will overrrule the value from the chosen design.

---

### `--max_n_bases`

**Type:** integer
**Default:** 3

The maximum number of Ns allowed in a read

---

### `--avg_qual`

**Type:** integer
**Default:** 20

Minimum avg. quality a read must have (0 will disable the filter)

---

### `--dedup`

**Type:** boolean

Remove duplicated reads (exact same sequence)

---

### `--remove_polyg`

**Type:** boolean

Remove PolyG sequences (length of 10 or more)

<a name="adapter-qc-options"/>

## Adapter QC Options

### `--adapterqc_mismatches`

**Type:** number
**Default:** 0.1

The number of mismatches allowed (in percentage) [default: 0.1; 0.0<=x<=0.9]

---

### `--pbs1`

**Type:** string

The PBS1 sequence that must be present in the reads. If you set this argument it will overrrule the value from the chosen design

---

### `--pbs2`

**Type:** ['string', 'null']

The PBS2 sequence that must be present in the reads. If you set this argument it will overrrule the value from the chosen design

<a name="demux-options"/>

## Demux options

### `--demux_mismatches`

**Type:** number
**Default:** 0.1

The number of mismatches allowed (in percentage) [default: 0.1; 0.0<=x<=0.9]

---

### `--demux_min_length`

**Type:** ['integer', 'null']

The minimum length of the barcode that must overlap when matching. If you set this argument it will overrrule the value from the chosen design

---

### `--demux_anchored`

**Type:** boolean

Enforce the barcodes to be anchored (at the end of the read)

---

### `--demux_rev_complement`

**Type:** boolean

Use the reverse complement of the barcodes sequences

<a name="collapse-options"/>

## Collapse options

### `--algorithm`

**Type:** string
**Options:** [adjacency|unique]
**Default:** adjacency

The algorithm to use for collapsing (adjacency will peform error correction using the number of mismatches given) [default: adjacency]

---

### `--upi1_start`

**Type:** integer

The start position (0-based) of UPI1. If you set this argument it will overrrule the value from the chosen design

---

### `--upi1_end`

**Type:** integer

The end position (1-based) of UPI1. If you set this argument it will overrrule the value from the chosen design

---

### `--upi2_start`

**Type:** integer

The start position (0-based) of UPI@. If you set this argument it will overrrule the value from the chosen design

---

### `--upi2_end`

**Type:** integer

The end position (1-based) of UPI2. If you set this argument it will overrrule the value from the chosen design

---

### `--umi1_start`

**Type:** integer

The start position (0-based) of UMI1 (disabled by default). If you set this argument it will overrrule the value from the chosen design

---

### `--umi1_end`

**Type:** integer

The end position (1-based) of UMI1 (disabled by default). If you set this argument it will overrrule the value from the chosen design

---

### `--umi2_start`

**Type:** integer

The start position (0-based) of UMI2 (disabled by default). If you set this argument it will overrrule the value from the chosen design

---

### `--umi2_end`

**Type:** integer

The end position (1-based) of UMI2 (disabled by default). If you set this argument it will overrrule the value from the chosen design

---

### `--neighbours`

**Type:** integer
**Default:** 60

The number of neighbours to use when searching for similar sequences (adjacency) This number depends on the sequence depth and the ratio of erronous molecules expected. A high value can make the algoritthm slower. [default: 60; 1<=x<=250]

---

### `--collapse_mismatches`

**Type:** integer
**Default:** 2

The number of mismatches allowed when collapsing (adjacency) [default: 2; 0<=x<=5]

---

### `--collapse_min_count`

**Type:** integer
**Default:** 1

Discard molecules with with a count (reads) lower than this value [default: 1; 0<=x<=5]

---

### `--use_counts`

**Type:** boolean

Use counts when collapsing (the difference in counts between two molecules must be more than double in order to be collapsed)

<a name="options-for-pixelator-cluster-command"/>

## Options for pixelator cluster command.

### `--min_size`

**Type:** integer

The minimum size (pixels) a cluster/cell must have (default is no filtering)

---

### `--max_size`

**Type:** integer

The maximum size (pixels) a cluster/cell must have (default is no filtering)

---

### `--max_size_recover`

**Type:** integer
**Default:** 10000

The maximum size cutoff to use in the recovery (--big-clusters-recover) [default: 10000]

---

### `--big_clusters_recover`

**Type:** boolean

Enable the recovery of big clusters/cells (above --max-size-recover) by using the community modularity approach to remove problematic edges

---

### `--condition`

**Type:** string
**Options:** [optimal|max-size]
**Default:** optimal

Which approach to use to select the best community (--big-clusters-recover) optimal will use the community that maximizes the modularity max-size will iterate until the biggest component in the community is below --max-size/2 or the maximum number of iterations is reached [default: optimal]

---

### `--cluster_min_count`

**Type:** integer
**Default:** 2

Discard molecules (edges) with with a count (reads) lower than this [default: 2; 1<=x<=50]

---

### `--min_size_markers`

**Type:** integer

The minimum number of detected markers a cluster/cell must have (default is no filtering)

<a name="options-for-pixelator-analysis-command"/>

## Options for pixelator analysis command.

### `--compute_polarization`

**Type:** boolean

Compute polarization scores matrix (clusters by markers)

---

### `--compute_colocalization`

**Type:** boolean

Compute colocalization scores matrix (clusters by markers)

---

### `--compute_coabundance`

**Type:** boolean

Compute coabundance scores matrix (clusters by markers)

---

### `--use_full_bipartite`

**Type:** boolean

Use the bipartite graph instead of the one-node projection when computing polarization, coabundance and colocalization scores

---

### `--binarization`

**Type:** string
**Options:** [percentile|denoise]
**Default:** percentile

Use the bipartite graph instead of the one-node projection when computing polarization, coabundance and colocalization scores

---

### `--percentile`

**Type:** number

The percentile value (0-1) to use when binarizing counts in the polarization and co-localization algorithms [default: 0.0; 0.0<=x<=1.0]

---

### `--antibody_control`

**Type:** string

A comma separated list of antibodies to use as control for the denoise binarization method (--binarization). The antibody(s) must be present in the data with the same names

<a name="options-for-pixelator-report-command"/>

## Options for pixelator report command.

### `--report_name`

**Type:** ['string']
**Default:** report

The name for the report

<a name="institutional-config-options"/>
## <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/university.svg" width=32 height=32 />    Institutional config options

Parameters used to describe centralised config profiles. These should not be edited.### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/users-cog.svg" width=16 height=16 /> `--custom_config_version`

**Type:** string
**Default:** master

Git commit id for Institutional configs.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/users-cog.svg" width=16 height=16 /> `--custom_config_base`

**Type:** string
**Default:** https://raw.githubusercontent.com/nf-core/configs/master

Base directory for Institutional configs.
If you're running offline, Nextflow will not be able to fetch the institutional config files from the internet. If you don't need them, then this is not a problem. If you do need them, you should download the files from the repo and tell Nextflow where to find them with this parameter.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/users-cog.svg" width=16 height=16 /> `--config_profile_name`

**Type:** string

Institutional config name.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/users-cog.svg" width=16 height=16 /> `--config_profile_description`

**Type:** string

Institutional config description.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/users-cog.svg" width=16 height=16 /> `--config_profile_contact`

**Type:** string

Institutional config contact information.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/users-cog.svg" width=16 height=16 /> `--config_profile_url`

**Type:** string

Institutional config URL link.

<a name="max-job-request-options"/>
## <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/fab acquisitions-incorporated.svg" width=32 height=32 />    Max job request options

Set the top limit for requested resources for any single job.### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/microchip.svg" width=16 height=16 /> `--max_cpus`

**Type:** integer
**Default:** 16

Maximum number of CPUs that can be requested for any single job.
Use to set an upper-limit for the CPU requirement for each process. Should be an integer e.g. `--max_cpus 1`

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/memory.svg" width=16 height=16 /> `--max_memory`

**Type:** string
**Default:** 128.GB

Maximum amount of memory that can be requested for any single job.
Use to set an upper-limit for the memory requirement for each process. Should be a string in the format integer-unit e.g. `--max_memory '8.GB'`

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/far clock.svg" width=16 height=16 /> `--max_time`

**Type:** string
**Default:** 240.h

Maximum amount of time that can be requested for any single job.
Use to set an upper-limit for the time requirement for each process. Should be a string in the format integer-unit e.g. `--max_time '2.h'`

<a name="global-options"/>
## <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/file-import.svg" width=32 height=32 />    Global options

Less common options for the pipeline (specific to nf-core-pixelator), typically set in a config file.### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/question-circle.svg" width=16 height=16 /> `--pixelator_tag`

**Type:** string

Override which container tag of pixelator to use. Use carefully!
This option allows you to use a different container tag for the pixelator tool.
This is intended for developers and power-users and can break the pipeline. Use on your own risk!

<a name="generic-options"/>
## <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/file-import.svg" width=32 height=32 />    Generic options

Less common options for the pipeline, typically set in a config file.### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/question-circle.svg" width=16 height=16 /> `--help`

**Type:** boolean

Display help text.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/copy.svg" width=16 height=16 /> `--publish_dir_mode`

**Type:** string
**Options:** [symlink|rellink|link|copy|copyNoFollow|move]
**Default:** copy

Method used to save pipeline results to output directory.
The Nextflow `publishDir` option specifies which intermediate files should be saved to the output directory. This option tells the pipeline what method should be used to move these files. See [Nextflow docs](https://www.nextflow.io/docs/latest/process.html#publishdir) for details.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/exclamation-triangle.svg" width=16 height=16 /> `--email_on_fail`

**Type:** string

Email address for completion summary, only when pipeline fails.
An email address to send a summary email to when the pipeline is completed - ONLY sent if the pipeline does not exit successfully.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/remove-format.svg" width=16 height=16 /> `--plaintext_email`

**Type:** boolean

Send plain-text email instead of HTML.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/file-upload.svg" width=16 height=16 /> `--max_multiqc_email_size`

**Type:** string
**Default:** 25.MB

File size limit when attaching MultiQC reports to summary emails.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/palette.svg" width=16 height=16 /> `--monochrome_logs`

**Type:** boolean

Do not use coloured log outputs.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/cog.svg" width=16 height=16 /> `--multiqc_config`

**Type:** string

Custom config file to supply to MultiQC.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/cogs.svg" width=16 height=16 /> `--tracedir`

**Type:** string
**Default:** ${params.outdir}/pipeline_info

Directory to keep pipeline Nextflow logs and reports.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/check-square.svg" width=16 height=16 /> `--validate_params`

**Type:** boolean
**Default:** True

Boolean whether to validate parameters against the schema at runtime

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/far eye-slash.svg" width=16 height=16 /> `--show_hidden_params`

**Type:** boolean

Show all params when using `--help`
By default, parameters set as _hidden_ in the schema are not shown on the command line when a user runs with `--help`. Specifying this option will tell the pipeline to show all parameters.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/bacon.svg" width=16 height=16 /> `--enable_conda`

**Type:** boolean

Run this workflow with Conda. You can also use '-profile conda' instead of providing this parameter.

---

### <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/folder-tree.svg" width=16 height=16 /> `--testdata_root`

**Type:** string

Root path to testdata for running local tests
