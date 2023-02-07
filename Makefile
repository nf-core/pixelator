SHELL := /bin/bash

.PHONY: tests
tests:
	PROFILE=DOCKER pytest --wt 4

.PHONY: tests-kwd
tests-kwd:
	PROFILE=DOCKER pytest --kwd --wt 4

prettier:
	npx prettier --check .

editor-config:
	npx editorconfig-checker -exclude README.md $(find .* -type f | grep -v '.git\|.py\|.md\|json\|yml\|yaml\|html\|css\|work\|.nextflow\|build\|nf_core.egg-info\|log.txt\|Makefile')

nf-core-lint:
	nf-core lint

black:
	black --check

lint: prettier editor-config nf-core-lint
	echo "All linting successful"
