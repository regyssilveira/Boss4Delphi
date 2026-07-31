# IDE installation and lifecycle use cases

RAD Studio registration is machine-wide state. Boss4D records the desired
package/compiler/platform state in `%BOSS_HOME%\ide-registrations.json` and
updates only the matching Registry keys and paths.

## 1. Install Boss4D on a workstation with multiple IDEs

**Situation:** a workstation has more than one supported RAD Studio version.

1. Close all RAD Studio processes.
2. Run `Boss4D_Setup.exe`.
3. Select only the detected IDE versions that should receive the integration.
4. Finish setup and run:

```powershell
boss4d doctor
```

**Expected result:** CLI/GUI files are installed, PATH is updated, and each
selected IDE has only its version-specific plugin registered.

**Risk controls:** do not copy one version's BPL into another BDS directory.
Delphi 10, 10.1, 11, 12, and 13 use distinct compiler/package conventions.

**Recovery:** rerun the installer and adjust the selected IDEs, or uninstall
before reinstalling. `doctor` must not report stale plugin paths.

## 2. Build and register one design package

**Situation:** a component maintainer wants the freshly built design-time
package in one IDE.

```powershell
boss4d build --compiler d13 --platform Win32 `
  --configuration Release --register --explain
```

**Expected result:** runtime dependencies build first, the design BPL comes
from the exact target output, and only Delphi 13/Win32 registration is changed.

**Risk controls:** close the target IDE before replacing a loaded BPL. Register
design-time packages for Win32 because the RAD Studio IDE process loads Win32
design packages; runtime libraries may still target Win64.

**Recovery:** if build fails, registration does not start. If registration
fails, the transaction restores previous Registry values and does not persist
a partial inventory.

## 3. Update a package already registered in the IDE

**Situation:** a new component build moves BPL/DCU/source paths.

```powershell
boss4d build --compiler d12 --platform Win32 `
  --configuration Release --force --register
boss4d doctor
```

**Expected result:** the previous registration owned by the same
package/compiler/platform is removed and replaced by the new BPL and paths.

**Risk controls:** do not manually append both old and new directories to
Library Path. Keep package identity stable when the operation is an update.

**Recovery:** run `boss4d ide repair`; if the new binary is invalid, rebuild the
previous commit and register that exact target again.

## 4. Unregister one package without affecting other IDEs

**Situation:** a design package should be removed from one Delphi version.

```powershell
boss4d ide unregister ComponentDesign370 `
  --compiler d13 --platform Win32
```

**Expected result:** only the matching BPL and paths owned by that inventory
entry are removed. Other packages, compiler versions, platforms, and user paths
remain.

**Risk controls:** provide the exact package name, compiler, and platform.
Avoid Registry-wide cleanup scripts.

**Recovery:** rebuild with `--register` to restore the exact target.

## 5. Repair Registry drift after a manual IDE change

**Situation:** someone edited Library Path or Known Packages in RAD Studio and
the Registry no longer matches Boss4D inventory.

```powershell
boss4d doctor
boss4d ide repair
boss4d doctor
```

**Expected result:** `repair` reapplies only entries whose desired state drifted
and the second diagnosis is clean.

**Risk controls:** inspect diagnostic paths before repair. Inventory is the
Boss4D source of desired state; unrelated IDE paths are preserved.

**Recovery:** unregister the affected exact entry if it should no longer be
managed, then reapply intentional manual paths.

## 6. Recover from a failed registration transaction

**Situation:** Registry access, inventory persistence, or a path mutation fails
during registration.

1. Keep the error output.
2. Run:

```powershell
boss4d doctor
boss4d ide repair
```

**Expected result:** the failed operation has already restored snapshotted
values in reverse order. Repair reconciles only previously committed inventory.

**Risk controls:** do not continue by manually writing half of the Registry
values. Verify `Known Packages`, Search Path, Browsing Path, and Debug DCU Path
as one state.

**Recovery:** correct permissions or invalid paths and repeat the original
exact `build --register`.

## 7. Install a third-party IDE plugin from a repository

**Situation:** an IDE extension is distributed as a Boss4D-compatible Git
package.

```powershell
boss4d plugin install github.com/user/my-plugin
boss4d doctor
```

**Expected result:** the repository is resolved, the plugin is compiled for the
active Delphi configuration, copied to the Boss4D plugin directory, and
registered in Known Packages.

**Risk controls:** review publisher, source revision, build scripts, and package
signature/provenance before installing code that executes inside the IDE.

**Recovery:** remove the registration and plugin files through the owning
package workflow; do not leave a Known Packages entry pointing to a missing
BPL.

## 8. Install an official GetIt package

**Situation:** the project depends on a package distributed through the
Embarcadero GetIt catalog.

```powershell
boss4d getit mode-online
boss4d getit install Jcl
boss4d doctor
```

**Expected result:** `GetItCmd.exe` from the selected Delphi installation
installs the package and the IDE configuration remains discoverable.

**Risk controls:** GetIt changes the machine environment outside the project
lock. Record the package/version in project evidence when it is a build
dependency.

**Recovery:** use the IDE/GetIt package lifecycle to remove or repair it. Do not
represent every installed GetIt package as a proven project dependency.

## 9. Put GetIt into corporate offline mode

**Situation:** policy prohibits GetIt network access.

```powershell
boss4d getit mode-offline
```

Return only when approved:

```powershell
boss4d getit mode-online
```

**Expected result:** the selected Delphi installation uses the requested GetIt
connectivity mode.

**Risk controls:** mode is machine/IDE state, not project state. Coordinate the
change on shared build machines.

**Recovery:** restore the previous mode and run `boss4d doctor` if package
operations still fail.

## Decision table

| Need | Action |
|---|---|
| Register fresh design BPL | Exact Win32 target with `--register` |
| Replace owned registration | Rebuild exact target and register again |
| Remove one registration | `ide unregister` with package/compiler/platform |
| Correct drift | `doctor`, `ide repair`, `doctor` |
| Recover failed transaction | Fix cause, repair inventory, retry exact target |
| Change GetIt connectivity | `getit mode-online` or `mode-offline` |

See [legacy Delphi compatibility](legacy-delphi.md), the
[build matrix contract](build-matrix-contract.md), and the
[complete user manual](usage.md).

