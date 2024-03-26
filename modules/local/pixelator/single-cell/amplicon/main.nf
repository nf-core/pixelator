process PIXELATOR_AMPLICON {
    tag "$meta.id"
    label 'process_low'


    conda "bioconda::pixelator=0.16.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pixelator:0.16.2--pyhdfd78af_0' :
        'biocontainers/pixelator:0.16.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("amplicon/*.merged.{fq,fastq}.gz"), emit: merged
    tuple val(meta), path("amplicon/*.report.json")         , emit: report_json
    tuple val(meta), path("amplicon/*.meta.json")           , emit: metadata
    tuple val(meta), path("*pixelator-amplicon.log")        , emit: log

    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-amplicon.log \\
        --verbose \\
        single-cell \\
        amplicon \\
        --output . \\
        $args \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
