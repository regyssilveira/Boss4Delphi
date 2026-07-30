# Build matrix contract

This document records the compatibility decisions that guide the Boss4D
evolution toward building and installing components across multiple Delphi
versions. It defines the contract; the declarative matrix syntax will be
documented when it is implemented.

## Initial scope

The first advanced matrix covers:

- Delphi 10.1 (`BDS 18.0`), Delphi 11 (`BDS 22.0`), Delphi 12 (`BDS 23.0`),
  and Delphi 13 (`BDS 37.0`);
- `Win32` and `Win64`;
- `Debug` and `Release`;
- runtime and design-time packages;
- selection of one target, multiple targets, or the complete matrix.

Existing Lazarus support remains valid, but an advanced Lazarus matrix is not
part of this first stage.

## `boss.json` compatibility

Existing formats remain valid without migration:

- `projects` continues to accept a list of strings;
- `scripts`, `dependencies`, and `devDependencies` remain `string: string`
  maps;
- `engines.compiler`, `engines.platforms`, and `toolchain` keep their current
  meaning;
- without a declared matrix, Boss4D keeps the current precedence: CLI
  argument, `toolchain`, `engines`, then the `Win32` default;
- saving a legacy manifest never silently converts strings into objects.

The matrix will be additive. New fields must not change the parsing,
serialization, or effective result of a legacy manifest.

## Target identity

A build target is identified by:

`package + project + compiler + platform + configuration`

This identity will drive output directories, fingerprints, cache, diagnostics,
and IDE registration. Artifacts produced by different compilers, platforms, or
configurations must never share the same final directory.

## Expected precedence

Once the matrix is available, selection follows this order:

1. explicit CLI filters;
2. project-declared targets;
3. matrix defaults;
4. the legacy `toolchain` and `engines` contract;
5. compatible Boss4D defaults.

An empty or incompatible selection must fail with an actionable message before
performing a partial installation.

## Acceptance criteria

Every contract increment requires:

- unit tests for new behavior and legacy regression;
- deterministic errors for invalid combinations;
- deterministic serialization;
- no artifact collision across targets;
- real builds proportional to the change on installed Delphi versions;
- Portuguese and English documentation updates;
- a passing Sonar quality gate before closing the release.
