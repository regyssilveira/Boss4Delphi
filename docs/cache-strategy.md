# Git object and compiled artifact caches

Dependency sources remain isolated working trees. Boss4D clones from the global
Git cache with `--reference-if-able --no-hardlinks`, uses shared objects only
during checkout, and removes `.git` afterward. Project files therefore never
depend on hardlinks or on the later lifetime of the global object cache.

The Linux/FPC host keeps bare Git mirrors under `~/.boss/cache/git`, updates
them before online installs, and clones with `--reference-if-able
--no-hardlinks`. `boss4d cache size|prune|clean` inspects or manages that cache;
prune removes entries older than 30 days.

Compiled executable artifacts are cached by:

- normalized source checksum;
- target platform;
- compiler/toolchain version;
- build configuration.

Each entry contains a deterministic file inventory and SHA-256 for every
artifact. Restoration uses staging plus atomic promotion and rejects missing,
extra, or modified files. A platform, compiler, configuration, or checksum
mismatch is a cache miss and triggers normal compilation.

Use a filesystem-backed shared cache between workstations or CI jobs:

```console
boss4d build --remote-cache X:\boss4d-cache
boss4d restore --ci --remote-cache X:\boss4d-cache
```

A valid remote entry repopulates a missing or corrupt local entry. A corrupt
remote entry is never promoted. Incremental `.boss4d-state` is regenerated for
the restored target and is not treated as a portable artifact.
