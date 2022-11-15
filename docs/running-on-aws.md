// TODO: Move this somewhere else before public release

# PixelgenTechnologies/nf-core-pixelator: Running on AWS Batch

## Introduction

This document describes step-by-step instructions on how to run the pipeline using the pixelgen AWS Batch execution environment.

## Setup

This section describes steps you need to take before running nextflow on AWS for the first time.

### Configuring your AWS credentials

Install the [AWS Command Line Interface](https://aws.amazon.com/cli/) tools on your system.
You can check if they are already present by trying the `aws` command.

You must configure your workstation with your credentials and an AWS Region, if you have not already done so. If you have the AWS CLI installed, we recommend running the following command:

`aws configure`

Provide your AWS access key ID, secret access key, and default Region when prompted.
If you already have your account configured you can just press enter to keep the current settings.

You can also manually create or edit the `~/.aws/config` and `~/.aws/credentials` (macOS/Linux) or `%USERPROFILE%\.aws\config` and `%USERPROFILE%\.aws\credentials` (Windows) files to contain credentials and a default Region. Use the following format.

In `~/.aws/config` or `%USERPROFILE%\.aws\config`

```
[default]
region=eu-north-1
```

In ~/.aws/credentials or %USERPROFILE%\.aws\credentials

```
[default]
aws_access_key_id=AKIAI44QH8DHBEXAMPLE
aws_secret_access_key=je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY
```

> **_NOTE:_** These credentials are just an example. Replace them the credentials of your AWS account or just leave it blank.

### Adding the nextflow AWS account credentials

To run nextflow on AWS Batch a separate set of credentials is needed.
Ask Alvaro Martinez Barrio to receive a copy of the credentials.
You can register these credentials with the AWS CLI using a separate "profile" in you credentials file (`~/.aws/credentials` or `%USERPROFILE%\.aws\credentials`)

```

[pixelgen-nf]
aws_access_key_id=EXAMPLE_KEY_ID
aws_secret_access_key=EXAMPLE_ACCESS_KEY

```

Now you can switch the AWS CLI to make requests using these credentials by settings the `AWS_PROFILE` environment variable.

Linux/Mac:

```
export AWS_PROFILE=pixelgen-nf
```

Windows:

```
set AWS_PROFILE=pixelgen-nf
```

## Running nextflow on AWS Batch

You can now run nextflow on AWS Batch by adding `-profile aws` to the nextflow run command.

The samplesheet should contains the path of your input data located either in a S3 bucket or on your local computer.
Different panel configuration can be found under: `s3://pixelgen-nf-input/pixelgen-panels/human-sc-immunology-spatial-proteomics/`

```
sample,design,panel,fastq_1,fastq_2
Sample1_S5_TK18102022,D21PE,s3://pixelgen-nf-input/pixelgen-panels/human-sc-immunology-spatial-proteomics/UNO_D21_conjV6.csv,s3://pixelgen-technologies-ngs/NextSeq2000/221027_VH00725_42_AACCMV7M5/Analysis/1/Data/fastq/Sample1_S5_TK18102022_S1_R1_001.fastq.gz,s3://pixelgen-technologies-ngs/NextSeq2000/221027_VH00725_42_AACCMV7M5/Analysis/1/Data/fastq/Sample1_S5_TK18102022_S1_R2_001.fastq.gz
Sample2_S7_TK18102022,D21PE,s3://pixelgen-nf-input/pixelgen-panels/human-sc-immunology-spatial-proteomics/UNO_D21_conjV6.csv,s3://pixelgen-technologies-ngs/NextSeq2000/221027_VH00725_42_AACCMV7M5/Analysis/1/Data/fastq/Sample2_S7_TK18102022_S2_R1_001.fastq.gz,s3://pixelgen-technologies-ngs/NextSeq2000/221027_VH00725_42_AACCMV7M5/Analysis/1/Data/fastq/Sample2_S7_TK18102022_S2_R2_001.fastq.gz
```

A separate S3 bucket for nextflow output has has been created: s3://pixelgen-nf-output.
Please use a directory in that bucket as the output directory of the pipeline run.

eg:

`nextflow run path/to/nf-core-pixelator -profile aws --input samplesheet.csv --outdir s3://pixelgen-nf-output/my-run-name`

### AWS specific options

#### `--awsqueue`

Valid options:

- nf-batch-spot
- nf-batch-ondemand

This determines which AWS compute environment will be used by default for all Jobs.
The `nf-batch-spot` queue will use compute instances which can be preempted, but they are much cheaper. This should be fine for most jobs.
The `nf-batch-ondemand` queue will use compute instances which cannot be preempted.

Note that you can also fine-tune which steps of the pipeline to run on which environment using the `queue` directive and process selectors in your configuration file.

```
process {
    withLabel: process_high {
      queue = 'nf-batch-ondemand'
  }
}
```
