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
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
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
    sample_defaults   //     map: technology (checked against the samplesheet), and the values for samplesheet
                      //          rows that leave them empty: design, sequencing_technology, reverse_read and
                      //          min_avg_quality (reverse_read and min_avg_quality: null to follow the sequencing technology)
    help              // boolean: Display help message and exit
    help_full         // boolean: Show the full help message
    show_hidden       // boolean: Show hidden parameters in the help message

    main:

    ch_versions = channel.empty()

    // Thrown an error if the pipeline is run with conda or mamba
    // as this is not supported in the pipeline at the moment
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("ERROR: Conda and Mamba are not supported in the pipeline at the moment. Please use docker or singularity.")
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

    def before_text = ""
    def after_text = ""
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
    if (monochrome_logs) {
        before_text = before_text.replaceAll(/\033\[[0-9;]*m/, '')
    }

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
        command,
        null
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE(
        nextflow_cli_args
    )

    //
    // Resolve relative paths and validate fastq files existence
    //
    def samplesheet_uri = file(input).toUri()
    def inputBaseDir = get_data_basedir(samplesheet_uri, input_basedir)

    log.info("Resolving relative paths in samplesheet relative to: ${inputBaseDir}")

    //
    // Read, validate and group the samplesheet. The 1-based samplesheet row number is
    // kept in the meta to name the edgelist files
    //
    def rows = samplesheetToList(input, "${projectDir}/assets/schema_input.json")
        .withIndex()
        .collect { row, index -> validate_input_samplesheet(inputBaseDir, row, index + 1, sample_defaults) }
    def units = group_samplesheet_units(rows, sample_defaults.technology)

    //
    // Validate design and panel samplesheet fields agains a dynamic set of allowed values
    //
    PIXELATOR_LIST_OPTIONS()

    // Create a set of valid pixelator options to pass to --design
    ch_design_options = PIXELATOR_LIST_OPTIONS.out.designs
        .splitText()
        .map { design_option -> design_option.trim() }
        .reduce(new HashSet()) { prev, curr -> prev << curr }

    // Create a set of valid pixelator panel keys to pass using --panel
    ch_panel_options = PIXELATOR_LIST_OPTIONS.out.panels
        .splitText()
        .map { panel_option -> panel_option.trim() }
        .reduce(new HashSet()) { prev, curr -> prev << curr }

    // Check every design/panel combination of the samplesheet once.
    // The lanes are only released when all of them are valid.
    ch_options_checked = channel
        .fromList(units.options)
        .combine(ch_panel_options)
        .combine(ch_design_options)
        .map { options, panel_options, design_options ->
            validate_panel(options, panel_options)
            validate_design(options, design_options)
            return options
        }
        .toList()
        .map { _all_options -> true } // single value, so that `combine` below adds exactly one element

    ch_lanes = channel
        .fromList(units.lanes)
        .combine(ch_options_checked)
        .map { meta, reads, panel_file, _checked -> [meta, reads, panel_file] }

    ch_unit_panel_files = channel.fromList(units.unit_panel_files)
    ch_sample_metas     = channel.fromList(units.sample_metas)

    emit:
    lanes            = ch_lanes
    unit_panel_files = ch_unit_panel_files
    sample_metas     = ch_sample_metas
    versions         = ch_versions
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

    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs for common issues: https://nf-co.re/docs/running/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

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

// Collect report inputs from the topic. Keep every JSON file, but only PXL files
// from the last pipeline stage that published one. Skipped steps never emit, so
// no skip-flag branching is needed. Filtering happens before EXPERIMENT_SUMMARY
// stages the files, so intermediate PXL copies are not downloaded.
def collectReportInputsFromTopic() {
    // Later stages first. The first stage that appears in the topic is the last that ran.
    def pxl_stage_preference = ['analysis', 'sample_calling', 'denoise', 'graph_collapse', 'graph']

    return channel
        .topic('all_results_for_reports')
        .map { stage, files ->
            def values = files instanceof List ? files : [files]
            values.collect { f -> tuple(stage, f) }
        }
        .flatMap { it }
        .collect(flat: false)
        .map { stageFilePairs ->
            def last_pxl_stage = pxl_stage_preference.find { stage ->
                stageFilePairs.any { pair ->
                    pair[0] == stage && pair[1].name.endsWith('.pxl')
                }
            }
            def filtered = stageFilePairs.findAll { pair ->
                !pair[1].name.endsWith('.pxl') || pair[0] == last_pxl_stage
            }
            tuple([id: 'all'], filtered.collect { it[0] }, filtered.collect { it[1] })
        }
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    // nf-core: Optionally add in-text citation tools to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "Tool (Foo et al. 2023)" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def citation_text = [
            "Tools used in the workflow included:",
            "."
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // nf-core: Optionally add bibliographic entries to this list.
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

    // nf-core: Only uncomment below if logic in toolCitationText/toolBibliographyText has been filled!
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
    catch (URISyntaxException _exc) {
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
        error("Please check input samplesheet -> panel field does not contains a valid key!\n\nInput: ${meta.panel}\nValid options:\n${options_list_str}")
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
        error("Please check input samplesheet -> design field does not contains a valid key!\n\nInput: ${meta.design}\nValid options:\n${options_list_str}")
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
    catch (URISyntaxException _exc) {
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
        error("ERROR: data path passed with --input_basedir does not exist!")
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
// Also resolve the design and how edgelist reads the FASTQ files. A value in the samplesheet row
// wins over the global parameter, which wins over the sequencing technology default.
// The edgelist module only sees how to read the FASTQ files (see edgelist_read_settings),
// not which technology made them.
//
def validate_input_samplesheet(URI samplesheetUrl, items, int row, Map defaults) {
    def meta = items[0] + [row: row]
    def panel_file = items[1]
    def fq = items[2..-1]

    // nf-schema yields an empty list for a missing fastq_2, so check the value, not the size
    def paired_end = fq.size() == 2 && fq[1]

    // Missing columns and empty cells arrive as null, [] or '', which Groovy treats as false
    def design = meta.design ?: defaults.design

    def sequencing_technology = meta.sequencing_technology ?: defaults.sequencing_technology
    if (sequencing_technology == 'sbx' && paired_end) {
        error("ERROR: Please check input samplesheet -> sample '${meta.id}' has a fastq_2, but sequencing technology sbx takes only fastq_1.")
    }
    if (meta.reverse_read && paired_end) {
        error("ERROR: Please check input samplesheet -> sample '${meta.id}' has a fastq_2, but reverse_read only applies to single-end samples.")
    }
    // SBX gives a single reverse read; single-end SBS gives a forward read unless overridden.
    // The global --reverse_read only applies to single-end rows.
    def reverse = paired_end ? false
        : meta.reverse_read ? meta.reverse_read == 'yes'
        : defaults.reverse_read != null ? defaults.reverse_read
        : sequencing_technology == 'sbx'
    // An empty cell in this integer column is not a number, and 0 is a valid threshold
    def row_quality = meta.min_avg_quality instanceof Number ? meta.min_avg_quality : null
    def min_avg_quality = row_quality != null ? row_quality
        : defaults.min_avg_quality != null ? defaults.min_avg_quality
        : sequencing_technology == 'sbx' ? 5 : 20

    meta = meta.findAll { key, _value -> !(key in ['sequencing_technology', 'reverse_read']) } + [
        design: design,
        single_end: !paired_end,
        single_end_reverse: reverse,
        min_avg_quality: min_avg_quality,
    ]
    def panel_file_abs = resolve_relative_path(panel_file, samplesheetUrl)
    def fq1_abs = resolve_relative_path(fq[0], samplesheetUrl)

    if (panel_file_abs && !file(panel_file_abs).exists()) {
        error("ERROR: Please check input samplesheet -> panel_file does not exist!\n${panel_file_abs}")
    }

    if (!file(fq1_abs).exists()) {
        error("ERROR: Please check input samplesheet -> fastq_1 does not exist!\n${fq1_abs}")
    }

    def reads = [fq1_abs]

    if (paired_end) {
        def fq2_abs = resolve_relative_path(fq[1], samplesheetUrl)

        if (fq2_abs && !file(fq2_abs).exists()) {
            error("ERROR: Please check input samplesheet -> fastq_2 does not exist!\n${fq2_abs}")
        }

        reads += [fq2_abs]
    }

    if (meta.pool && meta.pool == meta.id) {
        error("ERROR: Please check input samplesheet -> `pool` must be different from `sample`: ${meta.id}")
    }

    // The samplesheet schema only sees an explicit `design`, not the --design default
    if (meta.pool && design == 'proxiome-v1') {
        error("ERROR: Please check input samplesheet -> sample '${meta.id}' is pooled, but pooled samples can only be used with the `proxiome-v2` design.")
    }

    return [meta, panel_file_abs, reads]
}

//
// How edgelist reads one FASTQ input. These are set per samplesheet row, so they can
// differ between the runs of a sample or pool and only belong in the meta of a lane.
//
def edgelist_read_settings(Map meta) {
    return meta.subMap(['single_end', 'single_end_reverse', 'min_avg_quality'])
}

def without_read_settings(Map meta) {
    return meta.findAll { key, _value -> !(key in edgelist_read_settings(meta).keySet()) }
}

//
// Drop the samplesheet row, which differs between the runs of a sample or pool.
//
def without_row(Map meta) {
    return meta.findAll { key, _value -> key != 'row' }
}

//
// Drop samplesheet fields that describe a single sample; they are meaningless
// once samples are grouped into a pool.
//
def pool_meta(LinkedHashMap meta) {
    def grouped = meta.findAll { key, _value -> !(key in ['sample_alias', 'condition', 'hash_index', 'row']) }
    grouped.id = meta.pool
    return grouped
}

//
// Group the validated samplesheet rows ([meta, panel_file, reads]) into processing
// units (the pool if the row has a `pool`, else the sample) and check that the rows
// of a unit are consistent. Returns a map with:
//   lanes:            [meta, reads, panel_file] per unique FASTQ input of a unit.
//                     The meta is the unit meta, with the number of lanes (`parts`),
//                     the first samplesheet row listing the input (`row`) and how
//                     edgelist reads the input (see edgelist_read_settings).
//   unit_panel_files: [unit id, panel_file]
//   sample_metas:     [sample id, meta], to restore the per-sample metadata after sample calling
//   options:          distinct [design, panel] pairs to validate against pixelator
//
def group_samplesheet_units(List rows, String technology) {
    // The technology is only used to check that the samplesheet is consistent with it;
    // pooling itself is detected per row from the `pool` column.
    def expect_pooled = technology in ['proxiome-v2', 'hashed_samples']

    rows.each { meta, _panel_file, _reads ->
        if (expect_pooled && !meta.pool) {
            error("ERROR: Sample '${meta.id}' has no `pool`, but --technology ${technology} requires pooled samples.")
        }
        if (!expect_pooled && meta.pool) {
            error("ERROR: Sample '${meta.id}' has `pool` '${meta.pool}', but --technology ${technology} does not use pooled samples.")
        }
    }

    def lanes = []
    def unit_panel_files = []
    rows.groupBy { meta, _panel_file, _reads -> meta.pool ?: meta.id }.each { unit_id, unit_rows ->
        def (first_meta, _first_panel_file, _first_reads) = unit_rows[0]
        def is_pool = first_meta.pool

        if (unit_rows.collect { meta, _panel_file, _reads -> meta.design }.unique().size() > 1) {
            error("ERROR: Runs of the same sample or pool ('${unit_id}') must use the same design.")
        }

        def panel_files = unit_rows.collect { _meta, panel_file, _reads -> panel_file }.unique()
        if (panel_files.size() > 1) {
            error("ERROR: Runs of the same sample or pool ('${unit_id}') must use the same panel.")
        }

        // Unique FASTQ inputs (pooled samples repeat the same FASTQs on several rows),
        // each with the first samplesheet row it appears on. The row is used to name
        // the output files of the input, so that different FASTQs sharing the same
        // file name (e.g. in different folders) do not overwrite each other.
        // Example for pool1 (3 samples: sample1-3; 2 runs: original + re-sequencing), so 6 rows:
        // rows 1-3 (one per sample) list pool1_R1/R2.fastq.gz, rows 4-6 list pool1_reseq_R1/R2.fastq.gz
        def rows_by_reads = unit_rows.groupBy { _meta, _panel_file, reads -> reads }  // [[pool1_R1, pool1_R2]: [row1, row2, row3], [pool1_reseq_R1, pool1_reseq_R2]: [row4, row5, row6]]
        def unit_meta = without_read_settings(is_pool ? pool_meta(first_meta) : without_row(first_meta)) + [parts: rows_by_reads.size()]  // [id: 'pool1', pool: 'pool1', ..., parts: 2] (2 unique FASTQ pairs, not the 3 samples)
        rows_by_reads.each { reads, reads_rows ->  // 1st: reads = [pool1_R1, pool1_R2], reads_rows = [row1, row2, row3]
            def first_row = reads_rows.collect { meta, _panel_file, _reads -> meta.row }.min()  // 1st: [1, 2, 3].min() = 1, 2nd: [4, 5, 6].min() = 4
            // A FASTQ listed on several rows (the samples of a pool) must be read the same way on each of them
            def read_settings = reads_rows.collect { meta, _panel_file, _reads -> edgelist_read_settings(meta) }.unique()
            if (read_settings.size() > 1) {
                error("ERROR: Please check input samplesheet -> ${reads[0]} is listed on several rows with a different sequencing_technology, reverse_read or min_avg_quality.")
            }
            lanes << [unit_meta + [row: first_row] + read_settings[0], reads, panel_files[0]]  // 1st: [[id: 'pool1', ..., parts: 2, row: 1, single_end: false, ...], [pool1_R1, pool1_R2], panel]
        }
        unit_panel_files << [unit_id, panel_files[0]]
    }

    return [
        lanes: lanes,
        unit_panel_files: unit_panel_files,
        sample_metas: rows.collect { meta, _panel_file, _reads -> [meta.id, without_read_settings(without_row(meta))] }.unique(),
        options: rows.collect { meta, _panel_file, _reads -> [design: meta.design, panel: meta.panel] }.unique(),
    ]
}
