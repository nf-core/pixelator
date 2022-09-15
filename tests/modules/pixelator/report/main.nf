#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_REPORT } from '../../../../modules/local/pixelator/report/main.nf'


workflow test_pixelator_report {


    input = [ id: "${params.test_data['pixelator']['reads_test_data']['id']}", samples: ["test_data"] ]
    concatenate = file(params.test_data['pixelator']['reads_test_data']["result_dirs"]["concatenate"], checkIfExists: true)
    preqc = file(params.test_data['pixelator']['reads_test_data']["result_dirs"]["preqc"], checkIfExists: true)
    adapterqc = file(params.test_data['pixelator']['reads_test_data']["result_dirs"]["adapterqc"], checkIfExists: true)
    collapse = file(params.test_data['pixelator']['reads_test_data']["result_dirs"]["collapse"], checkIfExists: true)
    demux = file(params.test_data['pixelator']['reads_test_data']["result_dirs"]["demux"], checkIfExists: true)
    cluster = file(params.test_data['pixelator']['reads_test_data']["result_dirs"]["cluster"], checkIfExists: true)

    PIXELATOR_REPORT ( 
        input,
        concatenate,
        preqc,
        adapterqc,
        demux,
        collapse,
        cluster 
    )
}
