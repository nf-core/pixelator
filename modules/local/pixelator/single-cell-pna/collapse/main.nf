process PIXELATOR_PNA_COLLAPSE {
    tag "${meta.id}"
    label 'process_medium'

    containerOptions 'shm-size': 2.GB

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.22.1'
        : 'quay.io/pixelgen-technologies/pixelator:0.22.1'}"

    input:
    tuple val(meta), path(reads), path(panel_file), val(panel), val(design)

    output:
    tuple val(meta), path("collapse/*.parquet", arity: '1..*'),     emit: collapsed
    tuple val(meta), path("collapse/*.report.json", arity: '1..*'), emit: report_json
    tuple val(meta), path("collapse/*.meta.json"),                  emit: metadata_json
    tuple val(meta), path("*pixelator-collapse.log"),               emit: log

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    assert meta.design != null

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def read_args = reads.join(' ')
    def panel_opt = (panel
        ? "--panel ${panel}"
        : panel_file
            ? "--panel ${panel_file}"
            : "")

    """
    pixelator \\
        --log-file ${prefix}.pixelator-collapse.log \\
        --verbose \\
        single-cell-pna \\
        collapse \\
        --threads ${task.cpus} \\
        --output . \\
        --design ${design} \\
        ${panel_opt} \\
        ${args} \\
        ${read_args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    prefix = "${reads.name.replace('.parquet', '')}"

    """
    mkdir "collapse"

    touch collapse/${prefix}.report.json
    touch collapse/${prefix}.meta.json
    touch collapse/${prefix}.parquet
    touch ${prefix}.pixelator-collapse.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
