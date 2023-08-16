process PIXELATOR_LIST_OPTIONS {
    label 'process_single'

    // TODO: Update once pixelator is public in bioconda
    conda "local::pixelator=0.12.0"
    container "ghcr.io/pixelgentechnologies/pixelator:0.12.0"

    output:
    path "design_options.txt"     , emit: designs
    path "panel_options.txt"      , emit: panels
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''

    """
    pixelator single-cell --list-designs $args > design_options.txt
    pixelator single-cell --list-panels $args2 > panel_options.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
