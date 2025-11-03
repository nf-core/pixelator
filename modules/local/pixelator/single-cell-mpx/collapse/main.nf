process PIXELATOR_COLLAPSE {
    tag "${meta.id}"
    label 'process_medium'
    label 'process_long'

    // TODO: Add conda back
    // conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.22.1'
        : 'quay.io/pixelgen-technologies/pixelator:0.22.1'}"

    input:
    tuple val(meta), path(reads), path(panel_file), val(panel)

    output:
    tuple val(meta), path("collapse/*.collapsed.parquet"), emit: collapsed
    tuple val(meta), path("collapse/*.report.json"),       emit: report_json
    tuple val(meta), path("collapse/*.meta.json"),         emit: metadata
    tuple val(meta), path("*pixelator-collapse.log"),      emit: log

    path "versions.yml",                                   emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design != null

    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def reads_arg = reads.join(' ')
    def panel_opt = (panel
        ? "--panel ${panel}"
        : panel_file
            ? "--panel ${panel_file}"
            : "")

    """
    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-collapse.log \\
        --verbose \\
        single-cell-mpx \\
        collapse \\
        --output . \\
        --design ${meta.design} \\
        ${panel_opt} \\
        ${args} \\
        ${reads_arg}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir collapse
    touch "${prefix}.pixelator-collapse.log"
    touch "collapse/${prefix}.collapsed.parquet"
    touch "collapse/${prefix}.report.json"
    touch "collapse/${prefix}.meta.json"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
