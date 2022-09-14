#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_DEMUX } from '../../../../modules/local/pixelator/demux/main.nf'


workflow test_pixelator_demux {
    input = [ [ id: "${params.test_data['pixelator']['reads_test_data']['id']}",
                design: "D12",
                barcodes: "D12_v1"
              ],
              [ 
                file(params.test_data['pixelator']['reads_test_data']['adapterqc'], checkIfExists: true),
              ]
    ]

    PIXELATOR_DEMUX ( input )
}