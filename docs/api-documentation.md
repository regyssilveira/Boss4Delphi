# Static API documentation

`boss4d doc` turns Pascal source comments into a local, searchable API site.
It is useful when a project consumes several libraries and developers need one
reference that covers both application code and installed dependencies.

## Why generate documentation from the dependency tree?

API documentation is often scattered across repositories, tied to a website
version that differs from the lock file, or unavailable in an offline build
environment. Boss4D generates the reference from the exact sources present in
the workspace. The result can therefore be archived with a build, inspected
offline, or published by CI.

This feature complements SBOM and audit evidence. An SBOM identifies what is in
a release; API documentation explains the documented programming surface
available to its developers. It is not a replacement for an SBOM, VEX, license
report, or vulnerability audit.

## Supported comments and declarations

Boss4D reads Delphi/FPC `.pas` and `.pp` files and associates a documentation
comment with the next supported declaration:

- XML-style `///` comments, including `<summary>` text;
- PascalDoc `{** ... }` blocks;
- units, programs, libraries, and packages;
- classes, records, interfaces, and objects;
- procedures, functions, constructors, destructors, and operators;
- properties.

HTML tags in comments are removed and all generated metadata is HTML-escaped.
Documentation text is never inserted as executable markup.

## Generate the site

Run the command from the project root:

```console
boss4d doc
```

The default output is `docs-api/`:

```text
docs-api/
├── index.html
└── search-index.json
```

Open `index.html` directly in a browser. The page requires no server and
filters symbols by name, kind, source path, or summary.

Choose another output directory with either option form:

```console
boss4d doc --output artifacts/api
boss4d doc -o artifacts/api
```

By default, sources under `modules/` are included. To document only the current
project:

```console
boss4d doc --no-dependencies
```

The command is available in the native Delphi/Windows and FPC/Linux CLIs.

## Everyday workflows

### Review the API available to the locked application

```console
boss4d ci
boss4d doc --output artifacts/api
```

Restoring first ensures that the generated site describes the same dependency
sources used by the reproducible build.

### Publish documentation from CI

```console
boss4d ci
boss4d doc --output public/api
```

Publish `public/api` as a static artifact or site. Both files are deterministic
for the same documented source tree and traversal order.

### Consume the machine-readable index

`search-index.json` contains `schemaVersion`, `symbolCount`, and a `symbols`
array. CI or another tool can consume it without parsing HTML. Boss4D currently
indexes documented symbols; it does not yet report undocumented declarations
as a coverage metric.

## Scanning and safety rules

The generator scans recursively but excludes:

- the selected output directory;
- `.git`, `.codex-build`, and `.ci-build`;
- Delphi `__history` and `__recovery` directories;
- `modules/` when `--no-dependencies` is selected.

Documentation tags are stripped and values are HTML-escaped. The generator
does not execute source code or documentation supplied by packages.

## Current limits

- parsing is declaration-oriented, not a full Pascal compiler;
- only comments immediately associated with supported declarations are indexed;
- cross-references, visibility, overload signatures, and diagrams are not yet
  modeled;
- generated files should normally be treated as build artifacts.

See the [complete CLI manual](usage.md) and [FPC/Linux CLI](posix-cli.md).
