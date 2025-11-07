#!/bin/bash
# Run all tests in parallel
#   bash tests/run_tests_parallel.sh [--update-snapshot,--wipe-snaphot]

ARGS=$@

nf-test test --profile test,docker $ARGS \
    modules/local/pixelator/single-cell-mpx/ \
    --tap /tmp/pixelator_mpx_modules_tests.txt &> /dev/null &
nf-test test --profile test,docker $ARGS \
    modules/local/pixelator/single-cell-pna/ \
    --tap /tmp/pixelator_pna_modules_tests.txt &> /dev/null &
nf-test test --profile test,docker $ARGS \
    subworkflows/ \
    --tap /tmp/pixelator_subworkflow_tests.txt &> /dev/null &
nf-test test --profile test,docker $ARGS \
    tests/pna.nf.test \
    --tap /tmp/pixelator_pna_pipeline_tests.txt &> /dev/null &
nf-test test --profile test,docker $ARGS \
    tests/mpx.nf.test \
    --tap /tmp/pixelator_mpx_pipeline_tests.txt &> /dev/null &

wait

cat /tmp/pixelator_mpx_modules_tests.txt  \
    /tmp/pixelator_pna_modules_tests.txt  \
    /tmp/pixelator_subworkflow_tests.txt  \
    /tmp/pixelator_pna_pipeline_tests.txt \
    /tmp/pixelator_mpx_pipeline_tests.txt
