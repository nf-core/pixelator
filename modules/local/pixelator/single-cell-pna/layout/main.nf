process PIXELATOR_PNA_LAYOUT {
    tag "${meta.id}"
    label 'process_high'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.21.4'
        : 'quay.io/pixelgen-technologies/pixelator:0.21.4'}"

    input:
    tuple val(meta), path(data)

    output:
    tuple val(meta), path("layout/*.pxl"),         emit: pixelfile
    tuple val(meta), path("layout/*.report.json"), emit: report_json
    tuple val(meta), path("layout/*.meta.json"),   emit: metadata_json
    tuple val(meta), path("layout/*"),             emit: all_results

    tuple val(meta), path("*pixelator-layout.log"), emit: log

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-layout.log \\
        --verbose \\
        single-cell-pna \\
        layout \\
        --output . \\
        ${args} \\
        ${data}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir layout
    touch layout/${prefix}.report.json
    touch layout/${prefix}.meta.json
    touch layout/${prefix}.pxl
    touch ${prefix}.pixelator-layout.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
