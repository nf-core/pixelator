process RENAME_READS {
    tag "$meta.id"

    conda (params.enable_conda ? "conda-forge::sed=4.7" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://containers.biocontainers.pro/s3/SingImgsRepo/biocontainers/v1.2.0_cv2/biocontainers_v1.2.0_cv2.img"
    } else {
        container "biocontainers/biocontainers:v1.2.0_cv2"
    }

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}_*"), emit: reads

    script: // This script is bundled with the pipeline, in nf-core/pixelator/bin/
    assert reads.size() <= 2

    if (reads.size() == 2) {
        """
        mv ${reads[0]} ${meta.id}_R1.fastq.gz
        mv ${reads[1]} ${meta.id}_R2.fastq.gz
        """
    } else {
        """
        mv ${reads[0]} ${meta.id}_R1.fastq.gz
        """
    }
}
