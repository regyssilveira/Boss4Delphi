# Project and dependency use cases

These cases cover the operations most likely to change `boss.json`,
`boss-lock.json`, `modules/`, or the shared cache.

## 1. Adopt Boss4D in an existing project

**Situation:** the repository already contains Delphi projects but no Boss4D
manifest.

**Before you start:** use a clean Git worktree and run from the repository
root.

```powershell
boss4d init
boss4d doctor
git diff -- boss.json boss-lock.json
```

**Expected result:** `boss.json` exists, `doctor` identifies the intended
Delphi installation, and the diff contains no machine-specific paths.

**Risk controls:** do not delete an existing compatible `boss.json`; Boss4D
preserves legacy string maps. Review the generated name, version, platform,
and toolchain before adding dependencies.

**Recovery:** restore only the newly generated manifest if initialization used
the wrong directory, then rerun from the project root.

## 2. Add a runtime dependency with an explicit range

**Situation:** the application needs a library such as Horse.

```powershell
boss4d add github.com/hashload/horse@^3.1.0
boss4d tree
git diff -- boss.json boss-lock.json
```

**Expected result:** the manifest records the requested range, the lock records
the exact resolved revision and evidence, and `tree` shows the dependency.

**Risk controls:** prefer an explicit compatible range over an unbounded
default. Commit manifest and lock in the same change.

**Recovery:** if resolution selected an unacceptable version, do not edit the
lock manually. Remove or change the constraint and resolve again.

## 3. Add a development-only tool

**Situation:** tests or code generation need a dependency that production
builds must not install.

```powershell
boss4d add github.com/example/test-tool@^2.0.0 --dev
boss4d install --production
```

**Expected result:** the package is recorded in `devDependencies`; a production
install excludes it.

**Risk controls:** never place runtime units in development-only scope.

**Recovery:** remove the dependency and add it again without `--dev` if
production compilation requires it.

## 4. Reproduce the team build in CI

**Situation:** CI must use exactly the dependency graph reviewed in the pull
request.

```powershell
boss4d install --locked
```

For a network-isolated runner with a pre-populated cache:

```powershell
boss4d install --locked --offline
```

**Expected result:** installation succeeds without changing
`boss-lock.json`. Manifest drift, a missing lock, or unavailable offline
content fails the job.

**Risk controls:** never replace `--locked` with an unconstrained install in a
release pipeline. Treat a lock diff produced by CI as a failure.

**Recovery:** regenerate the lock on a development machine, review it, commit
it, populate the runner cache if necessary, and rerun CI.

## 5. Update one dependency without moving the whole graph

**Situation:** one package needs a controlled upgrade.

```powershell
boss4d outdated
boss4d why horse
boss4d update horse
boss4d tree
git diff -- boss.json boss-lock.json
```

To change the allowed range deliberately:

```powershell
boss4d update github.com/hashload/horse@^3.2.0
```

**Expected result:** only the intended package and unavoidable transitive
changes move.

**Risk controls:** inspect both manifest and lock diffs. Run the project tests
before accepting a transitive update.

**Recovery:** revert the manifest and lock together; the next locked install
restores the previous graph.

## 6. Find why a transitive package is installed

**Situation:** a license, vulnerability, or version conflict mentions a
package not declared directly.

```powershell
boss4d why package-name
boss4d tree
boss4d audit
```

**Expected result:** `why` identifies the dependency path and `tree` provides
the complete context.

**Risk controls:** do not remove transitive content directly from `modules/`.
Change the owning direct dependency or its constraint.

**Recovery:** if the graph is inconsistent with the lock, run a locked install
before investigating further.

## 7. Work without network access

**Situation:** a corporate or travel environment has no Registry/Git access.

```powershell
boss4d cache size
boss4d install --locked --offline
```

**Expected result:** every locked package restores from verified local cache.

**Risk controls:** test offline restore before disconnecting. Do not use
`cache clean`; it removes the recovery source.

**Recovery:** reconnect on a trusted network, run the locked install once to
populate missing entries, and retry offline.

## 8. Recover from suspected cache corruption

**Situation:** verification fails for content that should match the lock.

```powershell
boss4d doctor
boss4d cache size
boss4d cache prune
boss4d install --locked
```

Use `boss4d cache clean` only when the cache can be downloaded again.

**Expected result:** invalid or unused entries are removed and verified
artifacts are fetched again.

**Risk controls:** cache maintenance is machine-wide. Do not clean shared or
offline build agents during an active release.

**Recovery:** restore the cache from a trusted backup or repopulate it online;
never bypass digest verification.

## 9. Remove a dependency safely

**Situation:** a direct package is no longer referenced by the project.

```powershell
boss4d why package-name
boss4d remove package-name
boss4d install --locked
boss4d tree
git diff -- boss.json boss-lock.json
```

**Expected result:** the direct entry disappears and unneeded transitives are
removed from the resolved graph.

**Risk controls:** search the source and project files before removal. Compile
all supported targets after the graph changes.

**Recovery:** revert manifest and lock together and run a locked install.

## Daily decision table

| Need | Command |
|---|---|
| Restore reviewed dependencies | `boss4d install --locked` |
| Prove the build works offline | `boss4d install --locked --offline` |
| See available updates | `boss4d outdated` |
| Explain a package | `boss4d why <name>` |
| Inspect the graph | `boss4d tree` |
| Remove unused cache entries | `boss4d cache prune` |
| Diagnose environment and project | `boss4d doctor` |

See also [dependency lifecycle](dependency-lifecycle.md),
[dependency scopes](dependency-scopes.md), [reproducible installation](reproducible-install.md),
and [cache strategy](cache-strategy.md).

