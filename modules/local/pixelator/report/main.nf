

process PIXELATOR_REPORT {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "local::pixelator=0.2.3" : null)

    container 'ghcr.io/pixelgentechnologies/pixelator:0.2.3'

    input:
    val meta
    path "staged-concatenate??"
    path "staged-preqc??"
    path "staged-adapterqc??"
    path "staged-demux??"
    path "staged-collapse??"
    path "cluster/*"
    path "analysis/*"

    output:
    path("reports/report/report.html"),                     emit: report
    path("reports/report/summary_histograms.html"),         emit: summary_histograms
    path("reports/report/antibody_counts_barplot.html"),    emit: antibody_counts_barplot
    path("reports/report/antibody_counts_histogram.html"),  emit: antibody_counts_histogram
    path("reports/report/cluster_size_dist.html"),          emit: clusters_size_dist
    path("reports/report/*.csv"),                           emit: data
    path "versions.yml",                                    emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def samples = meta.samples.join(',')

    """
    mkdir results

    mkdir results/concatenate
    cp -r staged-concatenate*/* results/concatenate

    mkdir results/preqc
    cp -r staged-preqc*/* results/preqc

    mkdir results/adapterqc
    cp -r staged-adapterqc*/* results/adapterqc/

    mkdir results/demux
    cp -r staged-demux*/* results/demux

    mkdir results/collapse
    cp -r staged-collapse*/* results/collapse/

    cp -r cluster results/cluster

    cp -r analysis results/analysis

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
