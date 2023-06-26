

process PIXELATOR_REPORT {
    tag "$meta.id"
    label 'process_low'

    conda "local::pixelator=0.10.0"

    container "ghcr.io/pixelgentechnologies/pixelator:0.12.0"

    input:
    val meta
    path panel_file
    path concatenate_data,       stageAs: "results/concatenate/*"
    path preqc_data,             stageAs: "results/preqc/*"
    path adapterqc_data,         stageAs: "results/adapterqc/*"
    path demux_data,             stageAs: "results/demux/*"
    path collapse_data,          stageAs: "results/collapse/*"
    path graph_data,             stageAs: "results/graph/*"
    path annotate_data,          stageAs: "results/annotate/*"
    path analysis_data,          stageAs: "results/analysis/*"

    output:
    path "report/*.html",        emit: reports
    path "versions.yml",         emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    pixelator \\
        single-cell \\
        report \\
        --output . \\
        --panel-file ${panel_file} \\
        $args \\
        results

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
