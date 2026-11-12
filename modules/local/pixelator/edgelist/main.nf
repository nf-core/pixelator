process PIXELATOR_EDGELIST {
    tag "${meta.id}"
    label 'process_medium'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    container "${params.pixelator_container?:workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'ghcr.io/pixelgentechnologies/pixelator:0.32.0'
        : 'ghcr.io/pixelgentechnologies/pixelator:0.32.0'}"

    input:
    tuple val(meta), path(reads, arity: '1..*'), path(panel_file), val(panel), val(design)

    output:
    tuple val(meta), path("edgelist/*.parquet", arity: 1), emit: edgelist
    tuple val(meta), path("dropped_reads/*.parquet"),     emit: dropped_reads, optional: true
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
    // Output parquet/report/meta names come from the FASTQ basename (CLI).
    // --sample-name only sets report.json sample_id.
    // The FASTQs are linked as `<id>_<row>_<name>` (row: first samplesheet row of the FASTQs)
    // so that output names are unique, also when FASTQ files share the same name.
    def unit_prefix = "${meta.id}_${meta.row}"
    def staged_reads = read_list.collect { read -> "${unit_prefix}_${read.name}".toString() }
    def link_cmd = [read_list, staged_reads].transpose().collect { read, staged -> "ln -s ${read} ${staged}" }.join('\n    ')
    def read_args = meta.single_end
        ? "--read-forward ${staged_reads[0]}"
        : "--read-forward ${staged_reads[0]} --read-reverse ${staged_reads[1]}"
    def sample_name = task.ext.prefix ?: "${meta.id}"
    def log_prefix = task.ext.prefix ?: unit_prefix

    """
    ${link_cmd}

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

    # Keep the dropped reads out of edgelist/ so that the edgelist output stays unambiguous
    mkdir dropped_reads
    find edgelist -name '*.dropped_reads.parquet' -exec mv -t dropped_reads {} +
    """

    stub:
    def args = task.ext.args ?: ''
    def read_list = reads instanceof List ? reads : [reads]
    def unit_prefix = "${meta.id}_${meta.row}"
    def output_stem = "${unit_prefix}_${read_list[0].name}".replaceFirst(/\.(fastq|fq)\.gz$/, '')
    def log_prefix = task.ext.prefix ?: unit_prefix
    def dropped_reads_cmd = args.contains('--save-dropped-reads')
        ? "touch dropped_reads/${output_stem}.dropped_reads.parquet"
        : ""

    """
    mkdir edgelist dropped_reads
    touch edgelist/${output_stem}.report.json
    touch edgelist/${output_stem}.meta.json
    touch edgelist/${output_stem}.parquet
    touch ${log_prefix}.pixelator-edgelist.log
    ${dropped_reads_cmd}
    """
}
