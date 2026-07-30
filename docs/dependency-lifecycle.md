# Dependency lifecycle

Boss4D provides explicit commands for changing and inspecting a project's
dependency graph:

```console
boss4d add github.com/hashload/horse@^3.1.0
boss4d update horse
boss4d update github.com/hashload/horse@^3.2.0
boss4d list
boss4d why horse
boss4d remove horse
```

## Transaction guarantees

Commands that install, update, or remove packages snapshot `boss.json`,
`boss-lock.json`, and `modules/` before changing the project. If resolution,
checkout, integrity verification, or compilation fails, Boss4D restores the
previous files and installed modules. A successful operation commits all three
parts together.

`remove` also prunes transitive lock entries that are no longer reachable from a
direct dependency and deletes their module directories. Shared transitive
packages remain locked while at least one direct dependency still reaches them.

## Inspection

`list` reports the resolved version and identifies every entry as `direct` or
`transitive`. `why <dependency>` returns the shortest path from a direct
dependency to the requested package. Both commands read the resolved lock graph
and do not mutate the project.

`install <dependency>` remains compatible and has the same transaction
guarantees as `add`.
