# Project templates

`boss4d new <template> <name> [--path directory]` supports:

| Template | Result |
| --- | --- |
| `app` | Delphi console application |
| `package` | Reusable Pascal unit/package skeleton |
| `vcl` | VCL forms application |
| `fmx` | FireMonkey application |
| `api`, `horse-api`, `dext-api` | Horse HTTP API with Dext included |
| `dunitx` | DUnitX runner and sample fixture |
| `lazarus-app` | Lazarus `.lpr`/`.lpi` application |
| `lazarus-package` | Lazarus `.lpk` package |
| `workspace` | `apps/*` and `packages/*` monorepo |

Every template creates a `boss.json`, refuses to overwrite a non-empty target,
and declares projects, runtime dependencies, development dependencies, or
workspace globs as applicable.
