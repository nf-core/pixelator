#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_RND_REPORT } from '../../../../modules/local/pixelator/rnd-report/main.nf'


workflow test_pixelator_rnd_report {

    input = [ id: "${params.test_data['pixelator']['micro']['id']}", samples: ["test_data"] ]
    preqc = file("${params.test_data['pixelator']['micro']["result_dirs"]["preqc"]}/*", checkIfExists: true)
    adapterqc = file("${params.test_data['pixelator']['micro']["result_dirs"]["adapterqc"]}/*", checkIfExists: true)
    collapse = file("${params.test_data['pixelator']['micro']["result_dirs"]["collapse"]}/*", checkIfExists: true)
    demux = file("${params.test_data['pixelator']['micro']["result_dirs"]["demux"]}/*", checkIfExists: true)
    cluster = file("${params.test_data['pixelator']['micro']["result_dirs"]["cluster"]}/*", checkIfExists: true)
    annotate = file("${params.test_data['pixelator']['micro']["result_dirs"]["annotate"]}/*", checkIfExists: true)
    analysis = file("${params.test_data['pixelator']['micro']["result_dirs"]["analysis"]}/*", checkIfExists: true)

    PIXELATOR_RND_REPORT (
        input,
        preqc,
        adapterqc,
        demux,
        collapse,
        cluster,
        annotate,
        analysis
    )
}
