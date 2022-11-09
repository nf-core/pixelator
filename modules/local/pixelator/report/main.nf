

process PIXELATOR_REPORT {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "local::pixelator=0.4.0" : null)

    container 'ghcr.io/pixelgentechnologies/pixelator:0.4.0'

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
    path("reports/report/report.html"),                              emit: report
    path("reports/report/summary_histograms.html"),                  emit: summary_histograms
    path("reports/report/antibody_counts_barplot.html"),             emit: antibody_counts_barplot
    path("reports/report/antibody_counts_barplot_filtered.html"),    emit: antibody_counts_barplot_filtered
    path("reports/report/antibody_counts_histogram.html"),           emit: antibody_counts_histogram
    path("reports/report/antibody_counts_histogram_filtered.html"),  emit: antibody_counts_histogram_filtered
    path("reports/report/cluster_size_dist.html"),                   emit: clusters_size_dist
    path("reports/report/cluster_size_dist_filtered.html"),          emit: clusters_size_dist_filtered
    path("reports/report/*.csv"),                                    emit: data
    path "versions.yml",                                             emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def samples = meta.samples.join(',')

    """
    pixelator \\
        report \\
        --output reports \\
        --samples "${samples}" \\
        --name "${meta.id}" \\
        $args \\
        results

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
