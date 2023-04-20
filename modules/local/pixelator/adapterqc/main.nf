

process PIXELATOR_ADAPTERQC {
    tag "$meta.id"
    label 'process_medium'
    conda "local::pixelator=${pixelator_tag}"

    // TODO: make pixelator available on galaxyproject and quay.io support
    container "ghcr.io/pixelgentechnologies/pixelator:0.10.0"

    input:
    tuple val(meta), path(reads)

    output:

    tuple val(meta), path("adapterqc/*.processed.{fq,fastq}.gz"),   emit: processed
    tuple val(meta), path("adapterqc/*.failed.{fq,fastq}.gz"),      emit: failed
    tuple val(meta), path("adapterqc/*.report.json"),          emit: report_json
    tuple val(meta), path("*pixelator-adapterqc.log"),         emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    mkdir ${prefix}_output
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-adapterqc.log \\
        --verbose \\
        adapterqc \\
        --output . \\
        --design ${meta.design} \\
        ${args} \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
