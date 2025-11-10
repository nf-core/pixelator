/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_pixelator_pipeline'

// Inject the samplesheet SHA-1 into the params object
if (params.input) {
    params.samplesheet_sha = file(params.input).bytes.digest('sha-1')
}

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

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { MPX            } from '../subworkflows/local/mpx'
include { PNA            } from '../subworkflows/local/pna'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
/*
========================================================================================
    IMPORT CUSTOM MODULES/SUBWORKFLOWS
========================================================================================
*/
include { CAT_FASTQ                     } from '../modules/nf-core/cat/fastq/main'


/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow PIXELATOR {
    take:
    ch_samplesheet            // channel: [ meta, path(panel_file | []), path(sample_1.fq), path(sample_2.fq) ]

    main:

    file(params.input).copyTo("${params.outdir}/pipeline_info")

    ch_versions = Channel.empty()

    //
    // Split the samplesheet channel in reads and panel_files
    //
    ch_reads       = ch_samplesheet.map { meta, panel, reads -> [ meta, reads ] }
    ch_panel_files = ch_samplesheet.map { meta, panel, reads -> [ meta, panel ] }

    ch_fastq_split = ch_reads
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
        .map { meta, _ -> [meta.id, meta] }
        .join(ch_checked_panel_files)
        .map { id, meta, panel_files -> [meta, panel_files] }

    ch_versions = ch_versions.mix(CAT_FASTQ.out.versions.first())

    ch_fastq_technology_split = ch_cat_fastq
        .branch {
            meta, data ->
                mpx: meta.technology == 'mpx'
                    return [ meta, data ]
                pna: meta.technology == 'pna'
                    return [ meta, data ]
            }

    ch_panel_files_technology_split = ch_cat_panel_files
        .branch {
            meta, data ->
            mpx: meta.technology == 'mpx'
                return [ meta, data ]
            pna: meta.technology == 'pna'
                return [ meta, data ]
    }

    MPX(
        ch_fastq_technology_split.mpx,
        ch_panel_files_technology_split.mpx
    )

    ch_versions = ch_versions.mix(MPX.out.versions)

    PNA(
        ch_fastq_technology_split.pna,
        ch_panel_files_technology_split.pna
    )

    ch_versions = ch_versions.mix(PNA.out.versions)

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'pixelator_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
