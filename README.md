# metapipeline-ProteomicDDA

This Boutros Lab metapipeline optionally converts vendor RAW or other supported MS data to mzML, searches DDA mzML files with Comet, Sage, or MSFragger, validates peptide-spectrum matches (PSMs), quantifies peptides with TMT or label-free quantitation (LFQ), quantifies proteins with ProteinProphet or ProteinInferencer, runs DDA quality control, and builds a ProteoVault database.

![DDA metapipeline schematic](docs/pipeline-flow.svg)

## Quick start

1. Initialize the child pipelines and shared Boutros Lab modules:

   ```bash
   git submodule update --init --recursive
   ```

2. Prepare the [input CSV](input/input.csv) and a target-decoy FASTA. All input files must have the same format. Non-mzML input automatically runs through `convert-MSData`. Obtain the MSFragger JAR separately if MSFragger is selected. For TMT, prepare a channel CSV with the format required by [quantitate-ProteomicTMT](external/quantitate-ProteomicTMT/README.md).
3. Copy [config/template.config](config/template.config) to a run-specific file. Set `input_csv`, `decoy_database`, `output_dir`, `dataset_id`, `experiment_type`, and the selected search engines. Set `channel_csv` for TMT and `msfragger_executable` when using MSFragger. Keep the template's `includeConfig` lines and final `methods.setup()` call.
4. Run with Nextflow 24.10.6 and its v1 syntax parser. Choose a work directory with enough space for the mzML files and child pipeline work:

   ```bash
   export NXF_VER=24.10.6
   export NXF_SYNTAX_PARSER=v1
   export NXF_WORK=/scratch/$SLURM_JOB_ID/metapipeline-ProteomicDDA-work
   nextflow run main.nf -c /path/to/run.config -profile pines
   ```

