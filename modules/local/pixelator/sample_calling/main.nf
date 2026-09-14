process PIXELATOR_SAMPLE_CALLING {
    tag "${meta.id}"
    label 'process_high'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"
    container "${params.pixelator_container?:workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
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
    tuple val('sample_calling'), path("sample_calling/*.{meta.json,report.json,pxl}"), topic: all_results_for_reports

    tuple val("${task.process}"), val('pixelator'), eval("pixelator --version 2>/dev/null | sed 's/pixelator, version //g'"), emit: versions_pixelator, topic: versions

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
    """

    // The stub generates one pxl file per sample assigned to this pool in the
    // samplesheet, matching what a real run produces.
    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir sample_calling
    touch sample_calling/${prefix}.sample_calling.report.json
    touch sample_calling/${prefix}.sample_calling.meta.json

    # List the samples assigned to this pool. The samplesheet column order is not
    # fixed, so locate the columns by name in the header row. A sample can also
    # span several rows when it was sequenced on multiple lanes, hence the seen[].
    awk -F, -v wanted_pool="${prefix}" '
        NR == 1 {
            for (i = 1; i <= NF; i++) {
                if (\$i == "pool")   { pool_col = i }
                if (\$i == "sample") { sample_col = i }
            }
            next
        }
        \$pool_col == wanted_pool {
            sample = \$sample_col
            if (!(sample in seen)) {
                seen[sample] = 1
                print sample
            }
        }
    ' ${samplesheet} | while read -r sample; do
        touch "sample_calling/\${sample}.dehashed.pxl"
    done

    touch ${prefix}.pixelator-sample-calling.log
    """
}
