# SBOM examples

These examples use the `boss4d sbom` command implemented by the native Delphi CLI.
Run commands from the project directory unless an example says otherwise.

## Prepare authoritative lock evidence

```bash
boss4d install
```

Commit the resulting `boss-lock.json`. Schema v2 stores root metadata, direct
dependencies, resolved revisions, typed checksums, licenses, and dependency edges.

## Generate a development SBOM

This mode reads both `boss.json` and `boss-lock.json`:

```bash
boss4d sbom --format cyclonedx --output bom.cdx.json --validate
boss4d sbom --format spdx --output bom.spdx.json --validate
```

Omit `--output` to write JSON to standard output. Diagnostics remain on standard
error so redirected JSON is not corrupted.

## Generate reproducible release SBOMs from the lock only

The project manifest is not required in this mode:

```bash
boss4d sbom --format cyclonedx --lock-only --strict --validate --reproducible \
  --type application --output dist/sbom/app.cdx.json \
  --attestation-output dist/sbom/app.cdx.intoto.json

boss4d sbom --format spdx --lock-only --strict --validate --reproducible \
  --type application --output dist/sbom/app.spdx.json \
  --attestation-output dist/sbom/app.spdx.intoto.json
```

`--strict` rejects incomplete root, revision, checksum, identity, or graph evidence.
`--reproducible` removes volatile identifiers/timestamps and stabilizes ordering.
The root `--type` may be `application`, `library`, or `framework`.

## Verify detached attestations

Regenerate the same reproducible document and bind it to the saved attestation:

```bash
boss4d sbom --format cyclonedx --lock-only --strict --validate --reproducible \
  --type application --output dist/sbom/app.cdx.json \
  --verify-attestation dist/sbom/app.cdx.intoto.json
```

Verification fails when the SBOM bytes differ. The current in-toto Statement v1
attestation records a SHA-256 digest; it proves content integrity, not signer
identity. It is not a digital signature or a transparency-log publication.

## Add controlled build-environment evidence

Environmental collectors cannot be combined with `--lock-only`:

```bash
boss4d sbom --format cyclonedx --strict --validate \
  --include-getit --include-toolchain --include-artifacts \
  --output build-environment.cdx.json
```

- `--include-getit` records installed packages as environment inventory with
  unknown usage. It does not make every installed package a project dependency.
- `--include-toolchain` records detected `dcc32`, `dcc64`, and Win32/Win64
  `System.dcu` files with versions and SHA-256 hashes.
- `--include-artifacts` hashes files declared by resolved dependencies in the lock.

Collectors are opt-in and may make output machine-specific. A discovery failure is
reported as incomplete coverage and is fatal under `--strict`.

## Declare GetIt usage or another manual component

Installed GetIt inventory becomes a project dependency only when usage is declared:

```json
{
  "sbom": {
    "components": [
      {
        "id": "vendor-grid",
        "name": "Vendor Grid",
        "version": "4.2",
        "type": "library",
        "source": "getit",
        "license": "Commercial"
      }
    ]
  }
}
```

For non-GetIt SDKs, omit `source` and optionally add `repository` plus a SHA-256
`hash` object. Manual declarations are identified as declarations rather than
automatically discovered evidence.

## Select the base for dependency artifacts

An installed module in `boss-lock.json` may declare:

```json
{
  "artifacts": {
    "base": "module",
    "bin": ["bin/vendor.dll"],
    "dcp": ["lib/vendor.dcp"],
    "dcu": ["lib/vendor.dcu"],
    "bpl": ["bin/vendor.bpl"]
  }
}
```

Supported bases are `project`, `module` (`modules/<dependency>`), and `absolute`.
Omitting `base` keeps backward-compatible `project` behavior. Absolute paths require
the `absolute` base; relative traversal outside the selected base is rejected.

## Import offline VEX into CycloneDX

Create `security.vex.json`:

```json
{
  "vulnerabilities": [
    {
      "id": "CVE-2099-0001",
      "component": "my-project",
      "state": "not_affected",
      "detail": "The affected code path is not included.",
      "source": "Internal security review"
    }
  ]
}
```

Then generate and attest the enriched document:

```bash
boss4d sbom --format cyclonedx --strict --validate --reproducible \
  --vex security.vex.json --output dist/sbom/app.vex.cdx.json \
  --attestation-output dist/sbom/app.vex.cdx.intoto.json
```

`component` must match a component ID or name in the generated SBOM. Supported
states are `affected`, `not_affected`, `fixed`, and `under_investigation`. VEX is
rejected with SPDX 2.3 instead of being silently discarded.

## Validate the Boss4D release matrix

On Windows with Delphi 13, Docker, Java, and GitHub CLI:

```powershell
./scripts/test-sbom-runner.ps1 -RequireDockerDaemon
./scripts/ci-verify-sbom.ps1
```

The second command compiles and tests Win32/Win64, compares reproducible outputs,
verifies attestations, and runs the official CycloneDX and SPDX validators. Local
execution on the release commit is authoritative; the GitHub Actions workflow is
optional automation of the same matrix.
