//
// Check input samplesheet and get read channels
//

include { fromSamplesheet           } from 'plugin/nf-validation'

workflow INPUT_CHECK {
    take:

    main:
    ch_samplesheet = Channel.fromSamplesheet("input")

    reads = ch_samplesheet.map { meta, panel, fastq_1, fastq_2 ->
        def r = []
        r.add(fastq_1)
        if (fastq_2 != null) {
            r.add(fastq_2)
        }
        [meta, r]
    }

    panels = ch_samplesheet.map { meta, panel, fastq_1, fastq_2 -> [meta, panel] }

    emit:
    reads                                      // channel: [ val(meta), [ reads ] ]
    panels                                     // channel: [ val(meta), panel ]
}
