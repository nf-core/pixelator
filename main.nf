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

include { PROXIOME_V1              } from './workflows/proxiome_v1'
include { PROXIOME_V2              } from './workflows/proxiome_v2'
include { PIPELINE_INITIALISATION  } from './subworkflows/local/utils_nfcore_pixelator_pipeline'
include { PIPELINE_COMPLETION      } from './subworkflows/local/utils_nfcore_pixelator_pipeline'
include { collateVersionsFromTopic } from './subworkflows/local/utils_nfcore_pixelator_pipeline'

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
    samplesheet // channel: samplesheet read in from --input

    main:

    file(params.input).copyTo("${params.outdir}/pipeline_info")

    //
    // Split the samplesheet channel in reads and panel_files
    //
    ch_reads       = samplesheet.map { meta, _panel, reads -> [ meta, reads ] }
    ch_panel_files = samplesheet.map { meta, panel, _reads -> [ meta, panel ] }

    //
    // WORKFLOW: Run pipeline
    //
    if (params.technology == "proxiome-v1" || params.technology == "nonhashed_samples") {
        PROXIOME_V1(
            ch_reads,
            ch_panel_files
        )
    } else if (params.technology == "proxiome-v2" || params.technology == "hashed_samples") {
        PROXIOME_V2(
            ch_reads,
            ch_panel_files
        )
    } else {
        error "Unknown technology: \"${params.technology}\""
    }

    //
    // Collate and save software versions
    //
    collateVersionsFromTopic()
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'pixelator_software_'  + 'versions.yml',
            sort: true,
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
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_PIXELATOR (
        PIPELINE_INITIALISATION.out.samplesheet
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
