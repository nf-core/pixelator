process PIXELATOR_PNA_DEMUX {
    tag "${meta.id}"
    label 'process_medium'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.22.0'
        : 'quay.io/pixelgen-technologies/pixelator:0.22.0'}"

    input:
    tuple val(meta), path(reads), path(panel_file), val(panel), val(design)

    output:
    tuple val(meta), path("demux/*.parquet", arity: "1..*"),      emit: demuxed
    tuple val(meta), path("demux/*demux.passed*.{fq,fastq}.zst"), emit: passed
    tuple val(meta), path("demux/*demux.failed.{fq,fastq}.zst"),  emit: failed
    tuple val(meta), path("demux/*.report.json"),                 emit: report_json
    tuple val(meta), path("demux/*.meta.json"),                   emit: metadata_json
    tuple val(meta), path("*pixelator-demux.log"),                emit: log

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // --design is passed in meta and added to args through modules.conf

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def panelOpt = (panel
        ? "--panel ${panel}"
        : panel_file ? "--panel ${panel_file}" : "")
    def designOpt = "--design ${design}"

    """
    pixelator \\
        --log-file ${prefix}.pixelator-demux.log \\
        --verbose \\
        single-cell-pna \\
        demux \\
        --threads ${task.cpus} \\
        --output . \\
        ${panelOpt} \\
        ${designOpt} \\
        ${args} \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir demux
    touch demux/${prefix}.report.json
    touch demux/${prefix}.meta.json
    touch demux/${prefix}.demux.passed.fq.zst
    touch demux/${prefix}.demux.failed.fq.zst
    touch demux/${prefix}.demux.m1.part_000.parquet
    touch demux/${prefix}.demux.m2.part_000.parquet
    touch ${prefix}.pixelator-demux.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
