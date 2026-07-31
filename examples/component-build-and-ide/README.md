# Complete component example

This manifest demonstrates runtime/design packages, an application, a tool, a
prebuilt binary, IDE tools/templates, and a managed per-BDS Registry value.
Replace the placeholder paths with files from your component repository.

```console
boss4d support --compiler d13 --platform Win32 --kind design
boss4d doctor
boss4d build --compiler d13 --platform Win32 --configuration Release \
  --register --conflict fail --explain
boss4d build --compiler d13 --platform Win64 --configuration Release \
  --remote-cache X:\boss4d-cache
```

For CI:

```console
boss4d restore --ci --remote-cache X:\boss4d-cache
```

For recovery:

```console
boss4d ide repair
boss4d ide uninstall acme-controls
```

The example is parsed and expanded by the unit-test suite so its schema cannot
drift silently.
