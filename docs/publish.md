# Publishing packages

`boss4d publish` creates a deterministic package record from `boss.json` and
`boss-lock.json`, validates it, and optionally sends it to the official public
Registry or to a compatible private registry.
This makes the reviewed manifest and locked supply-chain evidence the source of
the published metadata.

## Safety gates

Publishing stops when the manifest or lock is missing, package identity differs
between them, lock schema v3 is not in use, or any dependency lacks a revision
or SHA-256 checksum. By default, the Git worktree must be clean and the
manifest's `test` script is executed when present.

Inspect the exact payload without network access:

```console
boss4d publish --dry-run --output publish.json
```

For an actual submission, keep the token out of command history:

```console
set BOSS4D_PUBLISH_TOKEN=your-token
boss4d publish --registry https://registry.example/api
```

The same command is available on Linux/FPC. It creates the deterministic
`.b4dpkg` and in-toto provenance locally, embeds both in the protocol payload,
and requires lock v3 evidence. Git dependencies require revision and checksum;
verified registry artifacts use their immutable checksum as evidence.

The Linux CLI reads the publication token from `BOSS4D_PUBLISH_TOKEN` by
default, or from the variable selected by `--token-env`. If neither is set, it
looks up the `registry` credential in Secret Service. Tokens are sent only in
the HTTP authorization header and are never written into the payload.

Published `(name, version)` identities are immutable. A registry response of
HTTP 409 is reported as a version conflict; the client never retries by
overwriting the existing release. Use a new version or publish an explicit
revocation.

Use `--token-env NAME` to select another environment variable. `--allow-dirty`
and `--skip-tests` explicitly bypass their respective gates and should be
reserved for controlled recovery workflows.

## Registry contract

Boss4D sends an authenticated `POST` with JSON content to
`<registry>/packages`. The payload contains package identity and descriptive
metadata, lock schema version, and dependencies sorted by canonical key with
version, repository, immutable revision, checksum, and scope. A registry must
return a 2xx status. Tokens are never written to the manifest, lock, or payload.

This command publishes metadata and supply-chain evidence; release binaries and
source archives remain artifacts of the project's release pipeline.
