# Database search

**MSFragger**, **Comet**, and **Sage** match tandem mass spectra to peptides in your target-decoy FASTA. MSFragger is selected by default; you can combine engines to contribute complementary identification evidence.

## How it works

1. Optionally reindex mzML spectra so native IDs are unique across a sample's fractions. This is off by default in SpectroMesa-DDA.
2. Search each acquisition with every selected engine through its OpenMS adapter.
3. Match peptides to proteins with PeptideIndexer and retain target/decoy labels.
4. Merge fractions into one unfiltered idXML per sample and engine for [validation](validation.md).

## Inputs and outputs

Inputs are the prepared mzML acquisitions, the shared target-decoy FASTA, and the MSFragger JAR when that engine is used. SpectroMesa-DDA supplies their paths. Outputs include per-acquisition search results and merged sample/engine idXML files. They are candidate identifications, before the downstream q-value filtering.

Files sharing `sample_name` contribute to the same validation unit. For TMT, that unit is a plex; its reporter channels identify biological samples later. See [Preparing inputs](../inputs.md).

## Parameter reference

Use the `search_ProteomicMSMS` block. Engine settings below include the actual search template used by this metapipeline. For example, MSFragger uses a 30 ppm precursor tolerance on either side and a 0.02 Da fragment tolerance unless overridden. Review each engine's digestion and modification settings when combining searches.

