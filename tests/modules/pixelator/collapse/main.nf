#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIXELATOR_COLLAPSE } from '../../../../modules/local/pixelator/collapse/main.nf'


workflow test_pixelator_collapse {

    def files = params.test_data['pixelator']['reads_test_data']['demux'].each( it -> file(it, checkIfExists: true) )

    input = [ [ id: "${params.test_data['pixelator']['reads_test_data']['id']}", 
                design: "D12"
              ], // meta map
              files
            ]

    PIXELATOR_COLLAPSE ( input )
}