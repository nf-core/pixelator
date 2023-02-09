process RENAME_MATRICES {
    tag "$meta.id"
    label "process_single"

    conda "conda-forge::sed=4.7"
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/ubuntu:20.04"
    } else {
        container "registry.hub.docker.com/biocontainers/biocontainers:v1.2.0_cv2"
    }

    input:
    tuple val(meta), path(matrix)

    output:
    tuple val(meta), path("${meta.id}*"),  emit: matrices
    path "versions.yml",                   emit: versions
    when:
    task.ext.when == null || task.ext.when

    script:

    """
    mv ${matrix} ${meta.id}.h5ad

    cat <<-END_VERSIONS > versions.yml
    "${task.process}": {}
    END_VERSIONS
    """
}
