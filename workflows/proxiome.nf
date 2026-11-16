/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { collectVersions              } from 'plugin/nf-core-utils'

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

include { PIXELATOR_EDGELIST           } from '../modules/local/pixelator/edgelist'
include { PIXELATOR_AGGREGATE          } from '../modules/local/pixelator/aggregate'
include { PIXELATOR_GRAPH              } from '../modules/local/pixelator/graph'
include { PIXELATOR_GRAPH_COLLAPSE     } from '../modules/local/pixelator/graph_collapse'
include { PIXELATOR_SAMPLE_CALLING     } from '../modules/local/pixelator/sample_calling'
include { PIXELATOR_DENOISE            } from '../modules/local/pixelator/denoise'
include { PIXELATOR_ANALYSIS           } from '../modules/local/pixelator/analysis'
include { EXPERIMENT_SUMMARY           } from '../modules/local/experiment_summary/main'
include { collectReportInputsFromTopic } from '../subworkflows/local/utils_nfcore_pixelator_pipeline'

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
    ch_lanes            // channel: [ meta, [path(sample_1.fq), path(sample_2.fq)], path(panel_file) | ], one per FASTQ input
    ch_unit_panel_files // channel: [ id, path(panel_file) | ]
    ch_sample_metas     // channel: [ sample_id, meta ], to restore the per-sample metadata after sample calling

    main:
    //
    // MODULE: Run pixelator single-cell-pna edgelist on each FASTQ input
    //
    PIXELATOR_EDGELIST(ch_lanes)

    // Collect the per-lane edgelist parquet files in a list per unit.
    // groupKey(id, size) lets groupTuple emit a unit as soon as all of its
    // lanes are done, instead of waiting for every unit to finish.
    ch_edgelist_collected = PIXELATOR_EDGELIST.out.edgelist
        .map { meta, parquet -> tuple(groupKey(meta.id, meta.parts), [meta, parquet]) }
        .groupTuple()
        .map { _key, data ->
            // Order the lanes by samplesheet row, so that the input of aggregate does
            // not depend on the order in which the edgelist tasks finish (-resume stability)
            def sorted = data.sort(false) { item -> item[0].row }
            // Remove the parts meta keys again
            def newMeta = sorted[0][0].clone()
            newMeta.remove('parts')
            newMeta.remove('row')
            def parquet = sorted.collect { item -> item[1] }.flatten()
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
        .join(ch_unit_panel_files)
        .map { _id, meta, parquet, panel_file -> [meta, parquet, panel_file] }

    PIXELATOR_GRAPH(ch_graph_input)
    ch_graph = PIXELATOR_GRAPH.out.pixelfile

    //
    // MODULE: Run pixelator single-cell-pna graph-collapse
    //
    ch_graph_collapsed = ch_graph
    if (!params.skip_graph_collapse) {
        PIXELATOR_GRAPH_COLLAPSE ( ch_graph )
        ch_graph_collapsed = PIXELATOR_GRAPH_COLLAPSE.out.pixelfile
    }

    //
    // MODULE: Run pixelator single-cell denoise
    //
    ch_denoise = ch_graph_collapsed
    if (!params.skip_denoise) {
        PIXELATOR_DENOISE ( ch_graph_collapsed )
        ch_denoise = PIXELATOR_DENOISE.out.pixelfile
    }

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
    ch_analysis = channel.empty()
    if (!params.skip_analysis) {
        PIXELATOR_ANALYSIS ( ch_analysis_input )
        ch_analysis = PIXELATOR_ANALYSIS.out.pixelfile
    }

    // Prepare all data needed by reporting for each pixelator step
    if (!params.skip_experiment_summary) {
        ch_input = channel.fromPath(params.input)
        ch_experiment_summary_input = collectReportInputsFromTopic()

        // Any process consuming this must not emit to the `versions` topic itself,
        // as the topic only closes once all of its publishers have finished.
        ch_versions_yml = channel.topic('versions')
            .toList()
            .map { versions -> collectVersions(versions) }
            .collectFile(name: 'software_versions.yml', newLine: true)
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
