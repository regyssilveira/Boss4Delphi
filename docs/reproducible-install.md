# Reproducible and offline installation

Boss4D can install the exact graph recorded in `boss-lock.json` without changing
the lock:

```console
boss4d install --locked
boss4d install --frozen-lockfile
boss4d install --locked --offline
boss4d ci
boss4d ci --offline
boss4d restore --ci --remote-cache X:\boss4d-cache
boss4d install --build-only --locked --remote-cache X:\boss4d-cache
```

`--locked` and its `--frozen-lockfile` alias require a lock with root metadata.
Boss4D rejects a manifest whose direct dependency set differs from the lock,
checks out each recorded Git revision, and validates its SHA-256 checksum. The
lock file, including its timestamp, is not rewritten.

`--offline` disables cache clone and update operations. Every dependency must
already exist in the global Boss4D cache; a cache miss fails the command.

`ci` and `restore --ci` are the release/automation mode. They enforce the
frozen lock, clean `modules/`, and disable IDE registration at the service
boundary. `install --build-only` also suppresses registration. Because the
operation is transactional, a failed clean install restores the previous
manifest, lock, and module tree. `--remote-cache` shares verified compiled
targets without weakening those isolation rules.

Recommended CI sequence:

```console
boss4d ci
boss4d sbom --lock-only --reproducible --strict --validate \
  --format cyclonedx --output bom.cdx.json
```
