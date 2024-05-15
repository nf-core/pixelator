process PIXELATOR_ANNOTATE {
    tag "$meta.id"
    label 'process_medium'


    conda "bioconda::pixelator=0.16.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pixelator:0.16.2--pyhdfd78af_0' :
        'biocontainers/pixelator:0.16.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(dataset), path(panel_file), val(panel)

    output:
    tuple val(meta), path("annotate/*.dataset.pxl") , emit: dataset
    tuple val(meta), path("annotate/*.report.json") , emit: report_json
    tuple val(meta), path("annotate/*.meta.json")   , emit: metadata
    tuple val(meta), path("annotate/*")             , emit: all_results
    tuple val(meta), path("*pixelator-annotate.log"), emit: log

    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def panelOpt = (
        panel      ? "--panel $panel"      :
        panel_file ? "--panel $panel_file" :
        ""
    )

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-annotate.log \\
        --verbose \\
        single-cell \\
        annotate \\
        --output . \\
        $panelOpt \\
        $args \\
        $dataset \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
