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

include { PIXELATOR_AMPLICON         } from '../../../../modules/local/pixelator/amplicon/main'
include { PIXELATOR_DEMUX            } from '../../../../modules/local/pixelator/demux/main'
include { PIXELATOR_COLLAPSE         } from '../../../../modules/local/pixelator/collapse/main'
include { PIXELATOR_GRAPH            } from '../../../../modules/local/pixelator/graph/main'
include { PIXELATOR_DENOISE          } from '../../../../modules/local/pixelator/denoise/main'
include { PIXELATOR_ANALYSIS         } from '../../../../modules/local/pixelator/analysis/main'
include { PIXELATOR_COMBINE_COLLAPSE } from '../../../../modules/local/pixelator/combine_collapse/main'
include { PIXELATOR_LAYOUT           } from '../../../../modules/local/pixelator/layout/main'
include { EXPERIMENT_SUMMARY             } from '../../../../modules/local/experiment_summary/main'
include { softwareVersionsYaml       } from '../../utils_nfcore_pixelator_pipeline'

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

include { CAT_FASTQ                     } from '../../../../modules/nf-core/cat/fastq/main'

/*
========================================================================================
    IMPORT CUSTOM MODULES/SUBWORKFLOWS
========================================================================================
*/

//


workflow PIXELATOR_PNA_V1 {
    take:
    ch_fastq       // channel: [ meta, [path(sample_1.fq), path(sample_2.fq)] ]
    ch_panel_files // channel: [ meta, path(panel_file) |  ]

    main:

    ch_fastq_split = ch_fastq
        .groupTuple()
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
    ch_fastq_split.multiple

    ch_cat_fastq = CAT_FASTQ ( ch_fastq_split.multiple )
        .reads
        .mix(ch_fastq_split.single)

    // Check that multi lane samples use the same panel file
    ch_checked_panel_files = ch_panel_files
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
        .map { meta, _fastqs -> [meta.id, meta] }
        .join(ch_checked_panel_files)
        .map { _id, meta, panel_files -> [meta, panel_files] }

    //
    // MODULE: Run pixelator single-cell-pna amplicon
    //
    PIXELATOR_AMPLICON ( ch_cat_fastq )
    ch_amplicon = PIXELATOR_AMPLICON.out.amplicon

    //
    // MODULE: Run pixelator single-cell demux
    //
    ch_demux_input = ch_amplicon
        .join(ch_panel_files)
        .map { meta, fq, panel_file -> [meta, fq, panel_file, meta.panel, meta.design] }


    PIXELATOR_DEMUX(ch_demux_input)
    ch_demuxed = PIXELATOR_DEMUX.out.demuxed

    //
    // MODULE: Run pixelator single-cell collapse
    //
    ch_collapse_input = ch_demuxed
        .join(ch_panel_files)
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


    PIXELATOR_COLLAPSE(ch_collapse_input)
    ch_collapsed = PIXELATOR_COLLAPSE.out.collapsed
    ch_collapsed_reports = PIXELATOR_COLLAPSE.out.report_json

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
            def parquet = data.collect { _meta, collapsed, _reports -> collapsed }.flatten()
            def reports = data.collect { _meta, _collapsed, reports -> reports }.flatten()
            [newMeta, parquet, reports]
        }

    ch_collapse_combine_split = ch_collapse_collected.branch {
        _meta, parquet, _reports ->
            single: parquet.size() == 1
            multi: parquet.size() > 1
    }


    PIXELATOR_COMBINE_COLLAPSE(ch_collapse_combine_split.multi)

    ch_combined_collapsed = ch_collapse_combine_split.single
        .map { meta, parquet, _reports -> [meta, parquet] }
        .mix(PIXELATOR_COMBINE_COLLAPSE.out.parquet)

    //
    // MODULE: Run pixelator single-cell graph
    //
    ch_graph_input = ch_combined_collapsed
        .join(ch_panel_files)
        .map { meta, parquet, panel_file -> [meta, parquet, panel_file, panel_file ? null : meta.panel] }

    PIXELATOR_GRAPH(ch_graph_input)
    ch_graph = PIXELATOR_GRAPH.out.pixelfile

    //
    // MODULE: Run pixelator single-cell denoise
    //
    PIXELATOR_DENOISE ( ch_graph )
    ch_denoise = PIXELATOR_DENOISE.out.pixelfile

    //
    // MODULE: Run pixelator single-cell analysis
    //
    ch_analysis_input = params.skip_denoise ? ch_graph : ch_denoise
    PIXELATOR_ANALYSIS(ch_analysis_input)
    ch_analysis = PIXELATOR_ANALYSIS.out.pixelfile

    //
    // MODULE: Run pixelator single-cell layout
    //

    PIXELATOR_LAYOUT(ch_analysis)

    // Prepare all data needed by reporting for each pixelator step
    if (!params.skip_experiment_summary) {
        ch_input = channel.fromPath(params.input)
        ch_experiment_summary_input = channel
            .topic('all_results_for_reports')
            .map { stage, files ->
                def values = files instanceof List ? files : [files]
                values.collect { f -> tuple(stage, f) }
            }
            .flatMap { it }
            .collect(flat: false)
            .map { stageFilePairs ->
                def meta = [id: 'all']
                def stages = stageFilePairs.collect { it[0] }
                def files = stageFilePairs.collect { it[1] }
                tuple(meta, stages, files)
            }

        ch_versions_yml = softwareVersionsYaml()
            .collectFile(name: 'software_versions.yml', sort: true, newLine: true)
            .first()

        EXPERIMENT_SUMMARY(
            ch_input,
            ch_experiment_summary_input,
            ch_versions_yml,
        )
    }

    emit:
    graph    = ch_graph
    analysis = ch_analysis
}
