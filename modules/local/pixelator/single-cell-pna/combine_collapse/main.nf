process PIXELATOR_PNA_COMBINE_COLLAPSE {
    tag "${meta.id}"
    label 'process_medium'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'ghcr.io/pixelgentechnologies/pixelator:0.20.1'
        : 'ghcr.io/pixelgentechnologies/pixelator:0.20.1'}"

    input:
    tuple val(meta), path(parquet_files, stageAs: "parquet/*"), path(json_report_files, stageAs: "reports/*")

    output:
    tuple val(meta), path("collapse/*.parquet", arity: 1),    emit: parquet
    tuple val(meta), path("collapse/*.report.json"),          emit: report_json
    tuple val(meta), path("collapse/*.meta.json"),            emit: metadata_json
    tuple val(meta), path("*pixelator-combine-collapse.log"), emit: log

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // --design is passed in meta and added to args through modules.conf

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def parquetArgs = parquet_files.join(' --parquet ')
    def reportArgs = json_report_files.join(' --report ')

    """
    pixelator \\
        --log-file ${prefix}.pixelator-combine-collapse.log \\
        --verbose \\
        single-cell-pna \\
        combine-collapse \\
        --output . \\
        ${args} \\
        --parquet ${parquetArgs} \\
        --report ${reportArgs}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    """
    mkdir demux
    touch collapse/${prefix}.collapse.parquet
    touch collapse/${prefix}.collapse.meta.json
    touch ${prefix}.pixelator-combine-collapse.log
    touch versions.yml
    """
}
