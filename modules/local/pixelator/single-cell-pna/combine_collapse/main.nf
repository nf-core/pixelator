process PIXELATOR_PNA_COMBINE_COLLAPSE {
    tag "${meta.id}"
    label 'process_medium'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.23.0'
        : 'quay.io/pixelgen-technologies/pixelator:0.23.0'}"

    input:
    tuple val(meta), path(parquet_files, stageAs: "parquet/*"), path(json_report_files, stageAs: "reports/*")

    output:
    tuple val(meta), path("collapse/*.parquet", arity: 1),    emit: parquet
    tuple val(meta), path("collapse/*.report.json"),          emit: report_json
    tuple val(meta), path("collapse/*.meta.json"),            emit: metadata_json
    tuple val(meta), path("*pixelator-combine-collapse.log"), emit: log

    tuple val("${task.process}"), val('pixelator'), eval("pixelator --version 2>/dev/null | sed 's/pixelator, version //g'"), emit: versions_pixelator, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // --design is passed in meta and added to args through modules.conf
    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def parquet_args = parquet_files.join(' --parquet ')
    def report_args = json_report_files.join(' --report ')
    def memory_factor = 0.75

    // The memory limit here needs to keep some buffer. This limit is used in DuckDB but it is not a hard limit.
    // Setting it too close to the actual RAM available may cause to not spill to disk soon enough and run out of memory.
    """
    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-combine-collapse.log \\
        --verbose \\
        single-cell-pna \\
        combine-collapse \\
        --output . \\
        --memory ${Math.ceil(task.memory.toMega() * memory_factor).intValue()}M \\
        ${args} \\
        --parquet ${parquet_args} \\
        --report ${report_args}
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir collapse
    touch collapse/${prefix}.collapse.parquet
    touch collapse/${prefix}.collapse.meta.json
    touch collapse/${prefix}.report.json
    touch ${prefix}.pixelator-combine-collapse.log
    """
}
