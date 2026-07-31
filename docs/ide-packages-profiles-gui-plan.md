# IDE packages, isolated profiles, and GUI delivery plan

This document is the authoritative implementation and acceptance map for the
component-installation maturity goal. It records current evidence, gaps, task
order, tests, and completion gates.

## Baseline evidence

The current implementation already provides:

- declarative runtime/design projects and dependency edges in `buildMatrix`;
- `.dpk` runtime/design detection and deterministic target expansion;
- dependency-ready parallel builds and isolated target artifacts;
- exact design-package registration by compiler/platform;
- transactional Registry snapshots, artifact staging, rollback, repair, and
  dependency-safe uninstall;
- managed DLL, CHM, tools, templates, paths, and restricted Registry values;
- conflict policies and global build/registration inventories;
- a VCL GUI for project dependencies, catalog search, doctor, and cache.

The following gaps prevent the goal from being considered complete:

| Area | Current evidence | Gap to close |
|---|---|---|
| Runtime/design model | Project `kind` is a free string and graph edges exist | No first-class package role/identity, install plan, palette metadata, or complete runtime/design status |
| IDE transaction | Exact registration and rollback exist | One global Registry namespace/inventory; no profile context, operation preview, machine lock, or open-IDE policy |
| Profiles | Registry store accepts only an HKEY root | No named profile, alternate BDS Registry branch, profile inventory, migration, clone, import/export, or `/r:` launch |
| GUI architecture | One VCL form calls core services | Form parses manifest/lock JSON directly, instantiates infrastructure, changes process current directory, and has no testable presentation layer |
| GUI coverage | Project/catalog/doctor/cache tabs | No targets, packages, profiles, operation plan, install/update/repair/uninstall, drift, or structured progress screens |

## Architectural decisions

1. Business rules remain in platform-neutral domain/application services.
2. CLI, IDE wizard, and GUI consume the same application contracts.
3. A profile is part of registration identity and storage ownership.
4. The existing unqualified installation becomes the `default` profile.
5. Registry keys are produced by a validated profile context, never assembled
   by forms or command handlers.
6. Every mutating operation first creates an immutable preview plan.
7. Files, Registry values, inventories, and profile state commit or roll back
   as one operation.
8. Unit tests use stores/process/filesystem abstractions; real Registry tests
   use only a disposable HKCU subtree.
9. Versions not installed locally are modeled and unit-tested but not reported
   as certified.
10. No feature commit is accepted without its corresponding unit tests.

## Phase 1 — first-class runtime/design packages

- Introduce typed project/package roles while preserving JSON compatibility.
- Introduce package identity: owner, logical name, BPL name, role, compiler,
  platform, configuration, and profile.
- Validate runtime/design dependency direction and compatible target pairs.
- Detect duplicate BPL identities before compilation.
- Add optional palette/category and registration metadata.
- Build a deterministic component installation plan from expanded targets.
- Report package state: declared, built, installed, drifted, broken.
- Keep application/tool/binary and experimental C++Builder behavior.

Acceptance evidence:

- unit tests for detection, identity, graph, suffixes, duplicates, incompatible
  targets, migration, and deterministic plans;
- legacy manifests serialize without semantic conversion;
- existing and new examples expand through the real parser.

## Phase 2 — complete IDE installation transaction

- Add dry-run/preview for files, Registry values, conflicts, and removals.
- Add a cross-process operation lock per profile/toolchain.
- Define an open-IDE policy: fail, defer, or explicit force.
- Make install/update/reinstall idempotent.
- Include runtime artifacts and design registration in one product operation.
- Preserve shared paths and unmanaged files.
- Repair exact missing targets before Registry reconciliation.
- Support target, product, and dependency-ordered cascade removal.
- Persist operation result and actionable recovery information.

Acceptance evidence:

- fault-injection tests for every mutation boundary;
- rollback restores all prior files, values, and inventories;
- `doctor -> repair -> doctor` produces no managed drift;
- repeated install produces no additional mutation.

## Phase 3 — isolated IDE profiles

Profile fields:

- stable id, display name, and description;
- BDS/compiler version and IDE executable;
- alternate Registry branch;
- default platform/configuration;
- profile inventory and installed package set;
- creation/update timestamps and schema version.

Commands:

```console
boss4d ide profile list
boss4d ide profile create <name> --compiler <version>
boss4d ide profile show <name>
boss4d ide profile clone <source> <target>
boss4d ide profile remove <name>
boss4d ide profile export <name> --output <file>
boss4d ide profile import <file>
boss4d ide profile install <name> <package>
boss4d ide profile repair <name>
boss4d ide profile launch <name>
```

Tasks:

- create versioned profile repository and migration to `default`;
- parameterize registration keys and inventories with profile context;
- validate profile names and prevent Registry-root collisions;
- generate safe `bds.exe /r:<branch>` launch arguments;
- isolate install, repair, and uninstall by profile;
- prevent deletion while a profile is in use;
- provide deterministic clone/export/import.

Acceptance evidence:

- two profiles for one BDS version keep different package/path sets;
- mutating or removing one profile never changes the other;
- default-profile migration preserves current registrations;
- all CLI commands have parser and service tests.

## Phase 4 — shared application services

- Add query DTOs for IDEs, profiles, products, packages, targets, drift, and
  operation results.
- Add use cases for plan, install, update, repair, uninstall, profile lifecycle,
  and IDE launch.
- Add structured progress and cooperative cancellation.
- Add stable error/recovery codes.
- Replace duplicated orchestration in CLI, wizard, and GUI.
- Eliminate global-current-directory mutation from service calls.

Acceptance evidence:

- services run without VCL, ToolsAPI, or a real Registry;
- CLI and GUI adapters produce the same plan/result for the same request;
- concurrent projects do not share mutable working-directory state.

## Phase 5 — GUI

Screens:

- dashboard: detected IDEs, profiles, installed products, drift, failures;
- catalog: package/version/support/security and profile-aware install;
- component: runtime/design graph, targets, artifacts, and dependents;
- profiles: create, clone, compare, remove, import/export, launch;
- operation preview: builds, files, Registry changes, conflicts, removals;
- diagnostics: drift, cause, suggested action, scoped/full repair;
- logs: structured progress, target filters, cancellation, artifact navigation.

Rules:

- forms bind to presenters/view models only;
- no direct JSON, Registry, process, or filesystem mutation in forms;
- background work never captures unsafe form state;
- destructive operations require a preview and explicit confirmation;
- UI refreshes from authoritative services after every operation.

Acceptance evidence:

- presenter/view-model unit tests for loading, selection, filters, preview,
  progress, cancellation, success, failure, and refresh;
- Delphi 13 Win32/Win64 GUI builds;
- manual smoke test covers install, repair, uninstall, and profile launch.

## Documentation and examples

- update both READMEs, CLI manual, component lifecycle, use cases, backlog, and
  changelog in English and Portuguese;
- provide simple runtime/design, multi-package, IDE assets, two-profile, CI,
  broken-install repair, and migration examples;
- load and validate every example in automated tests;
- document limitations and support levels without claiming untested IDE
  certification.

## Validation and closure

- Delphi unit suite: Win32 and Win64;
- CLI and GUI: Delphi 13 Win32/Win64;
- IDE plugin: installed Delphi 10, 11, 12, and 13;
- disposable Registry integration: default plus two isolated profiles;
- FPC/Linux Docker suite remains green;
- documentation links and example manifests validate;
- Sonar analysis succeeds with Quality Gate `OK` and zero open issues;
- worktree is clean, every phase is committed/pushed, and the completion audit
  maps every requirement to direct evidence.

