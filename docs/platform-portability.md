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

## Roadmap

1. Move remaining command execution and host filesystem behavior behind these
   contracts.
2. Add plain, interactive, JSON, and quiet progress renderers over a portable
   event model.
3. Add POSIX process, environment, link, console, and credential adapters.
4. Validate the portable CLI on Linux64, followed by macOS.

Every platform implementation requires contract tests. A platform is supported
only after its CLI build, unit suite, lock workflow, registry operations, audit,
and SBOM validation pass in CI.
