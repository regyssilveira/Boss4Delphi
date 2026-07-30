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
- `add`, `remove`, and `list`, including `devDependencies`;
- `install`, cloning declared Git dependencies into `modules`;
- lock schema v3 generation and manifest drift detection;
- `install --locked`, `--frozen-lockfile`, `--offline`, and `--production`;
- `ci`, as the locked and frozen automation shortcut;
- `--resolution=highest|minimal` for `^` and `~` Git tag ranges;
- Registry v1/v2 `search` and `info`, including composed indexes;
- persistent `registry add|remove|list` sources in the shared `boss.cfg.json`;
- HTTP registry cache with `--offline` and automatic cached fallback.

```console
boss4d registry add https://packages.example/index-v2.json
boss4d registry list
boss4d search horse
boss4d info Horse
boss4d search horse --offline
boss4d search horse --registry=./registry/index-v2.json
```

The original dependency map remains unchanged:

```json
{
  "dependencies": {
    "github.com/hashload/horse": "^3.0.0"
  }
}
```

Existing manifests therefore require no migration. New metadata is kept in
`boss-lock.json`; missing optional sections such as `devDependencies` remain
valid.

The Linux transaction stages each new clone and removes modules created by a
failed operation. Offline mode never queries Git and fails on a missing local
module. FPCUnit covers legacy manifest parsing, dependency editing, production
scope, lock v3, frozen drift detection, target naming, and highest/minimal
semantic-version selection. Registry tests cover v1/v2 composition, cycle
prevention, source persistence, config compatibility, offline cache, and
network-failure fallback.

The Windows CLI remains the host for IDE/GetIt integration, verified
`.b4dpkg` installation, SBOM/audit, OpenPGP, toolchain collection, and
self-update. Windows Registry behavior is not emulated on POSIX.
