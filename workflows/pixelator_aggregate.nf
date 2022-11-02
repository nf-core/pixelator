/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPixelator.initialise(workflow, params, log)


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
include { INPUT_CHECK_AGGREGATE       } from '../subworkflows/local/input_check_aggregate'
include { RUN_PIXELATOR_AGGREGATE     } from '../subworkflows/local/run_pixelator_aggregate'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
/*
========================================================================================
    IMPORT CUSTOM MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Defined locally
//
include { PIXELATOR_AGGREGATE           } from '../modules/local/pixelator/aggregate/main'
include { PIXELATOR_ANALYSIS            } from '../modules/local/pixelator/analysis/main'
include { PIXELATOR_REPORT              } from '../modules/local/pixelator/report/main'
include { RENAME_MATRICES               } from '../modules/local/rename_matrices'

/*
========================================================================================
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow PIXELATOR_AGGREGATE {

    ch_versions = Channel.empty()

    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    INPUT_CHECK_AGGREGATE ( ch_input )
    ch_versions = ch_versions.mix(INPUT_CHECK_AGGREGATE.out.versions)

    ch_matrices = INPUT_CHECK_AGGREGATE.out.matrices
    ch_matrices.dump(tag: "ch_matrices")

       // We need to rename to make all reads match the sample name,
    // since pixelator extracts sample_names from read namaes
    RENAME_MATRICES ( ch_matrices )
    ch_renamed_matrices = RENAME_MATRICES.out.matrices
    ch_renamed_matrices.dump(tag: "ch_renamed_matrices")
    ch_versions = ch_versions.mix(RENAME_MATRICES.out.versions.first())

    RUN_PIXELATOR_AGGREGATE ( ch_renamed_matrices )
    ch_analysis_inputs = RUN_PIXELATOR_AGGREGATE.out.matrices
    ch_versions = ch_versions.mix(RUN_PIXELATOR_AGGREGATE.out.versions)

    PIXELATOR_ANALYSIS ( ch_analysis_inputs )
    ch_versions = ch_versions.mix(PIXELATOR_ANALYSIS.out.versions.first())
    ch_analysis_col    = PIXELATOR_ANALYSIS.out.results_dir.map { meta, data -> [ meta.id, data] }

    ch_report_data     = ch_analysis_col.groupTuple ()
    ch_report_data.dump(tag: "ch_report_data")
    ch_analysis_grouped     = ch_report_data.map { id, data -> data[6] }.collect()

    ch_report_meta = ch_report_data
        .map { it -> it[0] }.collect()
        .map { [ id: params.report_name , samples: it] }

    ch_analysis_grouped.dump(tag: "ch_analysis_grouped")
    ch_report_meta.dump(tag: "ch_report_meta")

    PIXELATOR_REPORT (
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        ch_analysis_grouped
    )

    ch_versions = ch_versions.mix(PIXELATOR_REPORT.out.versions)

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
