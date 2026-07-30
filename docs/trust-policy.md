# Git signature trust policy

Projects can require cryptographic verification before dependency checkout:

```json
{
  "trust": {
    "requireSignedCommits": true,
    "requireSignedTags": true,
    "allowedSigners": ["release@example.com"]
  }
}
```

Boss4D runs native `git verify-commit` and `git verify-tag` against the cached
repository. When `allowedSigners` is non-empty, the signer reported by Git must
match one entry case-insensitively. A failure stops installation before checkout
and triggers the normal project rollback.

Signature validity depends on the user's Git/GPG or SSH trust configuration.
Boss4D does not download keys or silently establish trust.
