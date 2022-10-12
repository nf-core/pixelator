// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process PIXELATOR_DEMUX {
    tag "$meta.id"
    label 'process_low'

    // TODO: Enable conda support
    // conda (params.enable_conda ? "YOUR-TOOL-HERE" : null)
    container 'ghcr.io/pixelgentechnologies/pixelator:0.2.3'

    input:
    tuple val(meta), path(reads), path(barcodes)

    output:
    tuple val(meta), path("demux/*processed*.fastq.gz"),    emit: processed
    tuple val(meta), path("demux/*failed.fastq.gz"),        emit: failed
    tuple val(meta), path("demux/*.report.json"),           emit: report_json
    tuple val(meta), path("demux"),                         emit: results_dir
    tuple val(meta), path("*pixelator-demux.log"),          emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design != null

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-demux.log \\
        demux \\
        --output . \\
        --design ${meta.design} \\
        --barcodes ${barcodes} \\
        $args \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
