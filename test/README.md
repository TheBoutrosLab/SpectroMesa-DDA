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

`test_integration_Sage_LFQ_Protein` uses the same LFQ fixture with Sage search settings from the ecoli_lfq benchmark. It needs no MSFragger JAR.
