// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process PIXELATOR_REPORT {
    tag "$meta.id"
    label 'process_low'

    // TODO: Enable conda support
    // conda (params.enable_conda ? "YOUR-TOOL-HERE" : null)

    // TODO: make pixelator available on galaxyproject and quay.io support
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
    //     'quay.io/biocontainers/YOUR-TOOL-HERE' }"
    container "pixelator:0.2.2"

    input:
    val meta
    path "staged-concatenate??"
    path "staged-preqc??"
    path "staged-adapterqc??"
    path "staged-demux??"
    path "staged-collapse??"
    path "cluster/*"

    output:
    path("reports/report/report.html"),            emit: report
    path("reports/report/summary_stats.html"),     emit: summary_stats
    path("reports/report/antibody_counts.html"),   emit: antibody_counts
    path("reports/report/clusters_dist.html"),     emit: clusters_dist
    path "versions.yml",                       emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def samples = meta.samples.join('.')

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
