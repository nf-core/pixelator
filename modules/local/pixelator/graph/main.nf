

process PIXELATOR_GRAPH {
    tag "$meta.id"
    label 'process_medium'

    conda "local::pixelator=0.10.0"

    container "ghcr.io/pixelgentechnologies/pixelator:0.10.0"

    input:
    tuple val(meta), path(edge_list)

    output:
    tuple val(meta), path("graph/*.edgelist.csv.gz"),             emit: edgelist
    tuple val(meta), path("graph/*.raw_edgelist.csv.gz"),         emit: raw_edgelist
    tuple val(meta), path("graph/*.components_recovered.csv"),    emit: components_recovered, optional: true
    tuple val(meta), path("graph/*.report.json"),                 emit: report_json
    tuple val(meta), path("graph/*.meta.json"),                   emit: input_params
    tuple val(meta), path("graph/*"),                             emit: all_results
    tuple val(meta), path("*pixelator-graph.log"),                emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-graph.log \\
        --verbose \\
        single-cell \\
        graph \\
        --output . \\
        $args \\
        ${edge_list}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
