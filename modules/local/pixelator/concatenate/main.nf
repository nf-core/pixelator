

process PIXELATOR_CONCATENATE {
    tag "$meta.id"
    label 'process_medium'


    conda (params.enable_conda ? "local::pixelator=0.4.0" : null)

    container 'ghcr.io/pixelgentechnologies/pixelator:0.4.0'

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
        --verbose \\
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
