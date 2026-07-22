# Changelog

## Unreleased

### Added

- Collision-free dependency storage derived from canonical repository identity.
- Effective toolchain precedence and ordered declared project builds.
- Native routing for Lazarus `.lpi`/`.lpk` projects through `lazbuild`.
- `boss4d new app|package` protected project scaffolding.
- Deterministic CRLF normalization before checksum and SBOM evidence generation.
- DPK `requires` updates that preserve conditional compilation directives.

### Documentation

- Added dedicated English and Portuguese SBOM feature guides explaining motivation,
  evidence sources, coverage semantics, VEX, attestations, limitations, and the
  recommended release workflow.
- Added bilingual build compatibility guides and a mixed Delphi/Lazarus example.

## 1.1.0 - 2026-07-21

### Added

- CycloneDX 1.7 and SPDX 2.3 SBOM generation through `boss4d sbom`.
- Reproducible, strict, validation, output, root component type, and lock-only modes.
- Opt-in GetIt, Delphi toolchain/RTL, and declared binary artifact collectors.
- Manual SBOM components and shared SPDX-aware license normalization.
- Neutral SBOM domain with extension points for SCA, VEX, merge, and signing.
- Autonomous lock-only generation using root evidence stored in lock schema v2.
- Detached in-toto SHA-256 attestations and offline CycloneDX VEX enrichment.
- Exact Delphi compiler/RTL file provenance and explicit artifact path bases.
- Transactional release build and self-hosted Windows/Delphi SBOM CI matrix.
- Bilingual SBOM migration, release, and copyable usage examples covering VEX,
  attestations, environmental collectors, and artifact path bases.

### Changed

- `boss-lock.json` schema v2 records canonical repository identity, resolved Git
  revision/reference, typed checksum, license provenance, dependency graph, and
  compiled artifact paths while retaining v1 read compatibility.

### Migration

- Existing v1 locks remain readable and are promoted to v2 on the next save.
- Strict SBOM generation requires a v2 lock with revision, checksum, and graph
  evidence. See `docs/sbom-migration.md`.
