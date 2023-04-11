

process PIXELATOR_CLUSTER {
    tag "$meta.id"
    label 'process_medium'

    conda "local::pixelator=${pixelator_tag}"

    container "ghcr.io/pixelgentechnologies/pixelator:0.9.0"

    input:
    tuple val(meta), path(edge_list)

    output:
    tuple val(meta), path("cluster/*.edgelist.csv.gz"),             emit: edgelist
    tuple val(meta), path("cluster/*.raw_edgelist.csv.gz"),         emit: raw_edgelist
    tuple val(meta), path("cluster/*.components_recovered.csv"),    emit: components_recovered, optional: true
    tuple val(meta), path("cluster/*.report.json"),                 emit: report_json
    tuple val(meta), path("cluster/*"),                             emit: all_results
    tuple val(meta), path("*pixelator-cluster.log"),                emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-cluster.log \\
        --verbose \\
        cluster \\
        --output . \\
        $args \\
        ${edge_list}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
