# Multi-Delphi build matrix example

The adjacent `boss.json` declares runtime and design-time packages across
Delphi 10.1, 11, 12, and 13. It expands to 19 compatible targets after the
design package restrictions are applied.

From a real component repository, adapt the project paths and run:

```console
boss4d spec --detect
boss4d build --compiler d13 --platform Win64 --configuration Release --explain
boss4d build --compiler all --platform Win32 --configuration Release --jobs 4
boss4d build --full
boss4d build --compiler d13 --platform Win32 --configuration Release --register
boss4d doctor
```

`--full` selects every axis and forces recompilation. `--force` rebuilds only
the selected targets. `--register` registers BPLs from design-time targets in
the exact compiler/platform pair that produced them.

To remove or repair registrations:

```console
boss4d ide unregister ComponentDesign370 --compiler d13 --platform Win32
boss4d ide repair
```

Legacy manifests do not need this section and continue to use their existing
`projects`, `toolchain`, and `engines` values.
