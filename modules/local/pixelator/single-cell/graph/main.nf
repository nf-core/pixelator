process PIXELATOR_GRAPH {
    tag "$meta.id"
    label 'process_medium'


    conda "bioconda::pixelator=0.16.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pixelator:0.16.2--pyhdfd78af_0' :
        'biocontainers/pixelator:0.16.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(edge_list)

    output:
    tuple val(meta), path("graph/*.edgelist.parquet")         , emit: edgelist
    tuple val(meta), path("graph/*.components_recovered.csv"), emit: components_recovered, optional: true
    tuple val(meta), path("graph/*.report.json")             , emit: report_json
    tuple val(meta), path("graph/*.meta.json")               , emit: input_params
    tuple val(meta), path("graph/*")                         , emit: all_results
    tuple val(meta), path("*pixelator-graph.log")            , emit: log

    path "versions.yml"                                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-graph.log \\
        --verbose \\
        single-cell \\
        graph \\
        --output . \\
        $args \\
        ${edge_list}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
