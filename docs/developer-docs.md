# Developer documentation

This documentation covers things that are useful for you as a developer of
nf-core/pixelator but that a should normally not be needed for users of the
pipeline.

## Setting up the developer environment

### Install pre-requisites

Make sure you have node and npm installed then run:

```
npm install
```

Make sure you have conda installed, create a python environment, activate it
and create and install the pre-requisites:

```
conda create --name nf-core-pixelator python=3.8
conda activate nf-core-pixelator
pip install -r requirements.txt
```

### pre-commit hooks

Linting tests and formatting can be run automatically before each commit using pre-commit.
You can install pre-commit into your environment with `pip install pre-commit`.
To register the hooks you can run `pre-commit install --install-hooks`

## Using a private GitHub package repository to get docker containers

You can get docker containers from a private GitHub package repository, but
you need to make sure to configure an access token from GitHub to do so.

First create a Github Access token (using the "Classic" mode) with the following scopes:

- repo (full)
- read:packages

Next create or edit the file: $HOME/.nextflow/scm
and add the `github` block under the providers section.

```
providers {
    github {
        user = 'GitHub username'
        password = '<Your access token>'
    }
}
```

When running with docker you will also have to authenticate your Docker client with the Github Container Registry.

```bash
echo <github PAT token with read_repository scope> | docker login ghcr.io -u <github username> --password-stdin
```

## Running a specific version of nf-core/pixelator

If you want to run a specific version of nf-core/pixelator, e.g. to do release testing, you can do so
by specifying `-r <git branch, tag or revision number>`.

## Running a specific pixelator version

If you need to run a specific version of pixelator, you can add `--pixelator_tag <release tag>` to your version
to see which pixelator versions are available go to https://github.com/PixelgenTechnologies/pixelator/pkgs/container/pixelator
