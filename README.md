# Boss4D

<p align="center">
  <img src="docs/imgs/header_boss4d.jpg" alt="Boss4D Header" width="100%">
</p>

[Read in English](README.md) | [Leia em Português](README.pt-BR.md)

**Boss4D** is a modern native dependency manager for Delphi and Lazarus
projects. The Windows CLI is built with Delphi 13, the IDE plugin targets
Delphi 10/10.1 and is validated locally with Delphi 10, 11, 12, and 13. Native
FPC 3.2.2 command-line releases are built and tested for Linux x86-64 and
macOS arm64.

---

## ⚡ Key Features

1. **Native & Lightweight**: Executables compiled natively with Delphi or FPC,
   without a Go runtime. Individual operations use host tools such as Git,
   MSBuild, `lazbuild`, GnuPG, or Secret Service.
2. **Hexagonal Architecture (Ports & Adapters)**: Rigorous separation between core domain logic (package rules), use case services, and infrastructure adapters (Git, HTTP, and Compiler).
3. **Concurrent Downloads**: Employs Delphi's **Parallel Programming Library (PPL)** (`TTask` and `TParallel`) to download and clone multiple package dependencies concurrently during the installation phase.
4. **Command Buffer Overflow Prevention**: Implements the `@boss.cfg` configuration file technique to pass search paths directly to MSBuild, avoiding the Windows command-line 8191-character limit (Issue #205).
5. **Multi-path mainsrc Support**: Fully supports multiple paths separated by semicolons in the `mainsrc` option (aligned with BOSS Go PR #256).
6. **Thread-Safe Colored Logging**: Outputs clean, colored console logs asynchronously using critical sections, with optional `.log` file persistence for debug mode.
7. **100% Testable**: Comprehensive DUnitX unit-testing suite using Mock adapters to isolate network (HTTP), Git processes, and compiler executions.
8. **Deterministic Package Builds**: Collision-free module directories, declared project ordering, toolchain precedence, and safe CRLF normalization.
9. **Delphi and Lazarus Projects**: Builds declared `.dproj`, `.lpi`, and `.lpk`
   projects through MSBuild or `lazbuild`, automatically integrating resolved
   dependency unit paths into Lazarus projects and build modes.
10. **Multi-Delphi Build Matrix**: Declares Delphi 10/10.1/11/12/13,
    Win32/Win64, Debug/Release, runtime/design projects, dependency ordering,
    isolated artifacts, incremental state, safe parallelism, and transactional
    IDE registration without breaking legacy manifests.

---

## 🤝 Compatibility with BOSS projects

**Boss4D** accepts legacy manifests as a migration path without requiring a
project restructure:
* **Compatible Manifest**: Boss4D reads and preserves legacy string/string maps
  in `boss.json`.
* **Identical Directory Structure**: All project dependencies continue to be resolved locally under the `modules/` folder.
* **Evolving Lock**: Older locks remain readable, while `boss-lock.json` v3 adds
  scopes, checksums, graph, and Boss4D-specific evidence; this extension does
  not imply bidirectional compatibility with other tools.

---

## 📂 Project Directory Structure

```text
Boss4D/
├── src/
│   ├── Core/
│   │   ├── Domain/       # Domain entities and validation (SemVer, Dependency, Package, Lock)
│   │   ├── Ports/        # Deserialized Ports (interfaces) decoupling logic and infrastructure
│   │   └── Services/     # Use cases (Init, Config, Install)
│   ├── Adapters/         # Concrete adapters (Json, Http, Git, Registry, Compiler, Logger)
│   ├── CLI/              # Command line argument parser
│   └── Boss4D.dpr        # Executable console entry point
└── tests/                # DUnitX test project, mocks, and suites
```

---

## 🚀 Compiling and Validating the Project

Since Boss4D is written in modern Delphi, you can build it in two ways:

### 1. Via the RAD Studio IDE
* Open **`src/Boss4D.dpr`** or **`tests/Boss4DTests.dpr`** in the IDE; RAD Studio creates local project metadata when needed.
* Press **Ctrl + F9** to build.
* Press **F9** on the test project to run the DUnitX test runner.

### 2. Via RAD Studio Command Prompt
Open the RAD Studio Command Prompt and navigate to the project directory:

```cmd
cd /d d:\Projetos\BossDelphi
```

* **To compile and run the unit test suite**:
  ```cmd
  msbuild tests\Boss4DTests.dpr /p:Configuration=Debug
  tests\Win32\Debug\Boss4DTests.exe
  ```

* **To compile the production CLI**:
  ```cmd
  msbuild src\Boss4D.dpr /p:Configuration=Release
  ```

---

## 📚 Supported Commands

* `boss4d init`
  Interactively initializes a new `boss.json` file in the current directory.
  * *Flags*: `-q`, `--quiet` (creates a default file silently).
* `boss4d install`
  Reads the local `boss.json`, resolves the dependency graph recursively using
  SemVer, downloads modules, updates `boss-lock.json`, and triggers compilation.
  When `buildMatrix` is declared, it detects every compatible installed Delphi,
  builds the supported Win32/Win64 targets, and registers design-time packages.
  Use `--no-register` for a dependency-only or CI-style installation.
* `boss4d install <url>@<version>`
  Adds and installs a specific package dependency.
  * *Example*: `boss4d install github.com/hashload/horse@^3.1.0`
  * *Git references*: Supports tags, branches (e.g. `@master`), or commit hashes.
* `boss4d add|remove|update|list|why`
  Manages and inspects the complete dependency lifecycle with automatic rollback
  of `boss.json`, `boss-lock.json`, and `modules/` on failure. See the
  [dependency lifecycle guide](docs/dependency-lifecycle.md).
* `boss4d package versions`, `pin|unpin`, `upgrade|downgrade`, and `rollback`
  Provides deterministic SemVer selection, exact pins, durable version-history
  snapshots, and transactional recovery. See
  [version management](docs/version-management.md).
* `boss4d ci` / `boss4d install --locked|--frozen-lockfile|--offline|--production [--jobs <n>]`
  Runs reproducible installs with clean CI, offline cache, and production-only
  dependency support.
* `boss4d dependencies|tree|why|outdated` and `boss4d run <script>`
  Inspects the graph, explains dependencies, discovers updates, and runs
  manifest scripts.
* `boss4d registry add|remove|list|health`, `search`, and `info`
  Manages public/private Registry v1/v2 sources, audits the complete catalog,
  and provides package discovery. The current catalog contains 55 packages:
  16 signed schema-v2 releases and 39 legacy discovery entries.
* `boss4d package install <name>@<version>` and `boss4d pack`
  Installs or creates deterministic `.b4dpkg` files with compiler/platform
  selection, SHA-256, OpenPGP, and in-toto provenance.
* `boss4d publish [--dry-run]`, `boss4d publish --official --open-pr`, and
  `boss4d conformance registry|package <file>`
  Publishes to HTTP registries or prepares a signed, verified bundle, updates
  a clean Registry checkout, and opens the reviewed public Registry PR.
* `boss4d audit [--fail-on <severity>]`
  Queries OSV for locked revisions, with offline cache and VEX support.
* `boss4d doctor`, `cache`, `tool`, `plugin`, `getit`, and `license report`
  Covers diagnostics, cache maintenance, global tools, Windows integrations,
  and license reports.
  The GUI Health Center groups environment checks and exposes remediation,
  auto-fix, IDE repair/undo, and cache-prune actions.
* `boss4d doc [-o <folder>] [--no-dependencies]`
  Generates a searchable API site from PascalDoc/XML Doc comments in the
  project and installed dependencies. See the
  [static API documentation guide](docs/api-documentation.md).
* `boss4d spec --detect [--compiler <version>]`
  Detects `.dproj`/`.dpk` files, runtime/design directives, and local package
  dependencies, then persists a deterministic `buildMatrix`.
* `boss4d build [--compiler <version>|all] [--platform Win32|Win64|all]`
  `[--configuration Debug|Release|all] [--jobs <n>] [--force] [--full]`
  `[--explain] [--register]`
  Executes the selected matrix with isolated outputs, incremental rebuild,
  graph-safe parallelism, explanations, and optional exact IDE registration.
* `boss4d support [--compiler <version>|all] [--platform <target>|all]`
  `[--kind runtime|design|application|tool|binary] [--project <path>]`
  Reports `certified`, `compatible`, `experimental`, or `unsupported` for the
  requested compiler/platform/project combination.
* `boss4d ide unregister <package> --compiler <version> --platform <platform>`
  and `boss4d ide repair`
  Remove one exact registration or reconcile registry drift transactionally.
* `boss4d ide profile list|create|show|target|clone|remove|export|import|launch`,
  `snapshot|diff|restore|history|undo`, and
  `preview-install|install|repair|preview-uninstall|uninstall`
  Manages isolated RAD Studio Registry branches and performs previewable,
  transactional product installation. The GUI exposes the immutable operation
  journal as a structured timeline with recovery and undo evidence, plus a
  profile dashboard for live drift, installed-product comparison, and direct
  isolated IDE launch. See the
  [IDE profile and component guide](docs/ide-component-management.md).
* `boss4d config delphi use <path_or_release_version>`
  Sets the global path or the release version (e.g. "23.0", "22.0") of the Delphi installation directory for MSBuild. If not specified, the compiler adapter will automatically detect the latest installed Delphi version.
* `boss4d config git shallow <true/false>`
  Enables or disables shallow clones for faster Git download processes.
* `boss4d version`
  Prints the CLI version (`v1.6.0-delphi-native`).
* `boss4d self-update`
  Downloads the official installer, verifies it against `SHA256SUMS.txt`, and
  starts the update only after a successful SHA-256 check.
* `boss4d new <template> <name> [--path <directory>]`
  Creates protected Delphi, VCL, FMX, API (Horse + Dext), DUnitX, Lazarus, or
  workspace projects without overwriting a non-empty directory.
* `boss4d sbom --format cyclonedx|spdx --output <file> --validate`
  Generates CycloneDX 1.7 or SPDX 2.3 from `boss.json` plus `boss-lock.json` v3.
  `--lock-only` can generate a reproducible release SBOM using only root and
  dependency evidence stored in the lock. Optional collectors add GetIt inventory,
  Delphi compiler/RTL provenance, and declared artifact hashes. CycloneDX can also
  import offline VEX data and both formats support detached SHA-256 attestations.
  See [why and how SBOM support works](docs/sbom.md), the
  [CLI reference](docs/usage.md#71-sbom-generation-sbom),
  [copyable examples](docs/sbom-examples.md), and
  [v3 migration guide](docs/sbom-migration.md).
* `boss4d help`
  Prints the CLI help menu.

---

## 📖 Additional Documentation
* **[Start with Your Use Case](docs/use-cases.md)**: Everyday, risk-aware workflows for dependencies, Registry credentials, publication, compliance, Multi-Delphi builds, IDE recovery, Linux, CI, releases, and self-update.
* **[SBOM Feature Guide](docs/sbom.md)**: Motivation, evidence model, coverage, VEX, attestations, limitations, and recommended release workflow.
* **[Deterministic Build Improvements](docs/build-improvements.md)**: Collision-free paths, toolchains, declared projects, Lazarus, scaffolding, and normalization.
* **[Build Matrix Guide and Contract](docs/build-matrix-contract.md)**: Schema, CLI workflow, compiler conventions, migration, diagnostics, troubleshooting, and acceptance rules for multi-version Delphi builds.
* **[Component Build and IDE Lifecycle](docs/component-build-and-ide.md)**: Complete guide to project kinds, support levels, shared cache, IDE assets, conflicts, active repair, and safe removal.
* **[IDE Profiles and Component Management](docs/ide-component-management.md)**: Isolated Registry branches, runtime/design products, project bindings, snapshots, drift, restore/undo, CLI/GUI workflows, and everyday examples.
* **[Dependency Lifecycle](docs/dependency-lifecycle.md)**: Transactional add, update, and remove plus graph-aware list and why commands.
* **[Reproducible Installation](docs/reproducible-install.md)**: Frozen locks, offline cache behavior, CI clean installs, and rollback guarantees.
* **[Dependency Scopes](docs/dependency-scopes.md)**: `devDependencies`, production installs, lock v3, and SBOM scope evidence.
* **[Vulnerability Audit](docs/audit.md)**: OSV commit queries, offline cache, severity gates, and VEX suppression.
* **[Git Trust Policy](docs/trust-policy.md)**: Signed commit/tag verification and allowed signer enforcement.
* **[Package Indexes](docs/package-index.md)**: Public/private registries,
  search/info, rich GUI catalog, guided version/platform installation,
  cancellable progress/retry, and IDE discovery.
* **[GitHub Dependency Submission](docs/github-dependency-submission.md)**: Publish lock v3 snapshots to the GitHub Dependency Graph.
* **[Cache Strategy](docs/cache-strategy.md)**: Safe Git object reuse and platform/compiler-isolated executable artifacts.
* **[Project Templates](docs/templates.md)**: Delphi, VCL, FMX, Horse+Dext API, DUnitX, Lazarus, and workspace presets.
* **[Package Publishing](docs/publish.md)**: Dry-run, validation gates, token handling, and public/private registry contracts.
* **[Version Management](docs/version-management.md)**: Registry versions, revocation, pin/unpin, upgrade/downgrade, mirrors, and rollback.
* **[Platform Portability](docs/platform-portability.md)**: Portable contracts, native Linux/macOS coverage, and explicit Windows capability boundaries.
* **[Terminal Progress](docs/terminal-progress.md)**: Interactive, plain, JSON Lines, and quiet progress output for installs and CI.
* **[Secure Self-update](docs/self-update.md)**: Release discovery, SHA-256 verification, staging, and installer handoff.
* **[Release Artifact Matrix](docs/release-artifact-matrix.md)**: Windows/Linux/macOS builders, checksums, OIDC provenance, and tag promotion gates.
* **[Publisher Onboarding](docs/publisher-onboarding.md)**: Open community proposals, maintainer approval, publisher identity, signer onboarding, and immutable metadata.
* **[Registry Migration Plan](docs/registry-migration-plan.md)**: Curated waves for moving legacy discovery entries to signed schema-v2 packages.
* **[Parity Completion Audit](docs/parity-audit-2026-07-30.md)**: Requirement-by-requirement implementation and verification evidence.
* **[Immutable Package Format](docs/package-format.md)**: Deterministic `.b4dpkg`, verified installation, OpenPGP/in-toto evidence, source fallback, and compiler/platform variants.
* **[Legacy Delphi Compatibility](docs/legacy-delphi.md)**: Full modern wizard plus legacy integration profiles for Delphi 10 Seattle/BDS 17.0 and Delphi 10.1 Berlin/BDS 18.0.
* **[FPC/POSIX CLI](docs/posix-cli.md)**: Native Linux/macOS builds, dependency lifecycle, lock v3, frozen/offline CI, SemVer resolution, and FPCUnit tests.
* **[Static API Documentation](docs/api-documentation.md)**: Motivation, syntax, supported declarations, safe scanning, CI workflows, and current limits.
* **[Competitive Positioning](docs/competitive-positioning.md)**: Evidence-based comparison with BOSS, DPM, GetIt, Lazarus OPM, and mature package ecosystems.
* **[Resolution and Secure Credentials](docs/resolution-and-credentials.md)**: Highest/minimal SemVer policies and native credential storage.
* **[Conformance and Ecosystem](docs/conformance-and-ecosystem.md)**: Public protocol validation, static registry portal, and deterministic benchmarks.
* **[CLI Usage Manual](docs/usage.md)**: Detailed step-by-step guide covering all command options and dependency configurations.
* **[Contribution Guide](CONTRIBUTING.md)**: Coding standards and guidelines for contribution.
* **[Release Guide](RELEASE_GUIDE.md)**: Steps and instructions to compile with Delphi 13 (37.0) and publish releases on GitHub.
* **[Project Backlog](docs/backlog.md)**: Consolidated delivery status and next investments in macOS, documentation, performance, and ecosystem growth.
* **[Backlog Prioritization](docs/matriz_priorizacao.pt-BR.md)**: Technical ROI analysis prioritizing the project epics (Portuguese).

---

## ❤️ Special Thanks

This project is a direct evolution and native port of the original **[HashLoad BOSS](https://github.com/HashLoad/boss)**. We express our sincere gratitude and recognition to the **HashLoad** team and all their contributors for their brilliant initiative in introducing a modern package management ecosystem to the global Delphi community.
