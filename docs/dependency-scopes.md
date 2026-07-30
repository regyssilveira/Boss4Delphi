# Runtime and development dependencies

Boss4D separates shipped dependencies from development and test tools:

```json
{
  "dependencies": {"github.com/hashload/horse": "^3.1.0"},
  "devDependencies": {"github.com/example/test-kit": "1.0.0"}
}
```

Use `boss4d add <package> --dev` for a development dependency. A regular
`install` resolves both scopes. `install --production` and `ci --production`
install runtime dependencies only.

Lock schema v3 records `runtime` or `development` on each package and keeps
separate root lists. CycloneDX exports `boss4d:scope`; SPDX 2.3 exports the
scope in the package comment.
