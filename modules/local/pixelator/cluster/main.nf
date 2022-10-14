// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process PIXELATOR_CLUSTER {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "local::pixelator=0.2.3" : null)

    container 'ghcr.io/pixelgentechnologies/pixelator:0.2.3'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("cluster/$meta.id/*"),         emit: results
    tuple val(meta), path("cluster/$meta.id"),           emit: results_dir
    tuple val(meta), path("*pixelator-cluster.log"),     emit: log

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
        cluster \\
        --output . \\
        $args \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
