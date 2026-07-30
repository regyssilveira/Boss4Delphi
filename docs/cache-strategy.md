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
- compiler/toolchain version.

Only a complete cache entry is restored. A platform or compiler mismatch is a
cache miss and triggers a normal compilation. Package DCU/DCP/BPL outputs are
not shared until they can be isolated per dependency without cross-package
contamination.
