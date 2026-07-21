# Migrating to SBOM and `boss-lock.json` v2

Existing v1 lock files remain readable. Run `boss4d install` with the updated CLI
to resolve dependencies again and save canonical repository identities, Git
revisions, typed SHA-256 checksums, license provenance, and dependency edges in
schema v2. Commit the resulting `boss-lock.json`.

The updated v2 lock contains a `root` section with the project name, version,
license, and direct dependencies. This evidence allows `--lock-only` to operate
without `boss.json`. In strict mode, older locks without `root` are rejected with
instructions to run `boss4d install` again.

Generate a deterministic release SBOM with:

```bash
boss4d sbom --format cyclonedx --lock-only --strict --validate --reproducible \
  --output dist/sbom/boss4d.cdx.json \
  --attestation-output dist/sbom/boss4d.cdx.intoto.json
boss4d sbom --format spdx --lock-only --strict --validate --reproducible \
  --output dist/sbom/boss4d.spdx.json \
  --attestation-output dist/sbom/boss4d.spdx.intoto.json
```

`--lock-only` does not read or require `boss.json` and rejects all environmental
`--include-*` collectors. Without `--lock-only`, both project and lock files are
used and optional collectors may enrich the result.

Environment collectors are intentionally opt-in. Use them on a controlled build
agent when the installed GetIt inventory, Delphi compiler/RTL, or binary artifacts
declared in the lock are part of the desired scope. A collector failure is reported
as incomplete coverage; it is never converted into an empty inventory.

Installed GetIt packages are environmental inventory with unknown usage; they are
not root dependencies unless project usage is explicitly declared in
`sbom.components` with `"source": "getit"`. Every lock `artifacts` block may set
`"base"` to `project`, `module`, or `absolute`; omitted bases retain the compatible
`project` behavior. Traversal outside the selected base is rejected.

CycloneDX may import an offline VEX document with `--vex`. Detached attestations
created by `--attestation-output` can later be checked with
`--verify-attestation`; verification fails if the SBOM bytes changed. SPDX 2.3
does not accept `--vex` because it has no equivalent security profile.

CycloneDX output targets 1.7 and SPDX output targets 2.3. Consumers must validate
the document against the matching version. SBOM generation provides inventory and
provenance evidence; it is not by itself a legal-compliance or vulnerability scan.
See [SBOM examples](sbom-examples.md) for complete commands and JSON inputs.
