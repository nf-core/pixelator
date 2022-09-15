#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_PREQC } from '../../../../modules/local/pixelator/preqc/main.nf'


workflow test_pixelator_preqc {
    input = [ 
        [ 
            id: "${params.test_data['pixelator']['reads_test_data']['id']}",
            design: "D12",
        ],
        [ 
            file(params.test_data['pixelator']['reads_test_data']['concat'], checkIfExists: true),
        ]
    ]

    PIXELATOR_PREQC ( input )
}