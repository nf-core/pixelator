#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_ADAPTERQC } from '../../../../modules/local/pixelator/adapterqc/main.nf'


workflow test_pixelator_adapterqc {
    input = [ [ id: "${params.test_data['pixelator']['reads_test_data']['id']}" ], // meta map
              [ 
                file(params.test_data['pixelator']['reads_test_data']['concat'], checkIfExists: true),
              ]
            ]

    PIXELATOR_ADAPTERQC ( input )
}
