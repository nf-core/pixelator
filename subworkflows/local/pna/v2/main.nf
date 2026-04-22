/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { softwareVersionsToYAML } from '../../../nf-core/utils_nfcore_pipeline'

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

include { PIXELATOR_PNA_AMPLICON         } from '../../../../modules/local/pixelator/single-cell-pna/amplicon'
include { PIXELATOR_PNA_DEMUX            } from '../../../../modules/local/pixelator/single-cell-pna/demux'
include { PIXELATOR_PNA_COLLAPSE         } from '../../../../modules/local/pixelator/single-cell-pna/collapse'
include { PIXELATOR_PNA_GRAPH            } from '../../../../modules/local/pixelator/single-cell-pna/graph'
include { PIXELATOR_PNA_SAMPLE_CALLING   } from '../../../../modules/local/pixelator/single-cell-pna/sample_calling'
include { PIXELATOR_PNA_DENOISE          } from '../../../../modules/local/pixelator/single-cell-pna/denoise'
include { PIXELATOR_PNA_ANALYSIS         } from '../../../../modules/local/pixelator/single-cell-pna/analysis'
include { PIXELATOR_PNA_POST_ANALYSIS    } from '../../../../modules/local/pixelator/single-cell-pna/post_analysis'
include { PIXELATOR_PNA_COMBINE_COLLAPSE } from '../../../../modules/local/pixelator/single-cell-pna/combine_collapse'
include { PIXELATOR_PNA_LAYOUT           } from '../../../../modules/local/pixelator/single-cell-pna/layout'


include { EXPERIMENT_SUMMARY } from '../../../../modules/local/experiment_summary/main.nf'
include { CAT_FASTQ                     } from '../../../../modules/local/cat/fastq/main'

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


