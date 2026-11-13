# Changelog

All notable changes to metapipeline-ProteomicDDA are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.8] - 2026-11-12

### Fixed

- Use the validation mzML paths in QC and ProteoVault so reindexed run names match validated idXML.

## [1.2.7] - 2026-11-12

### Changed

- Update `quantitate-ProteomicTMT` to v2.1.0 for OpenMS 3.6.0 quantitation and align its integration fixture fraction IDs.
- Update `quantitate-ProteomicLFQ` to v1.1.0 and `quantitate-ProteomicProtein` to v1.3.0 for OpenMS 3.6.0 quantitation and labeled abundance columns.
- Pass the final LFQ or TMT IDConflictResolver consensusXML directly to protein quantitation.

## [1.2.6] - 2026-11-10

### Changed

- Update `search-ProteomicMSMS` to v1.1.1 so MSFragger PSMs retain their source spectrum FAIMS compensation voltage.

## [1.2.5] - 2026-11-10

### Changed

- Infer validation and LFQ fractionation from input rows and reject datasets mixing single-fraction and multi-fraction samples.
- Select the LFQ protein handoff for a single fractionated sample from its published consensusXML.

## [1.2.4] - 2026-11-10

### Added

- Build and validate a ProteoVault v0.2.1 database after DDA quality control for LFQ and TMT analyses.

### Changed

- Update `quantitate-ProteomicProtein` to v1.2.0 and pass one cohort consensusXML to its protein column reheader step.
- Update `quantitate-ProteomicTMT` to v2.0.0, pass fraction IDs for its feature-based workflow, and hand its dataset-level consensusXML to protein quantitation.
- Switch the existing MSFragger TMT integration case to feature-based quantitation.

## [1.2.3] - 2026-11-07

### Changed

- Update `convert-MSData` to v1.1.1 and follow its preserved or fraction-suffixed output names when creating the downstream mzML manifest.

### Fixed

- Pass search-reindexed mzML files with their fraction mapping through PSM validation and peptide quantitation, enabling spectrum reindexing for fractionated TMT plexes.

## [1.3.0-rc.1] - 2026-11-06

### Added

- Add automatic `convert-MSData` v1.1.0 conversion before DDA search when the input CSV contains vendor RAW or another non-mzML format, while preserving direct mzML input.
- Add a TMT integration case for RAW conversion with one RAW file for each E. coli TMT plex.

## [1.2.2] - 2026-10-28

### Changed

- Update `qc-ProteomicDDA` to release `v1.1.1`, which counts MSBooster PSMs by missed cleavages, cleavage specificity, and precursor charge.

## [1.2.1] - 2026-10-27

### Changed

- Update `validate-ProteomicPSM` to release `v2.3.2`, which fixes MSBooster calibration scores for MSFragger, Comet, and Sage.

## [1.2.0] - 2026-10-27

### Changed

- Update `qc-ProteomicDDA` to release `v1.1.0` and pass published PSMFeatureExtractor idXML and MSBooster PIN files into feature QC.
- Update `validate-ProteomicPSM` to release `v2.3.1`, which repairs ProteinProphet pepXML termini and publishes Percolator feature files for downstream QC.

## [1.1.0] - 2026-10-26

### Added

- Run `qc-ProteomicDDA` release `v1.0.0` after protein quantitation to summarize acquisition, identification, protein grouping, and abundance quality metrics.
- Restore the DDA workflow schematic and include the QC stage.

### Changed

- Update `quantitate-ProteomicProtein` to release `v1.1.2`, which publishes the final ProteinProphet grouping files.

## [1.0.1] - 2026-10-25

### Changed

- Update `quantitate-ProteomicProtein` to release `v1.1.1`, which fixes the ProteinQuantifier `include_all` flag mapping.

## [1.0.0] - 2026-10-25

### Added

- Add a Nextflow DSL2 DDA metapipeline that runs `search-ProteomicMSMS`, `validate-ProteomicPSM`, TMT or LFQ peptide quantitation, and `quantitate-ProteomicProtein`. Each child is launched by a separate process in `module/`.
- Add Comet, Sage, and MSFragger search selection. Merge multiple search-engine results through validation consensus before peptide quantitation, while retaining per-engine PEP-scored idXML for ProteinProphet.
- Add sample- and fraction-aware input handling, optional ProtLoom annotation IDs, child parameter namespaces, shared target-decoy settings, and CSV manifests for the child handoffs.
- Add versioned child output directories, process logs, resource profiles, schema validation, and local template configuration following the DIA metapipeline layout.
- Add NFTest integration cases for MSFragger LFQ, MSFragger TMT, and Sage LFQ, with a Slurm scratch-directory runner and environment-variable expansion for test inputs.
- Add pipeline documentation and an SVG workflow schematic.

### Changed

- Update the protein quantitation child to release `v1.1.0`, including ProteinProphet as the default grouping algorithm.

### Fixed

- Allow Sage-only and Comet-only searches without an MSFragger JAR, while requiring an existing JAR when MSFragger is selected.
- Support multiple mzML fractions per TMT plex and LFQ sample in the parent handoffs.

[1.0.0]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/releases/tag/v1.0.0
[1.0.1]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.0.0...v1.0.1
[1.1.0]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.0.1...v1.1.0
[1.2.0]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.1.0...v1.2.0
[1.2.1]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.2.0...v1.2.1
[1.2.2]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.2.1...v1.2.2
[1.2.3]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.3.0-rc.1...v1.2.3
[1.2.4]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.2.3...v1.2.4
[1.2.5]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.2.4...v1.2.5
[1.2.6]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.2.5...v1.2.6
[1.2.7]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.2.6...v1.2.7
[1.2.8]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.2.7...v1.2.8
[1.3.0-rc.1]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.2.2...v1.3.0-rc.1
[unreleased]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.2.8...HEAD
