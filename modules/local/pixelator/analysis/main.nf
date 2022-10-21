
process PIXELATOR_ANALYSIS {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "local::pixelator=0.2.3" : null)
    container 'ghcr.io/pixelgentechnologies/pixelator:0.2.3'

    input:
    tuple val(meta), path("cluster-results??")

    output:
    tuple val(meta), path("analysis/$meta.id/*"),        emit: results
    tuple val(meta), path("analysis/$meta.id"),          emit: results_dir
    tuple val(meta), path("*pixelator-analysis.log"),    emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    mkdir -p "cluster/$meta.id"
    cp -r cluster-results*/* "cluster/$meta.id"

    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-analysis.log \\
        analysis \\
        --output . \\
        $args \\
        .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
