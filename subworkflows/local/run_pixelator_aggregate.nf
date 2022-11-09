//
// Group h5ad channel by group and aggregate
//
include { PIXELATOR_AGGREGATE } from "../../modules/local/pixelator/aggregate/main"


workflow RUN_PIXELATOR_AGGREGATE {
    take:
    matrices            // [ val(meta), path(matrix) ]

    main:
    ch_versions = Channel.empty()

    // Group h5ad by group and aggregate
    ch_matrices_grouped = matrices
        .map { meta, value -> [meta.group, meta.id, meta, value] }
        .groupTuple()
        .map { group, ids, metas, values -> {
            Map meta = [:]
            meta.id = "aggregate_${group}"
            meta.sample_ids = ids
            [meta, values]
        }}

    ch_matrices_grouped.dump(tag: "ch_matrices_grouped")

    ch_matrices_grouped = ch_matrices_grouped.branch {
        meta, values -> values.size() == 1
            single: values.size() == 1
                return [ meta, values.flatten() ]
            multiple: values.size() > 1
                return [ meta, values.flatten() ]
    }

    ch_matrices_grouped.single.dump(tag: "ch_matrices_grouped_single")
    ch_matrices_grouped.multiple.dump(tag: "ch_matrices_grouped_multiple")

    PIXELATOR_AGGREGATE ( ch_matrices_grouped.multiple )
    ch_aggregated = PIXELATOR_AGGREGATE.out.h5ad
    ch_aggregated.dump(tag: "ch_aggregated")

    ch_aggregated_matrices = ch_aggregated.concat( ch_matrices_grouped.single )
    ch_aggregated_matrices.dump(tag: "ch_aggregated_matrices")

    ch_versions = ch_versions.mix(PIXELATOR_AGGREGATE.out.versions.first())

    emit:
    matrices = ch_aggregated_matrices           // channel: [ val(meta), [ matrices ] ]
    versions = ch_versions                     // channel: [ versions.yml ]
}
