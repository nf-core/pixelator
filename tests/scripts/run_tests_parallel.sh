#!/bin/bash
# Run all tests in parallel
#   bash tests/run_tests_parallel.sh [--update-snapshot,--wipe-snaphot]

ARGS=$@

echo Running tests: experiment summary...
nf-test test --profile test,docker $ARGS \
    modules/local/experiment_summary/ \
    &> /tmp/pixelator_es_tests.txt \
    && echo "Completed tests: experiment summary" &

echo Running tests: PNA modules...
nf-test test --profile test,docker $ARGS \
    modules/local/pixelator/single-cell-pna/ \
    &> /tmp/pixelator_pna_modules_tests.txt \
    && echo "Completed tests: PNA modules" &

echo Running tests: subworkflows...
nf-test test --profile test,docker $ARGS \
    subworkflows/ \
    &> /tmp/pixelator_subworkflow_tests.txt \
    && echo "Completed tests: subworkflows" &

echo Running tests: PNA pipeline V1...
nf-test test --profile test,docker $ARGS \
    tests/proxiome_v1.nf.test \
    &> /tmp/pixelator_pna_pipeline_v1_tests.txt \
    && echo "Completed tests: PNA pipeline" &

echo Running tests: PNA pipeline V2...
nf-test test --profile test,docker $ARGS \
    tests/proxiome_v2.nf.test \
    &> /tmp/pixelator_pna_pipeline_v2_tests.txt \
    && echo "Completed tests: PNA pipeline" &

wait

cat /tmp/pixelator_es_tests.txt           \
    /tmp/pixelator_pna_modules_tests.txt  \
    /tmp/pixelator_subworkflow_tests.txt  \
    /tmp/pixelator_pna_pipeline_v1_tests.txt \
    /tmp/pixelator_pna_pipeline_v2_tests.txt \
