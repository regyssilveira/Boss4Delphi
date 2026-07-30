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
      "sha256": "..."
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

Additional registry sources are stored in the global Boss4D configuration. A
source failure is reported as a warning and does not hide results from other
indexes.
Unknown protocol schemas are rejected. Artifact URLs are always paired with
their immutable SHA-256 digest, including entries inside `versions`.
The standalone GUI catalog and RAD Studio search action use the same index
service as the CLI.
