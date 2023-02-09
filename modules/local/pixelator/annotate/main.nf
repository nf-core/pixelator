
process PIXELATOR_ANNOTATE {
    tag "$meta.id"
    label 'process_medium'

    conda "local::pixelator=0.6.3"
    container 'ghcr.io/pixelgentechnologies/pixelator:0.6.3'

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("annotate/*.anndata.h5ad"),            emit: h5ad
    tuple val(meta), path("annotate/*.raw_anndata.h5ad"),        emit: raw_h5ad
    tuple val(meta), path("annotate/*pixel_data.csv"),           emit: pixel_data
    tuple val(meta), path("annotate/*.report.json"),             emit: report_json
    tuple val(meta), path("annotate/*.csv"),                     emit: csv
    tuple val(meta), path("annotate/*.png"),                     emit: png
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
        annotate \\
        --output . \\
        $args \\
        $h5ad

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
