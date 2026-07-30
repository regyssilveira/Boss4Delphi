# Immutable Boss4D packages

`boss4d pack` creates a deterministic `.b4dpkg` artifact from a project:

```text
boss4d pack
boss4d pack --output dist/my-library-1.0.0.b4dpkg
```

The v1 format is a canonical JSON envelope. It records `format`,
`schemaVersion`, and a path-sorted file array. Every file has a normalized
forward-slash path, SHA-256 digest, and Base64 content. Generated binaries,
`.git`, `modules`, `dist`, scratch data, and compiler outputs are excluded.

The same source tree therefore produces the same bytes and package SHA-256.
`boss4d publish` embeds this immutable artifact and digest in protocol-v1
publication payloads, allowing a registry to store content by digest rather
than mutable repository state.

The format favors auditability and deterministic behavior. Future schema
versions may introduce compression, but consumers must reject unknown versions
instead of guessing their semantics.
