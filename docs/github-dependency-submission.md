# GitHub Dependency Graph submission

Boss4D can submit the resolved lock graph to GitHub's Dependency Submission API:

```console
set GITHUB_TOKEN=github-token
boss4d dependency submit ^
  --repo owner/repository ^
  --sha 0123456789abcdef0123456789abcdef01234567 ^
  --ref refs/heads/main ^
  --job-id boss4d-ci
```

`--token-env` changes the environment variable name; the token is never written
to configuration or logs. The credential needs permission to write repository
contents/dependency snapshots as required by GitHub.

The snapshot uses generic Package URLs, marks root entries as direct, preserves
runtime/development scope, and includes transitive edges from lock schema v3.
Use the exact commit SHA and fully qualified Git ref for the build being
reported.
