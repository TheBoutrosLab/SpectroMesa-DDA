# Installing SpectroMesa-DDA

## Requirements

SpectroMesa-DDA can be run on a Linux workstation or a cluster compute node with an x86-64 processor. Before you begin, make sure you can access your mass spectrometry data and protein sequence database from that machine, and reserve working storage for the files the pipeline creates along the way. Measure storage use in a pilot run before sizing a large cohort.

Install or load the following on the machine that launches the pipeline:

| Software | Requirement |
| --- | --- |
| Nextflow | **24.10.6** with the **v1 syntax parser** is recommended. See below for selecting the version and parser. |
| Container runtime | Docker or Apptainer. Choose the runtime available on your workstation or cluster. |

Most analysis tools, including OpenMS, Comet, Sage, MSBooster, Percolator, and ProteoVault, are supplied through the configured container images. MSFragger must be obtained separately when you select it as a search engine. Comet-only and Sage-only runs do not need its JAR.

## Set up Nextflow

We recommend **Nextflow 24.10.6**. If you already have a newer Nextflow launcher installed, you can select the recommended version and syntax parser with these environment variables:

```bash
export NXF_VER=24.10.6
export NXF_SYNTAX_PARSER=v1
```

`NXF_VER` selects the Nextflow version, and `NXF_SYNTAX_PARSER` selects its syntax parser. To use a newer version, set `NXF_VER` to that release and keep `NXF_SYNTAX_PARSER=v1`, provided the release still supports the v1 parser. Version 24.10.6 remains our tested recommendation.

