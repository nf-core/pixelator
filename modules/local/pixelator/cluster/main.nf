

process PIXELATOR_CLUSTER {
    tag "$meta.id"
    label 'process_high'

    conda (params.enable_conda ? "local::pixelator=0.5.0" : null)

    container 'ghcr.io/pixelgentechnologies/pixelator:0.5.0'

    input:
    tuple val(meta), path(edge_list), path(antibody_panel)

    output:
    tuple val(meta), path("cluster/*anndata.h5ad"),             emit: h5ad
    tuple val(meta), path("cluster/*pixel_data.csv"),           emit: pixel_data
    tuple val(meta), path("cluster/*.report.json"),             emit: report_json
    tuple val(meta), path("cluster/*.csv"),                     emit: csv
    tuple val(meta), path("cluster/*.png"),                     emit: png
    tuple val(meta), path("*pixelator-cluster.log"),            emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-cluster.log \\
        --verbose \\
        cluster \\
        --output . \\
        --panel-file $antibody_panel \\
        $args \\
        ${edge_list}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
