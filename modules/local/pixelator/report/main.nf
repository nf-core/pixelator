

process PIXELATOR_REPORT {
    tag "$meta.id"
    label 'process_low'

    conda "local::pixelator=${pixelator_tag}"

    container "ghcr.io/pixelgentechnologies/pixelator:0.10.0"

    input:
    val meta
    path preqc_report_json,             stageAs: "results/preqc/*"
    path adapterqc_report_json,         stageAs: "results/adapterqc/*"
    path demux_report_json,             stageAs: "results/demux/*"
    path collapse_report_json,          stageAs: "results/collapse/*"
    path cluster_data,                  stageAs: "results/cluster/*"
    path annotate_report_json,          stageAs: "results/annotate/*"
    path analysis_report_json,          stageAs: "results/analysis/*"

    output:
    path "reports/report/*.html",                                           emit: reports
    path "reports/report/*.csv",                                            emit: data
    path "versions.yml",                                                    emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def samples = meta.samples.join(',')

    """
    pixelator \\
        report \\
        --output reports \\
        --name "${meta.id}" \\
        $args \\
        results

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
