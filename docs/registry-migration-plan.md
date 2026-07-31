# Public Registry schema-v2 migration plan

This plan was audited against the public GitHub repositories on 31 July 2026.
It is operational planning, not trusted package metadata. A package becomes
trusted only after its publisher, repository scope, OpenPGP fingerprint,
artifact digest, detached signature, and provenance pass the Registry pull
request checks.

## Current baseline

- 55 discoverable legacy v1 packages;
- 18 repository owners;
- 16 packages in the already registered `regyssilveira` namespace;
- 10 packages in the `HashLoad` namespace;
- zero schema-v2 packages and zero authorized signer fingerprints;
- 3 publisher-controlled packages passing the current reproducibility gates;
- 13 publisher-controlled packages requiring a release or corrected tag;
- catalog health: 55 packages, 109 migration warnings, zero structural errors.

The generated Registry portal is the public progress ledger. It currently
reports 0 verified packages, 55 legacy packages, and 0% verified migration.
Each accepted schema-v2 package with an authorized publisher fingerprint
increments that metric automatically.

## Wave 0 — establish signing identity

1. Use the GnuPG 2.4.9 implementation bundled with Git for Windows on the
   release workstation.
2. Create or import the release signing identity and retain its revocation
   certificate outside the repository.
3. Add only the complete public fingerprint to the `boss4d` publisher.
4. Verify signing and provenance through `boss4d publish --official --dry-run`.
5. Publish Boss4D itself first and require the Registry workflow to validate
   the external release assets.

The private key, passphrase, and revocation material must never be committed.

### Prepared first artifact

The immutable `v1.6.0` tag (`e53b8eb`) has already been packed with the
current deterministic packer:

- artifact: `Boss4Delphi-1.6.0.b4dpkg`;
- size: 9,166,284 bytes;
- SHA-256:
  `903d6c3349fe75892430273a577d1b13f65d81f2f0ebe854b046ba9b4d1bda0b`;
- in-toto subject digest: verified equal to the artifact digest;
- remaining gates: OpenPGP signature, authorized fingerprint, asset upload,
  and official Registry pull request.

## Wave 1 — publisher-controlled release-ready packages

The following repositories already have a tagged GitHub release and are in the
registered publisher scope:

| Package | Candidate | State |
|---|---:|---|
| Boss4Delphi | v1.6.0 | First end-to-end proof |
| horse-rate-limit | v1.0.0 | Blocked: undeclared REST test dependency and missing test unit |
| horse-compression-v2 | v1.0.0 | Blocked: tag declares `2.0.0` in `boss.json` |
| horse-static | v1.0.0 | Blocked: dependency alias resolves to `https://horse/` |
| horse-dto | v1.0.0 | Blocked: does not compile against resolved Horse 3.2.0 |
| horse-rbac | v1.0.0 | Blocked: tests do not compile against resolved Horse 3.2.0 |
| horse-schema-validation | v1.0.0 | Ready: install, compile, and 10/10 tests pass |
| horse-multipart | v1.0.0 | Ready: install, compile, and upload integration test passes |
| horse-helmet | v1.0.0 | Blocked: test manifest references a nonexistent repository |
| horse-ssl-redirect | v1.0.0 | Blocked: tests do not compile against resolved Horse 3.2.0 |
| horse-request-id | v1.0.0 | Blocked: uses Horse request services absent from 3.2.0 |
| horse-opentelemetry | v1.0.0 | Blocked: legacy dependency value resolves to `https://horse/` |
| horse-prometheus | v1.0.0 | Blocked: legacy dependency value resolves to `https://horse/` |

Each migration must build and test from the immutable tag, produce `.b4dpkg`,
OpenPGP signature and in-toto provenance, upload them to the tag release, and
use `boss4d publish --official --open-pr`.

Eleven middleware candidates with coherent `v1.0.0` manifests have already
been packed from detached immutable checkouts. All eleven `.b4dpkg` files pass
package conformance and all eleven in-toto subject digests match their
artifacts. They remain local preparation artifacts until their project tests,
OpenPGP signatures, release uploads, and Registry submissions are complete.
Only `horse-schema-validation` and `horse-multipart` currently pass the
project-test gate; package conformance alone is not release readiness.

### First publication batch

After the signer is protected and authorized, publish in this order:

1. Boss4Delphi `v1.6.0` as the end-to-end policy proof;
2. `horse-schema-validation` `v1.0.0`, whose 10 Delphi tests pass;
3. `horse-multipart` `v1.0.0`, whose real upload integration test passes.

For each package, repeat the same immutable sequence: sign and verify the
prepared `.b4dpkg`, upload `.b4dpkg`, `.asc`, and `.intoto.json` to that exact
GitHub release, verify all three public URLs and digest, run
`publish --official --dry-run`, then run `publish --official --open-pr`.
Never reuse one package's evidence URL for another package.

## Wave 2 — publisher-controlled packages needing a release

`Dext`, `horse-crud`, and `horse-sanitize` have no published tag/release.
The ten blocked Wave 1 packages additionally need corrected manifests, tests,
or Horse compatibility in new immutable releases. Before Registry migration
these packages need an exact SemVer tag, tests, immutable release assets, and
the same signed publication workflow.

## Wave 3 — external publisher onboarding

Prioritize active, widely used repositories:

1. Horse and its HashLoad middleware family;
2. RESTRequest4Delphi;
3. jhonson;
4. Academia do Código Horse middleware;
5. remaining active repositories by maintenance and adoption evidence.

An external publisher must authorize its GitHub owners, repository prefixes,
and fingerprint. Registry maintainers must not impersonate an owner or publish
unsigned third-party artifacts as trusted schema-v2 packages.

## Completion criteria

- every migrated version has retrievable immutable evidence;
- `boss4d registry health` reports it as trusted;
- installation verifies digest, signature, and provenance;
- Linux and macOS CI keep the full catalog at zero structural/trust errors;
- legacy warnings decrease only when equivalent trusted metadata is live.
