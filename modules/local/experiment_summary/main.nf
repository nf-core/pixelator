process EXPERIMENT_SUMMARY {
    tag "${meta.id}"
    label "process_medium"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelatores:0.4.2'
        : 'quay.io/pixelgen-technologies/pixelatores:0.4.2'}"

    input:
    val(meta)
    path samplesheet_path
    path amplicon_data                    , stageAs: "results/amplicon/*"
    path demux_data                       , stageAs: "results/demux/*"
    path collapse_data                    , stageAs: "results/collapse/*"
    path graph_data                       , stageAs: "results/graph/*"
    path denoise_data                     , stageAs: "results/denoise/*"
    path analysis_data                    , stageAs: "results/analysis/*"
    path layout_data                      , stageAs: "results/layout/*"


    output:
    tuple val(meta), path("*experiment-summary.html")  , emit: html
    path("versions.yml")                                , emit: versions

    script:

    """
    # Copy the full quarto dir from the read-only image into the workdir
    cp -r /workspace/inst/quarto/ ./quarto/
    quarto render ./quarto/pixelatorES.qmd \\
        -P sample_sheet="\$PWD/${samplesheet_path}" \\
        -P data_folder="\$PWD/results/"

    mv ./quarto/pixelatorES.html experiment-summary.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        experiment-summary: \$(Rscript -e 'cat(as.character(packageVersion("pixelatorES")), "\\n")')
    END_VERSIONS
    """

    stub:
    """
    touch experiment-summary.html

    # Hard coding the version for the stub, since for some
    # reason it work in nf-test otherwise.
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        experiment-summary: 0.4.2
    END_VERSIONS
    """
}
