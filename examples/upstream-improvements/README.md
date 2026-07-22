# Toolchain and declared projects example

Copy `boss.json` to a package root and adjust the project names. Boss4D builds
only the declared files, in order. `runtime.dproj` uses Delphi/MSBuild and
`runtime.lpk` uses Lazarus/lazbuild.

```powershell
boss4d install
boss4d install --platform Win32
```

The CLI platform overrides the manifest. Two repositories with the same
basename can coexist because physical directories include a repository hash.
