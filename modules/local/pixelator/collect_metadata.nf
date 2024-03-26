import groovy.json.JsonOutput



process PIXELATOR_COLLECT_METADATA {
    label 'process_single'
    cache false

    conda "bioconda::pixelator=0.16.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pixelator:0.16.2--pyhdfd78af_0' :
        'biocontainers/pixelator:0.16.2--pyhdfd78af_0' }"

    input:

    output:
    path "metadata.json", emit: metadata
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    Map nextflow_dict = [
        version: workflow.nextflow.version,
        build: workflow.nextflow.build,
        timestamp: workflow.nextflow.timestamp?.toString(),
    ]
    Map manifest_dict = [
        author: workflow.manifest.getAuthor(),
        defaultBranch: workflow.manifest.getDefaultBranch(),
        description: workflow.manifest.getDescription(),
        homePage: workflow.manifest.getHomePage(),
        gitmodules: workflow.manifest.getGitmodules(),
        mainScript: workflow.manifest.getMainScript(),
        version: workflow.manifest.getVersion(),
        nextflowVersion: workflow.manifest.getNextflowVersion(),
        doi: workflow.manifest.getDoi(),
    ]

    Map workflow_dict = [
        scriptId: workflow.scriptId,
        scriptName: workflow.scriptName,
        scriptFile: workflow.scriptFile.toString(),
        repository: workflow.repository,
        commitId: workflow.commitId,
        revision: workflow.revision,
        projectDir: workflow.projectDir.toString(),
        launchDir: workflow.launchDir.toString(),
        workDir: workflow.workDir.toString(),
        homeDir: workflow.homeDir.toString(),
        userName: workflow.userName,
        configFiles: workflow.configFiles.collect { it.toString() },
        container: workflow.container.collectEntries { [it.key, it.value?.toString()] },
        containerEngine: workflow.containerEngine,
        commandLine: workflow.commandLine,
        profile: workflow.profile,
        runName: workflow.runName,
        sessionId: workflow.sessionId,
        resume: workflow.resume,
        stubRun: workflow.stubRun,
        start: workflow.start?.toString(),
    ]

    def metadata = [
        nextflow: nextflow_dict,
        manifest: manifest_dict,
        workflow : workflow_dict,
        parameters: params
    ]

    def nextflowJson = JsonOutput.toJson(metadata)

    """
    echo '${nextflowJson}' > nextflow-metadata.json
    collect_metadata.py --process-name ${task.process} --workflow-data "nextflow-metadata.json"
    """
}
