
process PIXELATOR_ANALYSIS {
    tag "$meta.id"
    label 'process_medium'

    conda "local::pixelator=${pixelator_tag}"
    container "ghcr.io/pixelgentechnologies/pixelator:${pixelator_tag}"

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("analysis/*anndata.h5ad"),     emit: h5ad
    tuple val(meta), path("analysis/*report.json"),      emit: report_json
    tuple val(meta), path("analysis/*.csv"),             emit: csv
    tuple val(meta), path("analysis/*.png"),             emit: png
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
        analysis \\
        --output . \\
        $args \\
        $h5ad

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
