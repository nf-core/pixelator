process PIXELATOR_PNA_DEMUX {
    tag "${meta.id}"
    label 'process_medium'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.23.0'
        : 'quay.io/pixelgen-technologies/pixelator:0.23.0'}"

    input:
    tuple val(meta), path(reads), path(panel_file), val(panel), val(design)

    output:
    tuple val(meta), path("demux/*.parquet", arity: "1..*"),      emit: demuxed
    tuple val(meta), path("demux/*demux.passed*.{fq,fastq}.zst"), emit: passed
    tuple val(meta), path("demux/*demux.failed.{fq,fastq}.zst"),  emit: failed
    tuple val(meta), path("demux/*.report.json"),                 emit: report_json
    tuple val(meta), path("demux/*.meta.json"),                   emit: metadata_json
    tuple val(meta), path("*pixelator-demux.log"),                emit: log

    tuple val("${task.process}"), val('pixelator'), eval("pixelator --version 2>/dev/null | sed 's/pixelator, version //g'"), emit: versions_pixelator, topic: versions

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
    def memory_factor = 0.75

    // The memory limit here needs to keep some buffer. This limit is used in DuckDB but it is not a hard limit.
    // Setting it too close to the actual RAM available may cause to not spill to disk soon enough and run out of memory.
    """
    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-demux.log \\
        --verbose \\
        single-cell-pna \\
        demux \\
        --memory ${Math.ceil(task.memory.toMega() * memory_factor).intValue()}M \\
        --output . \\
        ${panelOpt} \\
        ${designOpt} \\
        ${args} \\
        ${reads}
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
    """
}
