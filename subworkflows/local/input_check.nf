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

    emit:
    reads                                     // channel: [ val(meta), [ reads ] ]
    barcodes                                  // channel: [ val(meta), barcodes ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}


// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def create_fastq_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id           = row.sample
    meta.single_end   = row.single_end.toBoolean()
    meta.design       = row.design

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
    // create meta map
    def meta = [:]
    def barcode       = row.barcodes
    meta.id           = row.sample
    meta.single_end   = row.single_end.toBoolean()
    meta.design       = row.design

    def f = file("${projectDir}/assets/barcodes/${barcode}.fa")

    if (f.exists()) {
        return  [ meta, f ]
    }

    if (file(barcode).exists()) {
        return [ meta, file(barcode) ]
    }

    exit 1, "ERROR: Please check barcode: ${barcode}: Not a basename of a file under assets/barcodes or a fasta file (.fa)"
}
