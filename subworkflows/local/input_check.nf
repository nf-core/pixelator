//
// Check input samplesheet and get read channels
//
include { fromSamplesheet }          from 'plugin/nf-validation'
include { SAMPLESHEET_CHECK }        from '../../modules/local/samplesheet_check'
include { PIXELATOR_LIST_OPTIONS }   from '../../modules/local/pixelator/list_options.nf'

workflow INPUT_CHECK {
    take:
    samplesheet                                // file: /path/to/samplesheet.csv

    main:

    // Create a new channel of metadata from a sample sheet
    // NB: `input` corresponds to `params.input` and associated sample sheet schema
    def samplesheetUrl = samplesheet.toUri()

    ch_input = Channel.fromSamplesheet("input")
        .map { check_channels(samplesheetUrl, *it) }

    PIXELATOR_LIST_OPTIONS()

    // Create a set of valid pixelator options to pass to --design
    ch_design_options = PIXELATOR_LIST_OPTIONS.out.designs
        .splitText()
        .map( text -> text.trim())
        .reduce( new HashSet() ) { prev, curr -> prev << curr }

    // Create a set of valid pixelator designs
    ch_panel_options = PIXELATOR_LIST_OPTIONS.out.panels
        .splitText()
        .map( text -> text.trim())
        .reduce( new HashSet() ) { prev, curr -> prev << curr }

    ch_checked_input = ch_input
        .map { it -> it[0] }
        .combine(ch_panel_options)
        .combine(ch_design_options)
        .map {
            meta, panel_options, design_options ->
                validate_panel(meta, panel_options)
                validate_design(meta, design_options)
                return [meta, []]
        }
        // Combine a dummy output after validation with the main input and strip the dummy value again
        // This adds a dependency to make sure all jobs wait untill the validation is complete
        .join(ch_input)
        .map { it -> [ it[0] ] + it[2..-1] }

    reads = ch_checked_input.map { it -> [it[0]] + it[2..-1] }
    panels = ch_checked_input.map { it -> [it[0], it[1]] }

    emit:
    reads                                      // channel: [ val(meta), [ reads ] ]
    panels                                     // channel: [ val(meta), panel ]

    versions = PIXELATOR_LIST_OPTIONS.out.versions  // channel: [ versions.yml ]
}


// Resolve relative paths relative to the samplesheet parent directory.
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
        return uri
    }

    def path = new File(relative_path);
    if (path.isAbsolute()) {
        return path
    }

    // Resolve relative paths agains the samplesheet_path
    def resolvedPath = samplesheet_path.resolve(relative_path);

    def stringPath = resolvedPath.toString()
    return stringPath
}


// Validate a given panel key if present against the (dynamic) set of panel options retrieved from pixelator
def validate_panel(LinkedHashMap meta, HashSet options) {
    if (meta.panel == null) {
        return
    }

    if (!options.contains(meta.panel)) {
        exit 1, "ERROR: Please check input samplesheet -> panel field does not contains a valid key!\n${meta.panel}\nValid options:\n${options}"
    }
}


// Validate a given design key if present against the (dynamic) set of design options retrieved from pixelator
def validate_design(LinkedHashMap meta, HashSet options) {
    if (meta.design == null) {
        return
    }

    if (!options.contains(meta.design)) {
        exit 1, "ERROR: Please check input samplesheet -> design field does contains a valid key!\n${meta.design}\nValid options:\n${options}"
    }
}

// Resolve relative paths and check that all files exist.
def check_channels(URI samplesheetUrl, Map meta, panel_file, ...fq) {
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
