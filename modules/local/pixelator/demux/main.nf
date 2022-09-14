// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process PIXELATOR_DEMUX {
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
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("demux/*processed*.fastq.gz"),    emit: processed
    tuple val(meta), path("demux/*failed.fastq.gz"),        emit: failed
    tuple val(meta), path("demux/*.report.json"),           emit: report_json
    tuple val(meta), path("*pixelator-demux.log"),          emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design != null
    assert meta.barcodes != null

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --threads $task.cpus \\
        --log-file ${prefix}.pixelator-demux.log \\
        demux \\
        --output . \\
        --design ${meta.design} \\
        --barcodes ${meta.barcodes} \\
        $args \\
        ${reads} \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
