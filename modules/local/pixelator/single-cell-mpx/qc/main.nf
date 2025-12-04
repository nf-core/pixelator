process PIXELATOR_QC {
    tag "${meta.id}"
    label 'process_medium'

    // TODO: Add conda back
    // conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.23.0'
        : 'quay.io/pixelgen-technologies/pixelator:0.23.0'}"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("adapterqc/*.processed.{fq,fastq}.gz"),      emit: processed

    tuple val(meta), path("adapterqc/*.processed.{fq,fastq}.gz"),      emit: adapterqc_processed
    tuple val(meta), path("preqc/*.processed.{fq,fastq}.gz"),          emit: preqc_processed

    tuple val(meta), path("adapterqc/*.failed.{fq,fastq}.gz"),         emit: adapterqc_failed
    tuple val(meta), path("preqc/*.failed.{fq,fastq}.gz"),             emit: preqc_failed
    tuple val(meta), path("{adapterqc,preqc}/*.failed.{fq,fastq}.gz"), emit: failed

    tuple val(meta), path("adapterqc/*.report.json"),                  emit: adapterqc_report_json
    tuple val(meta), path("preqc/*.report.json"),                      emit: preqc_report_json
    tuple val(meta), path("{adapterqc,preqc}/*.report.json"),          emit: report_json

    tuple val(meta), path("preqc/*.qc-report.html"),                   emit: preqc_report_html

    tuple val(meta), path("adapterqc/*.meta.json"),                    emit: adapterqc_metadata
    tuple val(meta), path("preqc/*.meta.json"),                        emit: preqc_metadata
    tuple val(meta), path("{adapterqc,preqc}/*.meta.json"),            emit: metadata

    tuple val(meta), path("*pixelator-preqc.log"),                     emit: preqc_log
    tuple val(meta), path("*pixelator-adapterqc.log"),                 emit: adapterqc_log
    tuple val(meta), path("*pixelator-*.log"),                         emit: log

    path "versions.yml",                                               emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design

    def prefix = task.ext.prefix ?: "${meta.id}"
    def preqc_args = task.ext.args ?: ''
    def adapterqc_args = task.ext.args2 ?: ''

    // --design is passed in meta and added to args and args2 through modules.conf
    """
    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-preqc.log \\
        --verbose \\
        single-cell-mpx \\
        preqc \\
        --output . \\
        ${preqc_args} \\
        ${reads}

    shopt -s nullglob
    preqc_results=( preqc/*.processed.* )
    echo \${preqc_results[@]}
    shopt -u nullglob # Turn off nullglob to make sure it doesn't interfere with anything later

    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-adapterqc.log \\
        --verbose \\
        single-cell-mpx \\
        adapterqc \\
        --output . \\
        ${adapterqc_args} \\
        \${preqc_results[@]}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir preqc
    echo "" | gzip >> "preqc/${prefix}.processed.fq.gz"
    echo "" | gzip >> "preqc/${prefix}.failed.fq.gz"
    touch "preqc/${prefix}.report.json"
    touch "preqc/${prefix}.meta.json"
    touch "preqc/${prefix}.qc-report.html"
    touch "${prefix}.pixelator-preqc.log"

    mkdir adapterqc
    echo "" | gzip >> "adapterqc/${prefix}.processed.fq.gz"
    echo "" | gzip >> "adapterqc/${prefix}.failed.fq.gz"
    touch "adapterqc/${prefix}.report.json"
    touch "adapterqc/${prefix}.meta.json"
    touch "${prefix}.pixelator-adapterqc.log"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
