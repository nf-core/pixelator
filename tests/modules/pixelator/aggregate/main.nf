#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_AGGREGATE } from '../../../../modules/local/pixelator/aggregate/main.nf'


workflow test_pixelator_aggregate {
    input = [
        [ id: "${params.test_data['pixelator']['micro']['id']}"], // meta map
        file(params.test_data['pixelator']['micro']['anndata'], checkIfExists: true),
    ]

    PIXELATOR_AGGREGATE( input )
}
