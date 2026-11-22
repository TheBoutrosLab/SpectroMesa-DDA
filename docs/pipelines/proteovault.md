# Results database

**[ProteoVault](https://github.com/TheBoutrosLab/package-ProteoVault)** combines completed DDA results into a validated DuckDB database. It provides a common entry point for querying identifications, quantitative results, sequence information, and QC.

## How it works

1. Collect the completed search, validation, LFQ or TMT, protein quantitation, and QC outputs.
2. Import the acquisition manifest and target-decoy FASTA; TMT also supplies the channel CSV and reporter type.
3. Build the database using ProteoVault's DDA importer and validate it before publishing.

## Inputs and outputs

All inputs are supplied automatically. The output is `<dataset_id>.proteovault.duckdb` under `<output_dir>/SpectroMesa-DDA-<version>/`, above the dataset's analysis directory. The individual analysis outputs remain available alongside the database.

Load and analyze the database in R using [ProteoVaultR](https://github.com/TheBoutrosLab/package-ProteoVaultR). Source paths stored in the database refer to the build work directory; use `proteovault update-paths` when you need to reconnect those links after moving the results. See the [ProteoVault CLI guide](https://github.com/TheBoutrosLab/package-ProteoVault/blob/v0.2.5/docs/cli.md).

## Parameter reference

These are shared settings directly inside `params`, without a separate block:

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `run_proteovault` | Boolean | `true` | Already enabled. Set false to finish after QC without assembling the database. |
| `proteovault_version` | Text | `0.2.5` | ProteoVault image version. Check importer compatibility before changing it. |
| `docker_image_proteovault` | Text | `ghcr.io/theboutroslab/proteovault:0.2.5` | Container image used to build and validate the database. |

When the default image is still selected, changing `proteovault_version` updates its image tag during setup. An explicitly chosen alternative image takes precedence. This setting controls only database assembly, not the upstream analysis.

## Related steps

[Understanding results](../results.md) · [Quality control](qc.md) · [Shared parameters](../parameters.md)
