# IDE component management and isolated profiles

Boss4D treats a Delphi component as a product rather than as a single BPL.
A product can contain runtime packages, design-time packages, applications,
tools, templates, help files, DLLs, and managed Registry values. The same
model is used by the CLI and the standalone GUI.

## Why profiles exist

RAD Studio normally reads its configuration from
`HKCU\Software\Embarcadero\BDS\<version>`. Installing every component into
that branch makes experiments, CI validation, upgrades, and recovery affect
the developer's main IDE.

A named Boss4D profile has:

- one Delphi compiler/BDS version;
- one executable;
- a Registry branch such as `Boss4D-team-a`;
- a private registration inventory;
- a default platform and configuration;
- the list of component products installed in that profile.

Boss4D starts a named profile with `bds.exe /r:<branch>`. The `default`
profile intentionally uses the standard `BDS` branch. Existing Boss4D
registration inventory is copied to the default profile once and is never
overwritten afterward.

## Runtime and design-time packages

Declare project roles in `buildMatrix.projects`:

```json
{
  "buildMatrix": {
    "compilers": ["37.0"],
    "platforms": ["Win32"],
    "configurations": ["Release"],
    "projects": [
      {
        "path": "packages/AcmeRuntime.dproj",
        "kind": "runtime"
      },
      {
        "path": "packages/AcmeDesign.dproj",
        "kind": "design",
        "dependsOn": ["packages/AcmeRuntime.dproj"]
      }
    ]
  }
}
```

Runtime packages are built before their design-time consumers. A runtime
package cannot depend on a design package. Only design-time BPLs are written
to `Known Packages`; runtime BPLs and DLLs are made available through the
managed runtime/search paths.

## Safe operation lifecycle

An install follows these steps:

1. validate the complete target and file plan;
2. acquire the profile/toolchain cross-process lock;
3. apply the selected open-IDE policy;
4. build or restore compatible runtime/design targets;
5. stage files and Registry changes;
6. commit the registration batch atomically;
7. persist the profile inventory and operation journal.

On failure, Boss4D restores files, Registry values, and inventories. Preview
commands never mutate the IDE. Removal uses the persisted ownership inventory,
preserves shared artifacts, and refuses unsafe cascades. A profile containing
installed products cannot be deleted; uninstall them first.

The latest operation and its recovery instruction are stored under
`%BOSS_HOME%\ide-operation-results`.

## CLI workflow

Create and inspect profiles:

```console
boss4d ide profile list
boss4d ide profile create Team-A --compiler 37.0 \
  --description "Isolated component set" \
  --executable "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\bds.exe"
boss4d ide profile show team-a
boss4d ide profile target team-a --platform Win64 --configuration Debug
boss4d ide profile clone team-a Team-A-Review
boss4d ide profile export team-a --output team-a.json
boss4d ide profile import team-a.json
boss4d ide profile snapshot team-a --output team-a.snapshot.json
boss4d ide profile diff team-a team-a.snapshot.json
boss4d ide profile restore team-a.snapshot.json
boss4d ide profile undo
boss4d ide profile history
```

A profile export contains its portable declaration. A snapshot additionally
captures the exact package list and registration inventory, protects the
inventory with SHA-256, detects drift, and restores the captured state with an
atomic file replacement. On another machine, the inventory path is rebased
under that machine's Boss4D profile directory.

Before a successful install or uninstall, Boss4D automatically creates a
snapshot and records it in the operation journal. `profile undo` reverses the
latest successful install or uninstall: removed products are rebuilt and
registered again, while newly installed products are removed before the
previous inventory is restored.

`profile history` lists every immutable journal entry with timestamp, status,
operation, profile, and target. The GUI exposes the same list through
**History** and keeps `latest.json` only as a convenience pointer. The visual
timeline shows newest entries first, indicates whether undo data is available,
and exposes completed actions, errors, and recovery instructions in a detail
panel.

Projects can bind themselves to a profile in `boss.json`:

```json
{
  "ideProfile": "team-a"
}
```

Run `boss4d ide profile project` from the project directory to resolve the
binding. Boss4D rejects a profile whose Delphi compiler differs from the
compiler requested by the project, preventing an accidental build or install
against another IDE environment.

