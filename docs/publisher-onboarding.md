# Publisher onboarding

The public Registry is maintained through reviewed Git pull requests. A
publisher cannot upload mutable metadata directly to the repository.

## First registration

1. Add a unique entry to `registry/publishers.json`.
2. Add the GitHub logins allowed to submit for the publisher to
   `githubOwners`. For an organization, list its authorized human maintainers.
3. Declare only repository prefixes controlled by that publisher.
4. Add at least one complete 40-character OpenPGP fingerprint to
   `allowedSigners`.
5. Copy `registry/package-template.json` to
   `registry/packages/<normalized-name>.json`.
6. Set `publisher` and `signerFingerprint` to registered values.
7. Add `packages/<normalized-name>.json` to `sparse` in
   `registry/index-v2.json`.
8. Open the pull request from a GitHub account declared in `githubOwners`.

Every new version requires a `.b4dpkg`, its exact SHA-256, a detached OpenPGP
signature, and in-toto provenance. Repository scope, signer authorization,
semantic versions, variants, and evidence are checked automatically. A
publisher-only onboarding can initially use an empty `allowedSigners`; no
package can be accepted until an authorized owner registers a signer.

The pull-request workflow passes `github.actor` to the validator. A new
publisher must include that account in `githubOwners`. Changes to an existing
publisher are authorized against the owners from the target branch, so a
contributor cannot add themselves and a new signer in the same pull request.
Package submissions are also restricted to the registered GitHub owners.
For a legacy publisher that predates `githubOwners`, one bootstrap update is
allowed only when the submitter login matches a personal
`github.com/<login>/` repository namespace already present in the target
branch. Later changes use `githubOwners` exclusively.

## Generate a package submission

After the publisher and signer are registered, generate the package document
and sparse-index entry together:

```powershell
./scripts/new-registry-submission.ps1 `
  -PackageName MyPackage `
  -Publisher my-publisher `
  -Repository github.com/owner/my-package `
  -SignerFingerprint 0123456789ABCDEF0123456789ABCDEF01234567 `
  -Version 1.0.0 `
  -Artifact https://github.com/owner/my-package/releases/download/v1.0.0/MyPackage-1.0.0.b4dpkg `
  -Sha256 <64-hexadecimal-characters> `
  -Signature https://github.com/owner/my-package/releases/download/v1.0.0/MyPackage-1.0.0.b4dpkg.asc `
  -Provenance https://github.com/owner/my-package/releases/download/v1.0.0/MyPackage-1.0.0.b4dpkg.intoto.json `
  -Description "My package" `
  -License MIT
```

The generator validates the registered publisher, repository scope, signer,
SemVer, SHA-256, and HTTPS evidence URLs before writing anything. It creates a
normalized `registry/packages/<name>.json` and updates `index-v2.json`
together; it refuses to overwrite existing package metadata.

For the next release, repeat the evidence parameters with the same package
identity and add `-AppendVersion`:

```powershell
./scripts/new-registry-submission.ps1 `
  -PackageName MyPackage -Publisher my-publisher `
  -Repository github.com/owner/my-package `
  -SignerFingerprint 0123456789ABCDEF0123456789ABCDEF01234567 `
  -Version 1.1.0 `
  -Artifact https://github.com/owner/my-package/releases/download/v1.1.0/MyPackage-1.1.0.b4dpkg `
  -Sha256 <64-hexadecimal-characters> `
  -Signature https://github.com/owner/my-package/releases/download/v1.1.0/MyPackage-1.1.0.b4dpkg.asc `
  -Provenance https://github.com/owner/my-package/releases/download/v1.1.0/MyPackage-1.1.0.b4dpkg.intoto.json `
  -AppendVersion
```

Append mode preserves every existing version, rejects duplicate SemVer, and
does not allow package identity, repository, or signer changes.

## Immutability

Existing version objects cannot be edited or removed. A publisher adds another
version or submits a root-level revocation. The pull-request check compares the
submission against the target branch, so changing a checksum, URL, signature,
provenance statement, or selector of an existing version fails.

Run the same checks locally:

```powershell
./scripts/validate-registry-submission.ps1 -Submitter <your-github-login>
./scripts/test-registry-submission.ps1
./scripts/test-new-registry-submission.ps1
```

Registry approval establishes catalog policy; clients still verify the
artifact checksum, OpenPGP signature, and provenance when installing.

The generated portal deliberately distinguishes a repository that merely
matches a registered namespace from a schema-v2 package whose declared signer
is authorized. Publisher registration is administrative identity, not proof
that a particular release was signed.

