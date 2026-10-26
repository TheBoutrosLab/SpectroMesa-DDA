# Changelog

All notable changes to metapipeline-ProteomicDDA are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
