# Immutable Boss4D packages

`boss4d pack` creates a deterministic `.b4dpkg` artifact from a project:

```text
boss4d pack
boss4d pack --output dist/my-library-1.0.0.b4dpkg
boss4d pack --output dist/my-library-1.0.0.b4dpkg --sign release@example.com
```

The v1 format is a canonical JSON envelope. It records `format`,
`schemaVersion`, and a path-sorted file array. Every file has a normalized
forward-slash path, SHA-256 digest, and Base64 content. Generated binaries,
`.git`, `modules`, `dist`, scratch data, and compiler outputs are excluded.

The same source tree therefore produces the same bytes and package SHA-256.
Every pack also writes an in-toto Statement v1 at `.intoto.json`, binding the
artifact name and SHA-256 to the Boss4D builder and file count. With `--sign`,
Boss4D asks GPG to create an armored detached `.asc` signature and immediately
verifies it before reporting success.
`boss4d publish` embeds this immutable artifact and digest in protocol-v1
publication payloads, allowing a registry to store content by digest rather
than mutable repository state.

## Verified installation

A registry v2 release may publish the artifact evidence together:

```json
{
  "version": "1.0.0",
  "artifact": "https://packages.example/my-library-1.0.0.b4dpkg",
  "sha256": "...",
  "signature": "https://packages.example/my-library-1.0.0.b4dpkg.asc",
  "provenance": "https://packages.example/my-library-1.0.0.b4dpkg.intoto.json"
}
```

Install an indexed package with:

```text
boss4d package install my-library
boss4d package install my-library --no-source-fallback
```

Boss4D downloads into an isolated staging area, checks the package SHA-256,
validates every embedded path and file digest, verifies a declared OpenPGP
signature and in-toto subject digest, and only then replaces the module
directory. A failed verification leaves the previous target unchanged.

By default, an unavailable or rejected artifact falls back to the indexed Git
repository. `--no-source-fallback` makes the immutable artifact mandatory.
Signature and provenance are mandatory whenever their URLs are declared by the
registry.

The native Linux/FPC CLI supports this verified installation flow, including
Registry v2 platform/compiler variants. OpenPGP verification requires `gpg` on
`PATH`; SHA-256 verification requires `sha256sum`.

The format favors auditability and deterministic behavior. Future schema
versions may introduce compression, but consumers must reject unknown versions
instead of guessing their semantics.
