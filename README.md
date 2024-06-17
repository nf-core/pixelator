<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/nf-core-pixelator_logo_dark.png">
    <img alt="nf-core/pixelator" src="docs/images/nf-core-pixelator_logo_light.png">
  </picture>
</h1>

[![GitHub Actions CI Status](https://github.com/nf-core/pixelator/workflows/nf-core%20CI/badge.svg)](https://github.com/nf-core/pixelator/actions?query=workflow%3A%22nf-core+CI%22)
[![GitHub Actions Linting Status](https://github.com/nf-core/pixelator/workflows/nf-core%20linting/badge.svg)](https://github.com/nf-core/pixelator/actions?query=workflow%3A%22nf-core+linting%22)[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/pixelator/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.10015112-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.10015112)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nf-core/pixelator)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23pixelator-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/pixelator)[![Follow on Twitter](http://img.shields.io/badge/twitter-%40nf__core-1DA1F2?labelColor=000000&logo=twitter)](https://twitter.com/nf_core)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**nf-core/pixelator** is a bioinformatics best-practice analysis pipeline for analysis of Molecular Pixelation assays.
It takes a samplesheet as input and will process your data using `pixelator` to produce final antibody counts.

![](./docs/images/nf-core-pixelator-metromap.svg)

1. Build amplicon from input reads ([`pixelator amplicon`](https://github.com/PixelgenTechnologies/pixelator))
2. Read QC and filtering, correctness of the pixel binding sequence sequences ([`pixelator preqc | pixelator adapterqc`](https://github.com/PixelgenTechnologies/pixelator))
3. Assign a marker (barcode) to each read ([`pixelator demux`](https://github.com/PixelgenTechnologies/pixelator))
4. Error correction, duplicate removal, compute read counts ([`pixelator collapse`](https://github.com/PixelgenTechnologies/pixelator))
5. Compute the components of the graph from the edge list in order to create putative cells ([`pixelator graph`](https://github.com/PixelgenTechnologies/pixelator))
6. Call and annotate cells ([`pixelator annotate`](https://github.com/PixelgenTechnologies/pixelator))
7. Analyze the cells for polarization and colocalization ([`pixelator analysis`](https://github.com/PixelgenTechnologies/pixelator))
8. Report generation ([`pixelator report`](https://github.com/PixelgenTechnologies/pixelator))

> [!WARNING]
> Since Nextflow 23.07.0-edge, Nextflow no longer mounts the host's home directory when using Apptainer or Singularity.
> This causes issues in some dependencies. As a workaround, you can revert to the old behavior by setting the environment variable
> `NXF_APPTAINER_HOME_MOUNT` or `NXF_SINGULARITY_HOME_MOUNT` to `true` in the machine from which you launch the pipeline.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,design,panel,fastq_1,fastq_2
uropod_control,D21,human-sc-immunology-spatial-proteomics,uropod_control_300k_S1_R1_001.fastq.gz,uropod_control_300k_S1_R2_001.fastq.gz
```

Each row represents a sample and gives the design, a panel file and the input fastq files.

Now, you can run the pipeline using:

```bash
nextflow run nf-core/pixelator \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

For more details and further functionality, please refer to the [usage documentation](https://nf-co.re/pixelator/usage) and the [parameter documentation](https://nf-co.re/pixelator/parameters).

## Pipeline output

To see the results of an example test run with a full size dataset refer to the [results](https://nf-co.re/pixelator/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://nf-co.re/pixelator/output).

## Credits

nf-core/pixelator was originally written for [Pixelgen Technologies AB](https://www.pixelgen.com/) by:

- Florian De Temmerman
- Johan Dahlberg
- Alvaro Martinez Barrio

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#pixelator` channel](https://nfcore.slack.com/channels/pixelator) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

If you use nf-core/pixelator for your analysis, please cite it using the following doi: [10.5281/zenodo.10015112](https://doi.org/10.5281/zenodo.10015112)

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).

You can cite the Molecular pixelation technology as follows:

> **Molecular pixelation: spatial proteomics of single cells by sequencing.**
>
> Filip Karlsson, Tomasz Kallas, Divya Thiagarajan, Max Karlsson, Maud Schweitzer, Jose Fernandez Navarro, Louise Leijonancker, Sylvain Geny, Erik Pettersson, Jan Rhomberg-Kauert, Ludvig Larsson, Hanna van Ooijen, Stefan Petkov, Marcela González-Granillo, Jessica Bunz, Johan Dahlberg, Michele Simonetti, Prajakta Sathe, Petter Brodin, Alvaro Martinez Barrio & Simon Fredriksson
>
> _Nat Methods._ 2024 May 08. doi: [10.1038/s41592-024-02268-9](https://doi.org/10.1038/s41592-024-02268-9)
