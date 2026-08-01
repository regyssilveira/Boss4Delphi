# Changelog

## Unreleased

## 1.7.0 - 2026-07-31

### Added

- Bilingual, risk-aware use-case guides covering 53 everyday workflows across
  project dependencies, Registry/credentials, secure publication, compliance,
  Multi-Delphi builds, IDE recovery, Linux/CI, releases, and self-update.
- Declarative, backward-compatible build matrix for Delphi 10 (`17.0`), 10.1
  (`18.0`), 11 (`22.0`), 12 (`23.0`), and 13 (`37.0`) across Win32/Win64 and
  Debug/Release.
- `spec --detect`, matrix-aware `build`, independent axis filters, `--jobs`,
  `--force`, `--full`, `--explain`, and exact `--register`.
- Stable project graph, incremental fingerprints, complete target cache,
  isolated `bin`/`bpl`/`dcp`/`dcu` trees, and resource-safe parallel scheduling.
- Transactional IDE inventory, exact unregister, drift repair, rollback, and
  `ide unregister` / `ide repair` commands.
- Project-aware doctor diagnostics for toolchains, paths, matrix/graph,
  missing or escaping projects, output/unit collisions, and registry drift.
- Dependency-ready parallel scheduling, reverse dependent builds,
  `--affected`, `--with-dependents`, and `--all-installed`.
- SHA-256-verified local and shared compiled-artifact cache with atomic
  restoration through `--remote-cache`.
- Isolated `ci`, `restore --ci`, and `install --build-only` workflows that
  enforce the lock, clean modules, and suppress IDE registration.
- Delphi XE through Delphi 13 capability modeling, cross-platform targets,
  applications, tools, prebuilt binaries, and experimental C++Builder support.
- `boss4d support` reports certified, compatible, experimental, and unsupported
  compiler/platform/project combinations with reasons.
- IDE assets for tools, templates, DLLs, CHM help, and restricted managed
  Registry values; active repair rebuilds missing artifacts.
- Explicit `fail`, `warn`, `adopt`, and `replace` IDE conflict policies plus
  dependency-safe complete and cascading uninstall.
- Optional and conditional runtime/design dependencies scoped by compiler,
  platform, and configuration while preserving legacy `dependsOn`.
- SHA-256-protected IDE profile snapshots, drift comparison, deterministic
  restore, project-to-profile binding, and compiler compatibility checks.
- Automatic pre-operation snapshots and tested undo for completed component
  installation and removal through both CLI and GUI.
- Immutable Registry version selection with `package versions`, exact
  installation, pin/unpin, upgrade/downgrade, transactional snapshots, and
  rollback.
- Searchable Registry v2 portal, consolidated search index, publisher trust
  badges, migration health metrics, and validated GitHub Pages publication.
- Version-aware GUI catalog plus complete profile target, preview, install,
  repair, uninstall, snapshot, history, and undo workflows.
- Static Pascal API documentation generation on Delphi and FPC hosts.
- Official Registry publication that generates signed metadata, updates a clean
  checkout transactionally, pushes an isolated branch, and opens a reviewed
  GitHub pull request.
- Community publisher onboarding guarded by GitHub owner authorization,
  repository scope, OpenPGP signer policy, immutable metadata, automated
  validation, and CODEOWNER approval.
- Native macOS arm64 FPC CLI release and CI validation alongside Linux x86-64.
- First curated Registry migration completed with 16 signed schema-v2 packages,
  including Boss4D, Dext, horse-crud, horse-sanitize, and the maintained Horse
  middleware set.
- Bounded concurrent Git acquisition with keyed operation gates and preserved
  deterministic installation behavior.
- Rich GUI catalog details for description, license, version and revocation
  history, compiler/platform variants, and digest/signature/provenance evidence.
- Guided GUI installation of immutable Registry packages with explicit version,
  compiler, platform, source-fallback policy, confirmation, and a copyable
  equivalent CLI command.
- Observable guided-install lifecycle in the GUI with a marquee progress
  indicator, elapsed time, cooperative cancellation of the child CLI process,
  explicit cancelled state, and retry of the preserved request.
- Structured environment health reports and a GUI Health Center grouped by
  tools, Delphi, compiler, and configuration, with summary counts,
  remediation guidance, environment auto-fix, IDE repair/undo, and cache prune.
- IDE operation timeline before/after comparison and confirmed rollback of a
  selected install/uninstall entry, with a compensating safety snapshot.

### Changed

- Dext now resolves and links to its canonical `cesarliws/dext` upstream,
  uses the same canonical publisher repository, and keeps signed Boss4D
  artifacts separate through explicit `distributionRepository` metadata.
- Delphi aliases from `xe` through `d13`, their package suffixes, compiler
  symbols, platforms, and path tokens are normalized through tested convention
  and capability tables.
- The release artifact and installer include the Delphi 10 Seattle/BDS 17.0
  legacy IDE plugin alongside the existing supported IDE targets.
- Sonar Quality Gate is clean with zero new violations.
- Public Registry health now reports 55 packages, 16 trusted schema-v2
  packages, 39 legacy discovery entries, 78 migration warnings, and zero
  structural errors.

### Fixed

- Deterministic packages exclude Git worktree pointer files.
- Verified release installation reliably honors artifact mirrors and
  `--no-source-fallback`.
- Registry migration removes legacy discovery metadata atomically only after
  the trusted sparse entry is accepted.

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
- Release-gate plugin matrix targeting Delphi 10.1/BDS 18.0 and validated
  locally with Delphi 11, 12, and 13.
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
