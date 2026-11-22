# Protein grouping and quantitation

**ProteinProphet** or **OpenMS ProteinInference** assigns protein groups, and **OpenMS ProteinQuantifier** summarizes the quantified peptide evidence into protein and peptide abundance tables.

![Protein grouping and quantitation workflow](flowcharts/protein.svg)

[Open the original flowchart at full size](flowcharts/protein.svg).

## How it works

1. Receive the final LFQ or TMT consensusXML containing quantitative features.
2. With the default ProteinProphet route, convert the unfiltered PEP-scored identifications to pepXML, repair supported enzyme-terminus annotations, combine the evidence with iProphet, and infer groups with ProteinProphet.
3. Remove zero-probability parent groups and supply the resulting protein groups to ProteinQuantifier.
4. Alternatively, use ProteinInferencer to infer groups directly in the consensusXML, optionally calculate and filter protein FDR, and resolve identification conflicts.
5. Quantify peptide and protein abundances, then label columns using the feature map's experimental design and channel descriptions.

## Inputs and outputs

All inputs are supplied automatically: the cohort quantitative feature map, unfiltered PEP-scored idXML manifest, target-decoy FASTA, and shared identifiers. ProteinProphet combines evidence across the cohort rather than performing independent grouping for each sample.

Final outputs are `<dataset_id>_ProteinQuantifier_protein.csv` and `<dataset_id>_ProteinQuantifier_peptide.csv`. The ProteinProphet route also publishes raw protXML and the filtered idXML used for quantitation. The ProteinInferencer route retains its groups in the final `IDConflictResolver.consensusXML`. See [Understanding results](../results.md) for paths and table interpretation.

!!! important "A configured cutoff does not enable filtering"
    `protein_fdr_cutoff` is `0.01`, but both FDR switches are false by default. Protein FDR filtering applies only in the ProteinInferencer route when `protein_inference_protein_fdr` and `filter_protein_fdr` are both true. The default ProteinProphet route removes zero-probability groups and does not apply this q-value cutoff.

By default, ProteinQuantifier combines charge states and sums fractions within each assay. `protein_quantifier_best_charge = true` selects one charge per modified peptide; `protein_quantifier_fractions_aggregate = 'best'` selects the best fraction per peptide and fraction group. These choices affect quantities and the detailed peptide table layout.

## Parameter reference

Use the `quantitate_ProteomicProtein` block inside `params`. Defaults below describe this step as launched by SpectroMesa-DDA. “Not set; tool default” means no override is passed. Automatically supplied values do not need to be repeated.

### Analysis settings

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `convert_idXML2pepXML_peptideprophet_analyzed` | Boolean | false | Mark the converted pepXML as PeptideProphet-analyzed; normally leave false for PEP-scored input. |
| `filter_protein_fdr` | Boolean | false | Enable protein FDR filtering in the ProteinInferencer route; also requires protein_inference_protein_fdr. |
| `protein_fdr_cutoff` | Number | 0.01 | Protein q-value threshold, used only by the ProteinInferencer filtering route when both FDR switches are true. |
| `protein_grouping_algorithm` | Text | ProteinProphet | Choose ProteinProphet (default) or ProteinInferencer (OpenMS ProteinInference). |
| `protein_inference_protein_fdr` | Boolean | false | Calculate protein FDR in ProteinInference. This switch alone does not filter the result. |
| `protein_quantifier_best_charge` | Boolean | false | Use one charge globally per modified peptide. False combines charge states. |
| `protein_quantifier_fractions_aggregate` | Text | sum | Combine fractions within each assay: sum adds them; best selects the best fraction per peptide and fraction group. |
| `proteinprophet_minprob` | Number | 0.00 | Minimum probability passed to the ProteinProphet command. This is not a protein q-value cutoff. |
| `save_intermediate_files` | Boolean | false | Publish additional intermediate files for inspection. Final outputs and execution logs are retained independently. |

### Software and containers

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `docker_image_fragpipe` | Text | fcyucn/fragpipe:24.0 | Container image for fragpipe. Change only to a compatible image. |
| `docker_image_openms` | Text | ghcr.io/theboutroslab/openms-thirdparty:3.6.0 | Container image for openms. Change only to a compatible image. |
| `docker_image_pyopenms` | Text | ghcr.io/theboutroslab/pyopenms:3.6.0 | Container image for pyopenms. Change only to a compatible image. |
| `fragpipe_version` | Text | 24.0 | Version used for output labeling and default container selection. |
| `openms_version` | Text | 3.6.0 | Version used for output labeling and default container selection. |
| `pyopenms_version` | Text | 3.6.0 | Version used for output labeling and default container selection. |

