

process PIXELATOR_COLLAPSE {
    tag "$meta.id"
    label 'process_medium'


    conda (params.enable_conda ? "local::pixelator=0.6.2" : null)

    container 'ghcr.io/pixelgentechnologies/pixelator:0.6.2'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("collapse/*.collapsed.csv"),        emit: collapsed
    tuple val(meta), path("collapse/*.report.json"),          emit: report_json
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
        --verbose \\
        collapse \\
        --samples "${meta.id}" \\
        --output . \\
        --design ${meta.design} \\
        $args \\
        ${readsArg}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
