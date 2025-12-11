process PIXELATOR_PNA_LAYOUT {
    tag "${meta.id}"
    label 'process_high'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.22.1'
        : 'quay.io/pixelgen-technologies/pixelator:0.22.1'}"

    input:
    tuple val(meta), path(data)

    output:
    tuple val(meta), path("layout/*.pxl"),         emit: pixelfile
    tuple val(meta), path("layout/*.report.json"), emit: report_json
    tuple val(meta), path("layout/*.meta.json"),   emit: metadata_json
    tuple val(meta), path("layout/*"),             emit: all_results

    tuple val(meta), path("*pixelator-layout.log"), emit: log

    tuple val("${task.process}"), val('pixelator'), eval("pixelator --version 2>/dev/null | sed 's/pixelator, version //g'"), emit: versions_pixelator, topic: versions

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
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir layout
    touch layout/${prefix}.report.json
    touch layout/${prefix}.meta.json
    touch layout/${prefix}.pxl
    touch ${prefix}.pixelator-layout.log
    """
}
