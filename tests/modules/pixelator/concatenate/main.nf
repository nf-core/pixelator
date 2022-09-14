#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_CONCATENATE } from '../../../../modules/local/pixelator/concatenate/main.nf'


workflow test_pixelator_concatenate {
    input = [ [ id: "${params.test_data['pixelator']['reads_test_data']['id']}" ], // meta map
              [ 
                file(params.test_data['pixelator']['reads_test_data']['R1'], checkIfExists: true),
                file(params.test_data['pixelator']['reads_test_data']['R2'], checkIfExists: true)
              ]
            ]

    PIXELATOR_CONCATENATE ( input )
}


workflow test_pixelator_concatenate_single_end {
    input = [ [ id: "${params.test_data['pixelator']['reads_test_data']['id']}", single_end: true ], // meta map
              [ 
                file(params.test_data['pixelator']['reads_test_data']['R1'], checkIfExists: true),
              ]
            ]

    PIXELATOR_CONCATENATE ( input )
}
