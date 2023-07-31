include { PIXELATOR_REPORT            } from '../../modules/local/pixelator/single-cell/report/main'


workflow GENERATE_REPORTS {
    take:
    panel_files              // [meta, panel_file] or [meta, []]
    amplicon_data            // [meta, [<sample_name>.report.json, <sample_name>.meta.json]]
    preqc_data               // [meta, [<sample_name>.report.json, <sample_name>.meta.json]]
    adapterqc_data           // [meta, [<sample_name>.report.json, <sample_name>.meta.json]]
    demux_data               // [meta, [<sample_name>.report.json, <sample_name>.meta.json]]
    collapse_data            // [meta, [<sample_name>.report.json, <sample_name>.meta.json]]
    graph_data               // [meta, [list of files]]
    annotate_data            // [meta, [list of files]]
    analysis_data            // [meta, [list of files]]

    main:
    ch_versions = Channel.empty()

    ch_meta_col = panel_files
        .map { meta, data -> [ meta.id, meta] }
        .groupTuple()
        .map { id, data ->
            if (data instanceof List) {
                def newMeta = [:]
                for (item in data) {
                    newMeta += item
                }
                return [id, newMeta]
            }
            return [id, data]
        }

    ch_panel_col = panel_files
        .map { meta, data -> [ meta.id, data] }

    // These first subcommands each return two files per sample used by the reporting
    // A json file with stats and a command invocation metadata json file

    ch_amplicon_col         = amplicon_data.map { meta, data -> [ meta.id, data] }
    ch_preqc_col            = preqc_data.map { meta, data -> [ meta.id, data] }
    ch_adapterqc_col        = adapterqc_data.map { meta, data -> [ meta.id, data] }
    ch_demux_col            = demux_data.map { meta, data -> [ meta.id, data] }
    ch_collapse_col         = collapse_data.map { meta, data -> [ meta.id, data] }
    ch_graph_col            = graph_data.map { meta, data -> [meta.id, data] }
    ch_annotate_col         = annotate_data.map { meta, data -> [meta.id, data] }
    ch_analysis_col         = analysis_data.map { meta, data -> [meta.id, data] }

    //
    // Combine all inputs and group them, then split them up again. This makes sure the per subcommand outputs have the sample order
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
        .groupTuple (size: 10)

    // Split up everything per stage so we can recreate the expected directory structure for
    // `pixelator single-cell report` using stageAs for each stage
    //
    // These ch_<stage>_grouped channels all emit a list of input files for each sample in the samplesheet
    // The channels will emit values in the same order so eg. the first list of files from each ch_<stage>_grouped
    // channel will match the same sample from the samplesheet.

    ch_panel_files_grouped  = ch_report_data.map { id, data -> [ data[0], data[1] ] }
    ch_amplicon_grouped     = ch_report_data.map { id, data -> data[2] ? data[2].flatten() : [] }
    ch_preqc_grouped        = ch_report_data.map { id, data -> data[3] ? data[3].flatten() : [] }
    ch_adapterqc_grouped    = ch_report_data.map { id, data -> data[4] ? data[4].flatten() : [] }
    ch_demux_grouped        = ch_report_data.map { id, data -> data[5] ? data[5].flatten() : [] }
    ch_collapse_grouped     = ch_report_data.map { id, data -> data[6] ? data[6].flatten() : [] }
    ch_graph_grouped        = ch_report_data.map { id, data -> data[7] ? data[7].flatten() : [] }
    ch_annotate_grouped     = ch_report_data.map { id, data -> data[8] ? data[8].flatten() : [] }
    ch_analysis_grouped     = ch_report_data.map { id, data -> data[9] ? data[9].flatten() : [] }

    // If no `panel_file` is given we need to pass in `panel` from the samplesheet instead
    ch_panel_keys           = ch_panel_files_grouped
        .map { meta, panel_file -> panel_file ? [] : meta.panel }


    PIXELATOR_REPORT (
        ch_panel_files_grouped,
        ch_panel_keys,
        ch_amplicon_grouped,
        ch_preqc_grouped,
        ch_adapterqc_grouped,
        ch_demux_grouped,
        ch_collapse_grouped,
        ch_graph_grouped,
        ch_annotate_grouped,
        ch_analysis_grouped,
    )

    ch_versions = ch_versions.mix(PIXELATOR_REPORT.out.versions.first())

    emit:
    pixelator_reports = PIXELATOR_REPORT.out.reports
    versions         = ch_versions
}