Nextflow 24.10.6 requires a compatible Java installation (Java 17–23); Java 17 or 21 is a suitable choice. If Nextflow is not installed, use the [official launcher](https://docs.seqera.io/nextflow/install). For a user-local installation, run the following with the environment settings above already exported:

```bash
mkdir -p "$HOME/.local/bin"
curl -fsSL https://get.nextflow.io -o "$HOME/.local/bin/nextflow"
chmod +x "$HOME/.local/bin/nextflow"
export PATH="$HOME/.local/bin:$PATH"
nextflow -version
```

## Get the pipeline

### Download a release (recommended)

The easiest way to get started is to [download the latest release with all submodules](https://github.com/TheBoutrosLab/SpectroMesa-DDA/releases/latest/download/source_code_with_submodules.tar.gz).

To download the latest release from a terminal, use either `wget`:

```bash
wget -O source_code_with_submodules.tar.gz https://github.com/TheBoutrosLab/SpectroMesa-DDA/releases/latest/download/source_code_with_submodules.tar.gz
```

or `curl`:

```bash
curl -fL -o source_code_with_submodules.tar.gz https://github.com/TheBoutrosLab/SpectroMesa-DDA/releases/latest/download/source_code_with_submodules.tar.gz
```

From the directory containing your download, extract it into a folder for the pipeline:

```bash
mkdir -p SpectroMesa-DDA
tar -xzf source_code_with_submodules.tar.gz -C SpectroMesa-DDA --strip-components=1
cd SpectroMesa-DDA
```

You can now continue to [check the container runtime](#check-the-container-runtime).

### Clone with Git (alternative)

If you prefer to work from a Git checkout, clone the repository with all nested submodules:

```bash
git clone --recurse-submodules git@github.com:TheBoutrosLab/SpectroMesa-DDA.git SpectroMesa-DDA
cd SpectroMesa-DDA
```

Some submodules use GitHub SSH URLs, so this command requires working GitHub SSH authentication and access to the repositories. To use HTTPS instead, use this alternative clone command:

```bash
git -c 'url.https://github.com/.insteadOf=git@github.com:' \
    clone --recurse-submodules \
    https://github.com/TheBoutrosLab/SpectroMesa-DDA.git SpectroMesa-DDA
cd SpectroMesa-DDA
```

For an existing checkout, initialize any missing submodules from its root:

```bash
git submodule update --init --recursive
```

When using HTTPS, apply the same command-scoped URL rewrite:

```bash
git -c 'url.https://github.com/.insteadOf=git@github.com:' \
    submodule update --init --recursive
```

The submodules provide the analysis software and configuration included with this pipeline. Keep their versions matched to the pipeline checkout. Check their status with:

```bash
git submodule status --recursive
```

A leading space indicates the recorded revision is checked out. A leading `-` means a submodule is not initialized; `+` means it differs from the recorded revision.

## Check the container runtime

Choose one runtime and use its matching Nextflow profile when launching an analysis:

| Runtime | Check | Pipeline profile |
| --- | --- | --- |
| Docker | `docker info` | `-profile docker` |
| Apptainer | `apptainer --version` | `-profile apptainer` |

Make sure Docker is running and accessible to your account, or that Apptainer is installed on the machines where the analysis will run. Docker and Apptainer are the documented end-to-end choices. A Singularity profile exists at the top level, but the pinned QC pipeline does not declare it; use Apptainer for that runtime family.

For Apptainer, configure persistent caches before launching a run. Use directories you own that are accessible from the execution nodes:

```bash
export NXF_APPTAINER_CACHEDIR="$HOME/.cache/nextflow/apptainer"
export APPTAINER_CACHEDIR="$HOME/.apptainer/cache"
mkdir -p "$NXF_APPTAINER_CACHEDIR" "$APPTAINER_CACHEDIR"
```

!!! tip "Reuse container images across runs"
    Use shared filesystem paths instead if your home directory is not available on those nodes. Both caches are relevant: some stages use Nextflow-managed images, while others use Apptainer's own image cache.

## Obtain MSFragger

MSFragger is the default search engine. Skip this section if your analysis uses only Comet or Sage.

Download MSFragger through its [official download instructions](https://github.com/Nesvilab/MSFragger) under the license appropriate to your use. Keep the extracted distribution in a persistent directory accessible to the analysis tasks. The pipeline requires the path to the JAR, not the containing directory.

In your run configuration, set:

```groovy
params.msfragger_executable = '/path/to/MSFragger/MSFragger.jar'
```

Replace the example with the actual filename, which may include a version number. The pipeline does not download this JAR for you.

## Storage and compute environment

Keep the repository, external tools, input data, and work and output directories accessible to the execution environment. Allow working storage for converted mzML files, feature maps, intermediate identifications, and container images. Space requirements depend on the cohort and should not be estimated from final output size alone.

!!! important "Request cluster resources before launching"
    Request a cluster allocation before launching the analysis. The bundled `pines` and `boutroslab_aws` profiles specify CPU and memory settings; they do not submit a Slurm job for you. Combine the resource and container profiles, for example `-profile pines,apptainer`.

## Verify the setup

From the pipeline directory, check:

```bash
export NXF_VER=24.10.6
export NXF_SYNTAX_PARSER=v1
nextflow -version
test -f main.nf
test -f config/template.config
test -f external/search-ProteomicMSMS/main.nf
test -f external/validate-ProteomicPSM/main.nf
test -f external/quantitate-ProteomicLFQ/main.nf
test -f external/quantitate-ProteomicTMT/main.nf
```

Confirm the expected Nextflow version, a working container runtime, and readable tool files. If you installed through Git, also check the submodule status as described above. The `test` commands produce no output when successful and return a nonzero exit status if a file is missing. These checks verify installation prerequisites; they do not run a proteomics analysis or validate all container images.

Next, prepare the acquisition table and target-decoy FASTA and create a run configuration from the repository's `config/template.config`. Preserve its `includeConfig` statements and final `methods.setup()` call. Input preparation, scientific settings, and analysis execution are separate from installation.

## Preview the documentation

To work on the documentation locally, install MkDocs in a separate Python environment:

```bash
python3 -m venv /path/to/mkdocs-env
source /path/to/mkdocs-env/bin/activate
python -m pip install "mkdocs==1.5.3"
mkdocs serve -f /path/to/SpectroMesa-DDA/mkdocs-config.yaml
```

Open [http://127.0.0.1:8000/](http://127.0.0.1:8000/) in your browser. Initialize the pipeline submodules first: the site reads their original flowcharts during the build. Use `--dev-addr 127.0.0.1:8001` if another documentation server is already using port 8000.
