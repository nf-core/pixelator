process PIXELATOR_PNA_GRAPH {
    tag "$meta.id"
    label 'process_high_memory'
    label 'process_long'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    // TODO: Add containers
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/pixelator:0.18.2--pyhdfd78af_0' :
    //     'biocontainers/pixelator:0.18.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(edge_list), path(panel_file), val(panel)

    output:
    tuple val(meta), path("graph/*")                    , emit: all_results
    tuple val(meta), path("graph/*.pxl")                , emit: pixelfile
    tuple val(meta), path("graph/*.report.json")        , emit: report_json
    tuple val(meta), path("graph/*.meta.json")          , emit: metadata_json
    tuple val(meta), path("*pixelator-graph.log")       , emit: log

    path "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def panelOpt = (
        panel ? "--panel $panel" :
        panel_file ? "--panel $panel_file" : ""
    )

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-graph.log \\
        --verbose \\
        single-cell-pna \\
        graph \\
        $panelOpt \\
        --output . \\
        $args \\
        ${edge_list}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
