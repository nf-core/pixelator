process PIXELATOR_PNA_ANALYSIS {
    tag "${meta.id}"
    label 'process_medium'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.21.2'
        : 'quay.io/pixelgen-technologies/pixelator:0.21.2'}"

    input:
    tuple val(meta), path(data)

    output:
    tuple val(meta), path("analysis/*.pxl"),          emit: pixelfile
    tuple val(meta), path("analysis/*.report.json"),  emit: report_json
    tuple val(meta), path("analysis/*.meta.json"),    emit: metadata_json
    tuple val(meta), path("analysis/*"),              emit: all_results
    tuple val(meta), path("*pixelator-analysis.log"), emit: log

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-analysis.log \\
        --verbose \\
        single-cell-pna \\
        analysis \\
        --output . \\
        ${args} \\
        ${data}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """


    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir "analysis"
    touch analysis/${prefix}.meta.json
    touch analysis/${prefix}.report.json
    touch analysis/${prefix}.pxl
    touch ${prefix}.pixelator-analysis.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
