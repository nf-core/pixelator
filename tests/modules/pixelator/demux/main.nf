#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_DEMUX } from '../../../../modules/local/pixelator/demux/main.nf'


workflow test_pixelator_demux {
    input = [
        [
            id: "${params.test_data['pixelator']['micro']['id']}",
            design: "D12",
            barcodes: "D12_v1"
        ],
        file(params.test_data['pixelator']['micro']['adapterqc'], checkIfExists: true),
        file(params.test_data['pixelator']['micro']['barcodes'], checkIfExists: true)
    ]

    PIXELATOR_DEMUX ( input )
}
