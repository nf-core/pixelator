process EXPERIMENT_SUMMARY {
    tag "${meta.id}"
    label "process_medium"
    label "error_retry"

    container "${params.experiment_summary_container?: workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelatores:0.11.2'
        : 'quay.io/pixelgen-technologies/pixelatores:0.11.2'}"

    input:
    path samplesheet_path
    tuple val(meta), val(result_stages), path(results_data, arity: "1..*", stageAs: "results_raw/?/*")

    output:
    tuple val(meta), path("*experiment-summary.html")  , emit: html
    tuple val("${task.process}"), val('experiment-summary'), eval("Rscript -e 'cat(as.character(packageVersion(\"pixelatorES\")), \"\\n\")'"), emit: versions_experiment_summary, topic: versions

    script:
    def args = task.ext.args ?: ''

    assert result_stages instanceof List : "Expected result_stages to be a List, got ${result_stages?.getClass()?.simpleName ?: 'null'}"
    assert results_data instanceof List : "Expected results_data to be a List, got ${results_data?.getClass()?.simpleName ?: 'null'}"
    assert results_data.size() == result_stages.size(): "Mismatch between result files (${results_data.size()}) and stage labels (${result_stages.size()})"

    def stageCopies = [result_stages, results_data].transpose().collect { stage, file ->
        """
        mkdir -p "results/${stage}"
        ln -s "../../${file}" "results/${stage}/"
        """
    }.join('\n')
    """
    # Copy the full quarto dir from the read-only image into the workdir
    cp -r /workspace/inst/quarto/ ./quarto/
    mkdir -p results
    ${stageCopies}
    quarto render ./quarto/pixelatorES.qmd \\
        -P sample_sheet="\$PWD/${samplesheet_path}" \\
        -P data_folder="\$PWD/results/" \\
        $args \\

    mv ./quarto/pixelatorES.html experiment-summary.html
    """

    stub:
    """
    touch experiment-summary.html
    """
}
