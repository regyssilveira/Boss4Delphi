# Conformance, registry portal, and benchmarks

Protocol implementers can validate public artifacts with the same rules used
by Boss4D:

```text
boss4d conformance registry registry/index-v2.json
boss4d conformance package dist/library.b4dpkg
```

Registry conformance accepts schemas v1/v2, package names and repositories, and
paired artifact URL/SHA-256 metadata. Package conformance verifies format v1,
safe relative paths, Base64 content, and every per-file SHA-256 digest.

A static, host-independent portal can be generated from any conforming index:

```text
boss4d registry portal registry/index-v2.json registry/index.html
```

The searchable portal renders v1 or v2 packages, version history, revocations,
and available SHA-256/signature/provenance evidence. All untrusted package
metadata is HTML-escaped. The `registry/` directory can
be served by GitHub Pages, a CDN, or any static HTTP server; the JSON index is
the protocol authority and the portal is only a human-readable projection.

For a local v2 entry point, the command recursively composes `includes` and
`sparse` documents, loads each document only once, and applies their
revocations before rendering. References must remain inside the entry point
directory. Parent traversal and HTTP references are rejected; materialize a
remote registry locally before generating a deterministic portal.

Pack performance and determinism can be tracked with:

```powershell
./scripts/benchmark-pack.ps1 -Iterations 5
```

The benchmark emits machine-readable JSON containing min/average/max latency
and fails if any iteration produces a different SHA-256.
