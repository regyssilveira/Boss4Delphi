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

## Current Linux status

The native FPC 3.2.2 Linux x86-64 host is built and tested in Docker. It
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
Secret Service credentials, environment-only CI tokens, bare Git mirrors,
cache maintenance, and POSIX workspace symlinks are native Linux workflows.

The Windows host remains required for RAD Studio/GetIt integration, GUI, IDE
plugins, and self-update. These
boundaries are intentional and documented, not silently emulated.

## Next portability steps

1. Add POSIX credential, workspace-link, and artifact-cache adapters.
2. Add macOS builds after the Linux contracts reach feature parity.

Every new portable capability requires unit tests and an actual target-host
build. Linux is currently supported for the dependency workflow listed above;
full cross-host feature parity remains in progress.
