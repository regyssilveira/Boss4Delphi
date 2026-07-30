# FPC/Linux CLI

Boss4D includes a native FPC 3.2.2 host that is compiled and tested on Linux,
not cross-compiled from Windows:

```powershell
./scripts/ci-fpc-linux.ps1
```

The script uses the existing `fpc-test:latest` Docker image, builds an x86-64
Linux executable, runs its FPCUnit suite, and smoke-tests `version` and
`platform`.

The portable host currently supports:

- `version` and `platform`;
- `init`, producing a compatible `boss.json`;
- `install`, cloning declared Git dependencies into `modules`.

Dependency target naming, exact-tag clone arguments, manifest parsing, and
platform detection have FPCUnit coverage. The Windows CLI remains the complete
host for IDE/GetIt integration, SBOM toolchain collection, registry mutation,
and self-update. Those capabilities are deliberately reported as unavailable
on POSIX until portable adapters exist; Windows Registry behavior is not
emulated.
