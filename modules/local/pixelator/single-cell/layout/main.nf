process PIXELATOR_LAYOUT {
    tag "$meta.id"
    label 'process_medium'

    conda "modules/local/pixelator/single-cell/layout/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pixelator:0.19.0--pyhdfd78af_0' :
        'biocontainers/pixelator:0.19.0--pyhdfd78af_0' }"

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

    def prefix = task.ext.prefix ?: "${meta.id}"
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

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir layout
    touch "${prefix}.pixelator-layout.log"
    touch "layout/${prefix}.layout.dataset.pxl"
    touch "layout/${prefix}.report.json"
    touch "layout/${prefix}.meta.json"

    cat <<-END_VERSIONS > versions.yml
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
