# Multi-Delphi build use cases

The build target identity is package, compiler, platform, and configuration.
Boss4D isolates outputs and state by that complete identity so that a DCU or
BPL from one target cannot silently satisfy another.

## 1. Detect runtime and design packages in an existing component

**Situation:** a component repository contains `.dproj` and `.dpk` files but
has no declarative matrix.

```powershell
boss4d spec --detect
git diff -- boss.json
boss4d doctor
```

**Expected result:** Boss4D detects runtime/design-time packages, local
`requires` relationships, supported compilers, platforms, configurations, and
deterministic project paths.

**Risk controls:** review every detected project and dependency edge. Detection
does not decide which design package should be installed in every IDE.

**Recovery:** restore `boss.json`, correct project metadata or directory layout,
and detect again. Do not hand-edit generated dependency edges without checking
the `.dpk` `requires` clauses.

## 2. Build one fast development target

**Situation:** a developer is changing code for one installed Delphi version.

```powershell
boss4d build --compiler d13 --platform Win64 `
  --configuration Debug --explain
```

**Expected result:** only the selected compiler/platform/configuration and its
required project dependencies build.

**Risk controls:** use an explicit target during daily work. `build` without
filters uses declared defaults, which must be reviewed in `boss.json`.

**Recovery:** run `boss4d doctor` if the toolchain is missing. Use
`--explain` before forcing a rebuild.

## 3. Validate a release across every declared compiler

**Situation:** a pull request or release candidate must prove the supported
matrix.

```powershell
boss4d build --compiler all --platform all `
  --configuration Release --jobs 4
```

**Expected result:** every compatible runtime/design project target builds into
its isolated output tree.

**Risk controls:** use only compilers actually installed on the runner or split
the matrix across labeled runners. Preserve logs by target identity.

**Recovery:** rerun the failing exact target with `--jobs 1 --explain`; do not
discard successful target evidence.

## 4. Understand why a target rebuilt or was skipped

**Situation:** a target unexpectedly compiled, restored from cache, or skipped.

```powershell
boss4d build --compiler d12 --platform Win32 `
  --configuration Release --explain
```

**Expected result:** each target reports a reason such as first build, source
change, dependency change, missing output, cache restore, or up-to-date state.

**Risk controls:** treat unexplained recompilation as a signal to inspect source
inputs, dependency fingerprints, and output inventory. Do not delete all caches
as the first diagnostic step.

**Recovery:** remove only the affected target under
`modules/artifacts/<package>/<compiler>/<platform>/<configuration>/` and rerun.
Missing outputs should trigger a normal rebuild.

## 5. Force one target without rebuilding the whole matrix

**Situation:** compiler behavior or an external build step requires a clean
recompile of the selected target.

```powershell
boss4d build --compiler d11 --platform Win32 `
  --configuration Release --force --explain
```

**Expected result:** selected targets compile even if fingerprints are current;
unselected axes remain untouched.

**Risk controls:** `--force` bypasses target cache restore. Use it only after
capturing the incremental explanation.

**Recovery:** subsequent normal builds return to fingerprint/cache decisions.

## 6. Perform a complete clean matrix validation

**Situation:** release engineering needs all axes selected and every target
recompiled.

```powershell
boss4d build --full --jobs 4
```

**Expected result:** all declared compilers, platforms, and configurations are
selected and forced.

**Risk controls:** `--full` is expensive and may require every toolchain. Use it
for release evidence, not as the default developer command.

**Recovery:** if infrastructure capacity is insufficient, partition exact
targets across runners; do not silently remove declared axes.

## 7. Use parallelism without output collisions

**Situation:** the matrix is correct but sequential release validation is slow.

```powershell
boss4d doctor
boss4d build --compiler all --platform Win32 `
  --configuration Release --jobs 4
```

**Expected result:** targets with distinct output roots run concurrently;
projects sharing a root are serialized and dependents wait for prerequisites.

**Risk controls:** do not point two targets at the same custom output path.
Increasing `--jobs` beyond available memory, disk, or compiler licenses can
reduce reliability.

**Recovery:** rerun with `--jobs 1` to distinguish scheduling/resource issues
from compiler failures. Fix collisions reported by `doctor`.

## 8. Diagnose a unit or output collision

**Situation:** the wrong DCU is loaded, a BPL is overwritten, or `doctor`
reports duplicate output/unit names.

```powershell
boss4d doctor
boss4d build --compiler d13 --platform Win32 `
  --configuration Release --explain
```

**Expected result:** diagnostics identify duplicate declarations, escaping
paths, output roots, missing projects, or conflicting target identity.

**Risk controls:** preserve the default isolated layout:

```text
modules/artifacts/<package>/<compiler>/<platform>/<configuration>/
```

Do not solve collisions by adding broad global Library Paths.

**Recovery:** correct paths/names in the manifest or project, remove only
affected outputs, and rebuild the exact target.

## 9. Migrate a legacy manifest gradually

**Situation:** an existing `boss.json` uses legacy `projects`, `toolchain`, or
string/string dependency maps.

```powershell
boss4d spec --detect
boss4d build --compiler d13 --platform Win32 `
  --configuration Release --explain
```

**Expected result:** the additive `buildMatrix` coexists with legacy fields and
one explicit target succeeds before expansion.

**Risk controls:** do not rewrite dependency maps merely to adopt the matrix.
Commit migration separately from component source changes.

**Recovery:** remove the additive matrix section to return to legacy selection;
the original maps remain valid.

## 10. Target Delphi 10/10.1 without mixing conventions

**Situation:** one component supports the legacy Delphi source profile.

Use:

- Delphi 10 Seattle: BDS `17.0`, alias `d10`, suffix `230`, `VER300`;
- Delphi 10.1 Berlin: BDS `18.0`, alias `d101`, suffix `240`, `VER310`.

```powershell
boss4d build --compiler d10 --platform Win32 `
  --configuration Release --explain
boss4d build --compiler d101 --platform Win32 `
  --configuration Release --explain
```

**Expected result:** paths using `{compiler}`, `{alias}`, and `{libsuffix}`
expand to the correct version-specific projects and outputs.

**Risk controls:** a Seattle compiler build is conservative source-compatibility
evidence for the shared legacy profile, but a BPL published specifically for
Berlin must be produced by BDS 18.0.

**Recovery:** inspect expanded paths with `--explain`, correct aliases or tokens,
and never rename one compiler's binary to impersonate another.

## Decision table

| Need | Command |
|---|---|
| Daily development | One exact target with `--explain` |
| Rebuild selected target | Exact target plus `--force` |
| Release matrix | `--compiler all --platform all --configuration Release` |
| Complete forced validation | `--full` |
| Investigate scheduler issue | Repeat with `--jobs 1` |
| Find configuration/collision problems | `boss4d doctor` |

See the [build matrix contract](build-matrix-contract.md),
[build improvements](build-improvements.md), [cache strategy](cache-strategy.md),
and the [matrix example](../examples/build-matrix/README.md).

