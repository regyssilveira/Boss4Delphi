# Linux, CI, release, and update use cases

Automation must start from reviewed source and produce immutable evidence.
Linux/FPC workflows are native; RAD Studio, GetIt, the Windows Registry, GUI,
and IDE plugin operations remain Windows capabilities.

## 1. Validate the native Linux CLI locally

**Situation:** a Windows developer wants to reproduce the Linux/FPC build
without installing FPC on the host.

```powershell
./scripts/ci-fpc-linux.ps1
```

**Expected result:** the Docker `fpc-test:latest` environment compiles the
x86-64 CLI, runs the FPCUnit suite, and executes command smoke tests.

**Risk controls:** use the project-provided image/workflow and record its
version. A successful Windows Delphi build does not prove the native Linux
host.

**Recovery:** confirm Docker is running, rebuild the designated image when its
contract changes, and rerun the same script. Do not silently fall back to a
different FPC version.

## 2. Run a deterministic Linux CI restore

**Situation:** a Linux runner must restore exactly the reviewed dependency
graph.

```bash
boss4d ci
```

For a prepared isolated runner:

```bash
boss4d ci --offline
```

**Expected result:** `ci` enforces locked/frozen behavior, rejects manifest
drift, and does not modify the lock.

**Risk controls:** pre-populate and verify cache before offline execution.
Archive logs and the exact `boss-lock.json`.

**Recovery:** regenerate/review the lock outside CI or populate missing cache;
never turn a failing locked job into an unconstrained install.

## 3. Install and maintain a global FPC tool

**Situation:** a command-line utility should be available under
`$BOSS_HOME/bin`.

```bash
boss4d tool install -g github.com/example/my-tool
boss4d tool list
boss4d tool update my-tool github.com/example/my-tool
boss4d tool uninstall my-tool
```

**Expected result:** install/update compiles in staging, promotes
transactionally, records executable SHA-256 in `tools.json`, and uninstall
removes only the owned tool.

**Risk controls:** global tools execute with user privileges and affect PATH.
Review source/revision and keep `$BOSS_HOME/bin` after trusted system paths.

**Recovery:** a failed update preserves the previous executable. Verify
`tools.json`, reinstall the last trusted revision, and inspect PATH for shadowed
commands.

## 4. Validate release contracts before tagging

**Situation:** maintainers want fast local proof that workflow and artifacts
still match their contracts.

```powershell
./scripts/test-release-workflow.ps1
./scripts/test-release-artifact-matrix.ps1
./scripts/test-linux-release-artifact.ps1
./scripts/test-delphi-plugin-matrix.ps1
```

**Expected result:** workflow structure, declared targets, Linux archive, and
available Delphi plugin builds pass before a tag exists.

**Risk controls:** these contract checks complement unit tests, real compiler
builds, SBOM validation, installer compilation, and Sonar; they do not replace
them.

**Recovery:** fix the contract or implementation on a branch. Do not create a
release tag while any required toolchain or artifact is missing.

## 5. Publish a release from an immutable tag

**Situation:** the release commit, changelog, tests, and artifacts are approved.

```powershell
git tag -a vX.Y.Z -m "Boss4D vX.Y.Z"
git push origin vX.Y.Z
```

**Expected result:** the tag workflow builds Windows, Linux, and macOS
independently, combines checksums, creates provenance attestations, and
publishes assets only after all platform jobs succeed.

**Risk controls:** tag only the reviewed commit. Tags and `(name, version)`
release identities are immutable operational contracts; never move a published
tag.

**Recovery:** if workflow fails before publication, fix on a new commit and use
the next version according to release policy. If assets were published, do not
replace them under the same identity.

## 6. Verify downloaded release artifacts

**Situation:** a user or deployment system downloaded the Windows/Linux/macOS
artifacts and checksum manifest.

On Linux:

```bash
sha256sum --check SHA256SUMS.txt
```

On macOS:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

On PowerShell, compare each published line with:

```powershell
Get-FileHash .\boss4d-windows.zip -Algorithm SHA256
Get-FileHash .\Boss4D_Setup.exe -Algorithm SHA256
```

**Expected result:** exact archive/installer bytes match the combined manifest.

**Risk controls:** obtain the checksum manifest from the same trusted release
and verify provenance when policy requires it. A checksum from an untrusted
location does not establish authenticity.

**Recovery:** delete mismatched files and download again from the official
release. Do not execute or redistribute a mismatched artifact.

## 7. Perform a secure self-update

**Situation:** an installed Boss4D should move to the latest official release.

```powershell
boss4d self-update
```

**Expected result:** Boss4D selects the official platform artifact, downloads
`SHA256SUMS.txt`, verifies exact bytes, stages replacement, and promotes only
after verification. An already-current version performs no replacement.

**Risk controls:** do not bypass the checksum or substitute an arbitrary
download URL. Windows uses the verified installer; Linux uses the verified
`boss4d-linux-x86_64.tar.gz`.

**Recovery:** a failed verification removes staging content; a failed Linux
promotion restores the previous executable. Keep the old installation until
the new `boss4d version` succeeds.

## 8. Diagnose a failed or suspicious self-update

**Situation:** the latest-release response is invalid, an asset is missing, or
checksum verification fails.

1. Stop; do not run the staged file.
2. Inspect the official release asset names and `SHA256SUMS.txt`.
3. Check network proxy/cache behavior.
4. Retain the currently installed binary.

```powershell
boss4d version
boss4d doctor
```

**Expected result:** the existing installation remains usable and no
unverified artifact is promoted.

**Risk controls:** a checksum mismatch is a security failure, not a retry hint
to disable validation.

**Recovery:** download from the official release after the publishing problem
is corrected, verify manually, and rerun self-update.

## 9. Respect platform capability boundaries

**Situation:** one automation definition runs on Windows and Linux.

Use Linux for native dependency, Registry, compliance, publication, update,
cache, workspace, and FPC tool workflows. Route these operations to Windows:

- RAD Studio compiler discovery and MSBuild;
- IDE Registry registration/repair;
- GetIt integration;
- GUI and Windows installer production.

**Expected result:** each job uses native supported capabilities instead of
emulating machine-specific state.

**Risk controls:** a portable manifest does not make every host feature
portable. Fail clearly when a requested capability is unavailable.

**Recovery:** move the step to a correctly labeled runner and pass only
immutable artifacts/evidence between jobs.

## Decision table

| Need | Workflow |
|---|---|
| Reproduce Linux suite locally | `./scripts/ci-fpc-linux.ps1` |
| Deterministic Linux restore | `boss4d ci` |
| Offline Linux restore | Pre-populated cache plus `boss4d ci --offline` |
| Validate release shape | Release contract scripts |
| Publish release | Approved immutable `v*` tag |
| Update installed CLI | `boss4d self-update` |
| Check downloaded bytes | `SHA256SUMS.txt` plus platform hash tool |

See [FPC/Linux CLI](posix-cli.md), [platform portability](platform-portability.md),
[release artifact matrix](release-artifact-matrix.md), and
[secure self-update](self-update.md).

