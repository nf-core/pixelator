process PIXELATOR_AGGREGATE {
    tag "${meta.id}"
    label 'process_high'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    container "${params.pixelator_container?:workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'ghcr.io/pixelgentechnologies/pixelator:sha-45647a1'
        : 'ghcr.io/pixelgentechnologies/pixelator:sha-45647a1'}"

    input:
    tuple val(meta), path(edgelist_parquet, arity: '1..*', stageAs: "edgelist/*")

    output:
    tuple val(meta), path("aggregate/*.parquet", arity: 1), emit: parquet
    tuple val(meta), path("aggregate/*.report.json"),      emit: report_json
    tuple val(meta), path("aggregate/*.meta.json"),        emit: metadata_json
    tuple val(meta), path("*pixelator-aggregate.log"),     emit: log
    tuple val('aggregate'), path("aggregate/*.{meta,report}.json"), topic: all_results_for_reports

    tuple val("${task.process}"), val('pixelator'), eval("pixelator --version 2>/dev/null | sed 's/pixelator, version //g'"), emit: versions_pixelator, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def edgelist_args = edgelist_parquet instanceof List ? edgelist_parquet.join(' ') : edgelist_parquet
    def memory_factor = 0.75

    // The memory limit here needs to keep some buffer. This limit is used in DuckDB but it is not a hard limit.
    // Setting it too close to the actual RAM available may cause to not spill to disk soon enough and run out of memory.
    """
    pixelator \\
        --log-file ${prefix}.pixelator-aggregate.log \\
        --verbose \\
        single-cell-pna \\
        aggregate \\
        --output . \\
        --sample-name ${prefix} \\
        --threads ${task.cpus} \\
        --memory ${Math.ceil(task.memory.toMega() * memory_factor).intValue()}M \\
        ${args} \\
        ${edgelist_args}
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir aggregate
    touch aggregate/${prefix}.parquet
    touch aggregate/${prefix}.report.json
    touch aggregate/${prefix}.meta.json
    touch ${prefix}.pixelator-aggregate.log
    """
}
