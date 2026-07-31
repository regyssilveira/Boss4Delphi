# Isolated IDE profile walkthrough

This walkthrough uses the runtime/design manifest in
[`../component-build-and-ide`](../component-build-and-ide/).

From that example directory, detect or build the component so the product is
recorded in the global build inventory:

```console
boss4d spec --detect --compiler d13
boss4d build --compiler d13 --platform Win32 --configuration Release
```

Create a review profile:

```console
boss4d ide profile create Component-Review --compiler d13 \
  --description "Temporary component validation"
boss4d ide profile show component-review
```

Replace `<product>` with the `name` from the example `boss.json`:

```console
boss4d ide profile preview-install component-review <product>
boss4d ide profile install component-review <product> \
  --conflict fail --ide-open fail
boss4d ide profile launch component-review
```

After validation:

```console
boss4d ide profile preview-uninstall component-review <product>
boss4d ide profile uninstall component-review <product>
boss4d ide profile remove component-review
```

The profile cannot be removed while the product remains installed. This keeps
the Registry branch and ownership inventory consistent.
