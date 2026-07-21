# Changelog

## Unreleased

### Added

- CycloneDX 1.7 and SPDX 2.3 SBOM generation through `boss4d sbom`.
- Reproducible, strict, validation, output, root-type, and lock-only modes.
- Opt-in GetIt, Delphi toolchain/RTL, and declared binary artifact collectors.
- Manual SBOM components and shared SPDX-aware license normalization.
- Neutral SBOM domain with extension points for SCA, VEX, merge, and signing.

### Changed

- `boss-lock.json` schema v2 records canonical repository identity, resolved Git
  revision/reference, typed checksum, license provenance, dependency graph, and
  compiled artifact paths while retaining v1 read compatibility.

### Migration

- Existing v1 locks remain readable and are promoted to v2 on the next save.
- Strict SBOM generation requires a v2 lock with revision, checksum, and graph
  evidence. See `docs/sbom-migration.md`.
