process PIXELATOR_REPORT {
    tag "$meta.id"
    label 'process_low'


    conda "bioconda::pixelator=0.16.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pixelator:0.16.2--pyhdfd78af_0' :
        'biocontainers/pixelator:0.16.2--pyhdfd78af_0' }"

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
    path "report/*.html"        , emit: reports
    path "versions.yml"         , emit: versions
    path "*pixelator-*.log"     , emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def panelOpt = (
        panel      ? "--panel $panel"      :
        panel_file ? "--panel $panel_file" :
        ""
    )

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-report.log \\
        --verbose \\
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
