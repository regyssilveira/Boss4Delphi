# Version selection, pinning, and rollback

Boss4D can resolve every immutable version published by a Registry v2 index.
Resolution is based on SemVer, ignores revoked releases, and does not depend on
the order of entries in the JSON document.

```console
boss4d package versions Horse
boss4d package install Horse@^3.0.0
boss4d package install Horse@3.2.1 --platform Win64 --compiler 37.0
```

`package versions` keeps revoked releases visible for audit purposes, but
installation never selects one. An artifact variant is selected deterministically
from platform and compiler. The primary URL and its ordered mirrors must all
match the same declared SHA-256. A verified installation writes
`.boss4d-package.json` inside the installed module with version, variant,
digest, signature, and provenance evidence.

## Pin and unpin

Pin a direct dependency to the exact SemVer already recorded in
`boss-lock.json`:

```console
boss4d pin horse
boss4d unpin horse
```

`pin` changes the manifest range to the resolved lock version. `unpin` restores
a compatible caret range. The lock remains the authority for reproducible
`--locked` and `ci` installations.

## Upgrade, downgrade, and rollback

Explicit version changes create a durable snapshot before installation:

```console
boss4d upgrade github.com/hashload/horse@3.2.1
boss4d downgrade github.com/hashload/horse@3.1.0
boss4d rollback
```

Snapshots live under `.boss4d/version-history/` and contain `boss.json`,
`boss-lock.json`, and `modules/`. `upgrade` only accepts a greater exact SemVer;
`downgrade` only accepts a lower one. `rollback` restores the latest snapshot
transactionally, including the installed source tree.

## Registry availability

HTTP indexes are cached under `BOSS_HOME/registry-cache`. A successful response
replaces the cached metadata. If the server later fails, Boss4D uses the last
valid cached document and emits a warning. Sparse package metadata and ordered
sparse mirrors follow the same policy.

