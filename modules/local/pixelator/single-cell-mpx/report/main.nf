process PIXELATOR_REPORT {
    tag "${meta.id}"
    label 'process_low'

    // TODO: Add conda back
    // conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.23.0'
        : 'quay.io/pixelgen-technologies/pixelator:0.23.0'}"

    input:
    tuple val(meta), path(panel_file), val(panel)
    path amplicon_data,  stageAs: "results/amplicon/*"
    path preqc_data,     stageAs: "results/preqc/*"
    path adapterqc_data, stageAs: "results/adapterqc/*"
    path demux_data,     stageAs: "results/demux/*"
    path collapse_data,  stageAs: "results/collapse/*"
    path graph_data,     stageAs: "results/graph/*"
    path annotate_data,  stageAs: "results/annotate/*"
    path analysis_data,  stageAs: "results/analysis/*"
    path layout_data,    stageAs: "results/layout/*"

    output:
    tuple val(meta), path("report/*.html"),    emit: reports
    tuple val(meta), path("*pixelator-*.log"), emit: log
    tuple val("${task.process}"), val('pixelator'), eval("pixelator --version 2>/dev/null | sed 's/pixelator, version //g'"), emit: versions_pixelator, topic: versions

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
        single-cell-mpx \\
        report \\
        --output . \\
        ${panelOpt} \\
        ${args} \\
        results
    """

    stub:

    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir report
    touch "${prefix}.pixelator-report.log"
    touch "report/${prefix}.html"
    """
}
