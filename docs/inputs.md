# Preparing inputs

An LFQ analysis needs **two inputs**: an acquisition CSV pointing to your mass spectrometry files, and a target-decoy protein FASTA. A TMT analysis needs those same inputs plus a **channel CSV** describing the samples in each plex. The acquisition files are part of the first input: a CSV pointing to missing files is not a valid input.

The separately obtained MSFragger JAR is part of [installation](installation.md#obtain-msfragger), rather than a sample input.

## Acquisition CSV

Create one row for each acquisition. Use these columns:

| Column | What to enter |
| --- | --- |
| `sample_name` | For LFQ, the sample identifier. For TMT, the plex identifier, matching `plex_id` in the channel CSV. Repeat the name only for fractions belonging to that same sample or plex. |
| `fraction_id` | Fraction identifier, such as `1`, `2`, or `F1`. Use `1` for an unfractionated sample. Each sample/fraction pair must be unique. |
| `annotation_id` | Usually the species name, such as `human`, `mouse`, or `ecoli`. Please include it even though the workflows described here do not currently use it. Keep it consistent across a sample's fractions. |
| `path` | Path to an existing mzML or supported vendor acquisition file. Relative paths are resolved from the CSV's directory. |
| `scan` | For WIFF conversion, the path to its existing `.wiff.scan` companion. Omit this column for mzML input. |

!!! important "Give technical replicates distinct names"
    Files with the same `sample_name` are treated as one sample or TMT plex. Their search results are combined before sample-level validation. Give separate LFQ technical replicates unique names so they remain separate quantitative assays. For TMT, biological samples are identified by their reporter channels, not by the acquisition CSV's `sample_name`.

### LFQ samples and fractions

An unfractionated LFQ input can look like this:

```csv
sample_name,fraction_id,annotation_id,path
sample_01_rep1,1,human,/data/sample_01_rep1.mzML
sample_01_rep2,1,human,/data/sample_01_rep2.mzML
```

For fractionated LFQ, repeat each sample name for its fractions:

```csv
sample_name,fraction_id,annotation_id,path
sample_01,F1,human,/data/sample_01_F1.mzML
sample_01,F2,human,/data/sample_01_F2.mzML
sample_02,F1,human,/data/sample_02_F1.mzML
sample_02,F2,human,/data/sample_02_F2.mzML
```

All LFQ samples must have **the same set of fraction IDs**, including unfractionated runs. Corresponding fractions are aligned and linked across samples. The pipeline detects fractionation from this table; you do not need to enable it separately.

### TMT plexes and fractions

For TMT, use a plex name in `sample_name`. Each row still represents one acquisition, not one reporter channel:

```csv
sample_name,fraction_id,annotation_id,path
plex_01,F1,human,/data/plex_01_F1.mzML
plex_01,F2,human,/data/plex_01_F2.mzML
plex_02,F1,human,/data/plex_02_F1.mzML
plex_02,F2,human,/data/plex_02_F2.mzML
```

Every sample or plex must have multiple fractions, or every one must have a single fraction; mixed layouts are rejected. For feature-based TMT, every plex must also have the same set of fraction IDs. The default scan-based TMT route does not require identical fraction sets across plexes.

### Acquisition paths and naming

All rows must use the same file extension; do not mix RAW and mzML files in one run. Existing mzML files go directly to searching. Other supported file formats pass through [conversion](pipelines/conversion.md). Thermo RAW is covered by an integration case; conversion of another format also depends on support in the configured converter and container. The current DDA input reader accepts files, not Bruker `.d` acquisition directories.

Use sample and fraction identifiers beginning with a letter or digit and containing only letters, digits, dots, underscores, or hyphens. Acquisition basenames must not contain additional dots: `sample_01_F1.mzML` is suitable, while `sample.01.F1.mzML` is not. mzML filenames must be unique within each sample, and the same acquisition path must not appear twice. Avoid commas in paths.

For WIFF conversion, supply its scan companion:

```csv
sample_name,fraction_id,annotation_id,path,scan
sample_01,1,human,/data/sample_01.wiff,/data/sample_01.wiff.scan
```

Keep the acquisition files accessible throughout the run. A path that exists on your laptop but is unavailable on the compute node or inside the container will not work.

## Protein sequence database
### Choose a reference proteome

For a typical experiment, start with the **gene-centric UniProt reference proteome** for the species you are studying. Use the canonical protein FASTA. For human and mouse, expect **about 20,000 proteins** before adding contaminants and decoys. UniProt distributes additional isoform sequences separately in files ending in `_additional.fasta.gz`. See the [UniProt reference proteome file descriptions](https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/reference_proteomes/README).

| Species | Reference proteome | Canonical protein FASTA |
| --- | --- | --- |
| Human | `UP000005640` | [UP000005640_9606.fasta.gz](https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/reference_proteomes/Eukaryota/UP000005640/UP000005640_9606.fasta.gz) |
| Mouse | `UP000000589` | [UP000000589_10090.fasta.gz](https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/reference_proteomes/Eukaryota/UP000000589/UP000000589_10090.fasta.gz) |

For example, download and decompress the human reference proteome:

```bash
curl -fL -o UP000005640_9606.fasta.gz \
    https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/reference_proteomes/Eukaryota/UP000005640/UP000005640_9606.fasta.gz
gunzip UP000005640_9606.fasta.gz
```

Keep a record of the UniProt release and download date so you can identify the exact database used in your analysis. Choose or extend the target sequence set to match your experiment if it includes multiple species or proteins absent from the reference proteome.

### Add contaminants and generate decoys

The pipeline requires a **combined target-decoy FASTA**, containing both the proteins you want to identify and decoy sequences used to estimate false discoveries. We also recommend adding common contaminant sequences so that peptides from laboratory contaminants can be assigned to those proteins.

[MSPtools](https://github.com/TheBoutrosLab/package-MSPtools) can prepare this database in one step.

!!! tip "No separate cRAP download needed"
    MSPtools bundles the cRAP contaminant sequences. Use `--include-crap` to add them and generate their decoys along with the reference-protein decoys.

After installing MSPtools, run:

```bash
msptools FASTA CreateDecoyDatabase \
    --input-path UP000005640_9606.fasta \
    --output-path UP000005640_9606-decoy_contam.fasta \
    --include-crap \
    --decoy-prefix DECOY_ \
    --contam-prefix CONTAM_
```

Start from a target-only FASTA. The resulting `UP000005640_9606-decoy_contam.fasta` contains the reference proteins, contaminants, and decoys for both. By default, MSPtools reverses protein sequences while preserving an initial methionine. The command shows its default prefixes, `DECOY_` and `CONTAM_`, explicitly. The pipeline defaults to `CONTAMINANT_` for contaminants, so update that setting as shown below.

### Match the database markers in your run configuration

Set `decoy_database` to the generated FASTA and check all four marker settings. For the command above, keep the default `decoy_string`, `decoy_position`, and `contam_position`, and change `contam_string` to `CONTAM_`. The matching configuration is:

```groovy
params {
    decoy_database = '/path/to/UP000005640_9606-decoy_contam.fasta'
    decoy_string = 'DECOY_'
    decoy_position = 'prefix'
    contam_string = 'CONTAM_'
    contam_position = 'prefix'
}
```

| Setting | Meaning |
| --- | --- |
| `decoy_string` | The text marking decoy accessions, such as `DECOY_`. |
| `decoy_position` | Where the decoy marker occurs. The current MSFragger workflow requires `prefix`. |
| `contam_string` | The text marking contaminant accessions. The pipeline defaults to `CONTAMINANT_`; use `CONTAM_` for the example above. |
| `contam_position` | Where the contaminant marker occurs: `prefix` or `suffix`. Use `prefix` for the MSPtools command above. |

!!! warning "Match the markers in your FASTA"
    **These settings must match the markers in your FASTA accessions.** A prefix appears at the beginning of the accession; a suffix appears at the end. With the example above, a contaminant accession begins with `CONTAM_`, and its decoy begins with `DECOY_CONTAM_`. Changing a pipeline setting does not rewrite the FASTA headers.

Edit the matching settings in your copy of the pipeline's template, keeping its existing `includeConfig` statements and final `methods.setup()` call.

## TMT channel CSV

For TMT, create a second CSV with `plex_id,channel,description`. `plex_id` must match the acquisition CSV's `sample_name` values exactly. `channel` is the reporter label, and `description` identifies the biological sample or technical replicate assigned to that channel.

For example, a complete ten-channel plex is:

```csv
plex_id,channel,description
plex_01,126,reference
plex_01,127N,sample_01
plex_01,127C,sample_02
plex_01,128N,sample_03
plex_01,128C,sample_04
plex_01,129N,sample_05
plex_01,129C,sample_06
plex_01,130N,sample_07
plex_01,130C,sample_08
plex_01,131,sample_09
```

Add the corresponding rows for every other plex in the acquisition CSV. Match the labels to `quantitate_ProteomicTMT.plex_type`, which defaults to `tmt10plex`; do not mix reporter types in one analysis. Use distinct descriptions for technical replicates you want to distinguish.

!!! important "Identify the normalization reference"
    With the default MAD normalization and a physical reference, label exactly one channel per plex `reference`. The alternative OpenMS normalization uses the same channel convention. MAD's optional virtual-reference mode does not need a channel named `reference`. Choose the route in [Configuring an analysis](configuration.md#tmt-quantitation).

## Before you run

- Check that every acquisition and required scan companion exists and is accessible on the analysis machine.
- Check sample/fraction uniqueness and matching fraction sets where required.
- Set `input_csv` and `decoy_database` to the prepared files and match the FASTA accession markers.
- For TMT, set `channel_csv`, check every plex and reporter label, and configure the labeling modifications used in the search.
