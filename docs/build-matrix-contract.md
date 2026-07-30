# Build matrix contract

This document defines the compatibility rules and the declarative model used by
Boss4D to describe builds across multiple Delphi versions.

## Initial scope

The first advanced matrix covers:

- Delphi 10 (`BDS 17.0`), Delphi 10.1 (`BDS 18.0`), Delphi 11 (`BDS 22.0`), Delphi 12 (`BDS 23.0`),
  and Delphi 13 (`BDS 37.0`);
- `Win32` and `Win64`;
- `Debug` and `Release`;
- runtime and design-time packages;
- selection of one target, multiple targets, or the complete matrix.

Existing Lazarus support remains valid, but an advanced Lazarus matrix is not
part of this first stage.

## `boss.json` compatibility

Existing formats remain valid without migration:

- `projects` continues to accept a list of strings;
- `scripts`, `dependencies`, and `devDependencies` remain `string: string`
  maps;
- `engines.compiler`, `engines.platforms`, and `toolchain` keep their current
  meaning;
- without a declared matrix, Boss4D keeps the current precedence: CLI
  argument, `toolchain`, `engines`, then the `Win32` default;
- saving a legacy manifest never silently converts strings into objects.

The matrix is additive. New fields do not change the parsing,
serialization, or effective result of a legacy manifest.

## Declarative syntax

```json
{
  "buildMatrix": {
    "compilers": ["17.0", "18.0", "22.0", "23.0", "37.0"],
    "platforms": ["Win32", "Win64"],
    "configurations": ["Debug", "Release"],
    "defaults": {
      "compiler": "37.0",
      "platform": "Win64",
      "configuration": "Release"
    },
    "projects": [
      {
        "path": "packages/ComponentRuntime.dproj",
        "kind": "runtime"
      },
      {
        "path": "packages/ComponentDesign.dproj",
        "kind": "design",
        "dependsOn": ["packages/ComponentRuntime.dproj"],
        "compilers": ["22.0", "23.0", "37.0"],
        "platforms": ["Win32"],
        "configurations": ["Release"]
      }
    ]
  }
}
```

The global axes declare every supported value. Optional arrays on a project
restrict that project to a subset of each global axis. A project constraint
outside its global axis, duplicate values, unsupported platform/configuration,
duplicate project paths, and a selection that yields no targets are rejected
before compilation.

`kind` accepts `runtime` or `design` and defaults to `runtime`. `dependsOn`
records build relationships by project path. Dependencies are resolved for the
same compiler, platform, and configuration as the consuming target. Boss4D
performs a stable topological sort, rejects missing compatible targets, and
reports every project participating in a cycle before compilation.

Default selection expands one target per applicable project. An all-targets
selection expands the complete Cartesian product after applying project
restrictions. The result is sorted by target identity and is independent from
the declaration order.

## Target identity

A build target is identified by:

`package + project + compiler + platform + configuration`

This identity drives output directories, fingerprints, cache, diagnostics,
and IDE registration. Artifacts produced by different compilers, platforms, or
configurations must never share the same final directory.

Matrix outputs use this layout:

```text
modules/artifacts/<package>/<compiler>/<platform>/<configuration>/
  bin/
  bpl/
  dcp/
  dcu/
```

The complete target tree is cached as one unit. Its cache key includes the
dependency identity, source checksum, compiler, platform, and configuration.
Restoring one target can therefore never overwrite or satisfy another target.
Legacy manifests keep their existing output layout until explicitly built
through the matrix executor.

## Incremental rebuild

Each project target stores an independent state document under
`.boss4d-state/`. The state records:

- target identity;
- source fingerprint;
- fingerprints of direct project dependencies;
- combined fingerprint;
- an inventory of produced outputs.

A target is skipped only when its state, source/dependency fingerprints, and
recorded outputs are all valid. The executor distinguishes and explains:

- up to date;
- forced rebuild;
- first build (missing state);
- missing output;
- source/project metadata change;
- dependency fingerprint change;
- invalid or corrupt state.

Changing a runtime package therefore invalidates its compatible design-time
consumers even when their own source files did not change.

## Parallel scheduling

The scheduler executes one topological level at a time and never starts a
consumer before all direct dependencies complete. Within a level, targets with
different output roots can run concurrently up to the configured jobs limit.
Projects sharing the same package/compiler/platform/configuration output root
are grouped and serialized to avoid compiler and filesystem races.

Cancellation is checked before scheduling and before each target. The first
failure stops new work, waits for already-running tasks to finish safely, and
reports the failing project. Consequently, no dependent level starts after a
dependency failure.

## Transactional IDE registration

Design-time packages are registered only in the Delphi toolchain and platform
that produced them. Boss4D no longer treats one BPL as compatible with every
installed IDE.

For each target, the registration transaction manages:

- `Known Packages` and cleanup of the matching `Known IDE Packages` entry;
- `Search Path`;
- `Browsing Path`;
- `Debug DCU Path`.

Every registry value is snapshotted before mutation. A failed write or
inventory update restores the values in reverse order and does not persist a
partial registration. The desired state is stored in
`%BOSS_HOME%\ide-registrations.json`.

