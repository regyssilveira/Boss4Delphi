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
installation, CI mode, and highest/minimal SemVer selection. Legacy
string-to-string `boss.json` dependency maps are covered by FPCUnit.

The Windows host remains required for Registry v2 discovery, verified
`.b4dpkg` installation, SBOM/audit commands, OpenPGP, credential storage,
RAD Studio/GetIt integration, GUI, IDE plugins, and self-update. These
boundaries are intentional and documented, not silently emulated.

## Next portability steps

1. Share the Registry v2 and verified package reader with the FPC host.
2. Port SBOM lock-only generation, OSV audit, and structured progress output.
3. Add POSIX credential, workspace-link, and artifact-cache adapters.
4. Add macOS builds after the Linux contracts reach feature parity.

Every new portable capability requires unit tests and an actual target-host
build. Linux is currently supported for the dependency workflow listed above;
full cross-host feature parity remains in progress.
