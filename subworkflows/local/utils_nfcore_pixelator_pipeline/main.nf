//
// Subworkflow with functionality specific to the nf-core/pixelator pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
include { paramsHelp                } from 'plugin/nf-schema'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'

include { PIXELATOR_LIST_OPTIONS  } from '../../../modules/local/pixelator/list_options'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {
    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet
    input_basedir     //  string: Path to the base directory for relative paths resolving
    help              // boolean: Display help message and exit
    help_full         // boolean: Show the full help message
    show_hidden       // boolean: Show hidden parameters in the help message

    main:

    ch_versions = channel.empty()

    // Thrown an error if the pipeline is run with conda or mamba
    // as this is not supported in the pipeline at the moment
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        exit(1, "ERROR: Conda and Mamba are not supported in the pipeline at the moment. Please use docker or singularity.")
    }

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE(
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1,
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    before_text = """
-\033[2m----------------------------------------------------\033[0m-
                                        \033[0;32m,--.\033[0;30m/\033[0;32m,-.\033[0m
\033[0;34m        ___     __   __   __   ___     \033[0;32m/,-._.--~\'\033[0m
\033[0;34m  |\\ | |__  __ /  ` /  \\ |__) |__         \033[0;33m}  {\033[0m
\033[0;34m  | \\| |       \\__, \\__/ |  \\ |___     \033[0;32m\\`-._,-`-,\033[0m
                                        \033[0;32m`._,._,\'\033[0m
\033[0;35m  nf-core/pixelator ${workflow.manifest.version}\033[0m
-\033[2m----------------------------------------------------\033[0m-
"""
    after_text = """${workflow.manifest.doi ? "\n* The pipeline\n" : ""}${workflow.manifest.doi.tokenize(",").collect { doi -> "    https://doi.org/${doi.trim().replace('https://doi.org/','')}"}.join("\n")}${workflow.manifest.doi ? "\n" : ""}
* The nf-core framework
    https://doi.org/10.1038/s41587-020-0439-x

* Software dependencies
    https://github.com/nf-core/pixelator/blob/master/CITATIONS.md
"""
    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE(
        nextflow_cli_args
    )

    //
    // Create channel from input file provided through params.input
    //

    ch_versions = channel.empty()

    //
    // Resolve relative paths and validate fastq files existence
    //
    def samplesheet_uri = file(input).toUri()
    def inputBaseDir = get_data_basedir(samplesheet_uri, input_basedir)

    log.info("Resolving relative paths in samplesheet relative to: ${inputBaseDir}")

    //
    // Create channel from input file provided through params.input
    //
    ch_input = channel
        .fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
        .map {
            validate_input_samplesheet(inputBaseDir, it)
        }

    //
    // Validate design and panel samplesheet fields agains a dynamic set of allowed values
    //
    PIXELATOR_LIST_OPTIONS()

    // Create a set of valid pixelator options to pass to --design
    ch_design_options = PIXELATOR_LIST_OPTIONS.out.designs
        .splitText()
        .map { it.trim() }
        .reduce(new HashSet()) { prev, curr -> prev << curr }

    // Create a set of valid pixelator panel keys to pass using --panel
    ch_panel_options = PIXELATOR_LIST_OPTIONS.out.panels
        .splitText()
        .map { it.trim() }
        .reduce(new HashSet()) { prev, curr -> prev << curr }


    //
    // Combine the validated inputs again into a single channel
    //
    ch_samplesheet = ch_input
        .map { it -> it[0] }
        .combine(ch_panel_options)
        .combine(ch_design_options)
        .map { meta, panel_options, design_options ->
            {
                meta = validate_panel(meta, panel_options)
                meta = validate_design(meta, design_options)
                return meta
            }
        }
        .join(ch_input)
        .map { meta, panel, reads ->
            def newMeta = detect_technology(meta)
            return [newMeta, panel, reads]
        }

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {
    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                []
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }

    workflow.onError {
        log.error("Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting")
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    def (metas, fastqs) = input[1..2]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect { meta -> meta.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }

    return [metas[0], fastqs]
}
//
// Get attribute from genome config file e.g. fasta
//
def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[params.genome].containsKey(attribute)) {
            return params.genomes[params.genome][attribute]
        }
    }
    return null
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
            "."
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // TODO nf-core: Optionally add bibliographic entries to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "<li>Author (2023) Pub name, Journal, DOI</li>" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def reference_text = [
        ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familiar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        def manifest_doi = meta.manifest_map.doi.tokenize(",")
        manifest_doi.each { doi_ref ->
            temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        }
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    }
    else {
        meta["doi_text"] = ""
    }
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = ""
    meta["tool_bibliography"] = ""

    // TODO nf-core: Only uncomment below if logic in toolCitationText/toolBibliographyText has been filled!
    // meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    // meta["tool_bibliography"] = toolBibliographyText()


    def methods_text = mqc_methods_yaml.text

    def engine = new groovy.text.SimpleTemplateEngine()
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
    def URI uri

    try {
        uri = new URI(relative_path)
    }
    catch (URISyntaxException exc) {
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
    def resolvedPath = samplesheet_path.resolve(relative_path)

    def stringPath = resolvedPath.toString()
    return stringPath
}

