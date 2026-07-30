# Secure self-update

`boss4d self-update` checks the latest official GitHub release and updates the
Windows installation through the published Inno Setup installer.

The command does not trust the download by location alone. It downloads
`Boss4D_Setup.exe` and `SHA256SUMS.txt`, calculates SHA-256 over the exact
installer bytes, and launches the installer only when the digest matches. A
missing asset, invalid release response, failed download, or checksum mismatch
stops the operation. A rejected installer is deleted from staging.

```text
boss4d self-update
```

If the installed semantic version is already current, no artifact is
downloaded or executed. The verified installer runs silently and without an
automatic restart. Existing Inno Setup replacement and rollback behavior
remains responsible for the transactional installation.

Only assets from the repository's official latest-release API are accepted.
This integrity check detects corruption or substitution after publication; the
release pipeline remains responsible for protecting and publishing the
checksum manifest.

## Linux

The native Linux/FPC CLI selects `boss4d-linux-x86_64.tar.gz` from the same
official release, verifies it against `SHA256SUMS.txt`, extracts into staging,
and replaces the running executable transactionally. The previous executable
is retained until the replacement succeeds and is restored on failure. The new
file is installed with executable permissions. When the latest semantic version
is already installed, no asset is downloaded.
