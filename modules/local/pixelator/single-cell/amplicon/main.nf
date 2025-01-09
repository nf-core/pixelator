process PIXELATOR_AMPLICON {
    tag "$meta.id"
    label 'process_low'
    label 'process_long'

    conda "modules/local/pixelator/single-cell/amplicon/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pixelator:0.19.0--pyhdfd78af_0' :
        'biocontainers/pixelator:0.19.0--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("amplicon/*.merged.{fq,fastq}.gz"), emit: merged
    tuple val(meta), path("amplicon/*.report.json")         , emit: report_json
    tuple val(meta), path("amplicon/*.meta.json")           , emit: metadata
    tuple val(meta), path("*pixelator-amplicon.log")        , emit: log

    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''

    // Make list of old name and new name pairs to use for renaming
    // Use R1/R2 style suffixes for limited backward compatibility with pixelator<0.17
    def old_new_pairs = (reads instanceof Path || reads.size() == 1)
        ? [[ reads, "${prefix}${getFileSuffix(reads)}" ]]
        : reads.withIndex().collect { entry, index -> [ entry, "${prefix}_R${index + 1}${getFileSuffix(entry)}" ] }

    def rename_to = old_new_pairs*.join(' ').join(' ')
    def renamed_reads = old_new_pairs.collect { old_name, new_name -> new_name }.join(' ')

    """
    printf "%s %s\\n" $rename_to | while read old_name new_name; do
        [ -f "\${new_name}" ] || ln -s \$old_name \$new_name
    done

    pixelator \\
        --cores $task.cpus \\
        --log-file ${prefix}.pixelator-amplicon.log \\
        --verbose \\
        single-cell \\
        amplicon \\
        --output . \\
        $args \\
        ${renamed_reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir amplicon
    touch "${prefix}.pixelator-amplicon.log"
    touch amplicon/${prefix}.merged.fq.gz
    touch amplicon/${prefix}.report.json
    touch amplicon/${prefix}.meta.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pixelator: \$(echo \$(pixelator --version 2>/dev/null) | sed 's/pixelator, version //g' )
    END_VERSIONS
    """
}


// for .gz files also include the second to last extension if it is present. E.g., .fasta.gz
// Source: nf-core/modules/cat/cat
def getFileSuffix(filename) {
    def match = filename =~ /^.*?((\.\w{1,5})?(\.\w{1,5}\.gz$))/
    return match ? match[0][1] : filename.substring(filename.lastIndexOf('.'))
}
