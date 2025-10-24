process PIXELATOR_PNA_DENOISE {
    tag "$meta.id"
    label 'process_high'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.22.0'
        : 'quay.io/pixelgen-technologies/pixelator:0.22.0'}"

    input:
    tuple val(meta), path(data)

    output:
    tuple val(meta), path("denoise/*.pxl")             , emit: pixelfile
    tuple val(meta), path("denoise/*.report.json")     , emit: report_json
    tuple val(meta), path("denoise/*.meta.json")       , emit: metadata_json
    tuple val(meta), path("denoise/*")                 , emit: all_results
    tuple val(meta), path("*pixelator-denoise.log")    , emit: log

    path "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-denoise.log \\
        --verbose \\
        single-cell-pna \\
        denoise \\
        --output . \\
        $args \\
        $data

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir denoise
    touch denoise/${prefix}.report.json
    touch denoise/${prefix}.meta.json
    touch denoise/${prefix}.pxl
    touch ${prefix}.pixelator-denoise.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
