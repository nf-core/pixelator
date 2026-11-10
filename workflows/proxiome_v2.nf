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

include { PIXELATOR_EDGELIST ; duplicateEdgelistStems } from '../modules/local/pixelator/edgelist'
include { PIXELATOR_AGGREGATE        } from '../modules/local/pixelator/aggregate'
include { PIXELATOR_GRAPH            } from '../modules/local/pixelator/graph'
include { PIXELATOR_GRAPH_COLLAPSE   } from '../modules/local/pixelator/graph_collapse'
include { PIXELATOR_SAMPLE_CALLING   } from '../modules/local/pixelator/sample_calling'
include { PIXELATOR_DENOISE          } from '../modules/local/pixelator/denoise'
include { PIXELATOR_ANALYSIS         } from '../modules/local/pixelator/analysis'
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


workflow PROXIOME_V2 {
    take:
    ch_fastq               // channel: [ meta, [path(sample_1.fq), path(sample_2.fq)] ]
    ch_panel_files         // channel: [ meta, path(panel_file) |  ]

    main:
    // Pool-level steps collapse samples together; sample calling splits them
    // apart again, so keep the original per-sample metadata to restore later.
    ch_sample_metas = ch_fastq
        .map { meta, _fq -> [meta.id, meta] }
        .unique()

    // Group hashed samples that share a pool, then keep unique FASTQ inputs so
    // each lane/run is processed by edgelist independently.
    ch_fastq_grouped_by_pool = ch_fastq
        .map { meta, fq -> tuple(meta.pool, [meta, fq]) }
        .groupTuple()
        .map { _pool, list ->
            def unique_endedness = list.collect { item -> item[0].single_end }.unique()
            if (unique_endedness.size() > 1) {
                exit 1, "ERROR: Samples in the same pool must all be single-end or all paired-end."
            }
            def meta = pool_meta(list[0][0])
            def fq = (list as List).collect { item -> item[1] }.unique()
            // Pixelator names the edgelist parquet from the FASTQ basename, and
            // aggregate stages every lane of a pool into one directory.
            def duplicate_stems = duplicateEdgelistStems(fq, meta.single_end)
            if (duplicate_stems) {
                exit 1, "ERROR: FASTQ files in pool '${meta.id}' produce the same edgelist name (${duplicate_stems.join(', ')}). Each run in a pool must have a unique FASTQ basename."
            }
            [meta, fq]
        }

    // Remap panel files to use pool as id, and check that a pool uses one panel
    ch_panel_files_grouped_by_pool = ch_panel_files
        .map { meta, panel_file_path -> tuple(meta.pool, [meta, panel_file_path]) }
        .groupTuple()
        .map { _pool, list ->
            def unique_panels = list.collect { item -> item[1] }.unique()
            if (unique_panels.size() > 1) {
                exit 1, "ERROR: Samples in the same pool must use the same panel."
            }
            [pool_meta(list[0][0]), unique_panels[0]]
        }

    ch_panel_by_id = ch_panel_files_grouped_by_pool
        .map { meta, panel_file -> [meta.id, panel_file] }

    //
    // MODULE: Run pixelator single-cell-pna edgelist on each FASTQ input
    //
    ch_edgelist_input = ch_fastq_grouped_by_pool
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
                [partMeta, reads, panel_file, panel_file ? null : meta.panel, meta.design]
            }
        }

    PIXELATOR_EDGELIST(ch_edgelist_input)

    // Collect the per-lane edgelist parquet files in a list per pool.
    // groupKey(id, size) lets groupTuple emit a pool as soon as all of its
    // lanes are done, instead of waiting for every pool to finish.
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
    // MODULE: Run pixelator single-cell sample-calling
    //
    ch_sample_calling_input = (params.skip_denoise ? ch_graph_collapsed : ch_denoise)
        .map { meta, pixel_file -> [meta, pixel_file, file(params.input)] }

    PIXELATOR_SAMPLE_CALLING (ch_sample_calling_input)

    // Extract the sample names from the pixel file names so that the original
    // per-sample metadata can be joined back in.
    // Also filter out the undetermined samples here
    ch_sample_called = PIXELATOR_SAMPLE_CALLING.out.pixelfile
        .flatMap { meta, pxl_files ->
            def files = pxl_files instanceof List ? pxl_files : [pxl_files]
            def undetermined = "${meta.id}_undetermined.dehashed.pxl".toString()
            files.findAll { pxl -> pxl.name != undetermined }
                 .collect { pxl -> [pxl.name.replace('.dehashed.pxl', ''), pxl] }
        }
        .join(ch_sample_metas, remainder: true)
        .filter { _sample_id, pxl, _meta -> pxl != null }
        .map { sample_id, pxl, meta ->
            if (!meta) {
                error("ERROR: sample calling produced \"${pxl.name}\" but \"${sample_id}\" is not in the samplesheet.")
            }
            [meta, pxl]
        }

    //
    // MODULE: Run pixelator single-cell analysis
    //
    PIXELATOR_ANALYSIS ( ch_sample_called )
    ch_analysis = PIXELATOR_ANALYSIS.out.pixelfile

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
    graph = ch_graph
    analysis = ch_analysis
}

// Drop samplesheet fields that describe a single sample; they are meaningless
// once samples are grouped into a pool.
def pool_meta(LinkedHashMap meta) {
    def grouped = meta.findAll { key, _value -> !(key in ['sample_alias', 'condition', 'hash_index']) }
    grouped.id = meta.pool
    return grouped
}
