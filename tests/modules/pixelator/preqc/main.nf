#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_PREQC } from '../../../../modules/local/pixelator/preqc/main.nf'


workflow test_pixelator_preqc {
    input = [ 
        [ 
            id: "${params.test_data['pixelator']['micro']['id']}",
            design: "D12",
        ],
        [ 
            file(params.test_data['pixelator']['micro']['concat'], checkIfExists: true),
        ]
    ]

    PIXELATOR_PREQC ( input )
}