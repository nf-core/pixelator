/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

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
    ch_versions = channel.empty()

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

    ch_report_data = ch_meta_col
        .join( panel_files.map   { meta, data -> [ meta.id, data ] } )
        .join( amplicon_data.map { meta, data -> [ meta.id, data ] } )
        .join( demux_data.map    { meta, data -> [ meta.id, data ] } )
        .join( collapse_data.map { meta, data -> [ meta.id, data ] } )
        .join( graph_data.map    { meta, data -> [ meta.id, data ] } )
        .join( denoise_data.map  { meta, data -> [ meta.id, data ] } )
        .join( analysis_data.map { meta, data -> [ meta.id, data ] } )
        .join( layout_data.map   { meta, data -> [ meta.id, data ] } )




    // Accumulate results across all samples grouped per stage

    def accumulator = [
        meta: [ id: "all-samples", samples: [] ],
        amplicon: [],
        demux:    [],
        collapse: [],
        graph:    [],
        denoise:  [],
        analysis: [],
        layout:   []
    ]

    ch_grouped_data = ch_report_data.reduce ( accumulator ) { acc, val ->
        def (_id, meta, _panels, amplicon, demux, collapse, graph, denoise, analysis, layout) = val
        acc.meta.samples += meta.id
        acc.amplicon += amplicon
        acc.demux    += demux
        acc.collapse += collapse
        acc.graph    += graph
        acc.denoise  += denoise
        acc.analysis += analysis
        acc.layout   += layout
        return acc
    }.map { acc ->
        [ acc.meta, acc.amplicon, acc.demux, acc.collapse, acc.graph, acc.denoise, acc.analysis, acc.layout ]
    }
    // Filter out the entry if it just contains empty lists, eg when no PNA samples are present
    .filter { it -> it[0].samples.size() > 0 }

    if (!skip_experiment_summary) {
        EXPERIMENT_SUMMARY ( samplesheet, ch_grouped_data )

        ch_versions           = ch_versions.mix(EXPERIMENT_SUMMARY.out.versions)
        ch_experiment_summary = EXPERIMENT_SUMMARY.out.html
    } else {
        ch_experiment_summary = ch_grouped_data.map { it -> it[0] }.combine(Channel.of([]))
    }


    emit:
    experiment_summary   = ch_experiment_summary
    versions             = ch_versions
}
