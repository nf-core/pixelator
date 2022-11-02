#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_DEMUX } from '../../../../modules/local/pixelator/demux/main.nf'


workflow test_pixelator_demux {
    input = [
        [
            id: "${params.test_data['pixelator']['micro']['id']}",
            design: "D12"
        ],
        file(params.test_data['pixelator']['micro']['adapterqc'], checkIfExists: true),
        file(params.test_data['pixelator']['micro']['antibody_panel'], checkIfExists: true)
    ]

    PIXELATOR_DEMUX ( input )
}
