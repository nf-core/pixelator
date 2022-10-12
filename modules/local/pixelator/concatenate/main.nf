// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process PIXELATOR_CONCATENATE {
    tag "$meta.id"
    label 'process_low'

    // TODO: Enable conda support
    // conda (params.enable_conda ? "YOUR-TOOL-HERE" : null)
    container 'ghcr.io/pixelgentechnologies/pixelator:0.2.3'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("concatenate/*.merged.fastq.gz"),       emit: merged
    tuple val(meta), path("concatenate"),                         emit: results_dir
    tuple val(meta), path("*pixelator-concatenate.log"),          emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    if ( meta.single_end && meta.single_end == true ) {
        exit 1, "pixelator concatenate requires paired-end input"
    }

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-concatenate.log \\
        concatenate \\
        --output . \\
        $args \\
        ${reads[0]} \\
        ${reads[1]}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>&1) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
