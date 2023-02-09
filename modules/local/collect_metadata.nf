process COLLECT_METADATA {

    label "process_single"
    cache false

    conda "local::pixelator=0.5.0"
    container 'ghcr.io/pixelgentechnologies/pixelator:0.5.0'

    input:

    output:
    path "metadata.json", emit: metadata

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    #!/usr/bin/env python

    import sys
    import subprocess
    import pkg_resources
    import json

    installed_packages = {i.key: i.version for i in pkg_resources.working_set}

    cutadapt_proc = subprocess.run(["cutadapt", "--version"], capture_output=True, text=True)
    fastp_proc = subprocess.run(["fastp", "--version"], capture_output=True, text=True)

    cutadapt_version = cutadapt_proc.stdout.strip('\\n')
    fastp_version = fastp_proc.stderr.strip('\\n').split(' ')[-1]

    root = {
        "platform": sys.platform,
        "python": {
            "version": {
                "major": sys.version_info.major,
                "minor": sys.version_info.minor,
                "micro": sys.version_info.micro,
                "releaselevel": sys.version_info.releaselevel,
                "serial": sys.version_info.serial,
            },
            "packages": installed_packages
        },
        "fastp": {
            "version": fastp_version
        },
        "cutadapt": {
            "version": cutadapt_version
        }
    }

    with open("metadata.json", 'w') as f:
        json.dump(root, f)
    """
}
