process PIXELATOR_GRAPH {
    tag "${meta.id}"
    label 'process_high'

    // TODO: Add conda back
    // conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.21.4'
        : 'quay.io/pixelgen-technologies/pixelator:0.21.4'}"

    input:
    tuple val(meta), path(edge_list)

    output:
    tuple val(meta), path("graph/*.edgelist.parquet"), emit: edgelist
    tuple val(meta), path("graph/*.report.json"),      emit: report_json
    tuple val(meta), path("graph/*.meta.json"),        emit: metadata
    tuple val(meta), path("graph/*"),                  emit: all_results
    tuple val(meta), path("*pixelator-graph.log"),     emit: log

    path "versions.yml",                               emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-graph.log \\
        --verbose \\
        single-cell-mpx \\
        graph \\
        --output . \\
        ${args} \\
        ${edge_list}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir graph
    touch "${prefix}.pixelator-graph.log"
    touch "graph/${prefix}.edgelist.parquet"
    touch "graph/${prefix}.report.json"
    touch "graph/${prefix}.meta.json"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
