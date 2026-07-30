# Vulnerability audit

`boss4d audit` queries the [OSV API](https://osv.dev) using the exact Git commit
recorded for each dependency in `boss-lock.json`.

```console
boss4d audit
boss4d audit --fail-on high
boss4d audit --offline
boss4d audit --cache-hours 48
boss4d audit --vex security.vex.json --fail-on medium
```

Responses are cached per revision under the Boss4D home directory. Offline mode
never contacts OSV and fails if a current cache entry is unavailable.

`--fail-on low|medium|high|critical` returns an error when an unsuppressed
finding reaches the selected severity. A VEX entry with `not_affected`, `fixed`,
or `resolved` suppresses the matching vulnerability ID; other states remain
visible and subject to policy.

The audit identifies source revisions, not Delphi package names. Findings are
therefore only as complete as OSV's commit coverage, and an empty report must
not be interpreted as proof that a dependency is vulnerability-free.
