include { PIXELATOR_AGGREGATE } from './pixelator_aggregate'
include { PIXELATOR_MAIN } from './pixelator_main'


workflow PIXELATOR {
    if (params.mode && params.mode == "aggregate") {
        PIXELATOR_AGGREGATE()
    } else {
        PIXELATOR_MAIN()
    }
}

