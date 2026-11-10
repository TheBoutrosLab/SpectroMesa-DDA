# Integration tests

Use `test/run-nftest.sh <case>` from the repository root in a Slurm allocation.
Set `NFX_VER`/`NXF_VER`, `NXF_SYNTAX_PARSER`, and `TEST_DATA_DIR` in `.env`.
The LFQ case uses its repository CSV with two fractions for each of two samples.
It expects the named `$TEST_DATA_DIR/ecoli_lfq/mzML/` files, the matching
FASTA under `database/`, and
`MSFragger-4.4.1.jar` in `TEST_DATA_DIR`. The TMT case uses repository input and channel CSVs with three mzML fractions
for each of the Fr1 and Fr2 plexes. It expects the six `ecoli_tmt/mzML/` files
named in its input CSV, the same FASTA, and `MSFragger-4.4.1.jar` under
`TEST_DATA_DIR`.
The input CSV uses `sample_name,fraction_id,path`; ProtLoom runs also need `annotation_id`.
The TMT sample names must match the `plex_id` values in `channel.csv`.
`test_integration_MSFragger_TMT_Protein` selects feature-based TMT quantitation with MAD normalization.
All complete LFQ and TMT cases build `<dataset_id>.proteovault.duckdb` under the versioned metapipeline output directory after QC.

`test_integration_MSFragger_TMT_Reindexed` uses two mzML fractions per E. coli TMT plex with `reindex_mzml = true`. It checks the complete search-to-validation-to-TMT handoff, including reporter extraction and identification mapping after scan IDs are made unique within each plex. Its input uses the same mzML fixtures, FASTA, and MSFragger JAR as the standard TMT case.

`test_integration_Sage_LFQ_Protein` uses the same LFQ fixture with Sage search settings from the ecoli_lfq benchmark. It needs no MSFragger JAR.
`test_integration_MSFragger_TMT_RAW` starts with ProteoWizard conversion of Thermo RAW files, then uses the existing MSFragger TMT search and quantitation settings. Its `input.csv` names one RAW file for each of the two E. coli TMT plexes. Keep the `sample_name` values aligned with `channel.csv` (`Ecoli_12prot_spike_Fr1` and `Ecoli_12prot_spike_Fr2`). The copied channel manifest can be edited if different plexes are used.
