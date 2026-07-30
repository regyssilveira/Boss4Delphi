# Legacy Delphi compatibility

Boss4D ships two IDE integration profiles:

- Delphi 11, 12, and 13 receive the full IDE wizard.
- Delphi 10.1 Berlin receives a compact legacy wizard compiled without inline
  variables or newer RTL assumptions.

The legacy plug-in preserves package discovery and a stable integration entry
point while directing dependency operations to the same `boss4d.exe` CLI. It
targets the BDS 18.0 compiler in the release matrix and is
published under `dist/plugins/10.1`.

```text
dist/plugins/10.1/Boss4D.IDE.Plugin.bpl
dist/plugins/11/Boss4D.IDE.Plugin.bpl
dist/plugins/12/Boss4D.IDE.Plugin.bpl
dist/plugins/13/Boss4D.IDE.Plugin.bpl
```

The CLI itself continues to be produced by the current release compiler,
because dependency resolution, SBOM, HTTP, and cryptographic code rely on
modern RTL APIs. Projects managed by that CLI may still target older Delphi
toolchains through `toolchain.compiler`.
