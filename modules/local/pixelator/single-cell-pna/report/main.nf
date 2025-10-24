process PIXELATOR_PNA_REPORT {
    tag "${meta.id}"
    label 'process_low'


    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.22.0'
        : 'quay.io/pixelgen-technologies/pixelator:0.22.0'}"

    input:
    tuple (
        val(meta),
        path(panel_file),
        val(panel),
        path(amplicon_data, stageAs: "results/amplicon/*"),
        path(demux_data, stageAs: "results/demux/*"),
        path(collapse_data, stageAs: "results/collapse/*"),
        path(graph_data, stageAs: "results/graph/*"),
        path(denoise_data, stageAs: "results/denoise/*"),
        path(analysis_data, stageAs: "results/analysis/*"),
        path(layout_data, stageAs: "results/layout/*")
    )

    output:
    tuple val(meta), path("report/*.html"),    emit: report
    tuple val(meta), path("*pixelator-*.log"), emit: log

    path "versions.yml",                       emit: versions

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
        --log-file ${prefix}.pixelator-report.log \\
        --verbose \\
        single-cell-pna \\
        report \\
        --output . \\
        ${panelOpt} \\
        ${args} \\
        results

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir report
    touch report/${prefix}.report.html
    touch ${prefix}.pixelator-report.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
