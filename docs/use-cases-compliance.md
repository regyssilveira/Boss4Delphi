# Compliance and audit use cases

An SBOM is useful only when its scope, evidence, and generation policy are
clear. These cases separate a quick developer inventory from release evidence
and vulnerability policy enforcement.

## 1. Generate a quick development inventory

**Situation:** a developer wants to inspect current dependencies while
investigating a package or license.

```powershell
boss4d sbom --format cyclonedx --output bom.cdx.json --validate
boss4d license report
```

**Expected result:** a valid CycloneDX document and a human-readable license
report are produced for review.

**Risk controls:** this is an exploratory inventory, not automatically release
evidence. Record whether environmental collectors were used.

**Recovery:** run `boss4d doctor`, repair manifest/lock evidence, and regenerate
rather than editing the SBOM manually.

## 2. Generate reproducible release SBOMs

**Situation:** a release needs both CycloneDX and SPDX documents derived only
from reviewed lock evidence.

```powershell
boss4d sbom --format cyclonedx --lock-only --strict --validate `
  --reproducible --type application --output dist/sbom/app.cdx.json `
  --attestation-output dist/sbom/app.cdx.intoto.json

boss4d sbom --format spdx --lock-only --strict --validate `
  --reproducible --type application --output dist/sbom/app.spdx.json `
  --attestation-output dist/sbom/app.spdx.intoto.json
```

**Expected result:** both formats validate, contain the same reviewed dependency
scope, and are stable across identical clean builds.

**Risk controls:** `--strict` must remain enabled. `--lock-only` prevents local
GetIt, toolchain, and artifact discovery from making release evidence
machine-dependent.

**Recovery:** if evidence is incomplete, fix `boss-lock.json` through a normal
verified install. Do not remove `--strict` to force publication.

## 3. Inventory the actual build environment

**Situation:** support or forensics needs to know which installed Delphi,
GetIt, and produced artifacts were present on one build machine.

```powershell
boss4d sbom --format cyclonedx --strict --validate `
  --include-getit --include-toolchain --include-artifacts `
  --output build-environment.cdx.json
```

**Expected result:** the document includes environmental components and reports
collector coverage.

**Risk controls:** do not combine environmental collectors with `--lock-only`.
Label this output as machine-specific; it does not replace the reproducible
release SBOM.

**Recovery:** missing collector evidence is fatal under `--strict`. Correct the
tool path or permissions and rerun on the same build host.

## 4. Record a vulnerability decision with VEX

**Situation:** a vulnerability is known but its status for this product has
been analyzed.

```powershell
boss4d sbom --format cyclonedx --strict --validate --reproducible `
  --vex security.vex.json --output dist/sbom/app.vex.cdx.json `
  --attestation-output dist/sbom/app.vex.cdx.intoto.json
```

**Expected result:** CycloneDX contains the VEX analysis associated with the
correct component identity and vulnerability.

**Risk controls:** a VEX state is a reviewed security decision, not a way to
hide findings. Preserve justification, response, timestamps where policy
requires them, and ownership of the decision. SPDX output does not accept the
CycloneDX VEX enrichment path.

**Recovery:** correct the source VEX file and regenerate all derived evidence.
Never patch the released SBOM directly.

## 5. Enforce vulnerability severity in CI

**Situation:** a pull request or release must fail on unsuppressed high or
critical vulnerabilities.

```powershell
boss4d audit --fail-on high
```

With reviewed VEX:

```powershell
boss4d audit --vex security.vex.json --fail-on high
```

**Expected result:** the command returns success when policy is satisfied and
exit code 6 for a policy violation.

**Risk controls:** do not treat network/cache failures as a clean audit. Keep
the threshold in versioned CI configuration and review every VEX suppression.

**Recovery:** update the dependency, publish a justified VEX decision, or fail
the release. Do not lower the threshold only to make a job green.

## 6. Audit in an offline or restricted environment

**Situation:** the build cannot query OSV during execution.

```powershell
boss4d audit --cache-hours 48
boss4d audit --offline --fail-on high
```

The first command runs while connected and refreshes evidence; the second
proves the offline gate.

**Expected result:** offline audit uses still-valid cached responses and fails
clearly if required evidence is absent.

**Risk controls:** choose cache freshness according to policy. Offline success
with stale evidence is not equivalent to a current online assessment.

**Recovery:** reconnect in a trusted environment, refresh the audit cache, and
repeat the offline workflow.

## 7. Verify detached SBOM attestation

**Situation:** a consumer received an SBOM and its detached in-toto statement.

```powershell
boss4d sbom --format cyclonedx --vex security.vex.json `
  --verify-attestation dist/sbom/app.cdx.intoto.json `
  --output verified-bom.cdx.json
```

**Expected result:** the statement subject digest matches the exact generated
SBOM content.

**Risk controls:** a detached SHA-256 statement proves integrity linkage, not
signer identity by itself. Apply the organization signing and provenance policy
in addition to digest verification.

**Recovery:** reject mismatched evidence and obtain the original artifacts from
the trusted release. Do not regenerate an attestation for untrusted bytes.

## 8. Assemble the release compliance bundle

**Situation:** release engineering needs a reviewable set of evidence.

Include:

- reproducible CycloneDX and SPDX documents;
- detached in-toto statements;
- VEX when applicable;
- vulnerability audit output and policy threshold;
- license report;
- release artifact checksums and provenance.

```powershell
boss4d license report
boss4d audit --vex security.vex.json --fail-on high
```

**Expected result:** every published binary maps to retained inventory,
integrity, vulnerability, and license evidence.

**Risk controls:** generate the bundle from the exact release commit and
artifacts. Do not mix documents from different builds.

**Recovery:** discard the partial bundle and regenerate all evidence together
from a clean release workspace.

## Decision table

| Need | Required mode |
|---|---|
| Quick developer inventory | CycloneDX plus `--validate` |
| Reproducible release evidence | `--lock-only --strict --validate --reproducible` |
| Machine-specific inventory | Environmental collectors without `--lock-only` |
| Security disposition | Reviewed VEX plus CycloneDX |
| CI vulnerability gate | `audit --fail-on <severity>` |
| Restricted-network audit | Pre-populated cache plus `audit --offline` |

See [SBOM guide](sbom.md), [SBOM examples](sbom-examples.md),
[audit](audit.md), [trust policy](trust-policy.md), and the
[release checklist](sbom-release-checklist.md).

