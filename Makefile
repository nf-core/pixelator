SHELL := /bin/bash

.PHONY: tests
tests:
	PROFILE=DOCKER pytest --wt 4

.PHONY: tests-kwd
tests-kwd:
	PROFILE=DOCKER pytest --kwd --wt 4
