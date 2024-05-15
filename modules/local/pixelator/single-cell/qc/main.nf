process PIXELATOR_QC {
    tag "$meta.id"
    label 'process_medium'


    conda "bioconda::pixelator=0.16.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pixelator:0.16.2--pyhdfd78af_0' :
        'biocontainers/pixelator:0.16.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("adapterqc/*.processed.{fq,fastq}.gz")     , emit: processed

    tuple val(meta), path("adapterqc/*.processed.{fq,fastq}.gz")     , emit: adapterqc_processed
    tuple val(meta), path("preqc/*.processed.{fq,fastq}.gz")         , emit: preqc_processed

    tuple val(meta), path("adapterqc/*.failed.{fq,fastq}.gz")        , emit: adapterqc_failed
    tuple val(meta), path("preqc/*.failed.{fq,fastq}.gz")            , emit: preqc_failed
    tuple val(meta), path("{adapterqc,preqc}/*.failed.{fq,fastq}.gz"), emit: failed

    tuple val(meta), path("adapterqc/*.report.json")                 , emit: adapterqc_report_json
    tuple val(meta), path("preqc/*.report.json")                     , emit: preqc_report_json
    tuple val(meta), path("{adapterqc,preqc}/*.report.json")         , emit: report_json

    tuple val(meta), path("adapterqc/*.meta.json")                   , emit: adapterqc_metadata
    tuple val(meta), path("preqc/*.meta.json")                       , emit: preqc_metadata
    tuple val(meta), path("{adapterqc,preqc}/*.meta.json")           , emit: metadata

    tuple val(meta), path("*pixelator-*.log")                        , emit: log

    path "versions.yml"                                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design

    prefix = task.ext.prefix ?: "${meta.id}"
    def preqc_args = task.ext.args ?: ''
    def adapterqc_args = task.ext.args2 ?: ''

    // --design is passed in meta and added to args and args2 through modules.conf
    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-qc.log \\
        --verbose \\
        single-cell \\
        preqc \\
        --output . \\
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
        ${adapterqc_args} \\
        \${preqc_results[@]}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
