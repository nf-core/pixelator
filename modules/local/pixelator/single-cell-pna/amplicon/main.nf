process PIXELATOR_PNA_AMPLICON {
    tag "${meta.id}"
    label 'process_medium'

    // TODO: Add conda
    // conda "bioconda::pixelator=0.18.2"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.22.1'
        : 'quay.io/pixelgen-technologies/pixelator:0.22.1'}"

    input:
    tuple val(meta), path(reads, arity: '1..*')

    output:
    tuple val(meta), path("amplicon/*.amplicon.{fq,fastq}.zst"), emit: amplicon
    tuple val(meta), path("amplicon/*.report.json"),             emit: report_json
    tuple val(meta), path("amplicon/*.meta.json"),               emit: metadata_json
    tuple val(meta), path("*pixelator-amplicon.log"),            emit: log

    tuple val("${task.process}"), val('pixelator'), eval("pixelator --version 2>/dev/null | sed 's/pixelator, version //g'"), emit: versions_pixelator, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def r = reads

    // Make list of old name and new name pairs to use for renaming
    // Use R1/R2 style suffixes for limited backward compatibility with pixelator<0.17
    def old_new_pairs = (reads.size() == 1
        ? [[reads[0], "${prefix}${getFileSuffix(reads[0])}"]]
        : reads.withIndex().collect { entry, index -> [entry, "${prefix}_R${index + 1}${getFileSuffix(entry)}"] })
    // Flatten a list of tuples into a single string joined with spaces
    def rename_to = old_new_pairs.flatten().join(' ')
    def renamed_reads = old_new_pairs.collect { old_name, new_name -> new_name }.join(' ')


    """
    printf "%s %s\\n" ${rename_to} | while read old_name new_name; do
        [ -f "\${new_name}" ] || ln -s \$old_name \$new_name
    done

    pixelator \\
        --log-file ${prefix}.pixelator-amplicon.log \\
        --verbose \\
        single-cell-pna \\
        amplicon \\
        --threads ${task.cpus} \\
        --output . \\
        ${args} \\
        ${renamed_reads}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir amplicon
    touch amplicon/${prefix}.report.json
    touch amplicon/${prefix}.meta.json
    touch amplicon/${prefix}.amplicon.fq.zst
    touch ${prefix}.pixelator-amplicon.log
    """
}



// for .gz files also include the second to last extension if it is present. E.g., .fasta.gz
// Source: nf-core/modules/cat/cat
def getFileSuffix(filename) {
    def match = filename =~ /^.*?((\.\w{1,5})?(\.\w{1,5}\.(gz|zst)$))/
    return match ? match[0][1] : filename.substring(filename.lastIndexOf('.'))
}
