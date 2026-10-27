# Changelog

All notable changes to metapipeline-ProteomicDDA are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
[unreleased]: https://github.com/TheBoutrosLab/metapipeline-ProteomicDDA/compare/v1.2.1...HEAD
