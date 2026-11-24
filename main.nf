#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/pixelator
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/pixelator
    Website: https://nf-co.re/pixelator
    Slack  : https://nfcore.slack.com/channels/pixelator
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PROXIOME                 } from './workflows/proxiome'
include { PIPELINE_INITIALISATION  } from './subworkflows/local/utils_nfcore_pixelator_pipeline'
include { PIPELINE_COMPLETION      } from './subworkflows/local/utils_nfcore_pixelator_pipeline'
include { collectVersions          } from 'plugin/nf-core-utils'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_PIXELATOR {

    take:
    lanes            // channel: [ meta, [path(sample_1.fq), path(sample_2.fq)], path(panel_file) | ], one per FASTQ input
    unit_panel_files // channel: [ id, path(panel_file) | ]
    sample_metas     // channel: [ sample_id, meta ]

    main:

    file(params.input).copyTo("${params.outdir}/pipeline_info")

    //
    // WORKFLOW: Run pipeline
    //
    PROXIOME(
        lanes,
        unit_panel_files,
        sample_metas
    )

    //
    // Collate and save software versions
    //
    channel.topic('versions')
        .toList()
        .map { versions -> collectVersions(versions) }
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'pixelator_software_'  + 'versions.yml',
            newLine: true
        )
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.input_basedir,
        [
            technology: params.technology,
            design: params.design,
            sequencing_technology: params.sequencing_technology,
            // Defaults to null, so a value given on the command line arrives as a string
            reverse_read: params.reverse_read?.toString()?.toBoolean(),
            min_avg_quality: params.pna_edgelist_min_avg_quality,
        ],
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_PIXELATOR (
        PIPELINE_INITIALISATION.out.lanes,
        PIPELINE_INITIALISATION.out.unit_panel_files,
        PIPELINE_INITIALISATION.out.sample_metas
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    // TODO: Pass MultiQC report here once implemented
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
