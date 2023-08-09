/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'


def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

// Inject the samplesheet SHA-1 into the params object
ch_input               = file(params.input)
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
include { PIXELATOR_AMPLICON            } from '../modules/local/pixelator/single-cell/amplicon/main'
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

    // Check that multi lane samples use the same panel file
    ch_checked_panel_files = ch_panel_files
        .map { meta, data -> [ meta.id, data] }
        .groupTuple()
        .map { id, data ->
            if (!data) {
                return [id, []]
            }
            def unique_panels = data.unique()
            if (unique_panels.size() > 1) {
                exit 1, "ERROR: Concatenated samples must use the same panel."
            }
            return [ id, unique_panels[0] ]
        }

    ch_cat_panel_files = ch_cat_fastq
        .map { meta, _ -> [meta.id, meta] }
        .join(ch_checked_panel_files, failOnMismatch:true, failOnDuplicate:true)
        .map { id, meta, panel_files -> [meta, panel_files] }

    ch_versions = ch_versions.mix(CAT_FASTQ.out.versions.first().ifEmpty(null))

    // We need to rename to make all reads match the sample name,
    // since pixelator extracts sample_names from read names
    RENAME_READS ( ch_cat_fastq )
    ch_renamed_reads = RENAME_READS.out.reads
    ch_versions = ch_versions.mix(RENAME_READS.out.versions.first())

    PIXELATOR_AMPLICON ( ch_renamed_reads )
    ch_merged = PIXELATOR_AMPLICON.out.merged
    ch_versions = ch_versions.mix(PIXELATOR_AMPLICON.out.versions.first())

    ch_input_reads = ch_merged

    PIXELATOR_QC ( ch_input_reads )
    ch_qc = PIXELATOR_QC.out.processed
    ch_versions = ch_versions.mix(PIXELATOR_QC.out.versions.first())

    ch_qc_and_panel_file = ch_qc.join(ch_cat_panel_files, failOnMismatch:true, failOnDuplicate:true)
    ch_demux_panel_keys = ch_qc_and_panel_file
        .map { meta, fq, panel_file -> panel_file ? [] : meta.panel }

    PIXELATOR_DEMUX ( ch_qc_and_panel_file, ch_demux_panel_keys )
    ch_demuxed = PIXELATOR_DEMUX.out.processed
    ch_versions = ch_versions.mix(PIXELATOR_DEMUX.out.versions.first())

    ch_demuxed_and_panel_file = ch_demuxed.join(ch_cat_panel_files, failOnMismatch:true, failOnDuplicate:true)
    ch_collapse_panel_keys = ch_demuxed_and_panel_file.map {
        meta, fq, panel_file -> panel_file ? [] : meta.panel }

    PIXELATOR_COLLAPSE ( ch_demuxed_and_panel_file, ch_collapse_panel_keys )
    ch_collapsed = PIXELATOR_COLLAPSE.out.collapsed
    ch_versions = ch_versions.mix(PIXELATOR_COLLAPSE.out.versions.first())

    PIXELATOR_GRAPH ( ch_collapsed )
    ch_clustered = PIXELATOR_GRAPH.out.edgelist
    ch_versions = ch_versions.mix(PIXELATOR_GRAPH.out.versions.first())

    ch_clustered_and_panel = ch_clustered.join(ch_cat_panel_files, failOnMismatch:true, failOnDuplicate:true)
    ch_annotate_panel_keys = ch_demuxed_and_panel_file
        .map { meta, fq, panel_file -> panel_file ? [] : meta.panel }

    PIXELATOR_ANNOTATE ( ch_clustered_and_panel, ch_annotate_panel_keys )
    ch_annotated = PIXELATOR_ANNOTATE.out.dataset
    ch_versions = ch_versions.mix( PIXELATOR_ANNOTATE.out.versions.first() )

    PIXELATOR_ANALYSIS ( ch_annotated )
    ch_analysed = PIXELATOR_ANALYSIS.out.dataset
    ch_versions = ch_versions.mix(PIXELATOR_ANALYSIS.out.versions.first())


    // Prepare all data needed by reporting for each pixelator step

    ch_amplicon_data    = PIXELATOR_AMPLICON.out.report_json
        .concat(PIXELATOR_AMPLICON.out.metadata)
        .groupTuple(size: 2)

    ch_preqc_data       = PIXELATOR_QC.out.preqc_report_json
        .concat(PIXELATOR_QC.out.preqc_metadata)
        .groupTuple(size: 2)

    ch_adapterqc_data   = PIXELATOR_QC.out.adapterqc_report_json
        .concat(PIXELATOR_QC.out.adapterqc_metadata)
        .groupTuple(size: 2)

    ch_demux_data       = PIXELATOR_DEMUX.out.report_json
        .concat(PIXELATOR_DEMUX.out.metadata)
        .groupTuple(size: 2)

    ch_collapse_data    = PIXELATOR_COLLAPSE.out.report_json
        .concat(PIXELATOR_COLLAPSE.out.metadata)
        .groupTuple(size: 2)

    ch_cluster_data     = PIXELATOR_GRAPH.out.all_results
    ch_annotate_data    = PIXELATOR_ANNOTATE.out.all_results
    ch_analysis_data    = PIXELATOR_ANALYSIS.out.all_results

    GENERATE_REPORTS(
        ch_cat_panel_files,
        ch_amplicon_data,
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
