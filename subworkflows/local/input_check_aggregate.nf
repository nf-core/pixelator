//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK as SAMPLESHEET_AGGREGATE_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK_AGGREGATE {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    ch_samplesheet_rows = SAMPLESHEET_AGGREGATE_CHECK ( samplesheet, samplesheet.toUri() )
        .csv
        .splitCsv ( header:true, sep:',' )

    ch_samplesheet_rows.dump(tag: "samplesheet_csv_split")
    matrices = ch_samplesheet_rows.map { create_matrix_channels(it) }

    emit:
    matrices            // channel: [ val(meta), [ matrices ] ]

    versions = SAMPLESHEET_AGGREGATE_CHECK.out.versions // channel: [ versions.yml ]
}


def get_meta(LinkedHashMap row) {
    def meta = [:]
    meta.id           = row.sample
    meta.group        = row.group
    return meta
}


def create_matrix_channels(LinkedHashMap row) {
    def meta = get_meta(row)

    if (file(row.matrix).exists()) {
        return [ meta, file(row.matrix) ]
    }

    exit 1, "ERROR: Please check matrix field: ${row.matrix}: Could not find existing h5ad file."
}