The scratch path is an example for a Slurm job; use another suitable work directory outside Slurm. Select `pines` for a 64 CPU, 500 GB node or `boutroslab_aws` for a 32 CPU, 128 GB node. Add `standard` or `docker` for Docker, `apptainer` for Apptainer, or `singularity` for Singularity, for example `-profile pines,apptainer`. The runtime profile configures the parent ProteoVault process and passes the matching `child_profile` to each child. `standard` uses Docker by default when no runtime profile is selected. Nextflow's `-c` option adds the run configuration to the project's configuration; see the [Nextflow configuration documentation](https://www.nextflow.io/docs/latest/config.html).

### Resource profiles

| Profile | Node budget | Parent child-launch processes |
| --- | --- | --- |
| `pines` | 64 CPUs, 500 GB | 2 CPUs, 4 GB per launcher. |
| `boutroslab_aws` | 32 CPUs, 128 GB | 2 CPUs, 4 GB per launcher. |

Parent CSV and configuration tasks request 1 CPU and 2 GB; parent child-launch tasks request 2 CPUs and 4 GB, and ProteoVault requests up to 8 CPUs and 64 GB from [config/resources.json](config/resources.json). The bundled JSON profiles set `max_cpus` and `max_memory` for the parent and children. Their `children` process-allocation entries are **not applied** by the current DDA metapipeline; each child uses its own resource defaults unless its namespace supplies `base_resource_update`. These profiles describe node budgets; they do not select a Slurm partition or change the local executor.

For a profile outside the repository, copy [pines.json](config/resource_profiles/pines.json) or [boutroslab_aws.json](config/resource_profiles/boutroslab_aws.json) to a directory you control, rename it `<name>.json`, and edit its `max_cpus` and `max_memory`. Set these values in the run config:

```groovy
params.compute_profile = 'my_cluster'
params.additional_resource_profile_dir = '/path/to/resource_profiles'
```

A matching Nextflow `-profile` entry is not required when `compute_profile` is set directly. `additional_resource_profile_dir` can contain multiple directories separated by the operating system's PATH separator (`:` on Linux/macOS). Lookup checks those directories from left to right, then the bundled `config/resource_profiles` directory. Relative directories resolve from the launch directory.

## Inputs

The input CSV has these required columns; `annotation_id` is needed only when ProtLoom is enabled. When all paths have the same non-mzML extension, the input is sent to the selected converter; `scan` is an optional column required for WIFF files:

```csv
sample_name,fraction_id,path
sample_01,1,/data/sample_01_fraction_1.mzML
sample_01,2,/data/sample_01_fraction_2.mzML
sample_02,1,/data/sample_02_fraction_1.mzML
sample_02,2,/data/sample_02_fraction_2.mzML
```

| Input | Requirement |
| --- | --- |
| `sample_name` | Sample name for LFQ, or plex ID for TMT. A name may appear in multiple rows when its `fraction_id` differs. |
| `fraction_id` | Required identifier unique within each sample or plex. LFQ samples must have the same set of fraction IDs. |
| `path` | Existing mzML or a format supported by the selected converter. Relative paths resolve from the input CSV's directory. All rows must have the same file extension; mixed formats are rejected. Conversion inputs must have basenames without additional dots. |
| `scan` | Optional conversion input column; required for WIFF scan companion files. Relative paths resolve from the input CSV's directory. |
| `annotation_id` | Optional column for ordinary runs. Required with ProtLoom; all fractions of a sample must have the same ID, which must occur in the ProtLoom project YAML. |
| `decoy_database` | Existing target-decoy FASTA shared by search, validation, and protein quantitation. |
| `msfragger_executable` | Separately obtained MSFragger JAR, required only when `MSFragger` is selected. |
| `channel_csv` | Required for TMT. Its `plex_id` values must match the input CSV's `sample_name` values. |

A TMT plex may contain several mzML fractions. The metapipeline infers fractionation from the input CSV and sets the validation and LFQ child options automatically. Either every sample or plex must have multiple fractions, or every one must have a single fraction; mixed layouts are rejected. LFQ samples must also have the same fraction IDs.

### ProtLoom project YAML

The validation child accepts a project YAML with `schema_version: 1`, `annotations` containing unique `annotation_id` values and existing GTF files, and `database.output_fasta` and `database.output_entries_tsv` pointing to existing files. Database decoy and contaminant markers must match the root run settings. The metapipeline generates the `samples` section from the input CSV, writes `protloom-project.generated.yaml` under `manifests/`, and resolves relative database, GTF, and FASTA source paths against the original YAML location.

ProtLoom also requires `validate_ProteomicPSM.percolator_workflow = 'msbooster'` and nonempty `protloom_pt_order` and `protloom_pc_order`. The current parent protein handoff for ProtLoom is incomplete; see [Current limitations](#current-limitations) before selecting this route.

## Parameters

Set shared values once at the root of the run config. `methods.setup()` derives the child-specific database and decoy settings before writing child parameter JSON files. Settings specific to one child belong in its namespace. Values passed by the metapipeline's child-call processes should not be repeated in a run config.

| Root parameter | Default | Purpose |
| --- | --- | --- |
| `input_csv` | Required | Sample-to-fraction MS data CSV. |
| `decoy_database` | Required | Target-decoy FASTA. |
| `experiment_type` | `LFQ` | Selects `LFQ` or `TMT` peptide quantitation. |
| `channel_csv` | Required for TMT | Reporter-channel manifest. |
| `msfragger_executable` | Required for MSFragger | Search-engine JAR. |
| `output_dir` | Required | Root directory for published results and logs. |
| `dataset_id` | `cohort` | Cohort result directory and child project name. |
| `decoy_string` / `decoy_position` | `DECOY_` / `prefix` | Shared decoy accession marker. MSFragger requires a prefix. |
| `contam_string` / `contam_position` | `CONTAMINANT_` / `prefix` | Contaminant marker, also checked against the ProtLoom YAML. |
| `child_profile` | `standard` | Container-runtime profile passed to each child. |
| `proteovault_version` | `0.2.1` | Version used for the ProteoVault image. |
| `docker_image_proteovault` | `ghcr.io/theboutroslab/proteovault:${params.proteovault_version}` | Container image for the parent ProteoVault process. |
| `compute_profile` | None | Node budget selected by `-profile pines`, `-profile boutroslab_aws`, or directly. |
| `additional_resource_profile_dir` | None | Optional PATH-style list of external resource-profile directories. |

### `convert_MSData` — optional MS data conversion

An input CSV containing uniform non-mzML paths runs [convert-MSData v1.1.1](external/convert-MSData/README.md) once for all input samples and fractions. The child writes mzML files under its versioned directory; the parent generates `conversion.csv` and `converted-input.csv` manifests and uses the converted mzML for search, validation, quantitation, and QC. Converted files retain their input basenames when these are unique within each sample. If any sample repeats an input basename, every output gains its fraction ID as a suffix. Keep `output_format = 'mzML'`. Select `convert_algorithm = 'ProteoWizard'` for supported vendor formats or `OpenMS` for supported open formats. Peak picking, indexing, and `pwiz_extra_args` are configured in `convert_MSData`; see the [conversion parameters](external/convert-MSData/README.md#config). The conversion child uses the same `child_profile` and compute budget as the other children.

### `search_ProteomicMSMS` — database search

| Parameter | Default | Purpose |
| --- | --- | --- |
| `search_engines` | `['MSFragger']` | Any nonempty combination of `Comet`, `Sage`, and `MSFragger`. |
| `CometAdapter`, `SageAdapter`, `MSFraggerAdapter` | Child defaults | Engine-specific tolerances, enzymes, modifications, and other OpenMS adapter settings. |
| `reindex_mzml` | `false` | Set true to assign unique native scan IDs across a sample's fractions. The reindexed mzML files are passed to validation and peptide quantitation. |
| `export_mzTab` | `false` | Optional search-stage mzTab export. |

The root `decoy_string` and `decoy_position` are copied into each selected adapter's `PeptideIndexing` settings; Sage also receives its `decoy_prefix`. See the [search pipeline configuration](external/search-ProteomicMSMS/config/template.config) and [schema](external/search-ProteomicMSMS/config/schema.yaml) for adapter options. Search results are merged per sample and engine before validation.

### `validate_ProteomicPSM` — PSM validation

| Parameter | Default | Purpose |
| --- | --- | --- |
| `run_percolator` | `true` | Produce PEP-scored identifications for ProteinProphet. |
| `percolator_workflow` | `openms` | Use `openms` or `msbooster`; the latter adds MSBooster features before direct Percolator scoring. |
| `msbooster_params` | Child bundled file | Optional override for MSBooster prediction settings. |
| `merge_consensus` | `false`; enabled automatically for multiple engines | Produce one validated consensus idXML per sample for peptide quantitation. |
| `fractionated` | Inferred from input CSV | Split each search engine's idXML by fraction before consensus merging when enabled. |
| `run_protloom` | `false` | Enable ProtLoom inference; currently blocked by the parent protein handoff. |
| `protloom_project_yaml` | None | Base project YAML required with ProtLoom. |
| `protloom_pt_order` / `protloom_pc_order` | Empty | Required ordering settings when ProtLoom is enabled. |
| `export_easypqp_reports` | Child default: `false` | DDA does not need EasyPQP reports. |

The parent passes the search idXML manifest, the mzML files used for search, and target-decoy FASTA to validation. When search reindexing is enabled, it maps each reindexed file back to its fraction by input CSV order. MSBooster, QC, and ProteoVault use the same mzML manifest, keeping their run names aligned with the validated idXML. The child publishes per-engine filtered idXML and unfiltered PEP-scored idXML; multiple engines also produce a filtered consensus idXML. See the [validation pipeline parameters](external/validate-ProteomicPSM/README.md#config) for filtering and inference options.

### `quantitate_ProteomicTMT` — isobaric quantitation

| Parameter | Default | Purpose |
| --- | --- | --- |
| `plex_type` | `tmt10plex` | Reporter-label set. |
| `tmt_workflow` | `scan_based` | Select reporter-scan quantitation or the experimental `feature_based` MS1 workflow. |
| `tmt_normalization_method` | Child default | Select the TMT normalization route, such as `mad`. |
| `consensusXML_entrypoint` | `false` | The metapipeline supplies mzML, idXML, and channel manifests. |

The TMT v2.1.0 child receives one validated idXML per plex and the same mzML fractions supplied to validation, including reindexed files when enabled. Channel labels come from `channel_csv`. For `feature_based`, give every plex the same set of `fraction_id` values and set `tmt_normalization_method = 'mad'` when normalization is enabled. Both TMT workflows publish one dataset-level consensusXML and peptide CSV. See the [TMT pipeline parameters](external/quantitate-ProteomicTMT/README.md) for correction matrices, normalization, and reporter-channel options.

### `quantitate_ProteomicLFQ` — label-free quantitation

| Parameter | Default | Purpose |
| --- | --- | --- |
| `algorithm` | `FFId` | FeatureFinderIdentification route used by this metapipeline. |
| `fractionated` | Inferred from input CSV | Use the fractionated LFQ workflow when each sample has multiple mzML fractions. |
| `ffid_strategy` | Child default: `merged` | Identification strategy within FeatureFinderIdentification. |
| `merge_featureXML` | Child default: `true` | Produce consensusXML for protein quantitation. |

The LFQ v1.1.0 child receives one validated idXML per sample and the sample-to-fraction mzML manifest. It publishes the final IDConflictResolver consensusXML directly under its output directory. See the [LFQ pipeline parameters](external/quantitate-ProteomicLFQ/README.md) for feature finding, alignment, and linking options.

### `quantitate_ProteomicProtein` — protein quantitation

| Parameter | Default | Purpose |
| --- | --- | --- |
| `protein_grouping_algorithm` | `ProteinProphet` | `ProteinProphet` or `ProteinInferencer`. |
| `protein_fdr_cutoff` | `0.01` | Protein FDR cutoff when the selected child workflow enables protein FDR filtering. |

The metapipeline passes the final LFQ or TMT IDConflictResolver consensusXML to protein quantitation. ProteinProphet also receives the per-engine, PEP-scored idXML files from validation. The v1.3.0 protein child labels its protein and peptide abundance columns from the quantified consensusXML. See the [protein pipeline parameters](external/quantitate-ProteomicProtein/README.md) for inference and filtering controls. Root-level `decoy_database` and `decoy_string` are passed to this child.

### `qc_ProteomicDDA` — quality control

The QC child runs after protein quantitation. It uses the original mzML fractions, the published unfiltered search and final filtered identification manifests, available PSMFeatureExtractor idXML and MSBooster PIN files from validation, the final ProteinProphet idXML or ProteinInferencer consensusXML, and both ProteinQuantifier abundance tables. Set optional QC-specific parameters in `qc_ProteomicDDA`; see the [QC pipeline parameters](external/qc-ProteomicDDA/README.md). The parent supplies all required input paths, `dataset_id`, and `inference_route`.

### ProteoVault — cohort database

After QC, the metapipeline builds and validates a ProteoVault v0.2.1 DuckDB database from the published search, validation, TMT or LFQ, protein quantitation, and QC outputs. It supplies the acquisition manifest, target-decoy FASTA, and the channel CSV for TMT. The database includes core quantities, identified TMT reporter observations when available, protein inference, and QC metrics. ProteoVault is skipped when `validate_ProteomicPSM.run_protloom = true`, because that route does not complete the current protein handoff. The database is published at the versioned metapipeline output root. It records paths from the build work directory; after relocating the result, use `proteovault update-paths` to update stored source paths. See the [ProteoVault v0.2.1 CLI guide](https://github.com/TheBoutrosLab/package-ProteoVault/blob/v0.2.1/docs/cli.md).

See [config/template.config](config/template.config) for an editable run configuration and [config/schema.yaml](config/schema.yaml) for root parameter validation.

## Pipeline steps and outputs

1. For uniform non-mzML input, `convert-MSData` converts all input files to mzML and passes the resulting files to the remaining stages.
2. `search-ProteomicMSMS` searches each mzML with the selected engines and merges fractions into one idXML per sample and engine.
3. `validate-ProteomicPSM` scores and filters PSMs. When several engines are selected, it produces a per-sample consensus idXML for peptide quantitation.
4. `quantitate-ProteomicTMT` or `quantitate-ProteomicLFQ` quantifies peptides according to `experiment_type`.
5. `quantitate-ProteomicProtein` uses peptide consensusXML and, for ProteinProphet, unfiltered PEP-scored idXML to quantify proteins.
6. `qc-ProteomicDDA` summarizes acquisition, search, PSM features, validated identifications, protein groups, and abundance, and creates per-fraction interactive MS1 plots.
7. ProteoVault builds and validates a DuckDB database from the completed DDA results.

Versioned child pipeline directories and handoff manifests are published at:

```text
<output_dir>/metapipeline-ProteomicDDA-<version>/
├── <dataset_id>.proteovault.duckdb
└── <dataset_id>/
    ├── main_workflow/
    │   ├── convert-MSData-<version>/            # conversion runs only
    │   ├── search-ProteomicMSMS-<version>/
    │   ├── validate-ProteomicPSM-<version>/
    │   ├── quantitate-ProteomicTMT-<version>/   # TMT runs only
    │   ├── quantitate-ProteomicLFQ-<version>/   # LFQ runs only
    │   ├── quantitate-ProteomicProtein-<version>/
    │   ├── qc-ProteomicDDA-<version>/
    │   └── manifests/
    └── log-metapipeline-ProteomicDDA-<version>-<timestamp>/
```

`manifests/` contains `search.csv`, `validation.csv`, `validation-mzml.csv`, `quant-idxml.csv`, `quant-mzml.csv`, `protein-unfiltered.csv`, `qc-mzml.csv`, and `qc-psm-features.csv`. LFQ runs also publish the merged `protein-cohort.consensusXML` there. Conversion runs also publish `conversion.csv` and `converted-input.csv`. The feature manifest has a header but no data rows when validation publishes no feature files. ProtLoom runs also publish `protloom-project.generated.yaml`. The QC child writes `<dataset_id>_QC_metrics.tsv` and per-stage metrics and plots under its versioned output directory. Each child directory contains its scientific results and its own logs. The ProteoVault database records source paths from its build work directory; publishing does not rewrite paths inside it. The timestamped metapipeline log directory contains the parent Nextflow trace, timeline, report, and effective parameters.

## Testing

The NFTest cases exercise MSFragger LFQ, scan-based and feature-based MSFragger TMT, TMT spectrum reindexing, and Sage LFQ, including QC and ProteoVault. The RAW TMT case uses two E. coli TMT RAW files under `TEST_DATA_DIR`. From the repository root, inside a Slurm job, copy `.env-template` to `.env`, set `TEST_DATA_DIR`, and run:

```bash
zsh test/run-nftest.sh test_integration_MSFragger_LFQ_Protein
zsh test/run-nftest.sh test_integration_MSFragger_TMT_Protein
zsh test/run-nftest.sh test_integration_MSFragger_TMT_Reindexed
zsh test/run-nftest.sh test_integration_Sage_LFQ_Protein
zsh test/run-nftest.sh test_integration_MSFragger_TMT_RAW
```

The test runner uses `/scratch/$SLURM_JOB_ID/<test-case>` for its work and output. Test CSVs expand `$TEST_DATA_DIR` through [test/csv_environment_expander.groovy](test/csv_environment_expander.groovy). See [test/README.md](test/README.md) for the expected mzML, FASTA, channel CSV, and MSFragger JAR files.

## Current limitations

- ProtLoom validation requires MSBooster and additional project settings, and its current output does not satisfy the parent protein-stage idXML handoff. Keep `run_protloom = false` for complete metapipeline runs.

## License

This pipeline is licensed under GNU GPL version 2. See [LICENSE](LICENSE).
