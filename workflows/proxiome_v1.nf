/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

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

include { PIXELATOR_EDGELIST ; duplicateEdgelistStems } from '../modules/local/pixelator/edgelist/main'
include { PIXELATOR_AGGREGATE        } from '../modules/local/pixelator/aggregate/main'
include { PIXELATOR_GRAPH            } from '../modules/local/pixelator/graph/main'
include { PIXELATOR_GRAPH_COLLAPSE   } from '../modules/local/pixelator/graph_collapse/main'
include { PIXELATOR_DENOISE          } from '../modules/local/pixelator/denoise/main'
include { PIXELATOR_ANALYSIS         } from '../modules/local/pixelator/analysis/main'
include { PIXELATOR_LAYOUT           } from '../modules/local/pixelator/layout/main'
include { EXPERIMENT_SUMMARY         } from '../modules/local/experiment_summary/main'
include { collateVersionsFromTopic; collectReportInputsFromTopic } from '../subworkflows/local/utils_nfcore_pixelator_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

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


workflow PROXIOME_V1 {
    take:
    ch_fastq       // channel: [ meta, [path(sample_1.fq), path(sample_2.fq)] ]
    ch_panel_files // channel: [ meta, path(panel_file) |  ]

    main:

    // Group the FASTQ inputs of each sample (one per samplesheet row), then keep
    // unique FASTQ inputs so each lane/run is processed by edgelist independently.
    ch_fastq_grouped_by_sample = ch_fastq
        .map { meta, fq -> tuple(meta.id, [meta, fq]) }
        .groupTuple()
        .map { _id, list ->
            def unique_endedness = list.collect { item -> item[0].single_end }.unique()
            if (unique_endedness.size() > 1) {
                exit 1, "ERROR: Runs of the same sample must all be single-end or all paired-end."
            }
            def meta = list[0][0].clone()
            def fq = (list as List).collect { item -> item[1] }.unique()
            // Pixelator names the edgelist parquet from the FASTQ basename, and
            // aggregate stages every lane of a sample into one directory.
            def duplicate_stems = duplicateEdgelistStems(fq, meta.single_end)
            if (duplicate_stems) {
                exit 1, "ERROR: FASTQ files in sample '${meta.id}' produce the same edgelist name (${duplicate_stems.join(', ')}). Each run of a sample must have a unique FASTQ basename."
            }
            [meta, fq]
        }

    // Check that all runs of a sample use one panel
    ch_panel_by_id = ch_panel_files
        .map { meta, panel_file_path -> tuple(meta.id, panel_file_path) }
        .groupTuple()
        .map { id, panel_files ->
            def unique_panels = panel_files.unique()
            if (unique_panels.size() > 1) {
                exit 1, "ERROR: Runs of the same sample must use the same panel."
            }
            [id, unique_panels[0]]
        }

    //
    // MODULE: Run pixelator single-cell-pna edgelist on each FASTQ input
    //
    ch_edgelist_input = ch_fastq_grouped_by_sample
        .map { meta, fq -> [meta.id, meta, fq] }
        .join(ch_panel_by_id)
        .flatMap { _id, meta, fq_units, panel_file ->
            // Inject the number of parts into the meta data
            // to be able to group the files without waiting later
            def baseMeta = meta.clone()
            baseMeta['parts'] = fq_units.size()
            fq_units.withIndex().collect { unit, index ->
                def partMeta = baseMeta.clone()
                partMeta['part'] = index
                def reads = unit instanceof Collection ? unit : [unit]
                [partMeta, reads, panel_file, meta.panel, meta.design]
            }
        }

    PIXELATOR_EDGELIST(ch_edgelist_input)

    // Collect the per-lane edgelist parquet files in a list per sample.
    // groupKey(id, size) lets groupTuple emit a sample as soon as all of its
    // lanes are done, instead of waiting for every sample to finish.
    ch_edgelist_collected = PIXELATOR_EDGELIST.out.edgelist
        .map { meta, parquet -> tuple(groupKey(meta.id, meta.parts), [meta, parquet]) }
        .groupTuple()
        .map { _key, data ->
            // Remove the parts meta keys again
            def newMeta = data[0][0].clone()
            newMeta.remove('parts')
            newMeta.remove('part')
            def parquet = data.collect { item -> item[1] }.flatten()
            [newMeta, parquet]
        }

    //
    // MODULE: Run pixelator single-cell-pna aggregate
    //
    PIXELATOR_AGGREGATE(ch_edgelist_collected)
    ch_aggregated = PIXELATOR_AGGREGATE.out.parquet

    //
    // MODULE: Run pixelator single-cell graph
    //
    ch_graph_input = ch_aggregated
        .map { meta, parquet -> [meta.id, meta, parquet] }
        .join(ch_panel_by_id)
        .map { _id, meta, parquet, panel_file -> [meta, parquet, panel_file, panel_file ? null : meta.panel] }

    PIXELATOR_GRAPH(ch_graph_input)
    ch_graph = PIXELATOR_GRAPH.out.pixelfile

    //
    // MODULE: Run pixelator single-cell-pna graph-collapse
    //
    PIXELATOR_GRAPH_COLLAPSE ( ch_graph )
    ch_graph_collapsed = params.skip_graph_collapse ? ch_graph : PIXELATOR_GRAPH_COLLAPSE.out.pixelfile

    //
    // MODULE: Run pixelator single-cell denoise
    //
    PIXELATOR_DENOISE ( ch_graph_collapsed )
    ch_denoise = PIXELATOR_DENOISE.out.pixelfile

    //
    // MODULE: Run pixelator single-cell analysis
    //
    ch_analysis_input = params.skip_denoise ? ch_graph_collapsed : ch_denoise
    PIXELATOR_ANALYSIS(ch_analysis_input)
    ch_analysis = PIXELATOR_ANALYSIS.out.pixelfile

    //
    // MODULE: Run pixelator single-cell layout
    //

    PIXELATOR_LAYOUT(ch_analysis)

    // Prepare all data needed by reporting for each pixelator step
    if (!params.skip_experiment_summary) {
        ch_input = channel.fromPath(params.input)
        ch_experiment_summary_input = collectReportInputsFromTopic()

        ch_versions_yml = collateVersionsFromTopic()
            .collectFile(name: 'software_versions.yml', sort: true, newLine: true)
            .first()

        EXPERIMENT_SUMMARY(
            ch_input,
            ch_experiment_summary_input,
            ch_versions_yml,
            'edgelist_aggregate',
        )
    }

    emit:
    graph    = ch_graph
    analysis = ch_analysis
}