Unregister removes only the exact paths and BPL owned by the selected
package/compiler/platform, preserving unrelated user paths. Re-registering the
same target replaces its previous paths and package cleanly. Repair compares
the inventory with the registry and reapplies only entries with drift.

## Delphi conventions

The CLI accepts either BDS versions or short aliases:

| Delphi | BDS/compiler selector | Alias | Package suffix | Symbol |
|---|---:|---|---:|---|
| 10 Seattle | `17.0` | `d10` | `230` | `VER300` |
| 10.1 Berlin | `18.0` | `d101` | `240` | `VER310` |
| 11 Alexandria | `22.0` | `d11` | `280` | `VER350` |
| 12 Athens | `23.0` | `d12` | `290` | `VER360` |
| 13 Florence | `37.0` | `d13` | `370` | `VER370` |

Paths can use `{compiler}`, `{alias}`, `{libsuffix}`, `{platform}`, and
`{configuration}`. For example,
`packages/{alias}/Component{libsuffix}.dproj` resolves to
`packages/d13/Component370.dproj` for Delphi 13. These values follow the RAD
Studio compiler/package conventions; `libsuffix` is useful when package output
names must coexist across IDE generations.

## CLI workflow

Detect a starting matrix from `.dproj` and `.dpk` files:

```console
boss4d spec --detect
boss4d spec --detect --compiler d13
```

Detection recognizes `{$RUNONLY}` and `{$DESIGNONLY}`, maps local `requires`
entries to `dependsOn`, ignores dependency/artifact directories, preserves
legacy `projects`, and writes deterministic paths with `/`.

Build one target, a mixed selection, or the complete matrix:

```console
boss4d build
boss4d build --compiler d13 --platform Win64 --configuration Release
boss4d build --compiler all --platform Win32 --configuration Release --jobs 4
boss4d build --compiler d13 --platform Win32 --configuration Release --explain
boss4d build --full
```

- `--compiler`, `--platform`, and `--configuration` accept one value or `all`
  independently.
- `--jobs n` limits concurrent isolated targets.
- `--force` rebuilds the selected targets and bypasses target cache restore.
- `--full` selects every axis and forces recompilation.
- `--explain` prints the incremental decision for every target.
- `--register` registers BPLs produced by selected design-time targets.

IDE lifecycle commands are deliberately exact:

```console
boss4d ide unregister ComponentDesign370 --compiler d13 --platform Win32
boss4d ide repair
```

## Doctor and troubleshooting

`boss4d doctor` checks the host tools and the current project. Project
diagnostics have stable codes and remediation for:

- invalid matrix values, missing compatible dependencies, and graph cycles;
- declared Delphi versions not installed or registered paths that no longer
  exist;
- missing projects and paths escaping the package root;
- duplicate project output names and duplicate Delphi unit declarations;
- drift between `%BOSS_HOME%\ide-registrations.json` and the registry.

Common recovery actions:

- run `boss4d spec --detect` after moving or adding package projects;
- use `boss4d build --explain` before forcing a rebuild;
- delete only the affected target under `modules/artifacts/` if investigating
  a corrupt output; normal rebuild decisions handle missing outputs;
- run `boss4d ide repair` after manually changing IDE library paths;
- verify that the selected BDS version is installed before using
  `--compiler`.

## Migrating from a legacy manifest

Migration is optional. A legacy manifest can continue to build unchanged.
To adopt the matrix:

1. commit the existing `boss.json`;
2. run `boss4d spec --detect`;
3. review detected project kinds and `dependsOn`;
4. narrow per-project axes where a design package is not available everywhere;
5. run one explicit target with `--explain`;
6. expand to `--compiler all` or `--full` only after the first target passes.

Removing `buildMatrix` returns the manifest to legacy selection behavior; the
string lists and string/string dependency maps are never rewritten.

## Expected precedence

Selection follows this order:

1. explicit CLI filters;
2. project-declared targets;
3. matrix defaults;
4. the legacy `toolchain` and `engines` contract;
5. compatible Boss4D defaults.

An empty or incompatible selection fails with an actionable message before
performing a partial installation.

## Validation evidence

The current branch is validated with:

- 184 DUnitX tests on Delphi 13 Win32 and Win64;
- production CLI builds on Delphi 13 Win32 and Win64;
- real IDE plugin builds with Delphi 10/BDS 17.0, Delphi 11/BDS 22.0, Delphi 12/BDS 23.0, and
  Delphi 13/BDS 37.0;
- 61 FPCUnit tests plus CLI and release-artifact smoke tests on Linux/FPC
  3.2.2 through Docker;
- Sonar Quality Gate `OK` with zero new violations.

Delphi 10 Seattle is validated with BDS 17.0. Delphi 10.1 remains a distinct
target and requires BDS 18.0; a Seattle build must not be reported as Berlin
evidence.

## Acceptance criteria

Every contract increment requires:

- unit tests for new behavior and legacy regression;
- deterministic errors for invalid combinations;
- deterministic serialization;
- no artifact collision across targets;
- real builds proportional to the change on installed Delphi versions;
- Portuguese and English documentation updates;
- a passing Sonar quality gate before closing the release.
