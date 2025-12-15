process PIXELATOR_LAYOUT {
    tag "${meta.id}"
    label 'process_medium'

    // TODO: Add conda back
    // conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.23.0'
        : 'quay.io/pixelgen-technologies/pixelator:0.23.0'}"

    input:
    tuple val(meta), path(data)

    output:
    tuple val(meta), path("layout/*dataset.pxl"),   emit: dataset
    tuple val(meta), path("layout/*report.json"),   emit: report_json
    tuple val(meta), path("layout/*.meta.json"),    emit: metadata
    tuple val(meta), path("layout/*"),              emit: all_results
    tuple val(meta), path("*pixelator-layout.log"), emit: log

    tuple val("${task.process}"), val('pixelator'), eval("pixelator --version 2>/dev/null | sed 's/pixelator, version //g'"), emit: versions_pixelator, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-layout.log \\
        --verbose \\
        single-cell-mpx \\
        layout \\
        --output . \\
        ${args} \\
        ${data}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir layout
    touch "${prefix}.pixelator-layout.log"
    touch "layout/${prefix}.layout.dataset.pxl"
    touch "layout/${prefix}.report.json"
    touch "layout/${prefix}.meta.json"
    """
}
