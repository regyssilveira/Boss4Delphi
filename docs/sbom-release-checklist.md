# SBOM release checklist

An SBOM-enabled release may be promoted only when every item below is proven for
the same commit:

- [ ] `boss-lock.json` was produced by `boss4d install` and contains root evidence, hash, and timestamp.
- [ ] `scripts/ci-verify-sbom.ps1` passed on Win32 and Win64.
- [ ] All DUnitX tests passed on both architectures with no leaks.
- [ ] Basic and VEX-enriched CycloneDX passed the official CycloneDX CLI.
- [ ] SPDX passed the official SPDX tools-java verifier.
- [ ] Reproducible SBOMs and attestations are identical across Win32 and Win64.
- [ ] Both attestations were verified against the SBOMs being published.
- [ ] `build_release.bat` completed and promoted `dist.new` to `dist`.
- [ ] `dist/sbom` contains CycloneDX, SPDX, and both attestations.
- [ ] Missing root evidence, incompatible flags, path traversal, missing VEX targets, and tampering have negative tests.
- [ ] `git diff --check` is clean and local IDE files are absent from the commit.
- [ ] Portuguese and English migration documentation matches the current CLI.

The GitHub Actions workflow is optional and requires a self-hosted Windows runner
with Delphi 13, Docker, Java, and `gh`. Without a runner, a complete local execution
of `scripts/ci-verify-sbom.ps1` on the release commit is authoritative evidence and
does not block promotion. If a runner is used, first run
`scripts/test-sbom-runner.ps1 -RequireDockerDaemon` as its service account.
