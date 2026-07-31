# Public Registry schema-v2 migration plan

This plan was audited against the public GitHub repositories on 31 July 2026.
It is operational planning, not trusted package metadata. A package becomes
trusted only after its publisher, repository scope, OpenPGP fingerprint,
artifact digest, detached signature, and provenance pass the Registry pull
request checks.

## Current baseline

- 41 discoverable legacy v1 packages;
- 18 repository owners;
- 16 packages in the already registered `regyssilveira` namespace;
- 10 packages in the `HashLoad` namespace;
- 14 signed schema-v2 packages and one authorized signer fingerprint;
- 14 publisher-controlled packages published through the reproducibility gates;
- 2 publisher-controlled packages requiring a release;
- catalog health: 55 packages, 82 migration warnings, zero structural errors.

The generated Registry portal is the public progress ledger. It currently
reports 14 verified packages, 41 legacy packages, and 25% verified migration.
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

### Published first artifact

The immutable `v1.6.0` tag (`e53b8eb`) has already been packed with the
current deterministic packer:

- artifact: `Boss4Delphi-1.6.0.b4dpkg`;
- size: 9,166,284 bytes;
- SHA-256:
  `903d6c3349fe75892430273a577d1b13f65d81f2f0ebe854b046ba9b4d1bda0b`;
- in-toto subject digest: verified equal to the artifact digest;
- OpenPGP signature, authorized fingerprint, release upload, independent
  installation, and Registry metadata are complete on the active pull request.

## Wave 1 — publisher-controlled release-ready packages

The following repositories already have a tagged GitHub release and are in the
registered publisher scope:

| Package | Candidate | State |
|---|---:|---|
| Boss4Delphi | v1.6.0 | Published and verified end to end |
| horse-rate-limit | v1.0.1 | Published; repaired suite, 14/14 tests and verified installation pass |
| horse-compression-v2 | v2.0.0 | Published; tag/manifest match, 3/3 tests and verified installation pass |
| horse-static | v1.0.1 | Published; 6/6 stable integration tests and verified installation pass |
| horse-dto | v1.0.1 | Published; Horse 3.2 compatibility, 9/9 tests and verified installation pass |
| horse-rbac | v1.0.1 | Published; 6/6 authorization integration tests and verified installation pass |
| horse-schema-validation | v1.0.0 | Published; install, signature, provenance, and 10/10 tests pass |
| horse-multipart | v1.0.0 | Published; install, signature, provenance, and upload integration test pass |
| horse-helmet | v1.0.1 | Published; repaired manifest, 12/12 tests and verified installation pass |
| horse-ssl-redirect | v1.0.1 | Published; 8/8 redirect integration tests and verified installation pass |
| horse-request-id | v1.0.1 | Published; Horse 3.2 compatibility, 4/4 request-isolation tests and verified installation pass |
| horse-opentelemetry | v1.0.1 | Published; request-scoped context, 62/62 assertions and verified installation pass |
| horse-prometheus | v1.0.1 | Published; 11/11 unit and 5/5 real HTTP metric assertions and verified installation pass |

Each migration must build and test from the immutable tag, produce `.b4dpkg`,
OpenPGP signature and in-toto provenance, upload them to the tag release, and
use `boss4d publish --official --open-pr`.

Eleven middleware candidates with coherent `v1.0.0` manifests have already
been packed from detached immutable checkouts. All eleven `.b4dpkg` files pass
package conformance and all eleven in-toto subject digests match their
artifacts. They remain local preparation artifacts until their project tests,
OpenPGP signatures, release uploads, and Registry submissions are complete.
`horse-schema-validation` and `horse-multipart` have now completed the
project-test, signing, upload, Registry, and verified-install gates. Package
conformance alone remains insufficient for the other candidates.

The next publication increment completed `horse-compression-v2` `v2.0.0`.
Its immutable tag now matches the manifest, its DUnitX suite passes on Delphi
10 Seattle against Horse 3.2.0, and its signed package installs without source
fallback.

`horse-static` `v1.0.1` then completed the same gates after correcting HTTP
304/416 chain interruption, Seattle compatibility, range-stream sizing, and
test isolation. Five consecutive six-test runs passed before the clean,
detached-tag package was signed and installed without source fallback.

