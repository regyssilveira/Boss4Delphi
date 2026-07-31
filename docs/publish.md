# Publishing packages

`boss4d publish` creates a deterministic package record from `boss.json` and
`boss-lock.json` and validates it. There are two explicit destinations:

- a compatible HTTP registry accepts the authenticated protocol payload;
- the official public Registry is Git-governed and accepts reviewed pull
  requests, not HTTP publication.
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

## Prepare an official public Registry submission

Use one local command to run the publication gates, create the immutable
`.b4dpkg`, create in-toto provenance, sign and verify the artifact with
OpenPGP, and generate the schema-v2 package document:

```console
boss4d publish --official ^
  --publisher my-publisher ^
  --repository github.com/owner/project ^
  --fingerprint 0123456789ABCDEF0123456789ABCDEF01234567 ^
  --sign 0123456789ABCDEF0123456789ABCDEF01234567 ^
  --artifact-url https://github.com/owner/project/releases/download/v1.2.3/project-1.2.3.b4dpkg
```

The default outputs are `dist/<name>-<version>.b4dpkg`, its `.asc` signature,
its `.intoto.json` provenance, and
`dist/<name>-<version>.registry.json`. Use `--artifact-output` and
`--submission-output` to override them.

To update a clean Registry checkout, create an isolated branch, commit only
the package metadata and sparse index, push it, and open the reviewed pull
request in one operation:

```console
boss4d publish --official ^
  --publisher my-publisher ^
  --repository github.com/owner/project ^
  --fingerprint 0123456789ABCDEF0123456789ABCDEF01234567 ^
  --sign 0123456789ABCDEF0123456789ABCDEF01234567 ^
  --artifact-url https://github.com/owner/project/releases/download/v1.2.3/project-1.2.3.b4dpkg ^
  --registry-root C:\src\Boss4Delphi ^
  --open-pr
```

The default branch is `boss4d/package-<name>-<version>`, the push remote is
`origin`, the base is `main`, and the PR repository is
`regyssilveira/Boss4Delphi`. Override them with `--registry-branch`,
`--registry-remote`, `--registry-base`, and `--registry-pr-repo`. When pushing
to a fork, use `--registry-pr-head owner:branch`. Use `--append-version` for a
package already present in the Registry.

The checkout must start clean. If metadata application fails, Boss4D restores
the exact index/package paths, returns to the original branch, and removes the
temporary branch. Once a local commit or remote push exists, a later failure
is preserved for inspection and safe retry. Unrelated files are never staged.

`--dry-run` executes the manifest, lock, clean-worktree, test, identity,
SemVer, HTTPS, hash-shape, and signer-input gates without creating the bundle.
The command does not upload assets, modify the Registry checkout, create a
branch, or open a PR. Upload the three evidence files to the immutable release
URL before the reviewed PR is merged. The Registry workflow independently
verifies publisher ownership, repository scope, fingerprint authorization,
immutability, signature, provenance, and digest.

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

## HTTP Registry contract

Boss4D sends an authenticated `POST` with JSON content to
`<registry>/packages`. The payload contains package identity and descriptive
metadata, lock schema version, and dependencies sorted by canonical key with
version, repository, immutable revision, checksum, and scope. A registry must
return a 2xx status. Tokens are never written to the manifest, lock, or payload.

The HTTP mode publishes metadata and embedded evidence. In official mode,
release assets remain controlled by the package project's release pipeline and
the Registry change remains reviewable in Git.
