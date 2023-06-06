
process PIXELATOR_ANALYSIS {
    tag "$meta.id"
    label 'process_medium'

    conda "local::pixelator=0.10.0"
    container "ghcr.io/pixelgentechnologies/pixelator:0.10.0"

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("analysis/*dataset.pxl"),      emit: dataset
    tuple val(meta), path("analysis/*report.json"),      emit: report_json
    tuple val(meta), path("analysis/*.meta.json"),       emit: metadata
    tuple val(meta), path("analysis/*"),                 emit: all_results
    tuple val(meta), path("*pixelator-analysis.log"),    emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-analysis.log \\
        --verbose \\
        single-cell \\
        analysis \\
        --output . \\
        $args \\
        $h5ad

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
