# Terminal progress

Boss4D exposes installation progress as structured events so people, CI jobs
and automation can observe the same operation without parsing incidental log
messages.

## Output modes

```text
boss4d install --progress interactive
boss4d install --progress plain
boss4d install --json
boss4d install --quiet
boss4d ci --json
```

- `interactive` refreshes active operations in place when stdout is a terminal.
- `plain` writes stable, line-oriented output and is the default.
- `--json` writes one valid JSON object per event (JSON Lines).
- `--quiet` disables progress events.

Each event contains `operationId`, `package`, `phase`, `current`, `total`,
`message` and an ISO 8601 `timestamp`. A total of zero means that the amount of
work is not known yet. Phases cover resolution, download, verification,
installation, compilation, cache hits, completion and failure.

Progress output never includes repository credentials or authentication
tokens. JSON Lines is intended for CI collectors; regular diagnostic logs may
still be emitted separately.

## Compatibility

Redirected output automatically falls back to complete lines even when
`interactive` was requested. Concurrent dependency downloads share a
thread-safe reporter, preventing interleaved or malformed events.

The native Linux/FPC CLI implements the same modes for `install`, `ci`, and
`package install`. `SIGINT`/Ctrl+C requests cooperative cancellation; commands
stop at a safe operation boundary and return exit code 130.

## Stable exit codes

| Code | Meaning |
|---:|---|
| 0 | Success |
| 1 | General or environment failure |
| 2 | Invalid command, option, or usage |
| 3 | Package not found |
| 4 | Integrity, signature, provenance, or unsafe-path rejection |
| 5 | Network or offline-cache failure |
| 6 | Vulnerability audit policy violation |
| 130 | Cancelled by the user |
