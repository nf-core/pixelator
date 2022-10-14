// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process PIXELATOR_COLLAPSE {
    tag "$meta.id"
    label 'process_low'


    conda (params.enable_conda ? "local::pixelator=0.2.3" : null)

    container 'ghcr.io/pixelgentechnologies/pixelator:0.2.3'

    input:
    tuple val(meta), path(reads), path(antibody_panel)

    output:
    tuple val(meta), path("collapse/*.collapsed.csv"),        emit: collapsed
    tuple val(meta), path("collapse/*.report.json"),          emit: report
    tuple val(meta), path("collapse"),                        emit: results_dir
    tuple val(meta), path("*pixelator-collapse.log"),         emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design != null

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def readsArg = reads.join(' ')

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-collapse.log \\
        collapse \\
        --samples "${meta.id}" \\
        --output . \\
        --design ${meta.design} \\
        --panel-file ${antibody_panel} \\
        $args \\
        ${readsArg}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
