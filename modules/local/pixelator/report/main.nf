

process PIXELATOR_REPORT {
    tag "$meta.id"
    label 'process_low'

    conda "local::pixelator=0.6.3"

    container 'ghcr.io/pixelgentechnologies/pixelator:0.6.3'

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
    path("reports/report/report.html"),                                     emit: report
    path("reports/report/summary_histograms_raw.html"),                     emit: summary_histograms_raw
    path("reports/report/summary_histograms_filtered.html"),                emit: summary_histograms_filtered
    path("reports/report/antibody_counts_barplot_log_filtered.html"),       emit: antibody_counts_barplot_log_filtered
    path("reports/report/antibody_counts_barplot_log_raw.html"),            emit: antibody_counts_barplot_raw_filtered
    path("reports/report/antibody_counts_barplot_rel_filtered.html"),       emit: antibody_counts_barplot_rel_filtered
    path("reports/report/antibody_counts_barplot_rel_raw.html"),            emit: antibody_counts_barplot_rel_raw
    path("reports/report/cluster_size_dist_raw.html"),                      emit: clusters_size_dist_raw
    path("reports/report/cluster_size_dist_filtered.html"),                 emit: clusters_size_dist_filtered
    path("reports/report/*.csv"),                                           emit: data
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
