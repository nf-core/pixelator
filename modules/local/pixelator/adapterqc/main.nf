// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process PIXELATOR_ADAPTERQC {
    tag "$meta.id"
    label 'process_medium'

    // TODO: Enable conda support
    // conda (params.enable_conda ? "YOUR-TOOL-HERE" : null)

    // TODO: make pixelator available on galaxyproject and quay.io support
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
    //     'quay.io/biocontainers/YOUR-TOOL-HERE' }"
    container "https://registry.gitlab.com/pixelgen-technologies/pixelator:dev"

    input:
    tuple val(meta), path(reads)

    output:

    tuple val(meta), path("adapterqc/*.processed.fastq.gz"),   emit: processed
    tuple val(meta), path("adapterqc/*.failed.fastq.gz"),      emit: failed
    tuple val(meta), path("adapterqc/*.report.json"),          emit: report_json
    tuple val(meta), path("adapterqc"),                        emit: results_dir
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
        adapterqc \\
        --output . \\
        --design ${meta.design} \\
        ${args} \\
        ${reads} \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
