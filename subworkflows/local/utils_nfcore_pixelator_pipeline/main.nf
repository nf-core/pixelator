//
// Subworkflow with functionality specific to the nf-core/pixelator pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFVALIDATION_PLUGIN } from '../../nf-core/utils_nfvalidation_plugin'
include { paramsSummaryMap          } from 'plugin/nf-validation'
include { fromSamplesheet           } from 'plugin/nf-validation'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { dashedLine                } from '../../nf-core/utils_nfcore_pipeline'
include { nfCoreLogo                } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { workflowCitation          } from '../../nf-core/utils_nfcore_pipeline'

include { PIXELATOR_LIST_OPTIONS    } from '../../../modules/local/pixelator/list_options.nf'

/*
========================================================================================
    SUBWORKFLOW TO INITIALISE PIPELINE
========================================================================================
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    help              // boolean: Display help text
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet
    input_basedir     //  string: Path to the base directory for relative paths resolving

    main:

    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    pre_help_text = nfCoreLogo(monochrome_logs)
    post_help_text = '\n' + workflowCitation() + '\n' + dashedLine(monochrome_logs)
    def String workflow_command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"
    UTILS_NFVALIDATION_PLUGIN (
        help,
        workflow_command,
        pre_help_text,
        post_help_text,
        validate_params,
        "nextflow_schema.json"
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )
    //
    // Custom validation for pipeline parameters
    //
    validateInputParameters()

    //
    // Create channel from input file provided through params.input
    //
    ch_versions = Channel.empty()

    //
    // Resolve relative paths and validate fastq files existence
    //
    def samplesheet_uri = file(input).toUri()
    def inputBaseDir    = get_data_basedir(samplesheet_uri, input_basedir)

    log.info "Resolving relative paths in samplesheet relative to: ${inputBaseDir}"

    ch_input = Channel.fromSamplesheet("input")
        .map {
            validate_input_samplesheet(inputBaseDir, it)
        }


    //
    // Validate design and panel samplesheet fields agains a dynamic set of allowed values
    //
    PIXELATOR_LIST_OPTIONS()
    ch_versions = ch_versions.mix(PIXELATOR_LIST_OPTIONS.out.versions)

    // Create a set of valid pixelator options to pass to --design
    ch_design_options = PIXELATOR_LIST_OPTIONS.out.designs
        .splitText()
        .map( text -> text.trim())
        .reduce( new HashSet() ) { prev, curr -> prev << curr }

    // Create a set of valid pixelator panel keys to pass using --panel
    ch_panel_options = PIXELATOR_LIST_OPTIONS.out.panels
        .splitText()
        .map( text -> text.trim())
        .reduce( new HashSet() ) { prev, curr -> prev << curr }



    //
    // Combine the validated inputs again in a single channel
    //
    ch_samplesheet = ch_input
        .map { it -> it[0] }
        .combine(ch_panel_options)
        .combine(ch_design_options)
        .map {
            meta, panel_options, design_options -> {
                meta = validate_panel(meta, panel_options)
                meta = validate_design(meta, design_options)
                return meta
            }
        }
        .join(ch_input)

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
========================================================================================
    SUBWORKFLOW FOR PIPELINE COMPLETION
========================================================================================
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications
    multiqc_report  //  string: Path to MultiQC report

    main:

    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(summary_params, email, email_on_fail, plaintext_email, outdir, monochrome_logs, multiqc_report.toList())
        }

        completionSummary(monochrome_logs)

        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/
//
// Check and validate pipeline parameters
//
def validateInputParameters() {
    // Keep this commented here to closely follow the template
    // genomeExistsError()
}

//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    def (metas, fastqs) = input[1..2]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect{ it.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }

    return [ metas[0], fastqs ]
}
//
// Get attribute from genome config file e.g. fasta
//
def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[ params.genome ].containsKey(attribute)) {
            return params.genomes[ params.genome ][ attribute ]
        }
    }
    return null
}

//
// Exit pipeline if incorrect --genome key provided
//
def genomeExistsError() {
    if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
        def error_string = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
            "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" +
            "  Currently, the available genome keys are:\n" +
            "  ${params.genomes.keySet().join(", ")}\n" +
            "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        error(error_string)
    }
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    // TODO nf-core: Optionally add in-text citation tools to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "Tool (Foo et al. 2023)" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def citation_text = [
            "Tools used in the workflow included:",
            "FastQC (Andrews 2010),",
            "MultiQC (Ewels et al. 2016)",
            "."
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // TODO nf-core: Optionally add bibliographic entries to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "<li>Author (2023) Pub name, Journal, DOI</li>" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def reference_text = [
            "<li>Andrews S, (2010) FastQC, URL: https://www.bioinformatics.babraham.ac.uk/projects/fastqc/).</li>",
            "<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics , 32(19), 3047–3048. doi: /10.1093/bioinformatics/btw354</li>"
        ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    meta["doi_text"] = meta.manifest_map.doi ? "(doi: <a href=\'https://doi.org/${meta.manifest_map.doi}\'>${meta.manifest_map.doi}</a>)" : ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "": "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = ""
    meta["tool_bibliography"] = ""

    // TODO nf-core: Only uncomment below if logic in toolCitationText/toolBibliographyText has been filled!
    // meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    // meta["tool_bibliography"] = toolBibliographyText()


    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}



//
// Resolve relative paths relative to the samplesheet parent directory.
//
def resolve_relative_path(relative_path, URI samplesheet_path) {
    if (!(relative_path instanceof String)) {
        return relative_path
    }

    // Try to create a java.net.UR object out of it. If it is not a proper URL, a MalformedURLException will be t
    URI uri;

    try {
        uri = new URI(relative_path)
    } catch (URISyntaxException exc) {
        return relative_path
    }

    // If a scheme is given we keep it as given
    if (uri.getScheme() != null) {
        return relative_path
    }

    def path = new File(relative_path)
    if (path.isAbsolute()) {
        return relative_path
    }

    // Resolve relative paths agains the samplesheet_path
    def resolvedPath = samplesheet_path.resolve(relative_path);

    def stringPath = resolvedPath.toString()
    return stringPath
}

//
// Validate a given panel key if present against the (dynamic) set of panel options retrieved from pixelator
//
def validate_panel(LinkedHashMap meta, HashSet options) {
    if (meta.panel == null) {
        return
    }

    if (!options.contains(meta.panel)) {
        options_list_str = " - ${options.join("\n - ")}"
        exit 1, "Please check input samplesheet -> panel field does not contains a valid key!\n\nInput: ${meta.panel}\nValid options:\n${options_list_str}"
    }

    return meta
}


//
// Validate a given design key if present against the (dynamic) set of design options retrieved from pixelator
//
def validate_design(LinkedHashMap meta, HashSet options) {
    if (meta.design == null) {
        return
    }

    if (!options.contains(meta.design)) {
        options_list_str = " - ${options.join("\n - ")}"
        exit 1, "Please check input samplesheet -> design field does not contains a valid key!\n\nInput: ${meta.design}\nValid options:\n${options_list_str}"
    }

    return meta
}

//
// Determine the path/url that will be used as the root for relative paths in the samplesheet
//
def get_data_basedir(URI samplesheet, String input_basedir) {

    URI uri;

    // nothing given to --input_data so we use the samplesheet as root directory
    // for resolving relative paths
    if (!input_basedir) {
        return samplesheet
    }

    try {
        uri = new URI(input_basedir)
    } catch (URISyntaxException exc) {
        return samplesheet
    }

    // If a scheme is given we keep check that it is a directory (trailing-slash)
    if (uri.getScheme() != null) {
        if (!uri.path.endsWith('/')) {
            def newUrl = new URI(
                    uri.getScheme(), uri.getUserInfo(), uri.getHost(),
                    uri.getPort(), uri.getPath() + '/', uri.getQuery(), uri.getFragment()
            )
            return newUrl
        }
        return uri
    }

    f = file(input_basedir)
    if (!f.exists()) {
        exit 1, "ERROR: data path passed with --input_basedir does not exist!"
    }
    if (f.isDirectory()) {
        data_root = new URI(f.toString() + '/')
    } else {
        data_root = new URI(f.toString())
    }

    return data_root
}

//
// Resolve relative paths and check that all files exist.
//
def validate_input_samplesheet(URI samplesheetUrl, items) {
    def meta = items[0]
    def panel_file = items[1]
    def fq = items[2..-1]

    def paired_end = fq.size() == 2
    def panel_file_abs = resolve_relative_path(panel_file, samplesheetUrl)
    def fq1_abs = resolve_relative_path(fq[0], samplesheetUrl)

    if (panel_file_abs && !file(panel_file_abs).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> panel_file does not exist!\n${panel_file_abs}"
    }

    if (!file(fq1_abs).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> fastq_1 does not exist!\n${fq1_abs}"
    }

    def reads = [ fq1_abs ]

    if (paired_end) {
        def fq2_abs = resolve_relative_path(fq[1], samplesheetUrl)

        if (fq2_abs && !file(fq2_abs).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> fastq_2 does not exist!\n${fq2_abs}"
        }

        reads += [ fq2_abs]
    }

    return [ meta, panel_file_abs, reads ]
}
