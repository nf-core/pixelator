process PIXELATOR_COLLECT_METADATA {
    label 'process_single'
    cache false

    // TODO: Add conda back
    // conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'quay.io/pixelgen-technologies/pixelator:0.21.2'
        : 'quay.io/pixelgen-technologies/pixelator:0.21.2'}"

    output:
    path "metadata.json", emit: metadata
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    def nextflow_dict = [
        version: workflow.nextflow.version,
        build: workflow.nextflow.build,
        timestamp: workflow.nextflow.timestamp?.toString(),
    ]
    def manifest_dict = [
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

    def workflow_dict = [
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
        workflow: workflow_dict,
        parameters: params,
    ]

    def nextflowJson = groovy.json.JsonOutput.toJson(metadata)
    """
    echo '${nextflowJson}' > nextflow-metadata.json
    collect_metadata.py --process-name ${task.process} --workflow-data "nextflow-metadata.json"
    """

    stub:

    def nextflow_dict = [
        version: workflow.nextflow.version,
        build: workflow.nextflow.build,
        timestamp: workflow.nextflow.timestamp?.toString(),
    ]
    def manifest_dict = [
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

    def workflow_dict = [
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
        workflow: workflow_dict,
        parameters: params,
    ]

    """
    echo '${metadata}' > metadata.json
    touch nextflow-metadata.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: 3.11.4
        collect-metadata: 1.0.0
    END_VERSIONS
    """
}
