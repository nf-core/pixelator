process PIXELATOR_LAYOUT {
    tag "$meta.id"
    label 'process_medium'


    conda "bioconda::pixelator=0.17.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pixelator:0.17.1--pyhdfd78af_0' :
        'biocontainers/pixelator:0.17.1--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(data)

    output:
    tuple val(meta), path("layout/*dataset.pxl")  , emit: dataset
    tuple val(meta), path("layout/*report.json")  , emit: report_json
    tuple val(meta), path("layout/*.meta.json")   , emit: metadata
    tuple val(meta), path("layout/*")             , emit: all_results
    tuple val(meta), path("*pixelator-layout.log"), emit: log

    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-layout.log \\
        --verbose \\
        single-cell \\
        layout \\
        --output . \\
        $args \\
        $data

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
