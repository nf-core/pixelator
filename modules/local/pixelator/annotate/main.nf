
process PIXELATOR_ANNOTATE {
    tag "$meta.id"
    label 'process_medium'

    conda "local::pixelator=0.10.0"
    container "ghcr.io/pixelgentechnologies/pixelator:0.10.0"

    input:
    tuple val(meta), path(dataset), path(panel)

    output:
    tuple val(meta), path("annotate/*.dataset.pxl"),             emit: dataset
    tuple val(meta), path("annotate/*.report.json"),             emit: report_json
    tuple val(meta), path("annotate/*.png"),                     emit: png
    tuple val(meta), path("annotate/*.meta.json"),               emit: metadata
    tuple val(meta), path("annotate/*"),                         emit: all_results
    tuple val(meta), path("*pixelator-annotate.log"),            emit: log


    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-annotate.log \\
        --verbose \\
        single-cell \\
        annotate \\
        --output . \\
        $args \\
        $dataset \\
        --panel-file $panel

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
