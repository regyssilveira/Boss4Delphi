# Package indexes and discovery

Boss4D queries the official public registry by default and can merge any number
of private, HTTP, or local JSON indexes. If the public registry is temporarily
unavailable, search remains usable through the built-in offline starter catalog
and every other configured source.

```console
boss4d registry add https://packages.example.com/boss4d-index.json
boss4d registry add C:\company\boss4d-index.json
boss4d registry list
boss4d search database
boss4d info InternalLib
boss4d package versions InternalLib
boss4d package install InternalLib@^2.0.0
boss4d registry remove C:\company\boss4d-index.json
```

The official entry point uses schema v2 and is stored in Git. Version 2 can
compose catalogs with relative references, which makes it possible to maintain
package families in separate files or repositories:

```json
{
  "schemaVersion": 2,
  "includes": [
    "community/index-v1.json",
    "company/index-v2.json"
  ],
  "packages": [{
    "name": "InternalLib",
    "repository": "git.example.com/team/internal",
    "description": "Internal Delphi library",
    "license": "MIT",
    "versions": [{
      "version": "2.4.0",
      "artifact": "https://packages.example.com/InternalLib-2.4.0.b4dpkg",
      "sha256": "...",
      "signature": "https://packages.example.com/InternalLib-2.4.0.b4dpkg.asc",
      "provenance": "https://packages.example.com/InternalLib-2.4.0.b4dpkg.intoto.json",
      "variants": [{
        "platform": "Win64",
        "compiler": "37.0",
        "artifact": "https://packages.example.com/InternalLib-2.4.0-win64-d37.b4dpkg",
        "sha256": "..."
      }, {
        "platform": "Linux64",
        "artifact": "https://packages.example.com/InternalLib-2.4.0-linux64.b4dpkg",
        "sha256": "..."
      }]
    }]
  }]
}
```

References may be HTTP(S) URLs, absolute local paths, or paths relative to the
index containing them. Cycles are detected and loaded only once. Unsafe parent
traversal is rejected by the conformance validator.

Schema v1 remains fully supported. Existing indexes and the original
string-to-string `dependencies` map in `boss.json` do not require migration.
In v2, `versions` is optional, and a package may still expose the v1-compatible
top-level `version`, `artifact`, and `sha256` fields.

## Sparse metadata and revocation

Large schema-v2 registries can keep one metadata document per package. The
entry point lists those documents in `sparse`; each uses the normal schema-v2
`packages` contract:

```json
{
  "schemaVersion": 2,
  "sparse": [
    "packages/horse.json",
    {
      "path": "packages/dext.json",
      "mirrors": ["https://mirror.example/packages/dext.json"]
    }
  ],
  "revocations": [{
    "name": "InternalLib",
    "version": "2.4.0",
    "reason": "publisher request"
  }],
  "packages": []
}
```

A version may also carry `"revoked": true` and `revocationReason`. Resolution
selects the first non-revoked version. A root-level revocation overrides
included or sparse metadata, and installation refuses a revoked selected
version. Historical metadata remains available to preserve lockfile and audit
evidence.

Sparse metadata objects try `path` first and then each `mirrors` entry in the
declared order. Package versions and platform/compiler variants can likewise
declare an ordered `mirrors` array containing alternate artifact URLs. Every
candidate must match the same immutable SHA-256; a reachable but altered mirror
is rejected and resolution continues to the next source.

Artifact variants are optional and do not change `boss.json`. Select them with:

```text
boss4d package install InternalLib --platform Win64 --compiler 37.0
```

Selection is deterministic: exact platform and compiler, platform-only,
compiler-only, then a generic variant. A variant with a conflicting non-empty
selector is never chosen. When no compatible artifact exists, installation
uses the indexed Git source unless `--no-source-fallback` was supplied.

Additional registry sources are stored in the global Boss4D configuration. A
source failure is reported as a warning and does not hide results from other
indexes.
Unknown protocol schemas are rejected. Artifact URLs are always paired with
their immutable SHA-256 digest, including entries inside `versions`.
The standalone GUI catalog and RAD Studio search action use the same index
service as the CLI.

HTTP metadata is persisted after every valid response. Network or server
failures fall back to the last valid cache. The POSIX client additionally uses
`ETag` and `Last-Modified` conditional requests and supports strict
`--offline` cache-only resolution.
