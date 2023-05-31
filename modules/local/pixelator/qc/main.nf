

process PIXELATOR_QC {
    tag "$meta.id"
    label 'process_medium'
    conda "local::pixelator=0.10.0"

    // TODO: make pixelator available on galaxyproject and quay.io support
    container "ghcr.io/pixelgentechnologies/pixelator:0.10.0"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("preqc/*.processed.{fq,fastq}.gz"),           emit: processed

    tuple val(meta), path("adapterqc/*.processed.{fq,fastq}.gz"),       emit: adapterqc_processed
    tuple val(meta), path("preqc/*.processed.{fq,fastq}.gz"),           emit: preqc_processed

    tuple val(meta), path("adapterqc/*.failed.{fq,fastq}.gz"),          emit: adapterqc_failed
    tuple val(meta), path("preqc/*.failed.{fq,fastq}.gz"),              emit: preqc_failed
    tuple val(meta), path("{adapterqc,preqc}/*.failed.{fq,fastq}.gz"),  emit: failed

    tuple val(meta), path("adapterqc/*.report.json"),                   emit: adapterqc_report_json
    tuple val(meta), path("preqc/*.report.json"),                       emit: preqc_report_json
    tuple val(meta), path("{adapterqc,preqc}/*.report.json"),           emit: report_json

    tuple val(meta), path("adapterqc/*.meta.json"),                     emit: adapterqc_input_params
    tuple val(meta), path("preqc/*.meta.json"),                         emit: preqc_input_params
    tuple val(meta), path("{adapterqc,preqc}/*.meta.json"),             emit: input_params

    tuple val(meta), path("*pixelator-qc.log"),                         emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design

    prefix = task.ext.prefix ?: "${meta.id}"
    def preqc_args = task.ext.args ?: ''
    def adapterqc_args = task.ext.args2 ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-qc.log \\
        --verbose \\
        single-cell \\
        preqc \\
        --output . \\
        --design ${meta.design} \\
        ${preqc_args} \\
        ${reads}

    shopt -s nullglob
    preqc_results=( preqc/*.processed.* )
    echo \${preqc_results[@]}
    shopt -u nullglob # Turn off nullglob to make sure it doesn't interfere with anything later

    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-qc.log \\
        --verbose \\
        single-cell \\
        adapterqc \\
        --output . \\
        --design ${meta.design} \\
        ${adapterqc_args} \\
        \${preqc_results[@]}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
