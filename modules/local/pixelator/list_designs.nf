process PIXELATOR_LIST_DESIGNS {
    label 'process_single'

    // TODO: Update once pixelator is public in bioconda
    conda "local::pixelator=0.12.0"
    container "ghcr.io/pixelgentechnologies/pixelator:0.12.0"

    output:
    path "design_options.txt"     , emit: designs
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    pixelator single-cell --list-designs $args > design_options.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}
