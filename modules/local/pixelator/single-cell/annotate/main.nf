process PIXELATOR_ANNOTATE {
    tag "$meta.id"
    label 'process_medium'

    // TODO: Update once pixelator is public in bioconda
    conda "local::pixelator=0.12.0"
    container "ghcr.io/pixelgentechnologies/pixelator:0.12.0"

    input:
    tuple val(meta), path(dataset), path(panel_file)
    val panel

    output:
    tuple val(meta), path("annotate/*.dataset.pxl"),             emit: dataset
    tuple val(meta), path("annotate/*.report.json"),             emit: report_json
    tuple val(meta), path("annotate/*.meta.json"),               emit: metadata
    tuple val(meta), path("annotate/*"),                         emit: all_results
    tuple val(meta), path("*pixelator-annotate.log"),            emit: log


    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def panelOpt = panel ?: panel_file

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
        --panel ${panelOpt}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
