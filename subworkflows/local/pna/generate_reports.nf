/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PIXELATOR_PNA_REPORT } from '../../../modules/local/pixelator/single-cell-pna/report/main'
include { EXPERIMENT_SUMMARY    } from '../../../modules/local/experiment_summary/main'

/*
========================================================================================
    SUBWORKFLOW TO GENERATE PIXELATOR REPORTS
========================================================================================
*/

workflow PNA_GENERATE_REPORTS {
    take:
    samplesheet              // channel: [path(samplesheet)]
    panel_files              // channel: [meta, path(panel_file) | []]
    amplicon_data            // channel: [meta, [path, ...]]
    demux_data               // channel: [meta, [path, ...]]
    collapse_data            // channel: [meta, [path, ...]]
    graph_data               // channel: [meta, [path, ...]]
    denoise_data             // channel: [meta, [path, ...]]
    analysis_data            // channel: [meta, [path, ...]]
    layout_data              // channel: [meta, [path, ...]]

    skip_experiment_summary  // boolean

    main:
    ch_versions = Channel.empty()

    ch_meta_col = panel_files
        .map { meta, _data -> [meta.id, meta] }
        .groupTuple()
        .map { id, data ->
            if (data instanceof List) {
                def newMeta = [:]
                data.each { newMeta += it }
                return [id, newMeta]
            }
            return [id, data]
        }

    ch_panel_col = panel_files.map { meta, data -> [meta.id, data] }

    ch_amplicon_col         = amplicon_data.map { meta, data -> [ meta.id, data] }
    ch_demux_col            = demux_data.map { meta, data -> [ meta.id, data] }
    ch_collapse_col         = collapse_data.map { meta, data -> [ meta.id, data] }
    ch_graph_col            = graph_data.map { meta, data -> [meta.id, data] }
    ch_analysis_col         = analysis_data.map { meta, data -> [meta.id, data] }
    ch_denoise_col          = denoise_data.map { meta, data -> [meta.id, data] }
    ch_layout_col           = layout_data.map { meta, data -> [meta.id, data] }

    ch_report_data = ch_meta_col
        .concat ( ch_panel_col )
        .concat ( ch_amplicon_col )
        .concat ( ch_demux_col )
        .concat ( ch_collapse_col )
        .concat ( ch_graph_col )
        .concat ( ch_denoise_col)
        .concat ( ch_analysis_col )
        .concat ( ch_layout_col )
        .groupTuple (size: 9)

    ch_split_report_data = ch_report_data.multiMap {
        _id, data ->
            panel_files:    [ data[0], data[1], data[1] ? null : data[0].panel ]
            amplicon:       data[2] ? data[2].flatten() : []
            demux:          data[3] ? data[3].flatten() : []
            collapse:       data[4] ? data[4].flatten() : []
            graph:          data[5] ? data[5].flatten() : []
            denoise:        data[6] ? data[6].flatten() : []
            analysis:       data[7] ? data[7].flatten() : []
            layout:         data[8] ? data[8].flatten() : []
    }

    PIXELATOR_PNA_REPORT (
        ch_split_report_data.panel_files,
        ch_split_report_data.amplicon,
        ch_split_report_data.demux,
        ch_split_report_data.collapse,
        ch_split_report_data.graph,
        ch_split_report_data.analysis,
        ch_split_report_data.layout
    )

    ch_meta_grouped         = ch_report_data.map { _id, data -> data[0] }.flatten().collect().map {
        def newMeta = [:]
        newMeta.id = "all-samples"
        newMeta.samples = it.collect { e -> e.id }
        return newMeta
    }

    ch_amplicon_flat        = ch_split_report_data.amplicon.flatten().collect()
    ch_demux_flat           = ch_split_report_data.demux.flatten().collect()
    ch_collapse_flat        = ch_split_report_data.collapse.flatten().collect()
    ch_graph_flat           = ch_split_report_data.graph.flatten().collect()
    ch_denoise_flat         = ch_split_report_data.denoise.flatten().collect()
    ch_analysis_flat        = ch_split_report_data.analysis.flatten().collect()
    ch_layout_flat          = ch_split_report_data.layout.flatten().collect()


    if (!skip_experiment_summary) {
        EXPERIMENT_SUMMARY(
            ch_meta_grouped,
            samplesheet,
            ch_amplicon_flat,
            ch_demux_flat,
            ch_collapse_flat,
            ch_graph_flat,
            ch_denoise_flat,
            ch_analysis_flat,
            ch_layout_flat
        )
        ch_versions           = ch_versions.mix(EXPERIMENT_SUMMARY.out.versions)
        ch_experiment_summary = EXPERIMENT_SUMMARY.out.html
    } else {
        ch_experiment_summary = ch_meta_grouped.combine(Channel.of([]))
    }

    ch_versions = ch_versions.mix(PIXELATOR_PNA_REPORT.out.versions.first())

    emit:
    pixelator_reports    = PIXELATOR_PNA_REPORT.out.report
    experiment_summary   = ch_experiment_summary
    versions             = ch_versions
}
