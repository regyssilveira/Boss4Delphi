# Resolution policy and secure credentials

Installations can explicitly select how a compatible SemVer range is resolved:

```text
boss4d install --resolution highest
boss4d install --resolution minimal
```

`highest` is the default and selects the greatest compatible stable/pre-release
according to SemVer ordering. `minimal` selects the lowest compatible version,
independently of the order returned by Git. Invalid and out-of-range tags are
ignored. The selected revision is still recorded in the lock.

Authentication tokens configured with `boss4d config auth` are stored in
Windows Credential Manager under `Boss4D/github` and `Boss4D/gitlab`.
`boss.cfg.json` contains only non-secret settings. The credential-store contract
is portable so Linux hosts can use Secret Service or another native vault
without changing configuration or Git services.

The native Linux/FPC CLI uses freedesktop Secret Service through `secret-tool`.
Tokens are sent to the vault through stdin and never stored in
`boss.cfg.json`. `BOSS4D_GITHUB_TOKEN`, `GITHUB_TOKEN`,
`BOSS4D_GITLAB_TOKEN`, and `GITLAB_TOKEN` take precedence for ephemeral CI
credentials. Git authentication is passed through process environment
configuration instead of embedding the token in repository URLs.

Secrets are injected only while preparing authenticated Git URLs and are
masked from failure output. Never commit exported credential data or pass
tokens directly as command arguments in CI; prefer the platform vault or
short-lived environment credentials.
