# Competitive positioning — July 2026

This assessment compares delivered capabilities, not roadmap promises.

| Capability | Boss4D | BOSS | DPM | GetIt | Cargo/npm/Composer class |
|---|---|---|---|---|---|
| Delphi source dependency workflow | Strong | Strong | Strong | Catalog-oriented | Not Delphi-specific |
| Lazarus/FPC | Native Linux workflow, partial parity | Established support | Delphi-focused | No | Ecosystem-specific |
| Public discovery | Git Registry v2, 55-entry catalog | Name/repository shortcuts | Hosted default source | Official RAD Studio catalog | Large hosted registries |
| Reproducibility | Lock v3, frozen/offline/CI | SemVer and cache | Package/version model | IDE installation state | Mature lock/offline/vendor flows |
| Immutable distribution | Verified `.b4dpkg` plus source fallback | Primarily Git source | Hosted packages | Hosted packages | Mature package archives |
| Supply-chain evidence | CycloneDX, SPDX, VEX, OSV, in-toto, OpenPGP | Not a central focus | Package signing | Vendor-controlled | Varies by ecosystem |
| Compiler/platform variants | Registry v2 deterministic variants | Install target flags | Project/platform-aware consumption | RAD Studio release catalog | Target/toolchain mechanisms vary |
| IDE experience | CLI, VCL GUI, RAD Studio plugins | CLI and IDE complement | CLI and IDE integration | Built into RAD Studio | Usually editor-independent |

## Where Boss4D is differentiated

Boss4D combines Delphi/Lazarus dependency management with an unusually complete
compliance evidence chain: immutable artifacts, external and internal digests,
OpenPGP, in-toto, CycloneDX/SPDX, VEX, OSV audit, dependency submission, and
strict lock-only release generation. Registry v2 can be maintained in Git,
composed from v1/v2 indexes, and distribute compiler/platform-specific artifacts
without changing legacy `boss.json`.

The project also validates real Delphi 10.1/11/12/13 plugin builds, Win32 and
Win64 tests, a native FPC/Linux build, deterministic packaging, and a complete
installer.

## Where competitors remain ahead

- BOSS has a larger established user base and a more mature portable CLI
  experience. Its documented CLI includes progress, self-upgrade, global
  installation, embedded/native Git selection, and compiler/platform flags.
- DPM has a hosted default package source and a conventional package publishing
  workflow, which reduces the effort required to discover and distribute
  packages.
- GetIt has first-party RAD Studio placement and a vendor-maintained catalog.
- Cargo, npm, and Composer have registry scale, mirrors/CDNs, incremental
  metadata protocols, mature publishing policy, and broad third-party tooling.

## Highest-value next work

1. Populate Registry v2 with real signed `.b4dpkg` releases; today most catalog
   entries remain Git repository pointers.
2. Bring Registry v2, verified artifacts, SBOM lock-only, audit, progress, and
   credentials to the Linux/FPC host.
3. Add sparse per-package metadata, HTTP cache validation, mirrors, revocation,
   and package yanking.
4. Automate publisher onboarding and signed metadata updates through reviewed
   pull requests.
5. Add macOS and expand the compiler/platform artifact matrix with packages
   built by their maintainers.

## Sources

- [BOSS repository and CLI](https://github.com/HashLoad/boss)
- [DPM documentation](https://docs.delphi.dev/)
- [DPM package sources](https://docs.delphi.dev/concepts/package-sources.html)
- [Embarcadero GetIt overview](https://tp.embarcadero.com/overview/)
- [Lazarus Online Package Manager source](https://gitlab.com/freepascal.org/lazarus/lazarus/-/tree/main/components/onlinepackagemanager)
- [Cargo registries](https://doc.rust-lang.org/cargo/reference/registries.html)
- [Cargo registry index](https://doc.rust-lang.org/cargo/reference/registry-index.html)
- [Composer repositories](https://getcomposer.org/doc/05-repositories.md)

