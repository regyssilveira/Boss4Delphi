# Platform portability

Boss4D separates portable package-management rules from host operating-system
integration. Core services consume three contracts:

- `IBoss4DProcessRunner` executes commands and captures their result;
- `IBoss4DPlatformEnvironment` exposes home/current directories, writable-file
  handling, and host capabilities;
- `IBoss4DFileLinkService` creates and removes workspace directory links.

The Windows CLI and GUI configure Windows implementations during startup.
Those adapters retain `CreateProcess`, Windows file attributes, directory
junctions, RAD Studio Registry discovery, MSBuild, and GetIt behavior outside
the portable domain.

## Capability boundaries

Portable commands must not assume that RAD Studio, GetIt, the Windows Registry,
or `cmd.exe` exists. Platform-specific commands will query capabilities and
return an explicit unsupported-platform error. The VCL GUI and RAD Studio
plugin remain Windows products; the command-line application is the portability
target.

## Current POSIX status

The native FPC 3.2.2 host is built and tested on Linux x86-64 and macOS arm64.
Linux also has a reproducible local Docker gate. The POSIX CLI
supports manifest initialization, `add`, `remove`, `list`, Git installation,
lock schema v3, runtime/development scopes, production mode, frozen and offline
installation, CI mode, highest/minimal SemVer selection, Registry v1/v2
discovery, persistent sources, and offline registry caching. Legacy
string-to-string `boss.json` dependency maps are covered by FPCUnit. The
`package install` command selects Registry v2 variants by platform/compiler,
verifies external and internal SHA-256 digests, optional OpenPGP signatures and
in-toto Statement v1 provenance, and commits extraction transactionally. A
verified install is recorded in the legacy-compatible manifest and lock v3.
The host also provides structured progress, stable automation exit codes,
cooperative Ctrl+C cancellation, and `doctor` checks for Git, SHA-256, GPG,
FPC, and a writable Boss home.
Secret Service credentials are a Linux integration. Environment-only CI
tokens, bare Git mirrors, cache maintenance, and POSIX workspace symlinks work
on both hosts. SHA-256 uses `sha256sum` when available and the native
`shasum -a 256` fallback on macOS.
Global FPC tools are compiled and installed transactionally under
`~/.boss/bin`.

The Windows host remains required for RAD Studio/GetIt integration, GUI, and
IDE plugins. These
boundaries are intentional and documented, not silently emulated.

## Next portability steps

1. Evaluate Linux ARM64 and publish a support matrix per architecture.
2. Maintain recurring cache and installation benchmarks on distributed
   platforms.

Every new portable capability requires unit tests and an actual target-host
build. Linux and macOS support the dependency workflow listed above; Windows
remains the only host for RAD Studio-specific capabilities.
