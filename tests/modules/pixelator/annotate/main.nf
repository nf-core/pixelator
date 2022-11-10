#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_ANNOTATE } from '../../../../modules/local/pixelator/annotate/main.nf'


workflow test_pixelator_annotate{
    input = [
        [ id: "${params.test_data['pixelator']['micro']['id']}"], // meta map
        file(params.test_data['pixelator']['micro']['cluster_h5ad'], checkIfExists: true),
    ]

    PIXELATOR_ANNOTATE ( input )
}
