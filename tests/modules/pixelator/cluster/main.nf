#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_CLUSTER } from '../../../../modules/local/pixelator/cluster/main.nf'


workflow test_pixelator_cluster {
    input = [
        [ id: "${params.test_data['pixelator']['micro']['id']}"], // meta map
        file(params.test_data['pixelator']['micro']['edge_list'], checkIfExists: true),
        file(params.test_data['pixelator']['micro']['antibody_panel'], checkIfExists: true),
    ]

    PIXELATOR_CLUSTER ( input )
}
