process PIXELATOR_ANNOTATE {
    tag "${meta.id}"
    label 'process_high'

    // TODO: Add conda back
    // conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.22.0'
        : 'quay.io/pixelgen-technologies/pixelator:0.22.0'}"

    input:
    tuple val(meta), path(dataset), path(panel_file), val(panel)

    output:
    tuple val(meta), path("annotate/*.dataset.pxl"),  emit: dataset
    tuple val(meta), path("annotate/*.report.json"),  emit: report_json
    tuple val(meta), path("annotate/*.meta.json"),    emit: metadata
    tuple val(meta), path("annotate/*"),              emit: all_results
    tuple val(meta), path("*pixelator-annotate.log"), emit: log

    path "versions.yml",                              emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def panelOpt = (panel
        ? "--panel ${panel}"
        : panel_file
            ? "--panel ${panel_file}"
            : "")

    """
    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-annotate.log \\
        --verbose \\
        single-cell-mpx \\
        annotate \\
        --output . \\
        ${panelOpt} \\
        ${args} \\
        ${dataset} \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir annotate
    touch "${prefix}.pixelator-annotate.log"
    touch "annotate/${prefix}.dataset.pxl"
    touch "annotate/${prefix}.report.json"
    touch "annotate/${prefix}.meta.json"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
