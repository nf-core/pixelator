

process PIXELATOR_PREQC {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "local::pixelator=0.4.0" : null)

    container 'ghcr.io/pixelgentechnologies/pixelator:0.4.0'

    input:
    tuple val(meta), path(reads)

    output:

    tuple val(meta), path("preqc/*.processed.fastq.gz"),   emit: processed
    tuple val(meta), path("preqc/*.failed.fastq.gz"),      emit: failed
    tuple val(meta), path("preqc/*.report.html"),          emit: report_html
    tuple val(meta), path("preqc/*.report.json"),          emit: report_json
    tuple val(meta), path("preqc"),                        emit: results_dir
    tuple val(meta), path("*pixelator-preqc.log"),         emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-preqc.log \\
        --verbose \\
        preqc \\
        --output . \\
        --design ${meta.design} \\
        ${args} \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