!!! important "Configure TMT labels in the search"
    `plex_type` selects reporter-ion quantitation and does not set search modifications. Add the label chemistry to each selected engine as described in [Configuring an analysis](../configuration.md#digestion-and-modifications).

Use the `search_ProteomicMSMS` block inside `params`. Defaults below describe this step as launched by SpectroMesa-DDA. “Not set; tool default” means no override is passed. Automatically supplied values do not need to be repeated.

### Analysis settings

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `CometAdapter` | Block | Not set; tool default | OpenMS CometAdapter parameters, nested as in the template. |
| `MSFraggerAdapter` | Block | Not set; tool default | OpenMS MSFraggerAdapter parameters, nested as in the template. |
| `SageAdapter` | Block | Not set; tool default | OpenMS SageAdapter parameters, nested as in the template. |
| `comet_default_params` | Path | Not supplied | Optional native Comet default parameter file. |
| `export_all_psms` | Boolean | true | Include all reported PSMs in mzTab exports. |
| `export_mzTab` | Boolean | false | Export merged idXML files to mzTab. |
| `fix_msfragger_spectrum_refs` | Boolean | false | Repair MSFragger spectrum references for affected OpenMS versions. |
| `merge_proteins_add_PSMs` | Boolean | true | Merge proteins by accession while retaining PSMs. |
| `reindex_mzml` | Boolean | false | Assign unique native spectrum IDs across fractions within each sample. |
| `reindex_mzml_keep_all_metadata` | Boolean | true | Preserve mzML metadata while reindexing. |
| `save_intermediate_files` | Boolean | false | Publish additional intermediate files for inspection. Final outputs and execution logs are retained independently. |
| `search_engines` | List | ['MSFragger'] | Search engines to run. |

### Software and containers

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `docker_image_openms` | Text | ghcr.io/theboutroslab/openms-thirdparty:3.5.0 | Container image for openms. Change only to a compatible image. |
| `docker_image_pyopenms` | Text | ghcr.io/theboutroslab/pyopenms:3.5.0 | Container image for pyopenms. Change only to a compatible image. |
| `openms_version` | Text | 3.5.0 | Version used for output labeling and default container selection. |
| `pyopenms_version` | Text | 3.5.0 | Version used for output labeling and default container selection. |

### Automatically supplied settings

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `decoy_database` | Path | Shared decoy_database | Target-decoy protein FASTA used by every search engine. |
| `input_csv` | Path | Generated mzML manifest | CSV with sample_name and mzML path columns; other columns are ignored. |
| `msfragger_executable` | Path | Shared msfragger_executable | Separately obtained MSFragger JAR; required when MSFragger is selected. |
| `output_dir` | Path | Assigned within the analysis output | Destination for this step. Set the shared output_dir for the complete analysis. |

### CometAdapter settings

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `CometAdapter.PeptideIndexing.decoy_string` | Text | Shared decoy_string | Derived from shared decoy_string. |
| `CometAdapter.PeptideIndexing.decoy_string_position` | Text | Shared decoy_position | Derived from shared decoy_position. |
| `CometAdapter.PeptideIndexing.unmatched_action` | Text | remove | Action for peptides not found in the FASTA; remove by default. |
| `CometAdapter.clip_nterm_methionine` | Boolean | true | Allow protein N-terminal methionine clipping. |
| `CometAdapter.enzyme` | Text | Trypsin | Digestion enzyme. |
| `CometAdapter.fixed_modifications` | List | ['Carbamidomethyl (C)'] | Fixed modifications using OpenMS names; configure TMT labels here for this engine. |
| `CometAdapter.fragment_bin_offset` | Number | 0.0 | Offset of the fragment-ion mass bins. |
| `CometAdapter.fragment_error_units` | Text | Da | Fragment tolerance unit. |
| `CometAdapter.fragment_mass_tolerance` | Number | 0.01 | Fragment tolerance; for Comet, half the fragment bin width. |
| `CometAdapter.instrument` | Text | high_res | Instrument resolution category. |
| `CometAdapter.isotope_error` | Text | 0/1/2 | Allowed precursor isotope offsets. |
| `CometAdapter.max_fragment_charge` | Number | 3 | Maximum fragment charge considered. |
| `CometAdapter.max_peptide_length` | Number | 35 | Maximum peptide length. |
| `CometAdapter.max_precursor_charge` | Number | 5 | Maximum precursor charge. |
| `CometAdapter.max_variable_mods_in_peptide` | Number | 3 | Maximum variable modifications per peptide. |
| `CometAdapter.min_peptide_length` | Number | 7 | Minimum peptide length. |
| `CometAdapter.minimum_peaks` | Number | 15 | Minimum number of peaks required in a spectrum. |
| `CometAdapter.missed_cleavages` | Number | 2 | Allowed missed cleavages. |
| `CometAdapter.num_enzyme_termini` | Text | fully | Required enzyme specificity. |
| `CometAdapter.num_hits` | Number | 1 | Peptide candidates retained per spectrum. |
| `CometAdapter.precursor_charge` | Text | 1:5 | Allowed precursor charge range. |
| `CometAdapter.precursor_error_units` | Text | ppm | Precursor tolerance unit. |
| `CometAdapter.precursor_mass_tolerance` | Number | 30.0 | Precursor tolerance width. |
| `CometAdapter.variable_modifications` | List | ['Oxidation (M)', 'Acetyl (Protein N-term)', 'Gln->pyro-Glu (N-term Q)'] | Variable modifications using OpenMS names. |

### MSFraggerAdapter settings

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `MSFraggerAdapter.PeptideIndexing.decoy_string` | Text | Shared decoy_string | Derived from shared decoy_string. |
| `MSFraggerAdapter.PeptideIndexing.decoy_string_position` | Text | Shared decoy_position | Derived from shared decoy_position. |
| `MSFraggerAdapter.PeptideIndexing.unmatched_action` | Text | remove | Action for peptides not found in the FASTA; remove by default. |
| `MSFraggerAdapter.digest.allowed_missed_cleavage` | Text | 2 | Allowed missed cleavages. |
| `MSFraggerAdapter.digest.max_length` | Number | 35 | Maximum peptide length. |
| `MSFraggerAdapter.digest.min_length` | Number | 7 | Minimum peptide length. |
| `MSFraggerAdapter.digest.num_enzyme_termini` | Text | fully | Required enzyme specificity. |
| `MSFraggerAdapter.digest.search_enzyme_name` | Text | Trypsin | Digestion enzyme name. |
| `MSFraggerAdapter.license` | Text | yes | MSFragger license acknowledgment; use only after obtaining the separately licensed JAR. |
| `MSFraggerAdapter.search.output_report_topn` | Number | 1 | Number of reported peptide candidates per spectrum. |
| `MSFraggerAdapter.spectrum.max_fragment_charge` | Text | 3 | Maximum fragment charge considered. |
| `MSFraggerAdapter.spectrum.minimum_peaks` | Number | 15 | Minimum number of peaks required in a spectrum. |
| `MSFraggerAdapter.spectrum.use_topn_peaks` | Number | 150 | Maximum number of intense peaks retained per spectrum. |
| `MSFraggerAdapter.statmod.add_C_cysteine` | Number | 57.021464 | Fixed cysteine mass shift in Da; 57.021464 represents carbamidomethylation. |
| `MSFraggerAdapter.tolerance.fragment_mass_tolerance` | Number | 0.02 | Fragment-ion mass tolerance. |
| `MSFraggerAdapter.tolerance.fragment_mass_unit` | Text | Da | Fragment tolerance unit. |
| `MSFraggerAdapter.tolerance.isotope_error` | Text | 0/1/2 | Allowed precursor isotope offsets. |
| `MSFraggerAdapter.tolerance.precursor_mass_tolerance_lower` | Number | 30.0 | Lower precursor tolerance width. |
| `MSFraggerAdapter.tolerance.precursor_mass_tolerance_upper` | Number | 30.0 | Upper precursor tolerance width. |
| `MSFraggerAdapter.tolerance.precursor_mass_unit` | Text | ppm | Precursor tolerance unit. |
| `MSFraggerAdapter.varmod.clip_nterm_m` | Boolean | true | Allow protein N-terminal methionine clipping. |
| `MSFraggerAdapter.varmod.masses` | List | [42.010565, -17.026549] | Variable modification mass shifts in Da, paired in order with syntaxes. |
| `MSFraggerAdapter.varmod.max_variable_mods_per_peptide` | Text | 3 | Maximum variable modifications per peptide. |
| `MSFraggerAdapter.varmod.not_allow_multiple_variable_mods_on_residue` | Boolean | true | Prevent multiple variable modifications on one residue. |
| `MSFraggerAdapter.varmod.syntaxes` | List | ['[^', 'nQ'] | MSFragger residue/terminus patterns paired with masses. |
| `MSFraggerAdapter.varmod.unimod` | List | ['Oxidation (M)'] | Additional variable modifications using OpenMS modification names. |

### SageAdapter settings

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `SageAdapter.PeptideIndexing.decoy_string` | Text | Shared decoy_string | Derived from shared decoy_string. |
| `SageAdapter.PeptideIndexing.decoy_string_position` | Text | Shared decoy_position | Derived from shared decoy_position. |
| `SageAdapter.PeptideIndexing.unmatched_action` | Text | remove | Action for peptides not found in the FASTA; remove by default. |
| `SageAdapter.decoy_prefix` | Text | Shared decoy_string | Derived from shared decoy_string. |
| `SageAdapter.fixed_modifications` | List | ['Carbamidomethyl (C)'] | Fixed modifications using OpenMS names; configure TMT labels here for this engine. |
| `SageAdapter.fragment_tol_left` | Number | -20.0 | Signed lower fragment mass-error bound. |
| `SageAdapter.fragment_tol_right` | Number | 20.0 | Signed upper fragment mass-error bound. |
| `SageAdapter.fragment_tol_unit` | Text | ppm | Fragment mass-error unit. |
| `SageAdapter.missed_cleavages` | Number | 2 | Allowed missed cleavages. |
| `SageAdapter.precursor_tol_left` | Number | -10.0 | Signed lower precursor mass-error bound. |
| `SageAdapter.precursor_tol_right` | Number | 10.0 | Signed upper precursor mass-error bound. |
| `SageAdapter.precursor_tol_unit` | Text | ppm | Precursor mass-error unit. |
| `SageAdapter.q_value_threshold` | Number | 1.0 | Search-stage q-value threshold. Keep 1.0 to pass unfiltered candidates to downstream validation. |
| `SageAdapter.variable_modifications` | List | ['Oxidation (M)'] | Variable modifications using OpenMS names. |

### Additional adapter options

The `CometAdapter`, `SageAdapter`, and `MSFraggerAdapter` blocks accept additional OpenMS adapter options. Nested names become colon-separated keys in the generated adapter configuration. Match the spelling and value type used by the configured OpenMS version, and leave input/output files and thread settings to the workflow.

See the OpenMS 3.5 documentation for [CometAdapter](https://openms.de/doxygen/release/3.5.0/html/TOPP_CometAdapter.html), [SageAdapter](https://openms.de/doxygen/release/3.5.0/html/TOPP_SageAdapter.html), and [MSFraggerAdapter](https://openms.de/doxygen/release/3.5.0/html/TOPP_MSFraggerAdapter.html). The tables above cover the settings explicitly supplied by the current workflow and template; additional tool options are version-dependent.

### Computing and temporary files

The [shared parameter reference](../parameters.md#computing-and-temporary-files) explains these settings. This pipeline declares: `apptainer_cache`, `apptainer_library`, `base_resource_update`, `max_cpus`, `max_memory`, `min_cpus`, `min_memory`, `resource_allocation_profile_tag`, `singularity_cache`, `singularity_library`, `ucla_cds`, `work_dir`.

The tables were checked against the [individual pipeline configuration](https://github.com/TheBoutrosLab/pipeline-search-ProteomicMSMS/tree/57e522cc85c1ba4de1a6ef3213134ce67f581819/config), its tool modules, and the SpectroMesa-DDA settings that select this workflow.

## Related steps

[Overview](../overview.md) · [Shared parameters](../parameters.md) · [Configuring an analysis](../configuration.md) · [Understanding results](../results.md)

## References

- [OpenMS 3 enables reproducible analysis of large-scale mass spectrometry data (2024)](https://doi.org/10.1038/s41592-024-02197-7).
- [MSFragger (2017)](https://doi.org/10.1038/nmeth.4256).
- [Comet (2013)](https://doi.org/10.1002/pmic.201200439).
- [Sage (2023)](https://doi.org/10.1021/acs.jproteome.3c00486).
