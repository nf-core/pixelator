include { PIXELATOR_REPORT            } from '../../modules/local/pixelator/single-cell/report/main'


workflow GENERATE_REPORTS {
    take:
    panel_files              // [meta, panel_file] or [meta, []]
    concatenate_data
    preqc_data
    adapterqc_data
    demux_data
    collapse_data
    graph_data
    annotate_data
    analysis_data

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

    // Make sure panel files are unique, we can have duplicates if we concatenated multiple samples
    ch_panel_files_col = panel_files
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


    ch_concatenate_col = concatenate_data
        .map { meta, data -> [ meta.id, data] }
        .groupTuple()

    ch_preqc_col = preqc_data
        .map { meta, data -> [ meta.id, data] }
        .groupTuple()

    ch_adapterqc_col = adapterqc_data
        .map { meta, data -> [ meta.id, data] }
        .groupTuple()

    ch_demux_col = demux_data
        .map { meta, data -> [ meta.id, data] }
        .groupTuple()

    ch_collapse_col = collapse_data
        .map { meta, data -> [ meta.id, data] }
        .groupTuple()

    ch_graph_col = graph_data
        .map { meta, data -> [meta.id, data] }
        .groupTuple()

    ch_annotate_col = annotate_data
        .map { meta, data -> [meta.id, data] }
        .groupTuple()

    ch_analysis_col = analysis_data
        .map { meta, data -> [meta.id, data] }
        .groupTuple()

  // Combine all inputs and group them to make per-stage channels have their output in the same order
    // ch_report_data: [[
    //       meta, panels_file,
    //      [concatenate files...], [preqc files...], [adapterqc files...], [demux files...],
    //      [collapse files...], [cluster files], [annotate files...], [analysis files...]
    // ], ...]
    ch_report_data = ch_meta_col
        .concat ( ch_panel_files_col )
        .concat ( ch_concatenate_col )
        .concat ( ch_preqc_col )
        .concat ( ch_adapterqc_col )
        .concat ( ch_demux_col )
        .concat ( ch_collapse_col )
        .concat ( ch_graph_col )
        .concat ( ch_annotate_col )
        .concat ( ch_analysis_col )
        .groupTuple()

    // Split up everything per stage so we can recreate the expected directory structure for
    // pixelator single-cell report using stageAs

    ch_panel_files_grouped  = ch_report_data.map { id, data -> [ data[0], data[1] ] }
    ch_concatenate_grouped  = ch_report_data.map { id, data -> data[2] ? data[2].flatten() : [] }
    ch_preqc_grouped        = ch_report_data.map { id, data -> data[3] ? data[3].flatten() : [] }
    ch_adapterqc_grouped    = ch_report_data.map { id, data -> data[4] ? data[4].flatten() : [] }
    ch_demux_grouped        = ch_report_data.map { id, data -> data[5] ? data[5].flatten() : [] }
    ch_collapse_grouped     = ch_report_data.map { id, data -> data[6] ? data[6].flatten() : [] }
    ch_graph_grouped        = ch_report_data.map { id, data -> data[7] ? data[7].flatten() : [] }
    ch_annotate_grouped     = ch_report_data.map { id, data -> data[8] ? data[8].flatten() : [] }
    ch_analysis_grouped     = ch_report_data.map { id, data -> data[9] ? data[9].flatten() : [] }

    ch_panel_keys           = ch_panel_files_grouped
        .map { meta, panel_file -> panel_file ? [] : meta.panel }


    PIXELATOR_REPORT (
        ch_panel_files_grouped,
        ch_panel_keys,
        ch_concatenate_grouped,
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
