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

## Establish a protected release signer

On Windows, Boss4D can use the GnuPG executable bundled with Git for Windows:

```powershell
$gpg = 'C:\Program Files\Git\usr\bin\gpg.exe'
& $gpg --version
& $gpg --full-generate-key
& $gpg --list-secret-keys --keyid-format LONG --with-fingerprint
```

Generate a signing-capable key for the publisher's durable release identity,
set an expiration policy that will actually be maintained, and enter the
passphrase only through GnuPG's protected pinentry. Never place a passphrase in
a command argument, environment variable, script, CI log, or repository file.
Copy the complete 40-character primary fingerprint exactly; short key IDs are
not accepted by the Registry.

Export only the public key for distribution:

```powershell
& $gpg --armor --export <40-character-fingerprint> |
  Set-Content -Encoding ascii boss4d-release-public.asc
```

Keep the secret-key backup and revocation certificate encrypted and offline,
separate from the workstation and repository. Test recovery and revocation
before trusting the identity for releases. If an existing organizational key
is imported instead, verify its fingerprint through an independent channel
before adding it to `allowedSigners`.

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

The recommended path creates the signed bundle, updates a clean checkout,
pushes a dedicated branch, and opens the pull request:

```console
boss4d publish --official --open-pr \
  --publisher my-publisher \
  --repository github.com/owner/my-package \
  --fingerprint 0123456789ABCDEF0123456789ABCDEF01234567 \
  --sign 0123456789ABCDEF0123456789ABCDEF01234567 \
  --artifact-url https://github.com/owner/my-package/releases/download/v1.0.0/MyPackage-1.0.0.b4dpkg \
  --registry-root /src/Boss4Delphi
```

For a fork, select its Git remote and identify the PR head explicitly:
`--registry-remote fork --registry-pr-head owner:branch`. The CLI stages only
the package file and `registry/index-v2.json`. Use `--dry-run` first; it
creates no artifact, checkout change, branch, push, or pull request.
Upload the generated package, signature, and provenance to the declared
immutable URLs before the pull request is merged.

The PowerShell generator remains available for maintainers who need to prepare
metadata without building or signing the package:

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

