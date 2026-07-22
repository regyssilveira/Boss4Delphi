# BOSS compatibility and build improvements

Boss4D incorporates selected behavior from recent BOSS releases while keeping
the native Delphi architecture and reproducible lock/SBOM model.

## Collision-free dependency directories

The display name remains the repository basename, but files are installed under
`modules/<name>-<canonical-hash-prefix>`. HTTPS and SSH forms of the same
repository resolve to the same directory; different repositories named `common`
do not overwrite each other. Lock keys and SBOM identities remain based on the
canonical repository URL.

## Toolchain precedence

The effective build platform is selected in this order:

1. `boss4d install --platform <platform>`;
2. `toolchain.platform` from the root `boss.json`;
3. the first entry in `engines.platforms`;
4. `Win32`.

`toolchain.compiler` selects the RAD Studio release before `.dproj`
autodetection and global configuration fallback.

## Declared Delphi and Lazarus projects

When a dependency declares `projects`, only those files are built, in the
declared order. Paths must exist, remain inside the dependency root, and use
`.dproj`, `.lpi`, or `.lpk`. Packages without `projects` retain recursive
discovery, excluding common example and test directories. Delphi projects use
MSBuild; Lazarus projects use `lazbuild` and require it on `PATH`.

## Project scaffolding

```powershell
boss4d new app MyConsole
boss4d new package MyLibrary --path D:\work\MyLibrary
```

The destination must be empty. Boss4D creates `boss.json`, `src`, `tests`, and
the initial Delphi source. Existing files are never overwritten.

## Reproducible source normalization

After checkout and before checksum calculation, textual Delphi/Lazarus sources
(`.pas`, `.inc`, `.dfm`, `.dpk`, `.dproj`, `.lpi`, `.lpk`) are normalized to
CRLF. Files containing a null byte are treated as binary and left unchanged.
Because normalization precedes checksum verification, the lock and generated
SBOM describe the exact installed bytes.

The DPK manifest helper adds missing `requires` entries without rebuilding the
clause, preserving comments and conditional compiler directives.

See the [copyable example](../examples/upstream-improvements/README.md).
