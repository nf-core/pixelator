#!/bin/bash
# Run tests suitable for quick and broad diagnostic
#   bash tests/run_smoke_tests.sh [args]

ARGS=$@

nf-test test --profile=+docker $ARGS --tag="smoke_test"
