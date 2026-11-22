# Understanding results

Start with the final **protein and peptide abundance tables**, then review the QC summaries before comparing samples. If database assembly is enabled, [ProteoVault](https://github.com/TheBoutrosLab/package-ProteoVault) provides a single DuckDB database that can be loaded and analyzed in R with [ProteoVaultR](https://github.com/TheBoutrosLab/package-ProteoVaultR).

## Where results are written

The `output_dir` and `dataset_id` in your run configuration determine the result location:

```text
<output_dir>/SpectroMesa-DDA-<version>/
├── <dataset_id>.proteovault.duckdb
└── <dataset_id>/
    ├── main_workflow/
    │   ├── convert-MSData-<version>/          # when conversion is needed
    │   ├── search-ProteomicMSMS-<version>/
    │   ├── validate-ProteomicPSM-<version>/
    │   ├── quantitate-ProteomicLFQ-<version>/ # LFQ analyses
    │   ├── quantitate-ProteomicTMT-<version>/ # TMT analyses
    │   ├── quantitate-ProteomicProtein-<version>/
    │   ├── qc-ProteomicDDA-<version>/
    │   └── manifests/
    └── log-SpectroMesa-DDA-<version>-<timestamp>/
```

Only the selected quantitation branch is present. The database is created when `run_proteovault` is true, which is the default. Version placeholders refer to the software used for the run, not necessarily the latest release.

## Protein and peptide abundance tables

The final tables are under:

```text
main_workflow/quantitate-ProteomicProtein-<version>/
  <dataset_id>/OpenMS-<version>/output/
    <dataset_id>_ProteinQuantifier_protein.csv
    <dataset_id>_ProteinQuantifier_peptide.csv
```

The protein table summarizes peptide evidence according to the selected protein groups. The peptide table provides the corresponding peptide-level quantities; its row and column detail depends on charge and fraction settings. Inspect the exported identifiers and headers before treating a protein group as a single protein or gene.

!!! note "The CSV files are tab-delimited"
    With the default export settings, ProteinQuantifier writes tab-separated data despite the `.csv` extension. Read them with a tab-delimited reader or through ProteoVaultR, rather than assuming commas separate columns.

For **LFQ**, abundance columns identify sample assays. By default, fractions within each assay are summed and charge states are combined. Technical replicates with separate sample identifiers remain separate assays.

For **TMT**, abundance columns identify plex/channel assays, with channel descriptions where available. The default scan-based workflow measures reporter-ion signal. The experimental feature-based route apportions MS1 feature area using reporter proportions. MAD normalization can produce quasi-intensities or log2 ratios depending on `MADNormalizer.quasi_intensity`; retain the run configuration so the values can be interpreted correctly.

Column relabeling preserves the numeric values and stops if an assay cannot be matched unambiguously. It does not merge identically named biological samples across different TMT channels. Detailed peptide tables can retain file, fraction, and charge information, so do not assume they have the same layout as the protein table.

## Protein groups and identification confidence

The protein quantitation directory also contains the grouping result:

| Grouping route | File | What it represents |
| --- | --- | --- |
| ProteinProphet | `<dataset_id>_ProteinProphet.protXML` | Raw grouping result before the pipeline's probability filtering. |
| ProteinProphet | `<dataset_id>_ProteinProphet_filtered.idXML` | Groups supplied to ProteinQuantifier, with zero-probability parent groups removed. |
| ProteinInferencer | `<dataset_id>_IDConflictResolver.consensusXML` | Inferred groups and quantified features after any enabled protein FDR filtering and identification conflict resolution. |

!!! important "PSM and protein confidence are different"
    The default validation threshold is a PSM q-value of `0.01`. The default ProteinProphet route does not apply a 1% protein q-value filter. In the ProteinInferencer route, protein FDR calculation and filtering are both off by default. See [Protein grouping and quantitation](configuration.md#protein-grouping-and-quantitation) for the settings that control this.

Search and validation directories retain the identification evidence. Filtered idXML files describe accepted PSMs for each sample or TMT plex. Unfiltered PEP-scored idXML files retain evidence used for cohort ProteinProphet grouping and should not be interpreted as an accepted-identification list. For multiple search engines, use the final consensus identifications for combined counts rather than summing the per-engine filtered files.

## Quantitation details

The LFQ or TMT directory contains the feature maps used for protein quantitation. The final `*_IDConflictResolver.consensusXML` resolves conflicting peptide assignments before the protein step. These files are useful for investigating feature-level quantities and sample mapping.

TMT also publishes a dataset peptide table and, for feature-based quantitation, `<dataset_id>_LinkedFeatures.tsv`. The linked table records the input `fraction_id`, `plex_id`, reporter label, and sample description. In the merged TMT peptide CSV, the design fraction does not necessarily equal the input acquisition's `fraction_id`; use the linked table when tracing feature-based results back to input fractions.

With MAD normalization, scaling information is published in `<dataset_id>_MADNormalizer_scaling.tsv`. Optional per-run diagnostics and intermediate feature maps are retained when `save_intermediate_files` is enabled for that step. See the [TMT](pipelines/tmt.md) and [LFQ](pipelines/lfq.md) references for details.

## Quality control

Open the combined table under:

```text
main_workflow/qc-ProteomicDDA-<version>/<dataset_id>/output/
  <dataset_id>_QC_metrics.tsv
```

It summarizes acquisition, search, PSM features, accepted identifications, protein inference, and quantitation. Every row has the columns `dataset_id`, `layer`, `source_process`, `sample_name`, `search_engine`, `fraction_id`, `metric_name`, `group`, `value`, `unit`, `status`, and `source_file`.

Compare corresponding fractions and like-for-like acquisition types. Sample-level identifications, cohort-level protein groups, and channel-level quantities describe different units. A metric marked `unavailable` is not a measured zero. TMT quantitation metrics use channel descriptions in `group`; acquisition metrics use the plex name.

Interactive MS1 maps are under `output/mzML/` as `<sample_name>_<fraction_id>_MS1_landscape.html`. They work offline and show a selected subset of peaks. Colors represent within-run intensity percentiles, so the same color does not imply the same absolute intensity across files. Use the maps together with the numerical summaries to investigate unusual samples, rather than applying a universal pass/fail threshold.

## ProteoVault database

The database is published above the dataset directory:

```text
<output_dir>/SpectroMesa-DDA-<version>/<dataset_id>.proteovault.duckdb
```

It combines DDA identification, quantitation, sequence, and QC information and is validated before publication. Load it with [ProteoVaultR](https://github.com/TheBoutrosLab/package-ProteoVaultR) for analysis in R.

The database records source paths from the build work directory. Moving the database does not update those paths. If you need to follow its source-file links after relocation, use the `proteovault update-paths` command described in the [ProteoVault CLI guide](https://github.com/TheBoutrosLab/package-ProteoVault/blob/v0.2.5/docs/cli.md).

## Keep the analysis record

Retain your acquisition and channel CSVs, exact FASTA, run configuration, software versions, and logs. The top-level log directory contains `nextflow-log/trace.txt`, `timeline.html`, `report.html`, and the resolved `params.json`. Each analysis step also saves its own logs.

The `manifests/` directory records file handoffs between analysis steps; it is useful for troubleshooting sample mapping. Published results alone do not provide Nextflow's resume cache. Keep the launch directory's `.nextflow` folder and the work directory if you may [resume the analysis](execution.md#resume-an-interrupted-run).