### Automatically supplied settings

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `decoy_database` | Path | Shared decoy_database | Target-decoy FASTA used for the idXML searches. |
| `decoy_string` | Text | Shared decoy_string | Accession prefix identifying decoy proteins in the search database. |
| `input_consensusXML` | Path | Final LFQ or TMT feature map | One cohort-level consensusXML file for protein quantification. |
| `output_dir` | Path | Assigned within the analysis output | Destination for this step. Set the shared output_dir for the complete analysis. |
| `project_name` | Text | Shared dataset_id | Project name for outputs. |
| `unfiltered_idXML` | Path | Generated unfiltered PEP-scored identification manifest | CSV of unfiltered PEP-scored idXML files for ProteinProphet. |

### Resolving identification conflicts

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `conflict_resolver_resolve_between_features` | Text | Not set; tool default | Resolve competing peptide assignments between features as well as within each feature. |

### ProteinInferencer filtering options

These options apply only when both protein FDR switches are enabled. `protein_fdr_cutoff` is additionally passed as the protein score threshold; avoid setting a conflicting `filter_protein_score_prot`.

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `filter_protein_best_n_peptide_hits` | Integer | Not set; tool default | Keep this number of best peptide hits per identification. |
| `filter_protein_best_n_protein_hits` | Integer | Not set; tool default | Keep this number of best protein hits. |
| `filter_protein_best_n_spectra` | Integer | Not set; tool default | Keep this number of best-scoring peptide-identification records. |
| `filter_protein_best_strict` | Boolean | Not set; flag omitted | Apply the best-hit limit strictly when scores tie. |
| `filter_protein_blacklist_peptides` | Path | Not set; tool default | Identification file defining peptide sequences to exclude. |
| `filter_protein_blacklist_protein_accessions` | Text | Not set; tool default | Protein accession list used to exclude matching identifications. |
| `filter_protein_blacklist_proteins` | Path | Not set; tool default | FASTA defining proteins whose matching peptide identifications should be excluded. |
| `filter_protein_in_silico_digestion_fasta` | Path | Not set; tool default | FASTA used to check peptide identifications against an in-silico digest. |
| `filter_protein_keep_unreferenced_protein_hits` | Boolean | Not set; flag omitted | Retain protein hits with no remaining peptide evidence. |
| `filter_protein_missed_cleavages_number_of_missed_cleavages` | Text | Not set; tool default | Allowed missed-cleavage count or range for retained peptides. |
| `filter_protein_precursor_charge` | Text | Not set; tool default | Retain identifications within a precursor-charge range, written min:max. |
| `filter_protein_precursor_length` | Text | Not set; tool default | Retain peptide sequences within a length range, written min:max. |
| `filter_protein_precursor_mz` | Text | Not set; tool default | Retain identifications within a precursor m/z range, written min:max. |
| `filter_protein_precursor_rt` | Text | Not set; tool default | Retain identifications within a retention-time range, written min:max. |
| `filter_protein_remove_decoys` | Boolean | Not set; flag omitted | Remove decoy identifications from the retained output. |
| `filter_protein_remove_shared_peptides` | Boolean | Not set; flag omitted | Remove peptides assigned to multiple proteins. |
| `filter_protein_score_pep` | Text | Not set; tool default | Peptide-level score threshold; interpret it using the score type in the input. |
| `filter_protein_score_prot` | Text | Not set; tool default | Protein-level score threshold; interpret it using the score type in the input. |
| `filter_protein_score_protgroup` | Text | Not set; tool default | Protein-group score threshold. |
| `filter_protein_var_mods` | Boolean | Not set; flag omitted | Restrict retained peptide hits to those carrying variable modifications. |
| `filter_protein_whitelist_peptides` | Path | Not set; tool default | Identification file defining peptide sequences to retain. |
| `filter_protein_whitelist_protein_accessions` | Text | Not set; tool default | Protein accession list used to retain matching identifications. |
| `filter_protein_whitelist_proteins` | Path | Not set; tool default | FASTA defining proteins whose matching peptide identifications may be retained. |

