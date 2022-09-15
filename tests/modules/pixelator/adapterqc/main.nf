#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_ADAPTERQC } from '../../../../modules/local/pixelator/adapterqc/main.nf'


workflow test_pixelator_adapterqc {
    input = [ [ id: "${params.test_data['pixelator']['micro']['id']}", design: "D12" ], // meta map
              [ 
                file(params.test_data['pixelator']['micro']['concat'], checkIfExists: true),
              ]
            ]

    PIXELATOR_ADAPTERQC ( input )
}
