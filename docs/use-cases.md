# Boss4D use cases

This guide starts with the job you need to complete and points to the safest
workflow. It complements the [complete command manual](usage.md), which remains
the authoritative CLI reference.

## How to use these guides

Every use case follows the same structure:

1. **Situation** — when the workflow applies.
2. **Before you start** — required files, tools, and access.
3. **Workflow** — the smallest safe sequence of commands.
4. **Expected result** — evidence that proves success.
5. **Risk controls** — choices that protect reproducibility, credentials, IDE
   state, or published packages.
6. **Recovery** — how to diagnose and undo a partial failure.

Commands are shown from the project root unless a case says otherwise. Commit
`boss.json` and `boss-lock.json`; do not commit credentials, generated build
trees, or machine-specific IDE state.

## Choose your situation

| Area | Everyday situation | Sensitivity | Guide |
|---|---|---|---|
| Project lifecycle | Start a project, add/update/remove dependencies, reproduce a restore, investigate the graph, recover from cache or lock problems | A lock change can alter every developer and CI build | [Project and dependency workflows](use-cases-project-lifecycle.md) |
| Registry and credentials | Select public/private sources, authenticate, work offline, verify packages, publish immutable versions | Secrets and supply-chain trust boundaries | [Registry, credentials, and publication](use-cases-registry-security.md) |
| Compliance and audit | Generate CycloneDX/SPDX, publish VEX, enforce vulnerability policy, create attestations | Compliance evidence must be complete and reproducible | [Compliance and audit workflows](use-cases-compliance.md) |
| Multi-Delphi build | Detect packages, select compiler/platform/configuration, use incremental and parallel builds | Wrong target identity can mix incompatible DCUs/BPLs | [Multi-Delphi build workflows](use-cases-build-matrix.md) |
| IDE lifecycle | Install, register, update, unregister, repair, and recover from a failed design-package change | Registry and Library Path changes affect the IDE globally | [Component build and IDE lifecycle](component-build-and-ide.md) |
| Linux and automation | Run FPC/Linux, CI validation, release packaging, self-update, and rollback | Automation must be deterministic and non-interactive | [Linux, CI, release, and update workflows](use-cases-operations-release.md) |

## Safety levels

- **Routine** — local and reversible; still verify the result.
- **Repository-wide** — changes the manifest or lock used by the team.
- **Machine-wide** — changes cache, global tools, PATH, or IDE registration.
- **External/immutable** — publishes metadata or artifacts that must not be
  overwritten.

For repository-wide or external operations, inspect the diff before committing.
For machine-wide operations, run `boss4d doctor` before and after the change.
For immutable publication, use a dry run and preserve the generated evidence.

## Related reference

- [Complete user manual](usage.md)
- [Dependency lifecycle](dependency-lifecycle.md)
- [Reproducible installation](reproducible-install.md)
- [Build matrix contract](build-matrix-contract.md)
- [Trust policy](trust-policy.md)
- [SBOM guide](sbom.md)
- [Package publication](publish.md)
