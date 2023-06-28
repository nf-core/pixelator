

process PIXELATOR_COLLAPSE {
    tag "$meta.id"
    label 'process_medium'


    conda "local::pixelator=0.10.0"

    container "ghcr.io/pixelgentechnologies/pixelator:0.12.0"

    input:
    tuple val(meta), path(reads), path(panel_file)
    val panel

    output:
    tuple val(meta), path("collapse/*.collapsed.csv.gz"),     emit: collapsed
    tuple val(meta), path("collapse/*.report.json"),          emit: report_json
    tuple val(meta), path("collapse/*.meta.json"),            emit: metadata
    tuple val(meta), path("*pixelator-collapse.log"),         emit: log


    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design != null

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def readsArg = reads.join(' ')
    def panelOpt = panel ?: "${panel_file}"

    """
    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-collapse.log \\
        --verbose \\
        single-cell \\
        collapse \\
        --output . \\
        --design ${meta.design} \\
        --panel ${panelOpt} \\
        $args \\
        ${readsArg}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
