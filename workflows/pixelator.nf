/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


// Check input path parameters to see if they exist
def checkPathParamList = [ params.input ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

// Inject the samplesheet SHA into the params object
params.samplesheet_sha = ch_input.bytes.digest('sha-1')

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK                 } from '../subworkflows/local/input_check'
include { GENERATE_REPORTS            } from '../subworkflows/local/generate_reports'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { CAT_FASTQ }                   from '../modules/nf-core/cat/fastq/main'
/*
========================================================================================
    IMPORT CUSTOM MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Defined locally
//
include { RENAME_READS                  } from '../modules/local/rename_reads'
include { COLLECT_METADATA              } from '../modules/local/collect_metadata'
include { PIXELATOR_CONCATENATE         } from '../modules/local/pixelator/single-cell/concatenate/main'
include { PIXELATOR_QC                  } from '../modules/local/pixelator/single-cell/qc/main'
include { PIXELATOR_DEMUX               } from '../modules/local/pixelator/single-cell/demux/main'
include { PIXELATOR_COLLAPSE            } from '../modules/local/pixelator/single-cell/collapse/main'
include { PIXELATOR_GRAPH               } from '../modules/local/pixelator/single-cell/graph/main'
include { PIXELATOR_ANALYSIS            } from '../modules/local/pixelator/single-cell/analysis/main'
include { PIXELATOR_ANNOTATE            } from '../modules/local/pixelator/single-cell/annotate/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow PIXELATOR {
    ch_versions = Channel.empty()

    COLLECT_METADATA ()
    ch_versions = ch_versions.mix(COLLECT_METADATA.out.versions)

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    // Create a new channel of metadata from a sample sheet
    // NB: `input` corresponds to `params.input` and associated sample sheet schema
    INPUT_CHECK ( ch_input )

    ch_reads = INPUT_CHECK.out.reads
    ch_panel_files = INPUT_CHECK.out.panels

    ch_fastq_split = ch_reads
        .map {
            meta, fastq ->
                new_id = meta.id - ~/_T\d+/
                [ meta + [id: new_id], fastq ]
        }
        .groupTuple()
        .branch {
            meta, fastq ->
                single  : fastq.size() == 1
                    return [ meta, fastq.flatten() ]
                multiple: fastq.size() > 1
                    return [ meta, fastq.flatten() ]
        }

    //
    // MODULE: Concatenate FastQ files from same sample if required
    //
    ch_cat_fastq = CAT_FASTQ ( ch_fastq_split.multiple )
        .reads
        .mix(ch_fastq_split.single)

    ch_versions = ch_versions.mix(CAT_FASTQ.out.versions.first().ifEmpty(null))



    // We need to rename to make all reads match the sample name,
    // since pixelator extracts sample_names from read names
    RENAME_READS ( ch_cat_fastq )
    ch_renamed_reads = RENAME_READS.out.reads
    ch_versions = ch_versions.mix(RENAME_READS.out.versions.first())

    ch_renamed_branched = ch_renamed_reads.branch {
        single_end: it[0].single_end
        paired_end: true
    }

    PIXELATOR_CONCATENATE ( ch_renamed_reads )
    ch_merged = PIXELATOR_CONCATENATE.out.merged
    ch_versions = ch_versions.mix(PIXELATOR_CONCATENATE.out.versions.first())

    ch_input_reads = ch_merged

    PIXELATOR_QC ( ch_input_reads )
    ch_qc = PIXELATOR_QC.out.processed
    ch_versions = ch_versions.mix(PIXELATOR_QC.out.versions.first())

    ch_qc_and_panel_file = ch_qc.join(ch_panel_files)
    ch_demux_panel_keys = ch_qc_and_panel_file
        .map { meta, fq, panel_file -> panel_file ? [] : meta.panel }

    PIXELATOR_DEMUX ( ch_qc_and_panel_file, ch_demux_panel_keys )
    ch_demuxed = PIXELATOR_DEMUX.out.processed
    ch_versions = ch_versions.mix(PIXELATOR_DEMUX.out.versions.first())

    ch_demuxed_and_panel_file = ch_demuxed.join(ch_panel_files)
    ch_collapse_panel_keys = ch_demuxed_and_panel_file.map {
        meta, fq, panel_file -> panel_file ? [] : meta.panel }

    PIXELATOR_COLLAPSE ( ch_demuxed_and_panel_file, ch_collapse_panel_keys )
    ch_collapsed = PIXELATOR_COLLAPSE.out.collapsed
    ch_versions = ch_versions.mix(PIXELATOR_COLLAPSE.out.versions.first())

    PIXELATOR_GRAPH ( ch_collapsed )
    ch_clustered = PIXELATOR_GRAPH.out.edgelist
    ch_versions = ch_versions.mix(PIXELATOR_GRAPH.out.versions.first())

    ch_clustered_and_panel = ch_clustered.join(ch_panel_files)
    ch_annotate_panel_keys = ch_demuxed_and_panel_file
        .map { meta, fq, panel_file -> panel_file ? [] : meta.panel }

    PIXELATOR_ANNOTATE ( ch_clustered_and_panel, ch_annotate_panel_keys )
    ch_annotated = PIXELATOR_ANNOTATE.out.dataset
    ch_versions = ch_versions.mix( PIXELATOR_ANNOTATE.out.versions.first() )

    PIXELATOR_ANALYSIS ( ch_annotated )
    ch_analysed = PIXELATOR_ANALYSIS.out.dataset
    ch_versions = ch_versions.mix(PIXELATOR_ANALYSIS.out.versions.first())


    // Do some transformations to split the inputs into their stages
    // and have all these "pixelator subcommand output" channels output in the same order
    // Note that we need to split inout per subcommand to stage those files in the right subdirs
    // as expected by pixelator single-cell report

    ch_concatenate_data = PIXELATOR_CONCATENATE.out.report_json.mix(PIXELATOR_CONCATENATE.out.metadata)
    ch_preqc_data = PIXELATOR_QC.out.preqc_report_json.mix(PIXELATOR_QC.out.preqc_metadata)
    ch_adapterqc_data = PIXELATOR_QC.out.adapterqc_report_json.mix(PIXELATOR_QC.out.adapterqc_metadata)
    ch_demux_data = PIXELATOR_DEMUX.out.report_json.mix(PIXELATOR_DEMUX.out.metadata)
    ch_collapse_data = PIXELATOR_COLLAPSE.out.report_json.mix(PIXELATOR_COLLAPSE.out.metadata)
    ch_cluster_data = PIXELATOR_GRAPH.out.all_results
    ch_annotate_data = PIXELATOR_ANNOTATE.out.all_results
    ch_analysis_data = PIXELATOR_ANALYSIS.out.all_results

    GENERATE_REPORTS(
        ch_panel_files,
        ch_concatenate_data,
        ch_preqc_data,
        ch_adapterqc_data,
        ch_demux_data,
        ch_collapse_data,
        ch_cluster_data,
        ch_annotate_data,
        ch_analysis_data
    )

    ch_versions = ch_versions.mix(GENERATE_REPORTS.out.versions)

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    // TODO: Add MultiQC after plugins are implemented
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
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
