

process PIXELATOR_CONCATENATE {
    tag "$meta.id"
    label 'process_medium'


    conda "local::pixelator=0.10.0"

    container "ghcr.io/pixelgentechnologies/pixelator:0.11.0"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("concatenate/*.merged.{fq,fastq}.gz"),  emit: merged
    tuple val(meta), path("concatenate/*.report.json"),           emit: report_json
    tuple val(meta), path("concatenate/*.meta.json"),             emit: metadata
    tuple val(meta), path("*pixelator-concatenate.log"),          emit: log

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-concatenate.log \\
        --verbose \\
        single-cell \\
        concatenate \\
        --output . \\
        $args \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
