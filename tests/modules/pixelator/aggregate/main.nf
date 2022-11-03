#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_AGGREGATE } from '../../../../modules/local/pixelator/aggregate/main.nf'


workflow test_pixelator_aggregate {
    input = [
        [ id: "aggregate_1", sample_ids: [ "${params.test_data['pixelator']['micro']['id']}", "test_data2"]],
        [
            file(params.test_data['pixelator']['micro']['annotate_h5ad'], checkIfExists: true),
            file(params.test_data['pixelator']['micro']['anndata'], checkIfExists: true)
        ]
    ]

    PIXELATOR_AGGREGATE( input )
}
