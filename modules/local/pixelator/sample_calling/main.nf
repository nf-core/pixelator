process PIXELATOR_SAMPLE_CALLING {
    tag "${meta.id}"
    label 'process_high'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.30.0'
        : 'quay.io/pixelgen-technologies/pixelator:0.30.0'}"

    input:
    tuple val(meta), path(data), path(samplesheet)

    output:
    tuple val(meta), path("sample_calling/*.pxl"),         emit: pixelfile
    tuple val(meta), path("sample_calling/*.report.json"), emit: report_json
    tuple val(meta), path("sample_calling/*.meta.json"),   emit: metadata_json
    tuple val(meta), path("sample_calling/*"),             emit: all_results

    tuple val(meta), path("*pixelator-sample-calling.log"), emit: log
    tuple val('sample_calling'), path("sample_calling/*"),  topic: all_results_for_reports

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    """
    pixelator \
        --cores ${task.cpus} \
        --log-file ${prefix}.pixelator-sample-calling.log \
        --verbose \
        single-cell-pna \
        sample-calling \
        --samplesheet ${samplesheet} \
        --output . \
        ${args} \
        ${data}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    // The stub here generates multiple output pxl files to mimic real run
    // in reality these should match up with what has been configured in the
    // samplesheet
    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir sample_calling
    touch sample_calling/${prefix}.sample_calling.report.json
    touch sample_calling/${prefix}.sample_calling.meta.json
    touch sample_calling/sample1.dehashed.pxl
    touch sample_calling/sample2.dehashed.pxl
    touch sample_calling/sample3.dehashed.pxl
    touch sample_calling/sample4.dehashed.pxl
    touch ${prefix}.pixelator-sample-calling.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
