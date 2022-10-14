#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_COLLAPSE } from '../../../../modules/local/pixelator/collapse/main.nf'


workflow test_pixelator_collapse {

    files = params.test_data['pixelator']['micro']['demux'].each( it -> file(it, checkIfExists: true) )

    input = [
        [ id: "${params.test_data['pixelator']['micro']['id']}", design: "D12" ], // meta map
        files
    ]
    panel = file("${params.test_data['pixelator']['micro']['antibody_panel']}")

    PIXELATOR_COLLAPSE ( input, panel )
}
