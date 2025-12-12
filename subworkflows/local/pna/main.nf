/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { softwareVersionsToYAML } from '../../nf-core/utils_nfcore_pipeline'

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

include { PIXELATOR_PNA_AMPLICON         } from '../../../modules/local/pixelator/single-cell-pna/amplicon/main'
include { PIXELATOR_PNA_DEMUX            } from '../../../modules/local/pixelator/single-cell-pna/demux/main'
include { PIXELATOR_PNA_COLLAPSE         } from '../../../modules/local/pixelator/single-cell-pna/collapse/main'
include { PIXELATOR_PNA_GRAPH            } from '../../../modules/local/pixelator/single-cell-pna/graph/main'
include { PIXELATOR_PNA_DENOISE          } from '../../../modules/local/pixelator/single-cell-pna/denoise/main'
include { PIXELATOR_PNA_ANALYSIS         } from '../../../modules/local/pixelator/single-cell-pna/analysis/main'
include { PIXELATOR_PNA_COMBINE_COLLAPSE } from '../../../modules/local/pixelator/single-cell-pna/combine_collapse/main'
include { PIXELATOR_PNA_LAYOUT           } from '../../../modules/local/pixelator/single-cell-pna/layout/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PNA_GENERATE_REPORTS           } from '../pna/generate_reports'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
========================================================================================
    IMPORT CUSTOM MODULES/SUBWORKFLOWS
========================================================================================
*/

//


workflow PNA {
    take:
    fastq       // channel: [ meta, [path(sample_1.fq), path(sample_2.fq)] ]
    panel_files // channel: [ meta, path(panel_file) |  ]

    main:
    //
    // MODULE: Run pixelator single-cell-pna amplicon
    //
    PIXELATOR_PNA_AMPLICON ( fastq )
    ch_amplicon = PIXELATOR_PNA_AMPLICON.out.amplicon

    //
    // MODULE: Run pixelator single-cell demux
    //
    ch_demux_input = ch_amplicon
        .join(panel_files)
        .map { meta, fq, panel_file -> [meta, fq, panel_file, meta.panel, meta.design] }


    PIXELATOR_PNA_DEMUX(ch_demux_input)
    ch_demuxed = PIXELATOR_PNA_DEMUX.out.demuxed

    //
    // MODULE: Run pixelator single-cell collapse
    //
    ch_collapse_input = ch_demuxed
        .join(panel_files)
        .map { meta, parquet, panel_file ->
            // Inject the number of parts into the meta data
            // to be able to group the files without waiting later
            def newMeta = meta.clone()
            newMeta['parts'] = parquet.size()
            parquet.collect { single_parquet_file ->
                [newMeta, single_parquet_file, panel_file, panel_file ? null : meta.panel, meta.design]
            }
        }
        .flatMap()


    PIXELATOR_PNA_COLLAPSE(ch_collapse_input)
    ch_collapsed = PIXELATOR_PNA_COLLAPSE.out.collapsed
    ch_collapsed_reports = PIXELATOR_PNA_COLLAPSE.out.report_json

    // Collect the partitioned collapse.parquet files in a list per sample
    // use the dynamic size information from `meta.parts` to group the files
    ch_collapse_collected = ch_collapsed
        .join(ch_collapsed_reports)
        .map { meta, collapsed, reports -> tuple(groupKey(meta.id, meta.parts), [meta, collapsed, reports]) }
        .groupTuple()
        .map { _key, data ->
            // Remove the parts meta key again
            def newMeta = data[0][0].clone()
            newMeta.remove('parts')

            // Strip the duplicates meta from each element
            def parquet = data.collect { it[1] }.flatten()
            def reports = data.collect { it[2] }.flatten()
            [newMeta, parquet, reports]
        }

    ch_collapse_combine_split = ch_collapse_collected.branch {
        single: it[1].size() == 1
        multi: it[1].size() > 1
    }


    PIXELATOR_PNA_COMBINE_COLLAPSE(ch_collapse_combine_split.multi)

    ch_combined_collapsed = ch_collapse_combine_split.single
        .map { meta, parquet, _reports -> [meta, parquet] }
        .mix(PIXELATOR_PNA_COMBINE_COLLAPSE.out.parquet)

    //
    // MODULE: Run pixelator single-cell graph
    //
    ch_graph_input = ch_combined_collapsed
        .join(panel_files)
        .map { meta, parquet, panel_file -> [meta, parquet, panel_file, panel_file ? null : meta.panel] }

    PIXELATOR_PNA_GRAPH(ch_graph_input)
    ch_graph = PIXELATOR_PNA_GRAPH.out.pixelfile

    //
    // MODULE: Run pixelator single-cell denoise
    //
    PIXELATOR_PNA_DENOISE ( ch_graph )
    ch_denoise = PIXELATOR_PNA_DENOISE.out.pixelfile

    //
    // MODULE: Run pixelator single-cell analysis
    //
    ch_analysis_input = params.skip_denoise ? ch_graph : ch_denoise
    PIXELATOR_PNA_ANALYSIS(ch_analysis_input)
    ch_analysis = PIXELATOR_PNA_ANALYSIS.out.pixelfile

    //
    // MODULE: Run pixelator single-cell layout
    //

    PIXELATOR_PNA_LAYOUT(ch_analysis)

    // Prepare all data needed by reporting for each pixelator step

    ch_amplicon_data = PIXELATOR_PNA_AMPLICON.out.report_json
        .concat(PIXELATOR_PNA_AMPLICON.out.metadata_json)
        .groupTuple(size: 2)

    ch_demux_data = PIXELATOR_PNA_DEMUX.out.report_json
        .concat(PIXELATOR_PNA_DEMUX.out.metadata_json)
        .groupTuple(size: 2)

    ch_collapse_data = PIXELATOR_PNA_COMBINE_COLLAPSE.out.report_json
        .concat(PIXELATOR_PNA_COMBINE_COLLAPSE.out.metadata_json)
        .groupTuple(size: 2)

    ch_cluster_data = PIXELATOR_PNA_GRAPH.out.all_results
    ch_denoise_data = PIXELATOR_PNA_DENOISE.out.all_results
    ch_analysis_data = PIXELATOR_PNA_ANALYSIS.out.all_results

    ch_layout_data = PIXELATOR_PNA_LAYOUT.out.report_json
        .concat(PIXELATOR_PNA_LAYOUT.out.metadata_json)
        .groupTuple(size: 2)


    ch_input = Channel.fromPath(params.input)

    PNA_GENERATE_REPORTS(
        ch_input,
        panel_files,
        ch_amplicon_data,
        ch_demux_data,
        ch_collapse_data,
        ch_cluster_data,
        ch_denoise_data,
        ch_analysis_data,
        ch_layout_data,
        params.skip_experiment_summary
    )

    emit:
    graph    = ch_graph
    analysis = ch_analysis
}
