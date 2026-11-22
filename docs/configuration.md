# Configuring an analysis

Start from the supplied template and adjust it to your experiment. Shared settings describe your inputs and analysis; the named blocks hold settings for each analysis step. The [pipeline reference](parameters.md) lists the available parameters and their effective defaults.

## Create a run configuration

Keep the pipeline installation separate from the analysis directory:

```bash
mkdir -p /project/analyses/human_dda_cohort
cp /path/to/SpectroMesa-DDA/config/template.config \
    /project/analyses/human_dda_cohort/run.config
```

Edit the copied file. Keep its `includeConfig` statements and final `methods.setup()` call. Nextflow's `projectDir` points to the pipeline installation when you launch its `main.nf`, so those statements still work from your analysis directory. Add all parameter changes before `methods.setup()`.

The required shared settings are:

```groovy
params {
    input_csv = '/project/analyses/human_dda_cohort/acquisitions.csv'
    decoy_database = '/data/databases/human-decoy_contam.fasta'
    msfragger_executable = '/opt/MSFragger/MSFragger-4.4.1.jar'
    output_dir = '/project/results'
    dataset_id = 'human_dda_cohort'
    experiment_type = 'LFQ'
    contam_string = 'CONTAM_'
}
```

These are fragments to edit into your copied template, not replacements for the whole file. Use your actual paths and the contaminant marker in your FASTA. `dataset_id` defaults to `cohort`; choose a meaningful name without spaces. The MSFragger JAR is required only when that engine is selected.

## Select LFQ or TMT

`experiment_type` already defaults to `LFQ`. For TMT, change it to `TMT` and provide the channel manifest:

```groovy
params {
    experiment_type = 'TMT'
    channel_csv = '/project/analyses/human_dda_cohort/channels.csv'
    quantitate_ProteomicTMT {
        plex_type = 'tmt10plex'
    }
}
```

The pipeline detects fractionation from your [acquisition CSV](inputs.md). Keep the sample/plex identifiers and fraction layout consistent; no separate fractionation switch is needed.

## Database searching

### Choose search engines

MSFragger is already selected by default. To use Sage alone, or combine search engines, edit `search_engines`:

```groovy
params {
    search_ProteomicMSMS {
        search_engines = ['MSFragger', 'Comet', 'Sage']
    }
}
```

Use any nonempty combination of those three names without duplicates. Multiple engines increase runtime and storage use. Their identifications are combined automatically during validation; you do not need to enable consensus merging separately.

### Mass tolerances

Match tolerances to your instrument, acquisition, and calibration. Each search engine has its own block. For example, these are MSFragger's current template values:

```groovy
params {
    search_ProteomicMSMS {
        MSFraggerAdapter {
            tolerance {
                precursor_mass_tolerance_lower = 30.0
                precursor_mass_tolerance_upper = 30.0
                precursor_mass_unit = 'ppm'
                fragment_mass_tolerance = 0.02
                fragment_mass_unit = 'Da'
            }
        }
    }
}
```

The two precursor settings describe the lower and upper tolerance widths. Sage uses signed left/right bounds instead. See [Database search](pipelines/search.md) for each engine's parameter names and values.

### Digestion and modifications

Set the enzyme and modifications to match sample preparation for **every selected engine**. MSFragger's default template uses trypsin with two missed cleavages and carbamidomethylated cysteine. It also includes variable methionine oxidation, protein N-terminal acetylation, and N-terminal glutamine cyclization. Comet and Sage have their own modification lists, so review them when combining engines.

For a different digestion enzyme, change the search settings and `validate_ProteomicPSM.enzyme` together. The validation default is `Trypsin`.

!!! important "TMT reporter settings do not configure search modifications"
    Setting `experiment_type = 'TMT'` or `plex_type` does not add TMT labels to the search. Configure the correct label mass on lysine and peptide N termini for each engine you use.

For conventional TMT10 labeling with MSFragger, the integration example uses:

```groovy
params {
    search_ProteomicMSMS {
        MSFraggerAdapter {
            statmod {
                add_C_cysteine = 57.021464
                add_K_lysine = 229.162932
                add_nterm_peptide = 229.162932
            }
        }
    }
}
```

Use the mass appropriate to your actual reagent; TMTpro uses different chemistry. Review variable modifications too, especially when a fixed label changes which modifications can occur at the same site.

### Spectrum identifiers

`reindex_mzml` defaults to `false` in SpectroMesa-DDA. Enable `search_ProteomicMSMS.reindex_mzml = true` when you need unique native spectrum IDs across a sample's fractions. The resulting mzML files are passed consistently to validation, quantitation, and QC. This option is covered by a TMT integration case.

## Identification validation

Percolator rescoring is already enabled. The default `percolator_workflow = 'openms'` uses the OpenMS adapter. To add prediction-based features with MSBooster, set:

```groovy
params {
    validate_ProteomicPSM {
        percolator_workflow = 'msbooster'
    }
}
```

