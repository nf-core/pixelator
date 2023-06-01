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
include { PIXELATOR_CONCATENATE         } from '../modules/local/pixelator/concatenate/main'
include { PIXELATOR_QC                  } from '../modules/local/pixelator/qc/main'
include { PIXELATOR_DEMUX               } from '../modules/local/pixelator/demux/main'
include { PIXELATOR_COLLAPSE            } from '../modules/local/pixelator/collapse/main'
include { PIXELATOR_CLUSTER             } from '../modules/local/pixelator/cluster/main'
include { PIXELATOR_ANALYSIS            } from '../modules/local/pixelator/analysis/main'
include { PIXELATOR_ANNOTATE            } from '../modules/local/pixelator/annotate/main'
include { PIXELATOR_REPORT              } from '../modules/local/pixelator/report/main'
include { RENAME_READS                  } from '../modules/local/rename_reads'
include { COLLECT_METADATA              } from '../modules/local/collect_metadata'

/*
========================================================================================
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow PIXELATOR_MAIN {
    ch_versions = Channel.empty()

    COLLECT_METADATA()
    ch_versions = ch_versions.mix(COLLECT_METADATA.out.versions)

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    ch_fastq  = INPUT_CHECK ( ch_input ).reads
    ch_fastq.dump(tag: 'ch_fastq')

    ch_fastq_split = ch_fastq
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

    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // MODULE: Concatenate FastQ files from same sample if required
    //
    ch_cat_fastq = CAT_FASTQ ( ch_fastq_split.multiple )
        .reads
        .mix(ch_fastq_split.single)

    ch_cat_fastq.dump(tag: 'ch_cat_fastq')
    ch_versions = ch_versions.mix(CAT_FASTQ.out.versions.first().ifEmpty(null))

    ch_reads = INPUT_CHECK.out.reads
    ch_reads.dump(tag: "ch_reads")

    ch_panels = INPUT_CHECK.out.panels
    ch_panels.dump(tag: "ch_panels")

    // We need to rename to make all reads match the sample name,
    // since pixelator extracts sample_names from read namaes
    RENAME_READS ( ch_reads )
    ch_renamed_reads = RENAME_READS.out.reads
    ch_renamed_reads.dump(tag: "ch_renamed_reads")
    ch_versions = ch_versions.mix(RENAME_READS.out.versions.first())

    ch_renamed_branched = ch_renamed_reads.branch {
        single_end: it[0].single_end
        paired_end: true
    }

    ch_renamed_branched.single_end.dump(tag: "ch_renamed_branched.single_end")
    ch_renamed_branched.paired_end.dump(tag: "ch_renamed_branched.paired_end")


    PIXELATOR_CONCATENATE ( ch_renamed_reads )
    ch_merged = PIXELATOR_CONCATENATE.out.merged
    ch_merged.dump(tag: "ch_merged")
    ch_versions = ch_versions.mix(PIXELATOR_CONCATENATE.out.versions.first())

    ch_input_reads = ch_merged

    PIXELATOR_QC( ch_input_reads )
    ch_qc = PIXELATOR_QC.out.processed
    ch_qc.dump(tag: "ch_ch_qcpreqc")
    ch_versions = ch_versions.mix(PIXELATOR_QC.out.versions.first())
    // Combine filtered input reads with panel files for input to PIXELATOR_DEMUX
    ch_qc_and_panel = ch_qc.join(ch_panels)
    ch_qc_and_panel.dump(tag: "ch_qc_and_panel")

    PIXELATOR_DEMUX ( ch_qc_and_panel )
    ch_demuxed = PIXELATOR_DEMUX.out.processed
    ch_demuxed.dump(tag: "ch_demuxed")
    ch_versions = ch_versions.mix(PIXELATOR_DEMUX.out.versions.first())

    PIXELATOR_COLLAPSE ( ch_demuxed )
    ch_collapsed = PIXELATOR_COLLAPSE.out.collapsed
    ch_collapsed.dump(tag: "ch_collapsed")
    ch_versions = ch_versions.mix(PIXELATOR_COLLAPSE.out.versions.first())

    PIXELATOR_CLUSTER ( ch_collapsed )
    ch_clustered = PIXELATOR_CLUSTER.out.edgelist
    ch_clustered.dump(tag: "ch_clustered")
    ch_versions = ch_versions.mix(PIXELATOR_CLUSTER.out.versions.first())

    ch_clustered_and_panel = ch_clustered.join(ch_panels)
    ch_clustered_and_panel.dump(tag: "ch_clustered_and_panel")

    PIXELATOR_ANNOTATE ( ch_clustered_and_panel )
    ch_annotated = PIXELATOR_ANNOTATE.out.dataset
    ch_annotated.dump(tag: "ch_annotated")
    ch_versions = ch_versions.mix(PIXELATOR_ANNOTATE.out.versions.first())

    if (!params.skip_analysis) {
        PIXELATOR_ANALYSIS ( ch_annotated )
        ch_analysed = PIXELATOR_ANALYSIS.out.dataset
        ch_versions = ch_versions.mix(PIXELATOR_ANALYSIS.out.versions.first())
    }

    if (!params.skip_report) {
        // Do some heroic transformations to split the inputs into their stages
        // and have all these "stage output" channel output their files list in the same order
        // Note that we need to split inout per stage to stage those files in the right subdirs
        // as expected by pixelator single-cell report

        ch_meta_col                  = ch_panels.map { meta, data -> [ meta.id, meta] }
        ch_panels_col                = ch_panels.map { meta, data -> [ meta.id, data] }

        ch_concatenate_col = PIXELATOR_CONCATENATE.out.report_json.mix(PIXELATOR_CONCATENATE.out.input_params)
            .map { meta, data -> [ meta.id, data] }.groupTuple()

        ch_preqc_col = PIXELATOR_QC.out.preqc_report_json.mix(PIXELATOR_QC.out.preqc_input_params)
            .map { meta, data -> [ meta.id, data] }
            .groupTuple()

        ch_adapterqc_col = PIXELATOR_QC.out.adapterqc_report_json.mix(PIXELATOR_QC.out.adapterqc_input_params)
            .map { meta, data -> [ meta.id, data] }
            .groupTuple()

        ch_demux_col = PIXELATOR_DEMUX.out.report_json.mix(PIXELATOR_DEMUX.out.input_params)
            .map { meta, data -> [ meta.id, data] }
            .groupTuple()

        ch_collapse_col = PIXELATOR_COLLAPSE.out.report_json.mix(PIXELATOR_COLLAPSE.out.input_params)
            .map { meta, data -> [ meta.id, data] }
            .groupTuple()

        ch_cluster_col = PIXELATOR_CLUSTER.out.all_results
            .map { meta, data -> [meta.id, data] }
            .groupTuple()

        ch_annotate_col = PIXELATOR_ANNOTATE.out.all_results
            .map { meta, data -> [meta.id, data] }
            .groupTuple()

        ch_analysis_col = null
        if (!params.skip_analysis) {
            ch_analysis_col = PIXELATOR_ANALYSIS.out.all_results
                .map { meta, data -> [meta.id, data] }
                .groupTuple()
        } else {
            ch_analysis_col = ch_meta_col.map { id, meta -> [id, []]}
        }


        // Combine all input and group it so we are sure that the per-stage channels will have their output in the same order
        // ch_report_data: [[
        //      id, meta, panels_file,
        //      [concatenate files...], [preqc files...], [adapterqc files...], [demux files...],
        //      [collapse files...], [cluster files], [annotate files...], [analsysis files...]
        // ], ...]
        ch_report_data = ch_meta_col
            .concat ( ch_panels_col )
            .concat ( ch_concatenate_col )
            .concat ( ch_preqc_col )
            .concat ( ch_adapterqc_col )
            .concat ( ch_demux_col )
            .concat ( ch_collapse_col )
            .concat ( ch_cluster_col )
            .concat ( ch_annotate_col )
            .concat ( ch_analysis_col )
            .groupTuple()

        ch_report_data.dump(tag: "ch_report_data")

        ch_meta_grouped         = ch_report_data.map { id, data -> data[0] }
        ch_panels_grouped       = ch_report_data.map { id, data -> data[1] }
        ch_concatenate_grouped  = ch_report_data.map { id, data -> data[2].flatten() }
        ch_preqc_grouped        = ch_report_data.map { id, data -> data[3].flatten() }
        ch_adapterqc_grouped    = ch_report_data.map { id, data -> data[4].flatten() }
        ch_demux_grouped        = ch_report_data.map { id, data -> data[5].flatten() }
        ch_collapse_grouped     = ch_report_data.map { id, data -> data[6].flatten() }
        ch_cluster_grouped      = ch_report_data.map { id, data -> data[7].flatten() }
        ch_annotate_grouped     = ch_report_data.map { id, data -> data[8].flatten() }
        ch_analysis_grouped     = ch_report_data.map { id, data -> data[8].flatten() }

        PIXELATOR_REPORT (
            ch_meta_grouped,
            ch_panels_grouped,
            ch_concatenate_grouped,
            ch_preqc_grouped,
            ch_adapterqc_grouped,
            ch_demux_grouped,
            ch_collapse_grouped,
            ch_cluster_grouped,
            ch_annotate_grouped,
            ch_analysis_grouped,
        )


        ch_versions = ch_versions.mix(PIXELATOR_REPORT.out.versions)
    }

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
