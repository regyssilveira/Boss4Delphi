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

Index format:

```json
{
  "schemaVersion": 1,
  "packages": [{
    "name": "InternalLib",
    "repository": "git.example.com/team/internal",
    "description": "Internal Delphi library",
    "version": "2.4.0",
    "license": "MIT",
    "artifact": "https://packages.example.com/InternalLib-2.4.0.b4dpkg",
    "sha256": "..."
  }]
}
```

Additional registry sources are stored in the global Boss4D configuration. A
source failure is reported as a warning and does not hide results from other
indexes.
Unknown protocol schemas are rejected. Artifact URLs are always paired with
their immutable SHA-256 digest.
The standalone GUI catalog and RAD Studio search action use the same index
service as the CLI.
