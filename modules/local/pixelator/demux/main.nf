

process PIXELATOR_DEMUX {
    tag "$meta.id"
    label 'process_medium'

    conda "local::pixelator=0.10.0"

    container "ghcr.io/pixelgentechnologies/pixelator:0.10.0"

    input:
    tuple val(meta), path(reads), path(antibody_panel)

    output:
    tuple val(meta), path("demux/*processed*.{fq,fastq}.gz"), emit: processed
    tuple val(meta), path("demux/*failed.{fq,fastq}.gz"),     emit: failed
    tuple val(meta), path("demux/*.report.json"),             emit: report_json
    tuple val(meta), path("demux"),                           emit: results_dir
    tuple val(meta), path("*pixelator-demux.log"),            emit: log

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
        --verbose \\
        single-cell \\
        demux \\
        --output . \\
        --panel-file ${antibody_panel} \\
        --design ${meta.design} \\
        $args \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