workflow PIXELATOR_PNA_V2 {
    take:
    fastq               // channel: [ meta, [path(sample_1.fq), path(sample_2.fq)] ]
    panel_files         // channel: [ meta, path(panel_file) |  ]

    main:
    ch_versions = Channel.empty()


    ch_fastq_grouped_by_pool = fastq
        .map { meta, fq -> tuple(meta.pool, [meta, fq]) }
        .groupTuple()
        .map { _pool, list ->
            def meta = list[0][0].clone()
            meta.id = meta.pool
            def fq = (list as List).collect { item -> item[1] }
            [meta, fq.unique()]
         }

    ch_fastq_split = ch_fastq_grouped_by_pool
        .branch {
            meta, fastq ->
                single: fastq.size() == 1
                    return [ meta, fastq.flatten() ]
                multiple: fastq.size() > 1
                    return [ meta, fastq.flatten() ]
        }

    //
    // MODULE: Concatenate FastQ files from the same sample if required
    //

    ch_cat_fastq = CAT_FASTQ ( ch_fastq_split.multiple )
        .reads
        .mix(ch_fastq_split.single)

    // Remap panel files to use pool as id
    panel_files_grouped_by_pool = panel_files
        .map { meta, panel_file_path -> tuple(meta.pool, [meta, panel_file_path]) }
        .groupTuple()
        .map { _pool, list ->
            def meta = list[0][0].clone()
            meta.id = meta.pool
            def panel_file = list[0][1]
            [meta, panel_file]
         }


    // Check that multi lane samples use the same panel file
    ch_checked_panel_files = panel_files_grouped_by_pool
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

    ch_cat_panel_files = ch_cat_fastq
        .map { meta, _ -> [meta.id, meta] }
        .join(ch_checked_panel_files)
        .map { id, meta, panel_files -> [meta, panel_files] }

    ch_versions = ch_versions.mix(CAT_FASTQ.out.versions.first())



    //
    // MODULE: Run pixelator single-cell-pna amplicon
    //
    PIXELATOR_PNA_AMPLICON ( ch_cat_fastq )
    ch_amplicon = PIXELATOR_PNA_AMPLICON.out.amplicon
    ch_versions = ch_versions.mix(PIXELATOR_PNA_AMPLICON.out.versions.first())

    //
    // MODULE: Run pixelator single-cell demux
    //
    ch_demux_input = ch_amplicon
        .join(panel_files_grouped_by_pool)
        .map { meta, fq, panel_file -> [meta, fq, panel_file, meta.panel, meta.design] }


    PIXELATOR_PNA_DEMUX(ch_demux_input)
    ch_demuxed = PIXELATOR_PNA_DEMUX.out.demuxed
    ch_versions = ch_versions.mix(PIXELATOR_PNA_DEMUX.out.versions.first())

    //
    // MODULE: Run pixelator single-cell collapse
    //
    ch_collapse_input = ch_demuxed
        .join(panel_files_grouped_by_pool)
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
    ch_versions = ch_versions.mix(PIXELATOR_PNA_COLLAPSE.out.versions.first())

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

    ch_versions = ch_versions.mix(PIXELATOR_PNA_COMBINE_COLLAPSE.out.versions.first())

    //
    // MODULE: Run pixelator single-cell graph
    //
    ch_graph_input = ch_combined_collapsed
        .join(panel_files_grouped_by_pool)
        .map { meta, parquet, panel_file -> [meta, parquet, panel_file, panel_file ? null : meta.panel] }

    PIXELATOR_PNA_GRAPH(ch_graph_input)
    ch_graph = PIXELATOR_PNA_GRAPH.out.pixelfile
    ch_versions = ch_versions.mix(PIXELATOR_PNA_GRAPH.out.versions.first())

    //
    // MODULE: Run pixelator single-cell sample-calling
    //
    ch_sample_calling_input = ch_graph
        .map { meta, parquet -> [meta, parquet, file(params.input)] }

    PIXELATOR_PNA_SAMPLE_CALLING (ch_sample_calling_input)
    ch_sample_called = PIXELATOR_PNA_SAMPLE_CALLING.out.pixelfile
    ch_versions = ch_versions.mix(PIXELATOR_PNA_SAMPLE_CALLING.out.versions.first())


    // Extract the sample names from the pixel file names so that we can
    // merge them in with the panel file names correctly
    // Also filter out the undetermined samples here
    ch_sample_called = ch_sample_called
        .flatMap { meta, pxl_files ->
            def files = pxl_files instanceof List ? pxl_files : [pxl_files]
            files.findAll { file -> !file.getName().contains('undetermined') }
                 .collect {
                    file ->
                        def new_meta = meta.clone()
                        new_meta.id = file.getName().replace('.dehashed.pxl', '')
                        [new_meta, file]
            }
        }

    //
    // MODULE: Run pixelator single-cell denoise
    //
    PIXELATOR_PNA_DENOISE ( ch_sample_called )
    ch_denoise = PIXELATOR_PNA_DENOISE.out.pixelfile
    ch_versions = ch_versions.mix(PIXELATOR_PNA_DENOISE.out.versions.first())

    //
    // MODULE: Run pixelator single-cell analysis
    //
    ch_analysis_input = params.skip_denoise ? ch_sample_called : ch_denoise
    PIXELATOR_PNA_ANALYSIS ( ch_analysis_input )
    ch_analysis = PIXELATOR_PNA_ANALYSIS.out.pixelfile
    ch_versions = ch_versions.mix(PIXELATOR_PNA_ANALYSIS.out.versions.first())

    //
    // MODULE: Run pixelator single-cell post-analysis
    //
    PIXELATOR_PNA_POST_ANALYSIS( ch_analysis )
    ch_post_analysis = PIXELATOR_PNA_POST_ANALYSIS.out.pixelfile
    ch_versions = ch_versions.mix(PIXELATOR_PNA_POST_ANALYSIS.out.versions.first())

    //
    // MODULE: Run pixelator single-cell layout
    //

    ch_layout_input = params.skip_post_analysis ? ch_analysis : ch_post_analysis
    PIXELATOR_PNA_LAYOUT( ch_layout_input )
    ch_versions = ch_versions.mix(PIXELATOR_PNA_LAYOUT.out.versions.first())

    // Prepare all data needed by reporting for each pixelator step
    ch_input = channel.fromPath(params.input)
    ch_all_results_grouped = channel
        .topic('all_results_for_reports')
        .map{ stage, files -> {
            tuple(stage, files)
        }}
        .groupTuple()

    ch_all_results_split_by_stage = ch_all_results_grouped.branch { topic, _files ->
        amplicon: topic == 'amplicon'
        demux: topic == 'demux'
        collapse: topic == 'collapse'
        graph: topic == 'graph'
        sample_calling: topic == 'sample_calling'
        denoise: topic == 'denoise'
        analysis: topic == 'analysis'
        post_analysis: topic == 'post_analysis'
        layout: topic == 'layout'
    }

    def pick_file_from_channel = { channel ->
        channel.map { _topic, files -> files.flatten() }
    }

    if (!params.skip_experiment_summary) {
        EXPERIMENT_SUMMARY(
            ch_input,
            pick_file_from_channel(ch_all_results_split_by_stage.amplicon),
            pick_file_from_channel(ch_all_results_split_by_stage.demux),
            pick_file_from_channel(ch_all_results_split_by_stage.collapse),
            pick_file_from_channel(ch_all_results_split_by_stage.graph),
            pick_file_from_channel(ch_all_results_split_by_stage.sample_calling),
            pick_file_from_channel(ch_all_results_split_by_stage.denoise),
            pick_file_from_channel(ch_all_results_split_by_stage.analysis),
            pick_file_from_channel(ch_all_results_split_by_stage.post_analysis),
            pick_file_from_channel(ch_all_results_split_by_stage.layout),
        )
    }

    emit:
    versions = ch_versions
    graph = ch_graph
    analysis = ch_analysis
}
