# Pixelator command reference

## Main

    Usage: pixelator [OPTIONS] COMMAND [ARGS]...

    Tool for automated processing Molecular Pixelation data from FASTQ reads.

    Options:
    --version          Show the version and exit.
    --verbose          Show extended messages during execution
    --profile          Activate profiling mode
    --log-file PATH    The path to the log file (it is created if it does not
                        exist)
    --threads INTEGER  The number of threads to use for parallel processing
                        [default: 7]
    --help             Show this message and exit.

    Commands:
    concatenate  process paired-end (PE) raw pixel data (FASTQ) to concatenate
                (stich) forward (R1) and reverse (R2) without overlapping
    preqc        process raw pixel data (FASTQ) to perform QC, filtering,
                trimming and remove duplicates
    adapterqc    process pixel data (FASTQ) to check for the presence of PBS1/2
                sequences
    demux        demultiplex pixel data (FASTQ) to generate one file per
                antibody
    collapse     collapse pixel data (FASTQ) by UMI-UPI to remove duplicates and
                perform error correction
    cluster      compute graph, clusters and other metrics from a edge list
                matrix (CSV)
    report       create a summary web report for all the samples  (you must
                complete all steps before)
    pipeline     performs all the commands using settings (yaml) and samplesheet
                (tsv) files


## Concatenate

    Usage: pixelator concatenate <options> FASTQ_FILES

    Process paired-end (PE) raw Molecular Pixelation data (FASTQ) to concatenate
    (stich) forward (R1) and reverse (R2) without overlapping

    Options:
    --input1-pattern TEXT  What string pattern to use to idenfity forward (R1)
                            files  [default: _R1]
    --input2-pattern TEXT  What string pattern to use to idenfity reverse (R2)
                            files  [default: _R2]
    --output PATH          The path where the results will be placed (it is
                            created if it does not exist)  [required]
    --help                 Show this message and exit.


## preqc

    Usage: pixelator preqc <options> FASTQ_FILES

    Process raw Molecular Pixelation data (FASTQ) to perform QC, filtering,
    trimming and removal of duplicates

    Options:
    --trim-front INTEGER            Trim N bases from the front of the reads
                                    [default: 0]
    --trim-tail INTEGER             Trim N bases from the tail of the reads
                                    [default: 0]
    --max-length INTEGER            The maximum length (bases) of a read (longer
                                    reads will be trimmed off). If you set this
                                    argument it will overrrule the value from
                                    the chosen design
    --min-length INTEGER            The minimum length (bases) of a read
                                    (shorter reads will be discarded). If you
                                    set this argument it will overrrule the
                                    value from the chosen design
    --max-n-bases INTEGER           The maximum number of Ns allowed in a read
                                    [default: 3]
    --avg-qual INTEGER              Minimum avg. quality a read must have (0
                                    will disable the filter)  [default: 20]
    --dedup                         Remove duplicated reads (exact same
                                    sequence)
    --remove-polyg                  Remove PolyG sequences (length of 10 or
                                    more)
    --output PATH                   The path where the results will be placed
                                    (it is created if it does not exist)
                                    [required]
    --design [D12|D12PE|D19|D21PE]  The design to load from the configuration
                                    file  [required]
    --help                          Show this message and exit.

## adapterqc

    Usage: pixelator adapterqc <options> FASTQ_FILES

    Process Molecular Pixelation data (FASTQ) to check for the presence of
    PBS1/2 sequences

    Options:
    --mismatches FLOAT RANGE        The number of mismatches allowed (in
                                    percentage)  [default: 0.1; 0.0<=x<=0.9]
    --pbs1 TEXT                     The PBS1 sequence that must be present in
                                    the reads. If you set this argument it will
                                    overrrule the value from the chosen design
    --pbs2 TEXT                     The PBS2 sequence that must be present in
                                    the reads. If you set this argument it will
                                    overrrule the value from the chosen design
    --output PATH                   The path where the results will be placed
                                    (it is created if it does not exist)
                                    [required]
    --design [D12|D12PE|D19|D21PE]  The design to load from the configuration
                                    file  [required]
    --help                          Show this message and exit.

## demux

    Usage: pixelator demux <options> FASTQ_FILES

    Demultiplex Molecular Pixelation data (FASTQ) to generate one file per
    antibody

    Options:
    --barcodes [D12_v1|D12_v2|D12_v3|D12_v4|D12_v5|D19_v1|D19_v1A|D19_v2|D19_v2A|D21_v1|D21_v2|D21_v3|TBS_v1]
                                    The path to the fasta file containing the
                                    barcodes sequences for each antibody
                                    [default: D12_v1]
    --mismatches FLOAT RANGE        The number of mismatches allowed (in
                                    percentage)  [default: 0.1; 0.0<=x<=0.9]
    --min-length INTEGER            The minimum length of the barcode that must
                                    overlap when matching. If you set this
                                    argument it will overrrule the value from
                                    the chosen design
    --output PATH                   The path where the results will be placed
                                    (it is created if it does not exist)
                                    [required]
    --design [D12|D12PE|D19|D21PE]  The design to load from the configuration
                                    file  [required]
    --help                          Show this message and exit.

