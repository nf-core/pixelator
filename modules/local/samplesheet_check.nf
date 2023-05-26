process SAMPLESHEET_CHECK {
    tag "$samplesheet"
    label 'process_single'

    conda "local::pixelator=0.10.0"
    container "ghcr.io/pixelgentechnologies/pixelator:0.10.0"

    input:
    path samplesheet
    val samplesheet_path

    output:
    path '*.csv'       , emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-core/pixelator/bin/
    def args = task.ext.args ?: ''

    """
    pixelator single-cell --list-designs > design_options.txt

    check_samplesheet.py \\
        $samplesheet \\
        samplesheet.valid.csv \\
        --samplesheet-path $samplesheet_path \\
        --design-options design_options.txt \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
