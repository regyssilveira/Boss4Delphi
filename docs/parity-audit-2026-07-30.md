# Boss4D parity completion audit — 30 July 2026

This audit maps each targeted criterion to authoritative repository evidence.
“Complete” means implemented and covered by a unit, contract, integration, or
real-compiler test; it does not mean the ecosystem has reached npm-scale.

| Criterion | Status | Authoritative evidence |
|---|---|---|
| Public Registry protocol | Complete | `registry/index-v2.json`, legacy composition, sparse-package support, and publisher registry; catalog population is ecosystem work |
| Search and package information | Complete | Windows DUnitX plus FPCUnit Registry search/info tests |
| Compiler/platform packages | Complete | deterministic Registry v2 variant selection and `release/artifact-matrix.json` |
| Sparse metadata and HTTP cache | Complete | ETag/Last-Modified/304 tests and offline cache tests |
| Mirrors and revocation | Complete | ordered metadata/artifact mirror tests, digest rejection, revocation test |
| Immutable publication | Complete | deterministic publish test, lock gates, token non-disclosure, HTTP 409 conflict |
| Publisher onboarding | Complete | scope/fingerprint/signature/provenance validator with negative tests |
| Older Delphi compilers | Complete | real plugin compilation with Delphi 10.1, 11, 12 and 13 |
| Native Linux CLI | Complete | FPC 3.2.2 x86_64 build, FPCUnit suite and real command smoke tests |
| Daily project workflows | Complete | install/update/tree/why/outdated/run tests and transactional rollback |
| Global tools/workspaces/cache | Complete | lifecycle, linking, pruning and real FPC tool smoke tests |
| Secure credentials | Complete | Secret Service mock contract, environment precedence and token masking |
| Terminal progress | Complete | plain/interactive/JSON/quiet formatting, cancellation and stable exit-code tests |
| Auto-update | Complete | release selection, SHA-256, extraction, transactional promotion and rollback tests |
| Compliance/audit | Complete | CycloneDX, SPDX, VEX, OSV, strict lock evidence and external validators |
| Release distribution | Complete | tag workflow, Windows/Linux archives, checksums, OIDC provenance and final tarball execution |
| Quality | Complete | Delphi Win32/Win64, FPC/Linux, workflow contract tests and Sonar zero-issue gate |

## Required invariants

- Legacy string-to-string maps in `boss.json` remain valid.
- Published `(name, version)` records cannot be changed or overwritten.
- An artifact is installed only after its external and internal SHA-256 checks
  pass; configured signature and provenance must also validate.
- Tokens are provided through process environment or Secret Service and are
  never embedded in repository URLs or publication payloads.
- Release promotion depends on both Windows and Linux builders for the exact
  tag commit.
- No new production capability in this program was accepted without a
  corresponding automated test.

## Final verification commands

```powershell
./scripts/ci-fpc-linux.ps1
./scripts/test-linux-release-artifact.ps1
./scripts/test-delphi-plugin-matrix.ps1
./scripts/test-release-workflow.ps1
./scripts/test-release-artifact-matrix.ps1
./scripts/test-registry-submission.ps1
docker run --rm -v "${PWD}:/repo" -w /repo rhysd/actionlint:latest `
  -config-file .github/actionlint.yaml
```

Delphi 13 DUnitX is executed separately with `dcc32` and `dcc64`. Sonar is
executed through the protected local runner; credentials and tokens are never
recorded in logs or this document.

## Outside the completed criteria

The following are legitimate next investments, but require ecosystem growth or
a new platform objective: publisher-supplied signed packages, hosted search/CDN
operations, native macOS distribution, and optional transparency-log identity.

