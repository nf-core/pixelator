#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_ANALYSIS } from '../../../../modules/local/pixelator/analysis/main.nf'


workflow test_pixelator_analysis {
    input = [
        [ id: "${params.test_data['pixelator']['micro']['id']}"], // meta map
        file(params.test_data['pixelator']['micro']['cluster_h5ad'], checkIfExists: true),
    ]

    PIXELATOR_ANALYSIS( input )
}
