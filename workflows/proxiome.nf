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

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Runs both non-pooled data (one sample per FASTQ set) and pooled data (hashed samples
    pooled together in the FASTQ files). The samplesheet decides, for each row
    (`--technology` is only checked against it):
      - what is processed as one unit: the pool if the row has a `pool`, else the sample
      - whether the sample-calling step splits the pool back into samples (pools only)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PROXIOME {
    take:
    ch_fastq       // channel: [ meta, [path(sample_1.fq), path(sample_2.fq)] ]
    ch_panel_files // channel: [ meta, path(panel_file) |  ]

    main:
    // The technology is only used to check that the samplesheet is consistent with it;
    // pooling itself is detected per row from the `pool` column.
    def expect_pooled = params.technology in ['proxiome-v2', 'hashed_samples']

    // Pool-level steps collapse samples together; sample calling splits them
    // apart again, so keep the original per-sample metadata to restore later.
    ch_sample_metas = ch_fastq
        .map { meta, _fq -> [meta.id, meta] }
        .unique()

    // Group the runs (e.g. lanes) of each unit, then keep unique FASTQ inputs so
    // each lane/run is processed by edgelist independently.
    ch_fastq_grouped = ch_fastq
        .map { meta, fq ->
            if (expect_pooled && !meta.pool) {
                exit 1, "ERROR: Sample '${meta.id}' has no `pool`, but --technology ${params.technology} requires pooled samples."
            }
            if (!expect_pooled && meta.pool) {
                exit 1, "ERROR: Sample '${meta.id}' has `pool` '${meta.pool}', but --technology ${params.technology} does not use pooled samples."
            }
            tuple(meta.pool ?: meta.id, [meta, fq])
        }
        .groupTuple()
        .map { _key, list ->
            def is_pool = list[0][0].pool
            def unit = is_pool ? 'pool' : 'sample'
            def unique_endedness = list.collect { item -> item[0].single_end }.unique()
            if (unique_endedness.size() > 1) {
                exit 1, "ERROR: Runs of the same ${unit} must all be single-end or all paired-end."
            }
            def meta = is_pool ? pool_meta(list[0][0]) : list[0][0].clone()
            def fq = (list as List).collect { item -> item[1] }.unique()
            // Pixelator names the edgelist parquet from the FASTQ basename, and
            // aggregate stages every lane of a unit into one directory.
            def duplicate_stems = duplicateEdgelistStems(fq, meta.single_end)
            if (duplicate_stems) {
                exit 1, "ERROR: FASTQ files in ${unit} '${meta.id}' produce the same edgelist name (${duplicate_stems.join(', ')}). Each run of a ${unit} must have a unique FASTQ basename."
            }
            [meta, fq]
        }

    // Key the panel files by unit id, and check that a unit uses one panel
    ch_panel_by_id = ch_panel_files
        .map { meta, panel_file_path -> tuple(meta.pool ?: meta.id, panel_file_path) }
        .groupTuple()
        .map { id, panel_files ->
            def unique_panels = panel_files.unique()
            if (unique_panels.size() > 1) {
                exit 1, "ERROR: Runs of the same sample or pool ('${id}') must use the same panel."
            }
            [id, unique_panels[0]]
        }

    //
    // MODULE: Run pixelator single-cell-pna edgelist on each FASTQ input
    //
    ch_edgelist_input = ch_fastq_grouped
        .map { meta, fq -> [meta.id, meta, fq] }
        .join(ch_panel_by_id)
        .flatMap { _id, meta, fq_units, panel_file ->
            // Inject the number of parts into the meta data
            // to be able to group the files without waiting later
            def baseMeta = meta.clone()
            baseMeta['parts'] = fq_units.size()
            fq_units.withIndex().collect { fq_unit, index ->
                def partMeta = baseMeta.clone()
                partMeta['part'] = index
                def reads = fq_unit instanceof Collection ? fq_unit : [fq_unit]
                [partMeta, reads, panel_file, panel_file ? null : meta.panel, meta.design]
            }
        }

    PIXELATOR_EDGELIST(ch_edgelist_input)

    // Collect the per-lane edgelist parquet files in a list per unit.
    // groupKey(id, size) lets groupTuple emit a unit as soon as all of its
    // lanes are done, instead of waiting for every unit to finish.
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
    ch_denoise = params.skip_denoise ? ch_graph_collapsed : PIXELATOR_DENOISE.out.pixelfile

    //
    // MODULE: Run pixelator single-cell sample-calling (pooled data only)
    //
    // Pools are split back into samples; non-pooled units skip the step.
    ch_denoise_split = ch_denoise.branch { meta, _pixel_file ->
        pooled: meta.pool
        single: true
    }

    ch_sample_calling_input = ch_denoise_split.pooled
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
    ch_analysis_input = ch_sample_called.mix(ch_denoise_split.single)
    PIXELATOR_ANALYSIS ( ch_analysis_input )
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
    graph    = ch_graph
    analysis = ch_analysis
}

// Drop samplesheet fields that describe a single sample; they are meaningless
// once samples are grouped into a pool.
def pool_meta(LinkedHashMap meta) {
    def grouped = meta.findAll { key, _value -> !(key in ['sample_alias', 'condition', 'hash_index']) }
    grouped.id = meta.pool
    return grouped
}
