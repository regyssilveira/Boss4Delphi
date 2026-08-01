# Competitive positioning — 30 July 2026

This assessment compares delivered, tested behavior. Adoption and registry
scale are kept separate from CLI feature count.

| Capability | Boss4D | BOSS | DPM | GetIt | Cargo/npm/Composer class |
|---|---|---|---|---|---|
| Delphi dependency workflow | Full CLI, GUI and IDE | Full CLI and IDE complement | Full package workflow and IDE | Catalog installation | Not Delphi-specific |
| Lazarus/FPC/POSIX | Native FPC 3.2.2 CLI and releases for Linux x86_64 and macOS arm64 | Established Delphi/Lazarus workflow | Delphi-focused; Windows | No | Native per ecosystem |
| Daily CLI | Install, update, tree, why, outdated, run, global tools | Install, update, dependencies, run, global install | NuGet-style create/push/install/restore | IDE-driven | Broad and mature |
| Public discovery | Git Registry v2 with 55 packages: 16 signed schema-v2 releases and 39 legacy entries | Repository/name shortcuts and historical adoption | Operational hosted `delphi.dev` source | Vendor catalog | Large hosted registries |
| Registry protocol | v1/v2 composition, sparse metadata, HTTP validators, mirrors, revocation | Git-oriented resolution | Multiple hosted/local sources | Vendor-controlled | Sparse/index APIs and CDNs |
| Reproducibility | Lock v3, frozen/locked/offline CI | SemVer and cache | Package/version restore | IDE installation state | Mature locks and offline/vendor modes |
| Immutable distribution | `.b4dpkg`, SHA-256, OpenPGP, in-toto, transactional install | Primarily Git checkout | Signed hosted packages | Hosted packages | Immutable archives and checksums |
| Publishing policy | Dry-run, gates, secure token, immutable versions, reviewed publishers | No comparable public registry workflow documented | Central source and package push | Vendor submission | Mature authenticated publishing |
| Supply-chain evidence | CycloneDX, SPDX, VEX, OSV, in-toto and OpenPGP | No SBOM/audit workflow documented | SBOM plus author/repository signing | Vendor-controlled | Ecosystem-dependent, generally mature |
| Compiler/platform matrix | Delphi 10/10.1/11/12/13 IDE plugins; Win32/Win64; Linux x86_64/FPC | Compiler/platform selection | Delphi XE2–13 and supported targets | Current vendor releases | Rich target mechanisms |
| Auto-update | Verified transactional Windows and Linux update | `upgrade`, including pre-release channel | Installer/package delivery | RAD Studio delivery | Mature toolchain-specific update |
| Progress/automation | Plain, interactive, JSON, quiet, cancellation and stable exit codes | Interactive dependency progress | Conventional CLI output | IDE UI | Mature machine-readable automation |

## Conclusion

For the implemented and tested criteria, Boss4D reaches technical parity with
BOSS and offers a broader surface in reproducibility, immutable artifacts,
Registry policy, compliance evidence, structured automation, and verified
releases. BOSS remains ahead in adoption, recognition, production history, and
the number of existing projects.

DPM remains stronger in two ecosystem dimensions: a running hosted central
service and support reaching back to Delphi XE2. It also provides package
signing and SBOM generation, so those capabilities must not be represented as
unique to Boss4D. Boss4D differentiates through VEX/OSV auditing, dual SBOM
formats, in-toto provenance, reviewed signer scopes, Git-compatible Registry
governance, and a native Linux CLI.

TMS Smart Setup remains the component installation/build reference, especially
for compiler breadth, parallel download/build, incremental rebuilds, and its
established commercial operation. GetIt retains first-party RAD Studio
placement. Cargo, npm and Composer remain
far ahead in package population, CDN scale, resolver history, third-party
tooling, and operational registry infrastructure.

## Evidence in this repository

- Delphi 13 DUnitX: 295 tests on Win32 and 295 on Win64.
- FPC 3.2.2/Linux x86_64: 61 FPCUnit tests plus real CLI smoke tests.
- Real IDE plugin builds: Delphi 10, 10.1, 11, 12 and 13.
- Release archives: Windows, Linux, and macOS with SHA-256 and GitHub OIDC
  provenance.
- Registry submission checks: publisher scope, OpenPGP fingerprint, immutable
  versions, signature and provenance.
- Sonar quality gate is required with zero open issues.

## Remaining ecosystem work

These are scale and reach improvements, not missing implementation from the
targeted parity criteria:

1. Migrate the remaining 39 legacy entries with signed `.b4dpkg` releases
   supplied by their maintainers.
2. Add a hosted read/search frontend and CDN while keeping reviewed Git metadata
   authoritative.
3. Broaden maintained package variants and add Linux ARM64.
4. Publish resolver and cold/warm-cache benchmarks on a recurring schedule.
5. Add optional transparency-log/Sigstore identity alongside OpenPGP.

## Sources

- [BOSS repository and current CLI](https://github.com/HashLoad/boss)
- [DPM repository and current capabilities](https://github.com/DelphiPackageManager/DPM)
- [DPM documentation](https://docs.delphi.dev/)
- [Embarcadero GetIt documentation](https://docwiki.embarcadero.com/RADStudio/en/GetIt_Package_Manager_Window)
- [Cargo registries](https://doc.rust-lang.org/cargo/reference/registries.html)
- [Cargo sparse index and cache contract](https://doc.rust-lang.org/cargo/reference/registry-index.html)
- [Composer repositories](https://getcomposer.org/doc/05-repositories.md)

