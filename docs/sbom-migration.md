# Migrating to SBOM and `boss-lock.json` v2

Existing v1 lock files remain readable. Run `boss4d install` with the updated CLI
to resolve dependencies again and save canonical repository identities, Git
revisions, typed SHA-256 checksums, license provenance, and dependency edges in
schema v2. Commit the resulting `boss-lock.json`.

Generate a deterministic release SBOM with:

```bash
boss4d sbom --format cyclonedx --strict --validate --reproducible -o dist/sbom/boss4d.cdx.json
boss4d sbom --format spdx --strict --validate --reproducible -o dist/sbom/boss4d.spdx.json
```

Environment collectors are intentionally opt-in. Use them on a controlled build
agent when the installed GetIt inventory, Delphi compiler/RTL, or binary artifacts
declared in the lock are part of the desired scope. A collector failure is reported
as incomplete coverage; it is never converted into an empty inventory.

CycloneDX output targets 1.7 and SPDX output targets 2.3. Consumers must validate
the document against the matching version. SBOM generation provides inventory and
provenance evidence; it is not by itself a legal-compliance or vulnerability scan.
