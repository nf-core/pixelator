//
// This file holds several functions specific to the main.nf workflow in the nf-core/pixelator pipeline
//
import groovy.json.JsonSlurper
import groovy.json.JsonBuilder
import nextflow.Nextflow

class WorkflowMain {

    //
    // Citation string for pipeline
    //
    public static String citation(workflow) {
        return "If you use ${workflow.manifest.name} for your analysis please cite:\n\n" +
            // TODO nf-core: Add Zenodo DOI for pipeline after first release
            //"* The pipeline\n" +
            //"  https://doi.org/10.5281/zenodo.XXXXXXX\n\n" +
            "* The nf-core framework\n" +
            "  https://doi.org/10.1038/s41587-020-0439-x\n\n" +
            "* Software dependencies\n" +
            "  https://github.com/${workflow.manifest.name}/blob/master/CITATIONS.md"
    }

    //
    // Generate help string
    //
    public static String help(workflow, params, log) {
        def command = "nextflow run ${workflow.manifest.name} --input samplesheet.csv --genome GRCh37 -profile docker"
        def help_string = ''
        help_string += NfcoreTemplate.logo(workflow, params.monochrome_logs)
        help_string += NfcoreSchema.paramsHelp(workflow, params, command)
        help_string += '\n' + citation(workflow) + '\n'
        help_string += NfcoreTemplate.dashedLine(params.monochrome_logs)
        return help_string
    }

    //
    // Generate parameter summary log string
    //
    public static String paramsSummaryLog(workflow, params, log) {
        def summary_log = ''
        summary_log += NfcoreTemplate.logo(workflow, params.monochrome_logs)
        summary_log += NfcoreSchema.paramsSummaryLog(workflow, params)
        summary_log += '\n' + citation(workflow) + '\n'
        summary_log += NfcoreTemplate.dashedLine(params.monochrome_logs)
        return summary_log
    }

    //
    // Validate parameters and print summary to screen
    //
    public static void initialise(workflow, params, log) {
        // Print help to screen if required
        if (params.help) {
            log.info help(workflow, params, log)
            System.exit(0)
        }

        // Print workflow version and exit on --version
        if (params.version) {
            String workflow_version = NfcoreTemplate.version(workflow)
            log.info "${workflow.manifest.name} ${workflow_version}"
            System.exit(0)
        }

        // Print parameter summary log to screen
        log.info paramsSummaryLog(workflow, params, log)

        // Validate workflow parameters via the JSON schema
        if (params.validate_params) {
            CustomNfcoreSchema.validateParameters(workflow, params, log, /*nextflow_schema=*/ 'nextflow_schema.json', /*strict=*/ true)
        }

        // Check that a -profile or Nextflow config has been provided to run the pipeline
        NfcoreTemplate.checkConfigProvided(workflow, log)

        // Check that conda channels are set-up correctly
        if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
            Utils.checkCondaChannels(log)
        }

        // Check AWS batch settings
        NfcoreTemplate.awsBatch(workflow, params)

        // Check input has been provided
        if (!params.input) {
            log.error "Please provide an input samplesheet to the pipeline e.g. '--input samplesheet.csv'"
            System.exit(1)
        }
    }
    //
    // Get attribute from genome config file e.g. fasta
    //
    public static Object getGenomeAttribute(params, attribute) {
        if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
            if (params.genomes[ params.genome ].containsKey(attribute)) {
                return params.genomes[ params.genome ][ attribute ]
            }
        }
        return null
    }

    private static String pixelgenOutputDir(workflow, params) {
        // Function used to generate the an output path on the form:
        // /<nf-core-pixelator version>-<pixelator version>/<date>-<sha>/

        // TODO This duplicates the function in `pixelgen.config`. It's ugly, but I've
        // not figured out any better way to do this so far.

        def pipelineVersion = workflow.manifest.version
        def pixelatorVersion = params.pixelator_tag ?: "unknown"
        def today = new Date().format("yyyy-MM-dd")

        def samplesheet = Nextflow.file(params.input)
        def samplesheetSha = samplesheet.bytes.digest('sha-1')
        def parameterSha = params.sort().toString().digest('sha-1')
        def combinedSha = "${samplesheetSha}${parameterSha}".digest("sha-1").substring(0, 6)

        return "${pipelineVersion}/${pixelatorVersion}/${today}/${combinedSha}"
    }

    public static void writeMetadata(workflow, params) {
        // Write detailed pipeline metrics

        def outputDir = new File("${params.outdir}/pipeline_info")

        // If we load the custom pixelgen conf write to the custom directory
        def pixelgenConfPath = System.getenv('CUSTOM_PIXELGEN_CONF')
        if (pixelgenConfPath?.trim()){
            outputDir = new File("${params.outdir}/${WorkflowMain.pixelgenOutputDir(workflow, params)}/pipeline_info")
        }

        if (!outputDir.exists()) {
            outputDir.mkdirs()
        }

        final nextflow_dict = [
            version: workflow.nextflow.version,
            build: workflow.nextflow.build,
            timestamp: workflow.nextflow.timestamp?.toString(),
        ]
        final manifest_dict = [
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

        final workflow_dict = [
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
            complete: workflow.complete?.toString(),
            duration: workflow.duration?.toString(),
            success: workflow?.success,
            exitStatus: workflow?.exitStatus,
            errorMessage: workflow?.errorMessage,
            errorReport: workflow?.errorReport,
        ]

        def metadata_file = new File(outputDir, "metadata.json")
        Map metadata = [:]

        if (metadata_file.exists() && metadata_file.text.length() > 0) {
            metadata = (Map) new JsonSlurper().parseText(metadata_file.text)
        }

        metadata += [
            nextflow: nextflow_dict,
            manifest: manifest_dict,
            workflow : workflow_dict,
            parameters: params
        ]

        def builder = new JsonBuilder(metadata)

        def file_writer = new FileWriter(metadata_file)
        file_writer.write(builder.toPrettyString())
        file_writer.close()
    }
}
