# Publisher onboarding

The public Registry is maintained through reviewed Git pull requests. A
publisher cannot upload mutable metadata directly to the repository.

## First registration

1. Add a unique entry to `registry/publishers.json`.
2. Declare only repository prefixes controlled by that publisher.
3. Add at least one complete 40-character OpenPGP fingerprint to
   `allowedSigners`.
4. Copy `registry/package-template.json` to
   `registry/packages/<normalized-name>.json`.
5. Set `publisher` and `signerFingerprint` to registered values.
6. Add `packages/<normalized-name>.json` to `sparse` in
   `registry/index-v2.json`.
7. Open a pull request.

Every new version requires a `.b4dpkg`, its exact SHA-256, a detached OpenPGP
signature, and in-toto provenance. Repository scope, signer authorization,
semantic versions, variants, and evidence are checked automatically.

## Immutability

Existing version objects cannot be edited or removed. A publisher adds another
version or submits a root-level revocation. The pull-request check compares the
submission against the target branch, so changing a checksum, URL, signature,
provenance statement, or selector of an existing version fails.

Run the same checks locally:

```powershell
./scripts/validate-registry-submission.ps1
./scripts/test-registry-submission.ps1
```

Registry approval establishes catalog policy; clients still verify the
artifact checksum, OpenPGP signature, and provenance when installing.

The generated portal deliberately distinguishes a repository that merely
matches a registered namespace from a schema-v2 package whose declared signer
is authorized. Publisher registration is administrative identity, not proof
that a particular release was signed.