## collapse

    Usage: pixelator collapse <options> FASTQ_FILES

    Collapse Molecular Pixelation data (FASTQ) by UMI-UPI to remove duplicates
    and perform error correction

    Options:
    --markers-ignore TEXT           A list of comma separated antibodies to
                                    ignore (discard)
    --algorithm [adjacency|unique]  The algorithm to use for collapsing
                                    (adjacency will peform error correction
                                    using the number of mismatches given)
                                    [default: adjacency]
    --upi1-start INTEGER            The start position (0-based) of UPI1. If you
                                    set this argument it will overrrule the
                                    value from the chosen design
    --upi1-end INTEGER              The end position (1-based) of UPI1. If you
                                    set this argument it will overrrule the
                                    value from the chosen design
    --upi2-start INTEGER            The start position (0-based) of UPI2. If you
                                    set this argument it will overrrule the
                                    value from the chosen design
    --upi2-end INTEGER              The end position (1-based) of UPI2. If you
                                    set this argument it will overrrule the
                                    value from the chosen design
    --umi1-start INTEGER            The start position (0-based) of UMI1
                                    (disabled by default). If you set this
                                    argument it will overrrule the value from
                                    the chosen design
    --umi1-end INTEGER              The end position (1-based) of UMI1 (disabled
                                    by default). If you set this argument it
                                    will overrrule the value from the chosen
                                    design
    --umi2-start INTEGER            The start position (0-based) of UMI2
                                    (disabled by default). If you set this
                                    argument it will overrrule the value from
                                    the chosen design
    --umi2-end INTEGER              The end position (1-based) of UMI2 (disabled
                                    by default). If you set this argument it
                                    will overrrule the value from the chosen
                                    design
    --neighbours INTEGER RANGE      The number of neighbours to use when
                                    searching for similar sequences (adjacency)
                                    This number depends on the sequence depth
                                    and the ratio of erronous molecules
                                    expected. A high value can make the
                                    algoritthm slower.  [default: 60; 1<=x<=250]
    --mismatches INTEGER RANGE      The number of mismatches allowed when
                                    collapsing (adjacency)  [default: 2;
                                    0<=x<=5]
    --min-count INTEGER RANGE       Discard molecules with with a count (reads)
                                    lower than this value  [default: 1; 0<=x<=5]
    --use-counts                    Use counts when collapsing (the difference
                                    in counts between two molecules must be more
                                    than double in order to be collapsed)
    --samples TEXT                  A list of comma separated sample
                                    identifiers. Only the samples included in
                                    this list will be processed. The ids
                                    provided must be present in the names of the
                                    input files  [required]
    --output PATH                   The path where the results will be placed
                                    (it is created if it does not exist)
                                    [required]
    --design [D12|D12PE|D19|D21PE]  The design to load from the configuration
                                    file  [required]
    --help                          Show this message and exit.


## Cluster

    Usage: pixelator cluster <options> COLLAPSED_FILES

    Compute graph, clusters and other metrics from a edge list matrix (CSV)

    Options:
    --min-size INTEGER              The minimum size (pixels) a cluster/cell
                                    must have (default is no filtering)
    --max-size INTEGER              The maximum size (pixels) a cluster/cell
                                    must have (default is no filtering)
    --max-size-recover INTEGER      The maximum size cutoff to use in the
                                    recovery (--big-clusters-recover)  [default:
                                    10000]
    --big-clusters-recover          Enable the recovery of big clusters/cells
                                    (above --max-size-recover) by using the
                                    community modularity approach to remove
                                    problematic edges
    --condition [optimal|max-size]  Which approach to use to select the best
                                    community (--big-clusters-recover) optimal
                                    will use the community that maximizes the
                                    modularity max-size will iterate until the
                                    biggest component in the community is below
                                    --max-size/2 or the maximum number of
                                    iterations is reached  [default: optimal]
    --min-count INTEGER RANGE       Discard molecules (edges) with with a count
                                    (reads) lower than this  [default: 2;
                                    1<=x<=50]
    --compute-polarization          Compute polarization scores matrix (clusters
                                    by markers)
    --compute-colocalization        Compute colocalization scores matrix
                                    (clusters by markers)
    --compute-coabundance           Compute coabundance scores matrix (clusters
                                    by markers)
    --percentile FLOAT RANGE        The percentile value (0-1) to use when
                                    binarizing counts in the polarization and
                                    co-localization algorithms  [default: 0.0;
                                    0.0<=x<=1.0]
    --output PATH                   The path where the results will be placed
                                    (it is created if it does not exist)
                                    [required]
    --help                          Show this message and exit.

## Report

    Usage: pixelator report <options> RESULTS_FOLDER

    Create a summary web report for all the samples (must complete all steps
    first)

    Options:
    --name TEXT     The name of the dataset to be included in the report
                    [required]
    --samples TEXT  A list of comma separated sample identifiers. Only the
                    samples included in this list will be included in the
                    report. The ids provided must be present in the names of the
                    input files  [required]
    --output PATH   The path where the results will be placed (it is created if
                    it does not exist)  [required]
    --help          Show this message and exit.
