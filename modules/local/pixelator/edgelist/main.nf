process PIXELATOR_EDGELIST {
    tag "${meta.id}"
    label 'process_medium'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    container "${params.pixelator_container?:workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'ghcr.io/pixelgentechnologies/pixelator:sha-45647a1'
        : 'ghcr.io/pixelgentechnologies/pixelator:sha-45647a1'}"

    input:
    tuple val(meta), path(reads, arity: '1..*'), path(panel_file), val(panel), val(design)

    output:
    tuple val(meta), path("edgelist/*.parquet", arity: 1), emit: edgelist
    tuple val(meta), path("edgelist/*.report.json"),      emit: report_json
    tuple val(meta), path("edgelist/*.meta.json"),        emit: metadata_json
    tuple val(meta), path("*pixelator-edgelist.log"),     emit: log
    tuple val('edgelist'), path("edgelist/*.{meta,report}.json"), topic: all_results_for_reports

    tuple val("${task.process}"), val('pixelator'), eval("pixelator --version 2>/dev/null | sed 's/pixelator, version //g'"), emit: versions_pixelator, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def panelOpt = (panel
        ? "--panel ${panel}"
        : panel_file ? "--panel ${panel_file}" : "")
    def designOpt = "--design ${design}"
    def read_list = reads instanceof List ? reads : [reads]
    def read_args = meta.single_end
        ? "--read-forward ${read_list[0]}"
        : "--read-forward ${read_list[0]} --read-reverse ${read_list[1]}"
    // Output parquet/report/meta names come from the FASTQ basename (CLI).
    // --sample-name only sets report.json sample_id.
    def sample_name = task.ext.prefix ?: "${meta.id}"
    def log_prefix = task.ext.prefix ?: edgelistOutputStem(read_list, meta.single_end)

    """
    pixelator \\
        --log-file ${log_prefix}.pixelator-edgelist.log \\
        --verbose \\
        single-cell-pna \\
        edgelist \\
        ${read_args} \\
        --sample-name ${sample_name} \\
        ${panelOpt} \\
        ${designOpt} \\
        --threads ${task.cpus} \\
        --output . \\
        ${args}
    """

    stub:
    def read_list = reads instanceof List ? reads : [reads]
    def output_stem = edgelistOutputStem(read_list, meta.single_end)
    def log_prefix = task.ext.prefix ?: output_stem

    """
    mkdir edgelist
    touch edgelist/${output_stem}.report.json
    touch edgelist/${output_stem}.meta.json
    touch edgelist/${output_stem}.parquet
    touch ${log_prefix}.pixelator-edgelist.log
    """
}

// Match pixelator edgelist output basenames. Strip only .fastq.gz/.fq.gz so a
// dot in the sample name is kept, and for paired reads also strip the R1/R2 suffix.
def edgelistOutputStem(read_list, single_end) {
    def stem = read_list[0].name.replaceFirst(/\.(fastq|fq)\.gz$/, '')
    if (single_end) {
        return stem
    }
    return stem.replaceFirst(/([._][Rr][12]|_[12])$/, '')
}

// Stems shared by more than one FASTQ unit. Identical paths are not duplicates;
// the caller drops those with unique() before calling this.
def duplicateEdgelistStems(units, single_end) {
    def stems = units.collect { unit ->
        def reads = (unit instanceof Collection ? unit : [unit]).collect { read -> file(read) }
        edgelistOutputStem(reads, single_end)
    }
    stems.countBy { stem -> stem }.findAll { _stem, count -> count > 1 }.keySet().sort()
}