`horse-helmet` `v1.0.1` completed next after repairing its test dependency
identity and adding a reproducible runner. Three consecutive 12-test runs plus
a clean post-merge run passed on Seattle before signed publication and verified
installation.

`horse-rate-limit` `v1.0.1` followed after restoring its missing cleanup unit,
declaring test dependencies, and updating test-only Horse/task APIs for
Seattle. Four complete 14-test runs passed, including concurrency, Redis,
CIDR, metrics, and sliding-window scenarios, before verified publication.

`horse-dto` `v1.0.1` then restored Horse 3.2 request, exception, routing, and
shutdown compatibility and corrected JSON-only binding without a live web
request. Four consecutive 9-test runs plus a clean post-merge run passed on
Seattle. Its package also drove a regression fix that excludes Git worktree
pointers from deterministic artifacts; the corrected 11-file bundle passed
independent signature, provenance, digest, conformance, and no-fallback
installation checks.

`horse-rbac` `v1.0.1` followed by adapting its route-scoped middleware and
session ownership tests to Horse 3.2 and adding a non-interactive Seattle
runner. Four complete six-scenario HTTP runs plus a clean post-merge run
covered unauthenticated, missing-claim, OR, and AND decisions before the
10-file bundle passed independent signature and verified no-fallback
installation.

`horse-ssl-redirect` `v1.0.1` followed with Horse 3.2 route-scoped test
compatibility and a reproducible Seattle runner. Four complete eight-test runs
plus a clean post-merge run covered localhost policy, proxy HTTPS headers,
custom TLS ports, and redirect status before the signed nine-file bundle
passed conformance and verified no-fallback installation.

`horse-request-id` `v1.0.1` then replaced its unavailable request-services
dependency with request-local storage compatible with Horse 3.2 and added a
reproducible Seattle runner. Five complete four-test runs plus a clean
post-merge run covered ID generation, request and correlation header
forwarding, and concurrent isolation before the signed 10-file bundle passed
independent signature, conformance, and verified no-fallback installation.

`horse-opentelemetry` `v1.0.1` followed by correcting its Horse dependency
identity and moving trace context into request-scoped Horse sessions. Four
complete 62-assertion runs plus a clean post-merge run covered context
creation and retrieval, W3C `traceparent` parsing, and hexadecimal ID
generation before the signed 15-file bundle passed independent signature,
conformance, and verified no-fallback installation.

`horse-prometheus` `v1.0.1` completed Wave 1 by correcting its Horse
dependency identity, supported request APIs, and middleware-chain interruption
for `/metrics`. Five complete runs combined 11 unit assertions with five real
HTTP metric assertions for methods, paths, status codes, counters, and
latencies before the signed 16-file bundle passed independent signature,
conformance, and verified no-fallback installation.

### First publication batch

The first publication batch completed in this order:

1. Boss4Delphi `v1.6.0` as the end-to-end policy proof;
2. `horse-schema-validation` `v1.0.0`, whose 10 Delphi tests pass;
3. `horse-multipart` `v1.0.0`, whose real upload integration test passes.

For each package, repeat the same immutable sequence: sign and verify the
prepared `.b4dpkg`, upload `.b4dpkg`, `.asc`, and `.intoto.json` to that exact
GitHub release, verify all three public URLs and digest, run
`publish --official --dry-run`, then run `publish --official --open-pr`.
Never reuse one package's evidence URL for another package.

## Wave 2 — publisher-controlled packages needing a release

`horse-sanitize` `v1.0.0` has completed this wave. Its vendored 107-file Horse
copy was replaced by a Boss4D-resolved and locked dependency. Five complete
seven-test Seattle runs plus a clean post-merge run covered tags, JavaScript
URIs, event attributes, dictionaries, nested JSON, arrays, and concurrency
without leaks. The signed 13-file bundle passed independent signature,
conformance, and verified no-fallback installation.

`Dext` and `horse-crud` still need their first published tag/release. Before
Registry migration they need an exact SemVer tag, tests, immutable release
assets, and the same signed publication workflow.

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
