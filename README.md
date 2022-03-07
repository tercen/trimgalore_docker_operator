# TrimGalore Docker operator

##### Description

The TrimGalore Docker operator implements TrimGalore inside Tercen.

TrimGalore is a tool developed by Felix Krueger to filter and trim fastq files.

More information on TrimGalore can be found in the [tool's website](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/).

##### Usage

Input projection|.
---|---
`column`        | documentId, the fastq files (gzipped or not) to be processed.


# Build

```shell
docker build -t tercen/trimgalore-operator:latest .
docker tag tercen/trimgalore-operator:latest fcadete/trimgalore_docker_operator:0.0.2
``` 