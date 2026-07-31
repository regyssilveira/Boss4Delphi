# Registry v2 package metadata

This directory contains one immutable schema-v2 metadata document per package.
It intentionally starts without third-party releases: maintainers must opt in,
register their identity and signer, and submit verifiable `.b4dpkg` evidence.

Use lowercase normalized filenames, for example `my-package.json`. Start from
[`../package-template.json`](../package-template.json), add the relative path to
`sparse` in [`../index-v2.json`](../index-v2.json), and follow the
[publisher onboarding guide](../../docs/publisher-onboarding.md).

References in the legacy v1 catalog are discovery links and do not imply that
their maintainers published or signed a v2 release.
