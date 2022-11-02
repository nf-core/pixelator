

process PIXELATOR_DEMUX {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "local::pixelator=0.2.3" : null)

    container 'ghcr.io/pixelgentechnologies/pixelator:0.2.3'

    input:
    tuple val(meta), path(reads), path(antibody_panel)

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
        --panel-file ${antibody_panel} \\
        --design ${meta.design} \\
        $args \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
