# Running the tests

The integration tests run SpectroMesa-DDA on small reference datasets to check that the analysis completes in your computing environment. You will need the installed pipeline, the public test data, the required search software, and **UCLA NFTest**. Start with one case before trying the other acquisition and quantitation routes.

## Install the test tools

Complete the [pipeline installation](installation.md), including its submodules, Java, Nextflow, and the container runtime you will use. The test launcher also needs Python 3.8 or newer and [UCLA NFTest (`uclahs-cds/tool-NFTest`)](https://github.com/uclahs-cds/tool-NFTest).

You can keep the Python tools in a dedicated environment:

```bash
python3 -m venv "$HOME/.venvs/spectromesa-tests"
source "$HOME/.venvs/spectromesa-tests/bin/activate"
python3 -m pip install \
    "git+https://github.com/uclahs-cds/tool-NFTest.git" \
    PyYAML python-dotenv
python3 -m nftest --help
```

If your NFTest version imports `pkg_resources`, install `setuptools<81` in this environment.

Activate this environment whenever you run a test, including inside a cluster job. The launcher uses NFTest from the same Python environment as `python3`.

Use the tested Nextflow settings:

```bash
export NXF_VER=24.10.6
export NXF_SYNTAX_PARSER=v1
```

## Download the public test data

The Boutros Lab public S3 location is `s3://boutroslab-public/test-data/`. DDA fixtures are under `spectromesa/ecoli_lfq/`, `spectromesa/ecoli_tmt/`, and `spectromesa/database/`. Install the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), then choose a persistent directory:

```bash
export TEST_DATA_DIR=/path/to/test/data
mkdir -p "$TEST_DATA_DIR"

aws s3 sync --no-sign-request \
    s3://boutroslab-public/test-data/spectromesa/database/ \
    "$TEST_DATA_DIR/database/"
aws s3 sync --no-sign-request \
    s3://boutroslab-public/test-data/spectromesa/ecoli_lfq/mzML/ \
    "$TEST_DATA_DIR/ecoli_lfq/mzML/"
aws s3 sync --no-sign-request \
    s3://boutroslab-public/test-data/spectromesa/ecoli_tmt/mzML/ \
    "$TEST_DATA_DIR/ecoli_tmt/mzML/"
```

For the RAW conversion case, also download:

```bash
aws s3 sync --no-sign-request \
    s3://boutroslab-public/test-data/spectromesa/ecoli_tmt/Raw/ \
    "$TEST_DATA_DIR/ecoli_tmt/Raw/"
```

`--no-sign-request` allows these public downloads without AWS credentials. Keep the directory names and filenames intact. The repository supplies the test acquisition and channel CSVs, so you do not need to construct them manually.

### Match the test database

!!! important "Update the older FASTA path in the selected test"
    The checked-in test configurations currently name an older FASTA that is not in the public fixture listing. Before running a case with the public download, update its database path and accession markers together. The available FASTA below uses `DECOY_` decoys and `contam_` contaminants.

In the selected `test/<case>/test.config`, use:

```groovy
params {
    decoy_database = "${TEST_DATA_DIR}/database/UP000000625_83333-FragPipe/2026-11-12-decoys-contam-input.fasta.fas"
    decoy_string = 'DECOY_'
    decoy_position = 'prefix'
    contam_string = 'contam_'
    contam_position = 'prefix'
}
```

Edit the existing values before `methods.setup()`; preserve the rest of the test's scientific settings. The shared database markers are propagated to search, validation, and protein quantitation. Changing the FASTA changes the scientific test input, so record the database used when comparing runs. The E. coli TMT fixture is described as a protein-spike experiment: verify that your sequence set contains any spike proteins you intend to evaluate; a workflow completion test is not a benchmark of their recovery.

### Supply MSFragger separately

For MSFragger cases, obtain the licensed distribution as described in [Installation](installation.md#obtain-msfragger), and place `MSFragger-4.4.1.jar` directly under `TEST_DATA_DIR`, or update the selected test's JAR path. The public bucket download does not supply this JAR. The Sage LFQ case does not need MSFragger.

## Configure the test environment

Unlike ordinary analyses, the test launcher is run from the repository root because it reads the repository's `nftest.yml`. Copy `.env-template` to `.env` if you have not already configured it:

```bash
cd /path/to/SpectroMesa-DDA
cp .env-template .env
```

Edit `.env` with your paths and execution environment:

```text
NXF_VER=24.10.6
NXF_SYNTAX_PARSER=v1
TEST_DATA_DIR=/path/to/test/data
NFT_RUN_ROOT=/scratch/your_user/spectromesa-dda-tests
NFT_CLUSTER=pines
```

| `NFT_CLUSTER` | Execution environment | Run location |
| --- | --- | --- |
| `pines` | Apptainer with the 64 CPU, 500 GB resource plan | `NFT_RUN_ROOT` |
| `boutroslab_aws` | Docker with the 32 CPU, 128 GB resource plan; requires `SLURM_JOB_ID` | `NFT_RUN_ROOT/SLURM_JOB_ID` |
| Unset or empty | Docker with the AWS resource plan | `NFT_RUN_ROOT` |

Request an appropriate compute allocation first. These resource plans do not submit a cluster job. Relative `NFT_RUN_ROOT` values resolve from the repository root; if unset, the root defaults to the repository. For Apptainer, set persistent caches as described in [Installation](installation.md#check-the-container-runtime).

## Run a test case

Activate the Python environment containing UCLA NFTest and run one case from the repository root:

```bash
python3 test/run-nftest.py test_integration_MSFragger_LFQ_Protein
```

The current cases are:

| Case | Coverage | ProteoVault |
| --- | --- | --- |
| `test_integration_MSFragger_LFQ_Protein` | MSFragger, two fractions per LFQ sample, ProteinProphet, QC | Disabled in the test configuration |
| `test_integration_Sage_LFQ_Protein` | Sage on the same fractionated LFQ fixture, ProteinProphet, QC | Enabled |
| `test_integration_MSFragger_TMT_Protein` | MSFragger, three fractions per TMT plex, experimental feature-based TMT with MAD normalization, ProteinProphet, QC | Disabled in the test configuration |
| `test_integration_MSFragger_TMT_Reindexed` | Two fractions per TMT plex, spectrum reindexing, scan-based TMT, ProteinProphet, QC | Enabled |
| `test_integration_MSFragger_TMT_RAW` | RAW conversion, one acquisition per TMT plex, scan-based TMT, ProteinProphet, QC | Enabled |

Use the case name as the launcher's argument. Start with one case and resolve its setup errors before running the full set. The supplied cases exercise workflow completion and file handoffs; `nftest.yml` does not define numerical assertions for biological results.

## Inspect the run

Results are written under `<run-root>/<test-case>/`; temporary work is under `<run-root>/.nftest-temp/<12-character case ID>/`. The launcher retains temporary files to help investigate failures. Check the final exit status, logs, expected quantitative outputs, and QC summaries. A successful setup check or a partially populated output directory is not evidence that the integration test completed.

The test CSVs expand `TEST_DATA_DIR` through the supplied launcher configuration. Ordinary analysis CSVs should contain actual paths as described in [Preparing inputs](inputs.md). Keep the test work directories while investigating a failure and review the [resume limitations](execution.md#resume-an-interrupted-run) before relaunching.
