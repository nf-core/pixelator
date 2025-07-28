/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../../nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../../nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../../local/utils_nfcore_pixelator_pipeline'

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
include { GENERATE_REPORTS            } from '../../local/generate_reports/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CAT_FASTQ }                   from '../../../modules/nf-core/cat/fastq/main'
/*
========================================================================================
    IMPORT CUSTOM MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Defined locally
//
include { PIXELATOR_COLLECT_METADATA    } from '../../../modules/local/collect_metadata'
include { PIXELATOR_AMPLICON            } from '../../../modules/local/pixelator/single-cell-mpx/amplicon'
include { PIXELATOR_QC                  } from '../../../modules/local/pixelator/single-cell-mpx/qc'
include { PIXELATOR_DEMUX               } from '../../../modules/local/pixelator/single-cell-mpx/demux'
include { PIXELATOR_COLLAPSE            } from '../../../modules/local/pixelator/single-cell-mpx/collapse'
include { PIXELATOR_GRAPH               } from '../../../modules/local/pixelator/single-cell-mpx/graph'
include { PIXELATOR_ANALYSIS            } from '../../../modules/local/pixelator/single-cell-mpx/analysis'
include { PIXELATOR_ANNOTATE            } from '../../../modules/local/pixelator/single-cell-mpx/annotate'
include { PIXELATOR_LAYOUT              } from '../../../modules/local/pixelator/single-cell-mpx/layout'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow MPX {
    take:
    fastq       // channel: [ meta, [path(sample_1.fq), path(sample_2.fq)] ]
    panel_files // channel [ meta, path(panel_file) |  ]

    main:

    ch_versions = Channel.empty()

    ch_amplicon_input = fastq.map { meta, reads ->
        {
            [meta, reads]
        }
    }

    //
    // MODULE: Run pixelator single-cell-mpx amplicon
    //
    PIXELATOR_AMPLICON ( fastq )
    ch_merged = PIXELATOR_AMPLICON.out.merged
    ch_versions = ch_versions.mix(PIXELATOR_AMPLICON.out.versions.first())

    ch_input_reads = ch_merged

    //
    // MODULE: Run pixelator single-cell-mpx preqc & pixelator single-cell-mpx adapterqc
    //
    PIXELATOR_QC ( ch_input_reads )
    ch_qc = PIXELATOR_QC.out.processed
    ch_versions = ch_versions.mix(PIXELATOR_QC.out.versions.first())

    ch_fq_and_panel = ch_qc
        .join(panel_files, failOnMismatch:true, failOnDuplicate:true)
        .map { meta, fq, panel_file -> [meta, fq, panel_file, panel_file ? null : meta.panel ] }

    //
    // MODULE: Run pixelator single-cell-mpx demux
    //
    PIXELATOR_DEMUX ( ch_fq_and_panel )
    ch_demuxed = PIXELATOR_DEMUX.out.processed
    ch_versions = ch_versions.mix(PIXELATOR_DEMUX.out.versions.first())

    ch_demuxed_and_panel = ch_demuxed
        .join(panel_files, failOnMismatch:true, failOnDuplicate:true)
        .map { meta, demuxed, panel_file -> [meta, demuxed, panel_file, panel_file ? null : meta.panel ] }

    //
    // MODULE: Run pixelator single-cell-mpx collapse
    //
    PIXELATOR_COLLAPSE ( ch_demuxed_and_panel )
    ch_collapsed = PIXELATOR_COLLAPSE.out.collapsed
    ch_versions = ch_versions.mix( PIXELATOR_COLLAPSE.out.versions.first())

    //
    // MODULE: Run pixelator single-cell-mpx graph
    //
    PIXELATOR_GRAPH ( ch_collapsed )
    ch_clustered = PIXELATOR_GRAPH.out.edgelist
    ch_versions = ch_versions.mix(PIXELATOR_GRAPH.out.versions.first())

    ch_clustered_and_panel = ch_clustered
        .join(panel_files, failOnMismatch:true, failOnDuplicate:true)
        .map { meta, clustered, panel_file -> [meta, clustered, panel_file, panel_file ? null : meta.panel ] }

    //
    // MODULE: Run pixelator single-cell-mpx annotate
    //
    PIXELATOR_ANNOTATE ( ch_clustered_and_panel )
    ch_annotated = PIXELATOR_ANNOTATE.out.dataset
    ch_versions = ch_versions.mix( PIXELATOR_ANNOTATE.out.versions.first() )

    //
    // MODULE: Run pixelator single-cell-mpx analysis
    //
    PIXELATOR_ANALYSIS ( ch_annotated )
    ch_analysed = PIXELATOR_ANALYSIS.out.dataset
    ch_versions = ch_versions.mix(PIXELATOR_ANALYSIS.out.versions.first())


    //
    // MODULE: Run pixelator single-cell-mpx layout
    //
    ch_layout_input = params.skip_analysis ? ch_annotated : ch_analysed
    PIXELATOR_LAYOUT ( ch_layout_input )
    _ch_layout = PIXELATOR_LAYOUT.out.dataset
    ch_versions = ch_versions.mix(PIXELATOR_LAYOUT.out.versions.first())

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
    ch_layout_data      = PIXELATOR_LAYOUT.out.report_json
        .concat(PIXELATOR_LAYOUT.out.metadata)
        .groupTuple(size: 2)

    GENERATE_REPORTS(
        panel_files,
        ch_amplicon_data,
        ch_preqc_data,
        ch_adapterqc_data,
        ch_demux_data,
        ch_collapse_data,
        ch_cluster_data,
        ch_annotate_data,
        ch_analysis_data,
        ch_layout_data
    )

    ch_versions = ch_versions.mix(GENERATE_REPORTS.out.versions)

    // TODO: Add MultiQC when plugins are ready

    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