### ProteinInferencer options

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `protein_inference_Algorithm_annotate_indistinguishable_groups` | Boolean | Not set; tool default | Annotate proteins that cannot be distinguished by the observed peptides. |
| `protein_inference_Algorithm_greedy_group_resolution` | Boolean | Not set; flag omitted | Resolve protein groups greedily from the peptide evidence. |
| `protein_inference_Algorithm_min_peptides_per_protein` | Integer | Not set; tool default | Minimum peptide evidence required per protein. |
| `protein_inference_Algorithm_score_aggregation_method` | Text | Not set; tool default | Method used to combine peptide evidence into a protein score. |
| `protein_inference_Algorithm_skip_count_annotation` | Boolean | Not set; flag omitted | Skip adding peptide-count annotations to inferred proteins. |
| `protein_inference_Algorithm_treat_charge_variants_separately` | Boolean | Not set; tool default | Count charge variants separately when assembling protein evidence. |
| `protein_inference_Algorithm_treat_modification_variants_separately` | Boolean | Not set; tool default | Count modification variants separately when assembling protein evidence. |
| `protein_inference_Algorithm_use_shared_peptides` | Boolean | Not set; tool default | Allow peptides matching multiple proteins to contribute evidence. |
| `protein_inference_Merging_allow_disagreeing_settings` | Boolean | Not set; flag omitted | Allow identification runs with differing search settings to merge. |
| `protein_inference_Merging_annotate_origin` | Boolean | Not set; tool default | Record the source identification run while merging. |
| `protein_inference_decoy_string` | Text | Not set; tool default | Decoy accession marker for picked FDR; match your FASTA when enabling that option. |
| `protein_inference_decoy_string_prefix` | Text | Not set; tool default | Whether the picked-FDR decoy marker is a prefix. |
| `protein_inference_merge_runs` | Text | Not set; tool default | Combine protein identification runs before inference. |
| `protein_inference_picked_fdr` | Boolean | Not set; tool default | Use picked target-decoy competition for protein FDR estimation. |

### Protein and peptide summarization

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `protein_quantifier_average` | Text | Not set; tool default | How selected peptide abundances are summarized for each protein group. |
| `protein_quantifier_consensus_fix_peptides` | Boolean | Not set; tool default | Use a consistent peptide set across assays when quantifying a protein. |
| `protein_quantifier_consensus_normalize` | Boolean | Not set; tool default | Apply consensus-map normalization during protein quantitation; changes the quantities used for summarization. |
| `protein_quantifier_debug` | Integer | Not set; tool default | Diagnostic verbosity for ProteinQuantifier. |
| `protein_quantifier_format_quoting` | Text | Not set; tool default | Quoting convention for exported text fields. Keep compatible with downstream readers. |
| `protein_quantifier_format_replacement` | Text | Not set; tool default | Replacement for separator characters inside text values. |
| `protein_quantifier_format_separator` | Text | Not set; tool default | Output field separator. Keep the default tab separator for the QC and database readers. |
| `protein_quantifier_greedy_group_resolution` | Boolean | Not set; tool default | Resolve shared-peptide associations using the tool’s greedy grouping option. |
| `protein_quantifier_include_all` | Boolean | Not set; flag omitted | Include groups with fewer than the requested number of top peptides. |
| `protein_quantifier_top` | Integer | Not set; tool default | Number of peptides used for top-peptide aggregation per protein group. |

### ProteinProphet options

| Parameter | Type | Default / supplied value | Meaning |
| --- | --- | --- | --- |
| `proteinprophet_maxppmdiff` | Number | Not set; tool default | Maximum precursor mass-error difference accepted by ProteinProphet, in ppm. |
| `proteinprophet_nonsp` | Boolean | Not set; flag omitted | Disable ProteinProphet’s number-of-sibling-peptides adjustment. |
| `proteinprophet_unmapped` | Boolean | Not set; flag omitted | Allow unmapped proteins in the ProteinProphet result. |

### Tool defaults

Version-specific tool references: [IDConflictResolver](https://openms.de/doxygen/release/3.6.0/html/TOPP_IDConflictResolver.html), [IDFilter](https://openms.de/doxygen/release/3.6.0/html/TOPP_IDFilter.html), [ProteinInference](https://openms.de/doxygen/release/3.6.0/html/TOPP_ProteinInference.html), [ProteinQuantifier](https://openms.de/doxygen/release/3.6.0/html/TOPP_ProteinQuantifier.html).

The additional option tables list parameters explicitly forwarded by the pipeline's OpenMS modules. Unset valued options use the tool's defaults; flags are added only when true. Check the configured tool's `-helphelp` for accepted values and interactions. Avoid overriding export formatting or generated input/output options that the next analysis step relies on.

### Computing and temporary files

The [shared parameter reference](../parameters.md#computing-and-temporary-files) explains these settings. This pipeline declares: `base_resource_update`, `max_cpus`, `max_memory`, `min_cpus`, `min_memory`, `resource_allocation_profile_tag`, `ucla_cds`, `work_dir`.

The tables were checked against the [individual pipeline configuration](https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicProtein/tree/5fc1931677f9b4f5d0fa25982580667657dc0ea0/config), its tool modules, and the SpectroMesa-DDA settings that select this workflow.

## Related steps

[Overview](../overview.md) · [Shared parameters](../parameters.md) · [Configuring an analysis](../configuration.md) · [Understanding results](../results.md)

## References

- [OpenMS 3 enables reproducible analysis of large-scale mass spectrometry data (2024)](https://doi.org/10.1038/s41592-024-02197-7).
- [iProphet (2011)](https://doi.org/10.1074/mcp.M111.007690).
- [ProteinProphet (2003)](https://doi.org/10.1021/ac0341261).
