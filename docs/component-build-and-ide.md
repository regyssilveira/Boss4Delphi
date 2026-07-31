# Component build and IDE lifecycle

Boss4D can build, cache, install, repair, and remove a component across several
RAD Studio targets without sharing incompatible DCUs or packages. The manifest
is the desired state; the build and IDE inventories record what was actually
produced and installed.

## Why this exists

A Delphi component is more than a source checkout. It can contain runtime and
design-time packages, applications, helper tools, prebuilt binaries, templates,
help, DLLs, and IDE settings. Each artifact belongs to an exact compiler,
platform, and configuration. Copying one BPL into several IDEs or growing a
global Library Path makes upgrades and removal unsafe.

Boss4D therefore:

- isolates outputs by package/compiler/platform/configuration;
- builds dependencies before consumers and runs independent targets in parallel;
- skips valid targets and rebuilds source, dependency, or missing-output changes;
- validates local and shared cache entries with SHA-256 before restoration;
- registers only the design package produced for the selected IDE target;
- records ownership so repair and uninstall do not remove unrelated user state;
- rolls files and Registry values back if an IDE transaction fails.

## Support levels

Not every modeled RAD Studio version must be installed on one workstation.
Query the public capability model before declaring a matrix:

```console
boss4d support
boss4d support --compiler d13 --platform Win64 --kind application
boss4d support --compiler d10 --platform Win32 --kind design
boss4d support --compiler d13 --platform Win64 --kind application \
  --project packages/client.cbproj
```

The levels mean:

| Level | Meaning |
|---|---|
| `certified` | The combination is covered by the project's real compiler validation matrix. |
| `compatible` | The compiler/platform contract is supported and unit-tested, but is not in the current certification matrix. |
| `experimental` | The route exists and is tested structurally, but needs broader real-project validation. |
| `unsupported` | The toolchain cannot produce the requested combination; the reason is printed. |

The modeled compiler catalog spans Delphi XE through Delphi 13. Platforms are
Win32, Win64, Linux64, macOS, iOS, and Android according to the availability of
each RAD Studio generation. A machine without an old IDE can still validate
the manifest and commands; it must not describe that local result as a real
compiler certification.

## Declarative package

```json
{
  "name": "acme-controls",
  "version": "2.0.0",
  "buildMatrix": {
    "compilers": ["17.0", "22.0", "37.0"],
    "platforms": ["Win32", "Win64"],
    "configurations": ["Debug", "Release"],
    "defaults": {
      "compiler": "37.0",
      "platform": "Win64",
      "configuration": "Release"
    },
    "projects": [
      {"path": "packages/AcmeRuntime.dproj", "kind": "runtime"},
      {
        "path": "packages/AcmeDesign.dproj",
        "kind": "design",
        "dependsOn": ["packages/AcmeRuntime.dproj"],
        "platforms": ["Win32"],
        "configurations": ["Release"]
      },
      {"path": "tools/AcmeDesigner.dproj", "kind": "tool"},
      {"path": "samples/AcmeDemo.dproj", "kind": "application"},
      {"path": "vendor/acme-driver.dll", "kind": "binary"}
    ]
  },
  "ideAssets": {
    "tools": ["ide/tools/acme-wizard.exe"],
    "templates": ["ide/templates/acme-component.zip"],
    "registry": [
      {
        "key": "Software\\Embarcadero\\BDS\\{compiler}\\Acme",
        "name": "TemplatePath",
        "value": "{templates}"
      }
    ]
  }
}
```

Project kinds are `runtime`, `design`, `application`, `tool`, and `binary`.
Delphi `.dproj` and C++Builder `.cbproj` projects use MSBuild. C++Builder is
currently experimental and limited to Win32/Win64. A `binary` entry is copied
to the isolated `bin` output without invoking a compiler.

IDE asset paths must remain inside the package. Registry declarations are
restricted to the current user's matching BDS subtree. Values can use
`{compiler}`, `{platform}`, `{root}`, `{bpl}`, `{tools}`, and `{templates}`.

## Daily workflows

Detect and review a matrix:

```console
boss4d spec --detect
git diff -- boss.json
boss4d doctor
```

Build one development target:

```console
boss4d build --compiler d13 --platform Win64 \
  --configuration Debug --explain
```

Build all compatible installed IDEs:

```console
boss4d build --all-installed --configuration Release
```

Build affected consumers with parallelism and a shared cache:

```console
boss4d build --affected --with-dependents --jobs 4 \
  --remote-cache X:\boss4d-cache --explain
```

For isolated CI, no IDE state is changed:

```console
boss4d restore --ci --remote-cache X:\boss4d-cache
boss4d install --build-only --locked --remote-cache X:\boss4d-cache
```

CI mode always uses the lock, starts from clean modules, and disables IDE
registration even if a caller supplied conflicting installation options.

## Install, conflicts, repair, and removal

Register exact design targets:

```console
boss4d build --compiler d13 --platform Win32 \
  --configuration Release --register --conflict fail
```

Conflict policies are explicit:

- `fail`: stop before replacing an unmanaged package;
- `warn`: keep going and report the collision;
- `adopt`: record the existing package as managed without replacing its BPL;
- `replace`: transactionally replace it with the built artifact.

Use `fail` in unattended automation. Use `adopt` or `replace` only after
verifying ownership and binary compatibility.

Repair verifies Registry state and managed artifacts. If an artifact is
missing, Boss4D rebuilds its exact compiler/platform/configuration target before
reapplying registration:

```console
boss4d doctor
boss4d ide repair
boss4d doctor
```

Remove one exact target or a complete product:

```console
boss4d ide unregister AcmeDesign370 --compiler d13 --platform Win32
boss4d ide uninstall acme-controls
boss4d ide uninstall acme-controls --cascade
```

Normal uninstall refuses to remove a package with installed consumers.
`--cascade` removes the transitive consumer closure in reverse dependency
order. `--force` bypasses that protection for the selected product and should
be reserved for recovery.

## Files and recovery

- target outputs: `modules/artifacts/<package>/<compiler>/<platform>/<configuration>/`;
- incremental state: the target's `.boss4d-state/`;
- global dependency/build inventory: `%BOSS_HOME%/build-inventory.json`;
- desired IDE state: `%BOSS_HOME%/ide-registrations.json`.

Do not hand-copy BPLs or erase all cache data to fix one target. Run
`build --explain`, remove only the affected target when necessary, and use
`ide repair` to reconcile committed inventory. DLLs, CHM help, tools, templates,
custom managed values, Library Paths, and user `PATH` entries participate in
ownership, rollback, repair, and uninstall.

See the [build matrix contract](build-matrix-contract.md), the
[IDE use cases](use-cases-ide.md), and the
[copyable component example](../examples/component-build-and-ide/README.md).