//
// Validate a given panel key if present against the (dynamic) set of panel options retrieved from pixelator
//
def validate_panel(LinkedHashMap meta, HashSet options) {
    if (meta.panel == null || meta.panel == []) {
        return meta
    }

    if (!options.contains(meta.panel)) {
        def options_list_str = " - ${options.join("\n - ")}"
        exit(1, "Please check input samplesheet -> panel field does not contains a valid key!\n\nInput: ${meta.panel}\nValid options:\n${options_list_str}")
    }

    return meta
}


//
// Validate a given design key if present against the (dynamic) set of design options retrieved from pixelator
//
def validate_design(LinkedHashMap meta, HashSet options) {
    if (meta.design == null || meta.design == []) {
        return meta
    }

    if (!options.contains(meta.design)) {
        def options_list_str = " - ${options.join("\n - ")}"
        exit(1, "Please check input samplesheet -> design field does not contains a valid key!\n\nInput: ${meta.design}\nValid options:\n${options_list_str}")
    }

    return meta
}

//
// Determine the path/url that will be used as the root for relative paths in the samplesheet
//
def get_data_basedir(URI samplesheet, String input_basedir) {

    def URI uri

    // nothing given to --input_data so we use the samplesheet as root directory
    // for resolving relative paths
    if (!input_basedir) {
        return samplesheet
    }

    try {
        uri = new URI(input_basedir)
    }
    catch (URISyntaxException exc) {
        return samplesheet
    }

    // If a scheme is given we keep check that it is a directory (trailing-slash)
    if (uri.getScheme() != null) {
        if (!uri.path.endsWith('/')) {
            def newUrl = new URI(uri.getScheme(), uri.getUserInfo(), uri.getHost(), uri.getPort(), uri.getPath() + '/', uri.getQuery(), uri.getFragment())
            return newUrl
        }
        return uri
    }

    def f = file(input_basedir)
    if (!f.exists()) {
        exit(1, "ERROR: data path passed with --input_basedir does not exist!")
    }

    def data_root = null

    if (f.isDirectory()) {
        data_root = new URI(f.toString() + '/')
    }
    else {
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
        exit(1, "ERROR: Please check input samplesheet -> panel_file does not exist!\n${panel_file_abs}")
    }

    if (!file(fq1_abs).exists()) {
        exit(1, "ERROR: Please check input samplesheet -> fastq_1 does not exist!\n${fq1_abs}")
    }

    def reads = [fq1_abs]

    if (paired_end) {
        def fq2_abs = resolve_relative_path(fq[1], samplesheetUrl)

        if (fq2_abs && !file(fq2_abs).exists()) {
            exit(1, "ERROR: Please check input samplesheet -> fastq_2 does not exist!\n${fq2_abs}")
        }

        reads += [fq2_abs]
    }

    return [meta, panel_file_abs, reads]
}

//
// Inject a `technology` field into the meta map based on the design
//
def detect_technology(LinkedHashMap meta) {
    def newMeta = [:]
    if (meta.design.startsWith('pna')) {
        newMeta = meta + [technology: 'pna']
    }
    else {
        newMeta = meta + [technology: 'mpx']
    }
    return newMeta
}
