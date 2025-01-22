/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PIXELATOR_REPORT            } from '../../../modules/local/pixelator/single-cell/report/main'


/*
========================================================================================
    SUBWORKFLOW TO GENERATE PIXELATOR REPORTS
========================================================================================
*/

workflow GENERATE_REPORTS {
    take:
    panel_files              // channel: [meta, path(panel_file) | []]
    amplicon_data            // channel: [meta, [path, ...]]
    preqc_data               // channel: [meta, [path, ...]]
    adapterqc_data           // channel: [meta, [path, ...]]
    demux_data               // channel: [meta, [path, ...]]
    collapse_data            // channel: [meta, [path, ...]]
    graph_data               // channel: [meta, [path, ...]]
    annotate_data            // channel: [meta, [path, ...]]
    analysis_data            // channel: [meta, [path, ...]]
    layout_data              // channel: [meta, [path, ...]]

    main:
    ch_versions = Channel.empty()

    // Combine meta maps for all input samples
    ch_meta_col = panel_files
        .map { meta, _path -> [ meta.id, meta] }
        .groupTuple()
        .map { id, data ->
            if (data instanceof List) {
                def newMeta = [:]
                data.forEach { newMeta += it }
                return [id, newMeta]
            }
            return [id, data]
        }

    ch_panel_col = panel_files
        .map { meta, data -> [ meta.id, data] }

    //
    // These first subcommands each return two files per sample used by the reporting
    // A json file with stats and a command invocation metadata json file
    //
    ch_amplicon_col         = amplicon_data.map { meta, data -> [ meta.id, data] }
    ch_preqc_col            = preqc_data.map { meta, data -> [ meta.id, data] }
    ch_adapterqc_col        = adapterqc_data.map { meta, data -> [ meta.id, data] }
    ch_demux_col            = demux_data.map { meta, data -> [ meta.id, data] }
    ch_collapse_col         = collapse_data.map { meta, data -> [ meta.id, data] }
    ch_graph_col            = graph_data.map { meta, data -> [meta.id, data] }
    ch_annotate_col         = annotate_data.map { meta, data -> [meta.id, data] }
    ch_analysis_col         = analysis_data.map { meta, data -> [meta.id, data] }
    ch_layout_col           = layout_data.map { meta, data -> [meta.id, data] }

    //
    // Combine all inputs and group them, then split them up again.
    // This is needed to have the per subcommand outputs in the sample order
    //
    // ch_report_data: [
    //    [
    //       meta, panel_files,
    //      [amplicon files...],
    //      [preqc files...],
    //      [adapterqc files...],
    //      [demux files...],
    //      [collapse files...],
    //      [cluster files],
    //      [annotate files...],
    //      [analysis files...]
    //    ],
    //    [ same structure repeated for each sample ]
    // ]

    ch_report_data = ch_meta_col
        .concat ( ch_panel_col )
        .concat ( ch_amplicon_col )
        .concat ( ch_preqc_col )
        .concat ( ch_adapterqc_col )
        .concat ( ch_demux_col )
        .concat ( ch_collapse_col )
        .concat ( ch_graph_col )
        .concat ( ch_annotate_col )
        .concat ( ch_analysis_col )
        .concat ( ch_layout_col )
        .groupTuple (size: 10)

    //
    // Split up everything per stage so we can recreate the expected directory structure for
    // `pixelator single-cell report` using stageAs for each stage
    //
    // These ch_<stage>_grouped channels all emit a list of input files for each sample in the samplesheet
    // The channels will emit values in the same order so eg. the first list of files from each ch_<stage>_grouped
    // channel will match the same sample from the samplesheet.

    // If no `panel_file` (data[1]) is given we need to pass in `panel` from the samplesheet instead
    //
    ch_report_inputs = ch_report_data.multiMap { _id, data ->
        panels: [ data[0], data[1], data[1] ? null : data[0].panel ]
        amplicon: data[2] ? data[2].flatten() : []
        preqc: data[3] ? data[3].flatten() : []
        adapterqc: data[4] ? data[4].flatten() : []
        demux: data[5] ? data[5].flatten() : []
        collapse: data[6] ? data[6].flatten() : []
        graph: data[7] ? data[7].flatten() : []
        annotate: data[8] ? data[8].flatten() : []
        analysis: data[9] ? data[9].flatten() : []
        layout: data[10] ? data[10].flatten() : []
    }

    //
    // MODULE: Run pixelator single-cell report for each samples
    //
    // NB: These channels need to be split per stage to allow PIXELATOR_REPORT to
    //     use stageAs directives to reorder the inputs and prevent filename collisions
    PIXELATOR_REPORT (
        ch_report_inputs.panels,
        ch_report_inputs.amplicon,
        ch_report_inputs.preqc,
        ch_report_inputs.adapterqc,
        ch_report_inputs.demux,
        ch_report_inputs.collapse,
        ch_report_inputs.graph,
        ch_report_inputs.annotate,
        ch_report_inputs.analysis,
        ch_report_inputs.layout
    )

    ch_versions = ch_versions.mix(PIXELATOR_REPORT.out.versions.first())

    emit:
    pixelator_reports = PIXELATOR_REPORT.out.reports
    versions         = ch_versions
}
