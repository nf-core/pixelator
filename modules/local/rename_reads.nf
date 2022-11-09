process RENAME_READS {
    tag "$meta.id"
    label "process_single"

    conda (params.enable_conda ? "conda-forge::sed=4.7" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/ubuntu:20.04"
    } else {
        container "registry.hub.docker.com/biocontainers/biocontainers:v1.2.0_cv2"
    }

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}*"),  emit: reads
    path "versions.yml",                   emit: versions
    when:
    task.ext.when == null || task.ext.when

    script:

    if (reads in List) {
        """
        mv ${reads[0]} ${meta.id}_R1.fastq.gz
        mv ${reads[1]} ${meta.id}_R2.fastq.gz

        cat <<-END_VERSIONS > versions.yml
        "${task.process}": {}
        END_VERSIONS
        """
    } else {
        """
        mv ${reads} ${meta.id}.fastq.gz

        cat <<-END_VERSIONS > versions.yml
        "${task.process}": {}
        END_VERSIONS
        """
    }
}
