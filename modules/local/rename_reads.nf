process RENAME_READS {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::sed=4.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"


    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}{,_R1,_R2}*"), emit: reads
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    if (reads in List) {
        """
        r1_ext=\$(echo ${reads[0]} | grep -E -o "f(ast)?q.gz")
        r2_ext=\$(echo ${reads[1]} | grep -E -o "f(ast)?q.gz")

        mv ${reads[0]} ${meta.id}_R1.\${r1_ext}
        mv ${reads[1]} ${meta.id}_R2.\${r2_ext}

        cat <<-END_VERSIONS > versions.yml
        "${task.process}": {}
        END_VERSIONS
        """
    } else {
        """
        r1_ext=\$(echo ${reads} | grep -E -o "f(ast)?q.gz")
        mv ${reads} ${meta.id}.\${r1_ext}

        cat <<-END_VERSIONS > versions.yml
        "${task.process}": {}
        END_VERSIONS
        """
    }
}
