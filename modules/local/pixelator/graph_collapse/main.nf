process PIXELATOR_GRAPH_COLLAPSE {
    tag "${meta.id}"
    label 'process_high'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"

    container "${params.pixelator_container?:workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'ghcr.io/pixelgentechnologies/pixelator:sha-45647a1'
        : 'ghcr.io/pixelgentechnologies/pixelator:sha-45647a1'}"

    input:
    tuple val(meta), path(data)

    output:
    tuple val(meta), path("graph-collapse/*.pxl"),                                emit: pixelfile
    tuple val(meta), path("graph-collapse/*.report.json"),                        emit: report_json
    tuple val(meta), path("graph-collapse/*.meta.json"),                          emit: metadata_json
    tuple val(meta), path("graph-collapse/*.collapsed_sequences.tsv"),            emit: collapsed_sequences, optional: true
    tuple val(meta), path("graph-collapse/*"),                                    emit: all_results
    tuple val(meta), path("*pixelator-graph-collapse.log"),                       emit: log
    tuple val('graph_collapse'), path("graph-collapse/*.{meta.json,report.json,pxl}"), topic: all_results_for_reports

    tuple val("${task.process}"), val('pixelator'), eval("pixelator --version 2>/dev/null | sed 's/pixelator, version //g'"), emit: versions_pixelator, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def memory_factor = 0.75

    // The memory limit here needs to keep some buffer. This limit is used in DuckDB but it is not a hard limit.
    // Setting it too close to the actual RAM available may cause to not spill to disk soon enough and run out of memory.
    """
    pixelator \\
        --cores ${task.cpus} \\
        --log-file ${prefix}.pixelator-graph-collapse.log \\
        --verbose \\
        single-cell-pna \\
        graph-collapse \\
        --design ${meta.design} \\
        --output . \\
        --memory ${Math.ceil(task.memory.toMega() * memory_factor).intValue()}M \\
        ${args} \\
        ${data}
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir graph-collapse
    touch graph-collapse/${prefix}.report.json
    touch graph-collapse/${prefix}.meta.json
    touch graph-collapse/${prefix}.graph-collapse.pxl
    touch ${prefix}.pixelator-graph-collapse.log
    """
}
