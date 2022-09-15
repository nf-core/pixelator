#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_CLUSTER } from '../../../../modules/local/pixelator/cluster/main.nf'


workflow test_pixelator_cluster {
    input = [
        [ id: "${params.test_data['pixelator']['reads_test_data']['id']}"], // meta map
        file(params.test_data['pixelator']['reads_test_data']['collapsed'], checkIfExists: true),
    ]

    PIXELATOR_CLUSTER ( input )
}