# Changelog

## Unreleased

## 1.6.0 - 2026-07-30

### Added

- Registry v2 composition with backward-compatible v1 includes, sparse package
  metadata, persistent sources, ETag/Last-Modified revalidation, offline cache,
  ordered metadata/artifact mirrors, and explicit version revocation.
- Verified `.b4dpkg` installation with deterministic compiler/platform variant
  selection, external and embedded SHA-256 evidence, optional OpenPGP
  signatures, in-toto provenance, transactional extraction, and Git fallback.
- Native Linux/FPC parity for locked dependency installation, Registry
  discovery, package verification, CycloneDX/SPDX generation, VEX, OSV audit,
  secure publication, credentials, cache, workspaces, global tools, and
  transactional self-update.
- Daily Linux project workflows: `update`/`upgrade`, `dependencies`/`tree`,
  `why`, `outdated`, and `run`, including rollback and preservation of immutable
  Registry artifacts.
- Stable operational output through interactive, plain, JSON Lines, and quiet
  renderers, cooperative cancellation, classified exit codes, and `doctor`.
- Secure immutable publication with deterministic payloads, lock/test/worktree
  gates, environment or Secret Service credentials, and HTTP 409 conflict
  handling.
- Public publisher onboarding through reviewed scope and OpenPGP fingerprints,
  a package template, submission validator, negative tests, and pull-request
  workflow.
- Automated tag releases for Windows x86/x86-64 and Linux x86-64, combined
  SHA-256 manifests, machine-readable artifact matrix, and GitHub OIDC build
  provenance.
- Real release-gate builds of the IDE plugin with Delphi 10.1, 11, 12, and 13.
- Final parity and competitive audits covering implementation evidence and the
  remaining ecosystem investments.

### Changed

- Clarified README compatibility guarantees: legacy `boss.json` maps remain
  supported, while lock v3 is an intentional Boss4D extension.
- Documented external host-tool requirements and separated Windows CLI, legacy
  IDE plugin, and native Linux compiler support.
- Consolidated the bilingual command reference and current/future backlog.

## 1.5.0 - 2026-07-30

### Added

- Injectable process, platform-environment, and directory-link contracts, with
  Windows adapters and unit coverage as the foundation for portable CLI hosts.
- Bilingual platform-portability architecture and capability documentation.
- Thread-safe structured install/CI progress with interactive, plain, JSON
  Lines, and quiet output modes.
- Bilingual terminal-progress usage and event-schema documentation.
- Secure `self-update` using the official installer and published SHA-256
  manifest, with tamper rejection and unit coverage.
- Deterministic `boss4d pack` artifacts with per-file and package SHA-256
  evidence, embedded into versioned registry publication payloads.
- Versioned public registry index schema with immutable artifact metadata.
- Delphi 10.1 Berlin IDE integration profile corrected to target BDS 18.0, alongside
  the full Delphi 11/12/13 wizard builds.
- Native FPC 3.2.2 Linux CLI host with FPCUnit coverage for platform detection,
  manifest initialization, dependency naming, and Git installation arguments.
- Explicit highest/minimal compatible SemVer resolution with deterministic,
  input-order-independent selection.
- Windows Credential Manager storage for GitHub/GitLab tokens; secrets are no
  longer serialized to `boss.cfg.json`.
- In-toto package provenance and optional verified OpenPGP detached signatures
  for immutable `.b4dpkg` artifacts.
- Public registry/package conformance commands, HTML-escaped static registry
  portal generation, and a deterministic pack benchmark.

### Changed

- The official public registry is now the default discovery source, with an
  offline built-in catalog used when the network source is unavailable.
- The Linux FPC validation runner normalizes commands to LF before executing
  them inside Docker.

## 1.4.0 - 2026-07-30

### Added

- Transactional `add`, `remove`, `update`, `list`, and `why` dependency
  lifecycle commands, including orphan lock pruning and automatic rollback of
  manifest, lock, and modules.
- Bilingual dependency lifecycle documentation and unit coverage for graph
  inspection and transaction failures.
- Frozen and offline installs through `--locked`, `--frozen-lockfile`, and
  `--offline`, plus a clean transactional `boss4d ci` workflow.
- `devDependencies`, `--dev`, and `--production`, with runtime/development
  scope evidence in lock schema v3, CycloneDX, and SPDX.
- OSV commit-based `audit` with revision cache, offline operation, severity
  policy gates, and VEX suppression.
- Manifest trust policies for native Git commit/tag signature verification and
  allowed signer enforcement before checkout.
- Configurable local/HTTP package indexes with `registry`, `search`, and `info`,
  shared by the CLI, standalone GUI catalog, and RAD Studio integration.
- GitHub Dependency Submission snapshots generated from lock v3 with direct and
  transitive relationships plus runtime/development scopes.
- Safe Git object reuse without working-file hardlinks and compiled executable
  caching isolated by source checksum, platform, and compiler version.
- Protected VCL, FMX, Horse+Dext API, DUnitX, Lazarus application/package, and
  workspace project templates.
- Gated `publish` workflow with deterministic registry metadata, offline
  dry-run, clean-worktree and test checks, immutable lock evidence, and
  environment-only bearer tokens.

## 1.3.0 - 2026-07-29

### Added

- Integração determinística dos paths de dependências em `OtherUnitFiles` para
  projetos Lazarus `.lpi` e pacotes `.lpk`, incluindo todos os build modes.

## 1.2.1 - 2026-07-27

### Added
- Suporte a caminhos de depuração (`browsingpath`) de pacotes na integração com a IDE (RAD Studio).

### Fixed
- Correção na injeção de dependências em arquivos DPK (`requires`) tratando corretamente comentários de fim de linha `//` e múltiplos blocos sob diretivas condicionais (`{$IFDEF}`).

## 1.2.0 - 2026-07-21

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
