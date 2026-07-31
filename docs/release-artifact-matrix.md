# Release artifact matrix

Every `v*` tag is promoted only after the Windows, Linux, and macOS jobs
succeed for the same commit.

The machine-readable contract is published as
`release/artifact-matrix.json`. It currently guarantees Delphi 13/37.0 for
Windows x86 and x86_64, FPC 3.2.2 for Linux x86_64, and FPC 3.2.2 for
macOS arm64.

| Artifact | Builder | Required validation |
|---|---|---|
| `boss4d-windows.zip` | Delphi 13 self-hosted runner | Win32/Win64 build, release SBOM generation, transactional `dist` promotion |
| `boss4d-linux-x86_64.tar.gz` | Ubuntu 24.04 with FPC | Native CLI compilation and the complete FPCUnit suite |
| `boss4d-macos-arm64.tar.gz` | GitHub macOS 15 arm64 with FPC | Native CLI compilation, complete FPCUnit suite, host and `shasum` verification |
| `SHA256SUMS.txt` | Release job | SHA-256 over the exact uploaded Windows, Linux, and macOS archives |
| CycloneDX, SPDX and in-toto documents | Delphi release build | Strict generation and validation from the release lock |
| GitHub build-provenance attestations | GitHub OIDC | Identity-bound attestation for every platform archive |

The release job cannot run for pull requests. It requires both platform jobs,
downloads their immutable workflow artifacts, recomputes the combined checksum
manifest, creates GitHub build-provenance attestations, and uploads everything
to the tag's GitHub release.

POSIX archive names are derived from the host platform and CPU and are part of
the self-update contract. Changing them requires accompanying service and unit
test updates.

Validate the workflow locally with:

```powershell
./scripts/test-release-workflow.ps1
./scripts/test-release-artifact-matrix.ps1
./scripts/test-linux-release-artifact.ps1
docker run --rm -v "${PWD}:/repo" -w /repo rhysd/actionlint:latest `
  -config-file .github/actionlint.yaml .github/workflows/release.yml
```
