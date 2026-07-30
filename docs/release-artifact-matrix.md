# Release artifact matrix

Every `v*` tag is promoted only after the Windows and Linux jobs succeed for
the same commit.

| Artifact | Builder | Required validation |
|---|---|---|
| `boss4d-windows.zip` | Delphi 13 self-hosted runner | Win32/Win64 build, release SBOM generation, transactional `dist` promotion |
| `boss4d-linux-x86_64.tar.gz` | Ubuntu 24.04 with FPC | Native CLI compilation and the complete FPCUnit suite |
| `SHA256SUMS.txt` | Release job | SHA-256 over the exact uploaded Windows and Linux archives |
| CycloneDX, SPDX and in-toto documents | Delphi release build | Strict generation and validation from the release lock |
| GitHub build-provenance attestations | GitHub OIDC | Identity-bound attestation for both platform archives |

The release job cannot run for pull requests. It requires both platform jobs,
downloads their immutable workflow artifacts, recomputes the combined checksum
manifest, creates GitHub build-provenance attestations, and uploads everything
to the tag's GitHub release.

The Linux archive name is part of the self-update contract. Changing it requires
an accompanying update to `Boss4D.Posix.Update` and its unit tests.

Validate the workflow locally with:

```powershell
./scripts/test-release-workflow.ps1
docker run --rm -v "${PWD}:/repo" -w /repo rhysd/actionlint:latest `
  -config-file .github/actionlint.yaml .github/workflows/release.yml
```

