process PIXELATOR_PNA_REPORT {
    tag "${meta.id}"
    label 'process_low'


    conda "bioconda::pixelator=0.18.2"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'ghcr.io/pixelgentechnologies/pixelator:0.20.1'
        : 'ghcr.io/pixelgentechnologies/pixelator:0.20.1'}"

    input:
    tuple val(meta), path(panel_file), val(panel)
    path amplicon_data, stageAs: "results/amplicon/*"
    path demux_data,    stageAs: "results/demux/*"
    path collapse_data, stageAs: "results/collapse/*"
    path graph_data,    stageAs: "results/graph/*"
    path analysis_data, stageAs: "results/analysis/*"
    path post_analysis_data, stageAs: "results/post_analysis/*"
    path layout_data, stageAs: "results/layout/*"

    output:
    tuple val(meta), path("report/*.html"), emit: report
    tuple val(meta), path("*pixelator-*.log"), emit: log

    path "versions.yml", emit: versions

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
    touch versions.yml
    """
}
