process PIXELATOR_REPORT {
    tag "$meta.id"
    label 'process_low'


    conda "bioconda::pixelator=0.13.1"
    container "biocontainers/pixelator:0.13.1--pyh7cba7a3_0"

    input:
    tuple val(meta), path(panel_file), val(panel)
    path amplicon_data      , stageAs: "results/amplicon/*"
    path preqc_data         , stageAs: "results/preqc/*"
    path adapterqc_data     , stageAs: "results/adapterqc/*"
    path demux_data         , stageAs: "results/demux/*"
    path collapse_data      , stageAs: "results/collapse/*"
    path graph_data         , stageAs: "results/graph/*"
    path annotate_data      , stageAs: "results/annotate/*"
    path analysis_data      , stageAs: "results/analysis/*"

    output:
    path "report/*.html", emit: reports
    path "versions.yml",  emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def panelOpt = (
        panel      ? "--panel $panel"      :
        panel_file ? "--panel $panel_file" :
        ""
    )

    """
    pixelator \\
        single-cell \\
        report \\
        --output . \\
        $panelOpt \\
        $args \\
        results

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
