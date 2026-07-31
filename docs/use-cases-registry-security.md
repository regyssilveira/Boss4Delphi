# Registry, credentials, and publication use cases

These workflows cross trust boundaries. Registry metadata chooses what may be
installed, credentials grant repository or publication access, and a published
`(name, version)` identity is immutable.

## 1. Add a private Registry source

**Situation:** the team publishes an internal package catalog in addition to
the public Boss4D Registry.

```powershell
boss4d registry list
boss4d registry add https://packages.example.com/index-v2.json
boss4d registry list
```

**Expected result:** the private source is persisted in global configuration
and appears after the public source.

**Risk controls:** use HTTPS, restrict write access to the index, and review
publisher identity, revision, digest, and revocation metadata. Source order is
significant when catalogs contain the same package identity.

**Recovery:** remove a source that is incorrect or compromised:

```powershell
boss4d registry remove https://packages.example.com/index-v2.json
```

Then remove affected cached metadata and repeat a locked install from trusted
sources.

## 2. Use a local Registry in an isolated network

**Situation:** an air-gapped environment mirrors approved metadata to a local
file.

```powershell
boss4d registry add C:\company\boss4d-index.json
boss4d registry list
boss4d install --locked --offline
```

**Expected result:** resolution uses the configured local index and package
content already present in verified cache.

**Risk controls:** protect the local index from unreviewed writes. A local path
does not waive digest, signature, provenance, or revocation checks.

**Recovery:** restore the index and cache from a trusted snapshot. Do not edit
immutable version records to make a failing package pass.

## 3. Authenticate to a private Git dependency on a workstation

**Situation:** a dependency is hosted in a private GitHub or GitLab repository.

```powershell
boss4d config auth github <personal-access-token>
boss4d install --locked
```

Use `gitlab` instead of `github` for GitLab.

**Expected result:** the token is stored by the OS credential service and Git
receives authentication without a credential embedded in the repository URL.

**Risk controls:** use a least-privilege token. The command argument may be
visible to local process inspection or shell history; enter it only on a
trusted workstation and remove sensitive history according to company policy.
Never place a token in `boss.json`, `boss-lock.json`, Git URLs, or logs.

**Recovery:** revoke the token at the provider, replace the stored credential,
and inspect logs and Git configuration for accidental disclosure.

## 4. Provide short-lived credentials in CI

**Situation:** an automated job needs temporary access without persisting a
credential store.

```powershell
$env:BOSS4D_GITHUB_TOKEN = $env:CI_GITHUB_TOKEN
boss4d install --locked
Remove-Item Env:\BOSS4D_GITHUB_TOKEN
```

**Expected result:** the environment credential takes precedence for the
process and is not written to repository configuration.

**Risk controls:** source `CI_GITHUB_TOKEN` from the CI vault, mask it in logs,
restrict it to the job, and avoid diagnostic shell tracing. Prefer short-lived
tokens.

**Recovery:** cancel the job and rotate the credential if any output reveals
it. A successful package install does not prove that logs are secret-free;
inspect the job output.

## 5. Install from mirrors without weakening verification

**Situation:** the primary metadata or artifact host is unavailable.

```powershell
boss4d install --locked
boss4d audit
```

**Expected result:** Boss4D tries declared mirrors in order but accepts content
only when immutable evidence matches the selected version.

**Risk controls:** never change the lock digest merely because a mirror returns
different bytes. Revoked versions must remain rejected even if a mirror still
serves them.

**Recovery:** restore the trusted primary or mirror artifact. If no candidate
matches, stop the deployment and publish a new reviewed version rather than
overwriting the old identity.

## 6. Inspect a publication without network access

**Situation:** a maintainer wants to review exactly what would be submitted.

```powershell
boss4d publish --dry-run --output publish.json
```

**Expected result:** `publish.json` contains deterministic package identity,
revision, checksum, scope, and evidence; no network submission occurs.

**Risk controls:** run project tests first, require a clean worktree and lock
evidence, and review the payload for private paths or unintended metadata.
Treat the generated file as release evidence.

**Recovery:** correct the manifest, lock, or repository state and regenerate
the payload. Do not hand-edit `publish.json`.

## 7. Publish an immutable version

**Situation:** the dry-run payload has been approved and the exact version is
ready for external publication.

```powershell
$env:BOSS4D_PUBLISH_TOKEN = $env:RELEASE_REGISTRY_TOKEN
boss4d publish --registry https://registry.example/api
Remove-Item Env:\BOSS4D_PUBLISH_TOKEN
```

**Expected result:** the Registry accepts the new `(name, version)` record and
the returned metadata matches the reviewed payload.

**Risk controls:** use a release-scoped credential, protect the job
environment, archive checksums and provenance, and never use `--allow-dirty`
in normal releases.

**Recovery:** HTTP 409 means the identity already exists. Do not overwrite or
retry with altered bytes; compare the existing record and publish a new
version if content changed.

## 8. Submit a package to the official public Registry

**Situation:** a publisher is onboarding or adding a reviewed version through
the Git-backed public catalog.

1. Register the publisher and controlled repository prefixes in
   `registry/publishers.json`.
2. Add a complete OpenPGP fingerprint.
3. Reserve the immutable release URL for the package evidence.
4. Run:

```console
boss4d publish --official --open-pr \
  --publisher my-publisher \
  --repository github.com/owner/my-package \
  --fingerprint <40-hex-fingerprint> \
  --sign <key-id> \
  --artifact-url <immutable-https-url> \
  --registry-root /src/Boss4Delphi
```

**Expected result:** publisher scope, signer fingerprint, immutable metadata,
artifact evidence, exact-file commit, and index composition pass before review;
the CLI prints the created pull-request URL.

Upload the generated package, signature, and provenance to the declared URL
before the pull request is merged; the Registry check validates those external
assets independently.

**Risk controls:** never edit or remove an existing version object. Add a new
version or an explicit revocation. Keep publisher and signer ownership
reviewable in Git history.

**Recovery:** fix the proposed commit and rerun both validators. If a published
version is unsafe, submit revocation metadata instead of rewriting history.

## Decision table

| Need | Safe action |
|---|---|
| Add a trusted catalog | `boss4d registry add <source>` |
| Inspect configured sources | `boss4d registry list` |
| Deterministically inspect publication | `boss4d publish --dry-run --output publish.json` |
| Publish from CI | Environment token plus `boss4d publish --registry <url>` |
| Open an official Registry submission | `boss4d publish --official --open-pr ...` |
| Resolve an immutable conflict | Publish a new version; do not overwrite |
| Handle a compromised release | Revoke it in reviewed Registry metadata |

See [package index](package-index.md), [resolution and credentials](resolution-and-credentials.md),
[trust policy](trust-policy.md), [publication](publish.md), and
[publisher onboarding](publisher-onboarding.md).

