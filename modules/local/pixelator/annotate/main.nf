
process PIXELATOR_ANNOTATE {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "local::pixelator=0.3.0" : null)
    container 'ghcr.io/pixelgentechnologies/pixelator:0.3.0'

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("annotate/*filtered_anndata.h5ad"),    emit: h5ad
    tuple val(meta), path("annotate"),                           emit: results_dir
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
