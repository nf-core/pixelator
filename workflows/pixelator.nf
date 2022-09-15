/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPixelator.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
// ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

/*
========================================================================================
    IMPORT CUSTOM MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Defined locally
//
include { PIXELATOR_CONCATENATE         } from '../modules/local/pixelator/concatenate/main'
include { PIXELATOR_PREQC               } from '../modules/local/pixelator/preqc/main'
include { PIXELATOR_ADAPTERQC           } from '../modules/local/pixelator/adapterqc/main'
include { PIXELATOR_DEMUX               } from '../modules/local/pixelator/demux/main'
include { PIXELATOR_COLLAPSE            } from '../modules/local/pixelator/collapse/main'
include { PIXELATOR_CLUSTER             } from '../modules/local/pixelator/cluster/main'
include { PIXELATOR_REPORT              } from '../modules/local/pixelator/report/main'
include { RENAME_READS                  } from '../modules/local/rename_reads'


/*
========================================================================================
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow PIXELATOR {

    ch_versions = Channel.empty()

    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    ch_reads = INPUT_CHECK.out.reads
    ch_reads.dump(tag: "ch_reads")

    // We need to rename to make all reads match the sample name,
    // since pixelator extracts sample_names from read namaes
    RENAME_READS ( ch_reads )
    ch_renamed_reads = RENAME_READS.out.reads
    ch_renamed_reads.dump(tag: "ch_renamed_reads")

    ch_renamed_branched = ch_renamed_reads.branch {
        single_end: it[0].single_end
        paired_end: true
    }

    ch_renamed_branched.single_end.dump(tag: "ch_renamed_branched.single_end")
    ch_renamed_branched.paired_end.dump(tag: "ch_renamed_branched.paired_end")


    PIXELATOR_CONCATENATE ( ch_renamed_branched.paired_end )
    ch_merged = PIXELATOR_CONCATENATE.out.merged
    ch_merged.dump(tag: "ch_merged")
    ch_versions = ch_versions.mix(PIXELATOR_CONCATENATE.out.versions.first())

    // Return concatenate ouput but with [] placeholder for single_end reads
    ch_concat_results = ch_renamed_branched.single_end
        .map { meta, _ -> [meta, []] }
        .mix(PIXELATOR_CONCATENATE.out.results_dir)
    ch_concat_results.dump(tag: "ch_concat_results")

    ch_input_reads = ch_renamed_branched.single_end.mix(ch_merged)
    ch_input_reads.dump(tag: "ch_input_reads")

    PIXELATOR_PREQC ( ch_input_reads )
    ch_preqc = PIXELATOR_PREQC.out.processed
    ch_preqc.dump(tag: "ch_preqc")
    ch_versions = ch_versions.mix(PIXELATOR_PREQC.out.versions.first())

    PIXELATOR_ADAPTERQC ( ch_input_reads )
    ch_adapterqc = PIXELATOR_ADAPTERQC.out.processed
    ch_adapterqc.dump(tag: "ch_adapterqc")
    ch_versions = ch_versions.mix(PIXELATOR_ADAPTERQC.out.versions.first())

    PIXELATOR_DEMUX ( ch_adapterqc )
    ch_demuxed = PIXELATOR_DEMUX.out.processed
    ch_demuxed.dump(tag: "ch_demuxed")
    ch_versions = ch_versions.mix(PIXELATOR_DEMUX.out.versions.first())

    PIXELATOR_COLLAPSE ( ch_demuxed )
    ch_collapsed = PIXELATOR_COLLAPSE.out.collapsed
    ch_collapsed.dump(tag: "ch_collapsed")
    ch_versions = ch_versions.mix(PIXELATOR_COLLAPSE.out.versions.first())

    PIXELATOR_CLUSTER( ch_collapsed )
    ch_clustered = PIXELATOR_CLUSTER.out.results
    ch_clustered.dump(tag: "ch_clustered")
    ch_versions = ch_versions.mix(PIXELATOR_CLUSTER.out.versions.first())

    ch_concatenate_col = ch_concat_results.map { meta, data -> [meta.id, data] }
    ch_preqc_col       = PIXELATOR_PREQC.out.results_dir.map { meta, data -> [ meta.id, data] }
    ch_adapterqc_col   = PIXELATOR_ADAPTERQC.out.results_dir.map { meta, data -> [ meta.id, data] }
    ch_demux_col       = PIXELATOR_DEMUX.out.results_dir.map { meta, data -> [ meta.id, data] }
    ch_collapse_col    = PIXELATOR_COLLAPSE.out.results_dir.map { meta, data -> [ meta.id, data] }
    ch_cluster_col     = PIXELATOR_CLUSTER.out.results_dir.map { meta, data -> [ meta.id, data] }

    ch_report_data    = ch_concatenate_col
        .concat ( ch_preqc_col )
        .concat ( ch_adapterqc_col )
        .concat ( ch_demux_col )
        .concat ( ch_collapse_col )
        .concat ( ch_cluster_col )
        .groupTuple ()

    ch_report_data.dump(tag: "ch_report_data")

    ch_concatenate_grouped  = ch_report_data.map { id, data -> data[0] }.collect()
    ch_preqc_grouped        = ch_report_data.map { id, data -> data[1] }.collect()
    ch_adapterqc_grouped    = ch_report_data.map { id, data -> data[2] }.collect()
    ch_demux_grouped        = ch_report_data.map { id, data -> data[3] }.collect()
    ch_collapse_grouped     = ch_report_data.map { id, data -> data[4] }.collect()
    ch_cluster_grouped      = ch_report_data.map { id, data -> data[5] }.collect()
    ch_report_meta          = ch_report_data.map { it -> it[0] }.collect()
                                            .map { [ id: params.report_name , samples: it] }

    ch_concatenate_grouped.dump(tag: "ch_concatenate_grouped")
    ch_preqc_grouped.dump(tag: "ch_preqc_grouped")
    ch_adapterqc_grouped.dump(tag: "ch_adapterqc_grouped")
    ch_demux_grouped.dump(tag: "ch_demux_grouped")
    ch_collapse_grouped.dump(tag: "ch_collapse_grouped")
    ch_cluster_grouped.dump(tag: "ch_cluster_grouped")
    ch_report_meta.dump(tag: "ch_report_meta")

    PIXELATOR_REPORT (
        ch_report_meta,
        ch_concatenate_grouped,
        ch_preqc_grouped,
        ch_adapterqc_grouped,
        ch_demux_grouped,
        ch_collapse_grouped,
        ch_cluster_grouped
    )
    ch_versions = ch_versions.mix(PIXELATOR_REPORT.out.versions.first())

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    workflow_summary    = WorkflowPixelator.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)
    ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml')
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