Preview and perform component operations:

```console
boss4d ide profile preview-install team-a acme-controls
boss4d ide profile install team-a acme-controls \
  --conflict fail --ide-open fail
boss4d ide profile repair team-a
boss4d ide profile preview-uninstall team-a acme-controls
boss4d ide profile uninstall team-a acme-controls
boss4d ide profile launch team-a
boss4d ide profile remove team-a
```

Conflict policies:

- `fail`: stop before overwriting an unmanaged or conflicting entry;
- `warn`: preserve the conflict and report it;
- `adopt`: start managing an equivalent existing entry;
- `replace`: replace the entry transactionally.

Open-IDE policies:

- `fail`: require the target IDE to be closed;
- `defer`: record that the operation must be retried later;
- `force`: continue only when the operator explicitly accepts the risk.

## GUI workflow

Open `Boss4D.GUI.exe` and select **Components and IDEs**:

1. open **Dashboard** to review every profile, its live drift state, installed
   products, compiler/target, and Registry branch;
2. select two dashboard rows to compare exclusive and shared products, or
   select one and use **Open IDE** to launch its isolated branch;
3. create, clone, select, remove, or launch a profile;
4. choose its default platform and configuration;
5. select a product from the global build inventory;
6. use **Preview install** for a quick target inspection, or press
   **Install** to open the complete guided workflow;
7. in the guided workflow, explicitly confirm the isolated profile, package,
   conflict policy, and open-IDE policy. Review the compiler, Registry branch,
   exact runtime/design targets, transactional snapshot, registration, and
   inventory changes before pressing **Install**;
8. use **Repair** to reconcile drift;
9. use **Undo** or open the structured **History** timeline to recover or audit
   completed operations;
10. inspect **Preview remove**, then remove the managed product.

The package grid distinguishes products available in the build inventory from
products installed in the selected profile. The target list provides a quick
preview; the guided installation is the authoritative confirmation surface and
shows the exact request that will be sent to the shared transactional service.
Changing the profile inside the dialog reloads its available products and
recalculates the target/change preview.

After confirmation, compilation runs outside the visual thread. The operation
bar advances with the real completed/total target count and identifies the
current runtime/design target. Started, built, cache-restored, unchanged, and
failed states are written immediately to the structured log. Cancellation is
propagated to the build scheduler, and failed or cancelled component requests
remain available through **Retry**.

## Everyday profile patterns

### Keep the daily IDE stable

Use the default profile only for approved components. Clone a named review
profile, install candidate versions there, launch it with its isolated branch,
and delete it after all products have been uninstalled.

### Maintain Win32 and Win64 build sets

Create two profiles for the same compiler and choose a different default target
for each. Preview verifies that each component actually declares the requested
target before compilation begins.

### Recover after manual IDE changes

Close the IDE and run `repair`. Boss4D compares the Registry and managed
artifacts with the profile inventory, restores recoverable entries, and writes
an operation journal. If repair reports missing source artifacts, rebuild the
product and repeat the install.

The GUI Health Center also lists every drift identity separately. Selecting
one enables **Re-register target**, which repairs only that inventory identity,
leaves healthy registrations untouched, and records a transactional
`registration-repair` operation. A healthy project/build row enables
**Full rebuild**, with cancellation and live target progress.

### Validate in CI without an old IDE

Use support/matrix tests and compiler mocks for toolchains that are not
installed. Certify installed IDEs with real builds. Registry writes remain
Windows-only; FPC/Linux builds validate portable package and dependency
contracts without pretending to install into RAD Studio.

## Troubleshooting

- **Package not listed:** run a component build/install first so it appears in
  the global build inventory.
- **No compatible target:** compare the profile compiler/platform/configuration
  with the product's `buildMatrix`.
- **IDE is open:** close the matching `bds.exe`, or deliberately select
  `defer`/`force`.
- **Profile cannot be deleted:** uninstall every product shown as installed.
- **Registry conflict:** use preview, identify the owner, and select `adopt` or
  `replace` only after confirming the existing entry is safe to manage.

See also the [component build lifecycle](component-build-and-ide.md), the
[build matrix contract](build-matrix-contract.md), and the
[IDE use cases](use-cases-ide.md).
