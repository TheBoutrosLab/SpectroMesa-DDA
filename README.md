# metapipeline-ProteomicDDA

Nextflow DSL2 metapipeline for DDA proteomics. It runs Comet, Sage, and/or MSFragger search through
`pipeline-search-ProteomicMSMS`, validates PSMs with
`pipeline-validate-ProteomicPSM`, quantifies with `pipeline-quantitate-ProteomicTMT`
or `pipeline-quantitate-ProteomicLFQ` according to `experiment_type`, then runs
`pipeline-quantitate-ProteomicProtein`.

![DDA metapipeline schematic](docs/pipeline-flow.svg)

## Run

Copy `config/template.config` and fill in input paths and experiment parameters.
Input CSV columns are `sample_name,fraction_id,path`; each row is
one mzML fraction. TMT rows may repeat `sample_name` for distinct `fraction_id`
values within a plex. For TMT, provide `channel_csv` in the format required by
the TMT child pipeline; its `plex_id` must match `sample_name`. LFQ samples may have multiple mzML fractions when all samples share the same
fraction IDs and `quantitate_ProteomicLFQ.fractionated = true`. Set `search_ProteomicMSMS.search_engines` to any nonempty subset of
`Comet`, `Sage`, and `MSFragger`. The default is MSFragger. Multiple engines
are combined by validation consensus before quantitation. The MSFragger JAR
is required only when MSFragger is selected. It passes
the same target-decoy FASTA and decoy prefix to search,
validation, and protein quantitation. For ProtLoom validation, set
`validate_ProteomicPSM.run_protloom = true` and provide
`validate_ProteomicPSM.protloom_project_yaml`; add an `annotation_id` column to
the input CSV. ProtLoom sample and annotation IDs come from that CSV.

```
nextflow run main.nf -c config/my-study.config
```

Use `-profile pines` or `-profile boutroslab_aws` to set the lab's shared CPU and memory limits for the metapipeline and each child.
An external profile JSON can be selected with `compute_profile` and
`additional_resource_profile_dir`. Child process allocations can be tuned
through each child namespace.

## Pipeline steps and outputs

The parent output layout follows the DIA metapipeline:

```text
<output_dir>/metapipeline-ProteomicDDA-1.0.0/<dataset_id>/
├── main_workflow/
│   ├── search-ProteomicMSMS-<version>/
│   ├── validate-ProteomicPSM-<version>/
│   ├── quantitate-ProteomicTMT-<version>/       # TMT runs only
│   ├── quantitate-ProteomicLFQ-<version>/       # LFQ runs only
│   ├── quantitate-ProteomicProtein-<version>/
│   └── manifests/
└── log-metapipeline-ProteomicDDA-1.0.0-<timestamp>/
    └── nextflow-log/
```

The `manifests/` directory contains `search.csv`, `validation.csv`,
`validation-mzml.csv`, `quant-idxml.csv`, `quant-mzml.csv`,
`protein-unfiltered.csv`, and `protein-consensus.csv`. ProtLoom runs also
publish `protloom-project.generated.yaml`. These are the handoff files used
by the child pipelines. The parent log directory contains the Nextflow trace,
timeline, report, and effective `params.json`.

Each child keeps its native output hierarchy. Search and validation publish
per-sample results under `<sample_name>/OpenMS-<version>/output/` (or
`<sample_name>/ProtLoom-<version>/output/` for ProtLoom validation). TMT
publishes per-plex results under `OpenMS-<version>/output/<plex_id>/`.
LFQ and protein quantitation use
`<dataset_id>/OpenMS-<version>/output/`. These differences come from the
component pipelines; the parent directories and versioned stage names follow
the DIA layout.

## Integration tests

See `test/README.md`. Run a named case with `test/run-nftest.sh CASE` inside a
Slurm job after setting `.env` and providing test data. The `.env` file is local
and ignored by Git.

## Pinned child revisions

The component submodules are pinned to the revisions below. The Protein
quantitation child was updated to release `v1.1.0` on 2026-10-25:

| Pipeline | Commit |
| --- | --- |
| search-ProteomicMSMS | `2df53f041d77c3dead9d15188610a2a35019b2d8` |
| validate-ProteomicPSM | `6697d95c705836a87053748df56d3ed1d2af910f` |
| quantitate-ProteomicTMT | `b35383753c4d9dc414451e62528b89cb4b0161ec` |
| quantitate-ProteomicLFQ | `a022a1bb035b50fa31de95447e571535698a7657` |
| quantitate-ProteomicProtein (`v1.1.0`) | `c8af440a4a83c4cc84b5a3ea8dfc9e8995c5d1c5` |

The shared Nextflow config, module, and lib submodules follow the DIA
metapipeline's pinned revisions.