`filter_psm_score_peptide` already defaults to `0.01`. Despite its historical name, this is a **PSM q-value cutoff** for the filtered identification output. It is not a protein FDR threshold. Keep `run_percolator = true` for the default ProteinProphet grouping route, which uses the unfiltered PEP-scored results.

## LFQ quantitation

LFQ already uses the identification-guided `FFId` route. `merge_featureXML` is enabled so the pipeline produces the combined feature map required for protein quantitation; keep it enabled for an end-to-end run.

`save_intermediate_files` is **true in the LFQ template launched by SpectroMesa-DDA**. Set `quantitate_ProteomicLFQ.save_intermediate_files = false` if you do not need the published intermediate feature maps; final results and execution logs remain available.

Match between runs is **off by default**. If appropriate for your experiment, enable `quantitate_ProteomicLFQ.enable_mbr = true`. It requires at least two samples and `merge_featureXML = true`. This transfers identification evidence between linked features and changes how missing identifications are handled. Review the [LFQ reference](pipelines/lfq.md) before enabling it.

## TMT quantitation

The default `tmt_workflow = 'scan_based'` quantifies reporter ions. Normalization is already enabled, and the template launched by SpectroMesa-DDA selects `tmt_normalization_method = 'mad'`. Label one channel in each plex `reference` in the [channel CSV](inputs.md#tmt-channel-csv), unless you deliberately enable a virtual reference.

MAD produces reference-scaled quasi-intensities by default. For scan-based quantitation, you can instead choose `tmt_normalization_method = 'openms'` to use IsobaricAnalyzer's median-ratio normalization with a physical reference. `MADNormalizer.quasi_intensity = false` instead produces log2 ratios, changing the meaning of the output values. Disable normalization altogether with `enable_tmt_normalization = false` if that is your intended analysis.

!!! warning "Feature-based TMT is experimental"
    The optional `feature_based` route apportions integrated MS1 feature areas using reporter-ion proportions. It requires matching fraction IDs across plexes. When normalization is enabled, keep `mad`; switching to `openms` normalization is incompatible with this route. Validate its behavior on representative data before using it for biological comparisons.

The [TMT reference](pipelines/tmt.md) explains virtual references, bridge scaling, isotope correction, and the two workflows.

## Protein grouping and quantitation

`quantitate_ProteomicProtein.protein_grouping_algorithm` already defaults to `ProteinProphet`. This combines the unfiltered PEP-scored identifications across the cohort with iProphet and ProteinProphet, then quantifies the resulting groups with OpenMS ProteinQuantifier.

!!! important "The protein cutoff is not enabled automatically"
    `protein_fdr_cutoff` defaults to `0.01`, but `filter_protein_fdr` and `protein_inference_protein_fdr` both default to `false`. The default ProteinProphet route removes zero-probability groups; it does **not** apply a 1% protein q-value filter. Do not describe its output as filtered to 1% protein FDR.

The alternative ProteinInferencer route can calculate and filter protein FDR when both switches are enabled:

```groovy
params {
    quantitate_ProteomicProtein {
        protein_grouping_algorithm = 'ProteinInferencer'
        protein_inference_protein_fdr = true
        filter_protein_fdr = true
        protein_fdr_cutoff = 0.01
    }
}
```

ProteinQuantifier combines charge states by default (`protein_quantifier_best_charge = false`) and sums fractions within each assay (`protein_quantifier_fractions_aggregate = 'sum'`). See the [protein reference](pipelines/protein.md) before changing these choices.

## Computing resources

Choose a container profile, normally `docker` or `apptainer`, when launching. The bundled resource plans are:

| Resource profile | Node budget |
| --- | --- |
| `boutroslab_aws` | 32 CPUs, 128 GB |
| `pines` | 64 CPUs, 500 GB |

Combine the resource plan and runtime, for example `-profile pines,apptainer`. These plans control local task allocations; they do not request a Slurm job. Launch inside an allocation of the matching size.

For a custom machine, copy a JSON plan from `config/resource_profiles/` into a directory you control, rename it `my_cluster.json`, and adjust its CPU/memory budget and process requests. Keep every pipeline and process entry. Then set:

```groovy
params {
    compute_profile = 'my_cluster'
    additional_resource_profile_dir = '/project/resource_profiles'
}
```

The custom directory is searched before bundled profiles. Multiple directories may be separated by `:` on Linux/macOS. A corresponding Nextflow `-profile my_cluster` is not needed. See [Shared parameters](parameters.md#computing-and-temporary-files) for per-step limits and allocation adjustments.

## Results database

ProteoVault assembly is already enabled with `run_proteovault = true`. Leave it enabled to create the DuckDB database for analysis with [ProteoVaultR](https://github.com/TheBoutrosLab/package-ProteoVaultR). Set it to `false` to finish after QC while retaining the individual result files.

Next, follow [Running and resuming](execution.md) to launch from your analysis directory.
