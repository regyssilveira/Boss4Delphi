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
boss4d registry search-index registry/index-v2.json registry/search-index.json
```

The responsive portal renders catalog statistics and filters packages by text,
publisher trust, platform, and compiler. It also presents v1/v2 version
history, revocations, and available SHA-256/signature/provenance evidence. All
untrusted metadata is HTML-escaped. The companion search index is a
deterministic, fully composed JSON snapshot suitable for GitHub Pages, a CDN,
or a hosted search service. The `registry/` directory can
be served by GitHub Pages, a CDN, or any static HTTP server; the JSON index is
the protocol authority and the portal is only a human-readable projection.

For a local v2 entry point, the command recursively composes `includes` and
`sparse` documents, loads each document only once, and applies their
revocations before rendering. References must remain inside the entry point
directory. Parent traversal and HTTP references are rejected; materialize a
remote registry locally before generating a deterministic portal.

If `publishers.json` exists beside the entry point, the portal also projects
publisher identity. `registered namespace` means only that the repository
matches a reviewed publisher prefix. `authorized publisher` additionally means
the package declares an allowed fingerprint. Neither label replaces artifact
verification: SHA-256, detached signature, and provenance remain independent
release evidence and are shown separately.

Pack performance and determinism can be tracked with:

```powershell
./scripts/benchmark-pack.ps1 -Iterations 5
```

The benchmark emits machine-readable JSON containing min/average/max latency
and fails if any iteration produces a different SHA-256.
