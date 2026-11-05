# Security policy

## Reporting a vulnerability

Report it privately: on this repository's **Security** tab, choose **Report a vulnerability**, or go straight to [the form](https://github.com/QuantEcon/actions/security/advisories/new). Do not open a public issue, pull request or discussion about it.

Say which action, template or image it affects, the release or commit (or the image's digest) you found it in, and how it can be exploited. A suggested fix is welcome in the report.

## Scope

- **The composite actions** in this repository, as released under the `v0` and `v0.x.y` tags.
- **The workflow templates** in [`templates/`](templates/).
- **The container images** built from [`containers/`](containers/): `ghcr.io/quantecon/quantecon` and `ghcr.io/quantecon/quantecon-build`.

A vulnerability in a tool these use, such as Jupyter Book, a deploy CLI or an Ubuntu package, belongs with that tool's own project. Report it here as well when the way this repository uses or pins the tool is what exposes it.

Fixes land on `main` and ship in the next release. A workflow on `@v0` gets a fix when `v0` moves to that release; one pinned to an exact release, when the pin is moved. How each job of the templates is kept away from secrets is in the user manual's [Security](docs/user/security.md) chapter.
