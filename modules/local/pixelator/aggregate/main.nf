

process PIXELATOR_AGGREGATE {
    tag "$meta.id"
    label 'process_low'

    conda "local::pixelator=0.10.0"

    // TODO: make pixelator available on galaxyproject and quay.io support
    container "ghcr.io/pixelgentechnologies/pixelator:0.10.0"

    input:
    tuple val(meta), path(anndata)

    output:


    tuple val(meta), path("aggregate/*merged_anndata.h5ad"),     emit: h5ad
    tuple val(meta), path("aggregate/*.parameters.json"),        emit: parameters
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
        single-cell \\
        aggregate \\

        --output . \\
        ${anndata}

    mv aggregate/merged_anndata.h5ad aggregate/${prefix}.merged_anndata.h5ad

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
