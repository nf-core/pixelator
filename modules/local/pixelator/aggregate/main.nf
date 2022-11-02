

process PIXELATOR_AGGREGATE {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "local::pixelator=0.2.3" : null)

    // TODO: make pixelator available on galaxyproject and quay.io support
    container 'ghcr.io/pixelgentechnologies/pixelator:0.2.3'

    input:
    tuple val(meta), path(anndata)

    output:


    tuple val(meta), path("aggregate/*anndata.h5ad"),                   emit: h5ad
    tuple val(meta), path("*pixelator-aggregate.log"),           emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-aggregate.log \\
        --verbose \\
        aggregate \\
        --output . \\
        ${anndata}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
