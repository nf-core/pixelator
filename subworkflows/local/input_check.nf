//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    ch_samplesheet_rows = SAMPLESHEET_CHECK ( samplesheet, samplesheet.toUri() )
        .csv
        .splitCsv ( header:true, sep:',' )

    ch_samplesheet_rows.dump(tag: "samplesheet_csv_split")
    reads = ch_samplesheet_rows.map { create_fastq_channel(it) }
    barcodes = ch_samplesheet_rows.map { create_barcodes_channel(it) }
    panels = ch_samplesheet_rows.map { create_panels_channel(it) }

    emit:
    reads                                     // channel: [ val(meta), [ reads ] ]
    barcodes                                  // channel: [ val(meta), barcodes ]
    panels                                    // channel: [ val(meta), panel ]

    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}


def get_meta(LinkedHashMap row) {
    def meta = [:]
    meta.id           = row.sample
    meta.single_end   = row.single_end.toBoolean()
    meta.design       = row.design

    return meta
}

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def create_fastq_channel(LinkedHashMap row) {
    def meta = get_meta(row)

    // add path(s) of the fastq file(s) to the meta map
    def fastq_meta = []

    if (!file(row.fastq_1).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 1 FastQ file does not exist!\n${row.fastq_1}"
    }
    if (!meta.single_end && !meta.design.endsWith("PE")) {
        exit 1, "ERROR: Please check input samplesheet -> Non paired-end design with paired-end input! Consider adding 'PE' suffix to the design.\n${row.fastq_1}"
    }
    if (meta.single_end && meta.design.endsWith("PE")) {
        exit 1, "ERROR: Please check input samplesheet -> Paired-end design with single-end input! Consider removing 'PE' suffix from the design.\n${row.fastq_1}"
    }

    if (meta.single_end) {
        fastq_meta = [ meta, [ file(row.fastq_1) ] ]
    } else {
        if (!file(row.fastq_2).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> Read 2 FastQ file does not exist!\n${row.fastq_2}"
        }
        fastq_meta = [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
    }
    return fastq_meta
}


def create_barcodes_channel(LinkedHashMap row) {
    def meta = get_meta(row)

    if (file(row.barcodes).exists()) {
        return [ meta, file(row.barcodes) ]
    }

    exit 1, "ERROR: Please check barcode field: ${row.barcode}: Could not find existing fasta file (.fa)"
}


def create_panels_channel(LinkedHashMap row) {
    def meta = get_meta(row)

    if (file(row.panel).exists()) {
        return [ meta, file(row.panel) ]
    }

    exit 1, "ERROR: Please check panel field: ${row.panel}: Could not find existing csv file."
}
