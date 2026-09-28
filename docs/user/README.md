# QuantEcon Actions user manual

How to use the QuantEcon composite actions: what each one does, how to set it up, and every input and output.

The actions are built for QuantEcon's lecture repositories, and are on 0.x, where a minor release can change what an action does. Using them elsewhere is fine, but unsupported.

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

## Actions

A workflow step uses an action as `quantecon/actions/<action>@v0`.

<!-- BEGIN GENERATED: actions. scripts/generate-docs.py writes this from each action.yml: edit that, not this. -->

| Action | What it does |
|---|---|
| [`setup-environment`](actions/setup-environment.md) | Sets up the Python environment for a lecture build. Inside a QuantEcon container it uses the image's environment, adding any extra packages you list; on a standard runner it builds a cached Conda environment and can install LaTeX. |
| [`build-lectures`](https://github.com/QuantEcon/actions/tree/main/build-lectures) | Builds QuantEcon lectures using Jupyter Book |
| [`build-jupyter-cache`](https://github.com/QuantEcon/actions/tree/main/build-jupyter-cache) | Fresh build of all lecture formats and save to GitHub cache (runs on main branch, typically weekly) |
| [`restore-jupyter-cache`](https://github.com/QuantEcon/actions/tree/main/restore-jupyter-cache) | Restores Jupyter Book build cache from GitHub Actions cache, with optional save for PR-scoped caching |
| [`preview-netlify`](https://github.com/QuantEcon/actions/tree/main/preview-netlify) | Deploys lecture builds to Netlify for PR previews with smart comments showing changed pages |
| [`preview-cloudflare`](https://github.com/QuantEcon/actions/tree/main/preview-cloudflare) | Deploys lecture builds to Cloudflare Pages for PR previews with smart comments showing changed pages |
| [`publish-gh-pages`](https://github.com/QuantEcon/actions/tree/main/publish-gh-pages) | Publishes lecture builds to GitHub Pages using native GitHub Pages deployment (no gh-pages branch needed) |
| [`deploy-cloudflare`](https://github.com/QuantEcon/actions/tree/main/deploy-cloudflare) | Publishes a built site to an existing Cloudflare Worker behind Cloudflare Access, and fails unless the site is proven gated before and after the deploy |

<!-- END GENERATED -->

## Other guides

- [Workflow templates](https://github.com/QuantEcon/actions/tree/main/templates): the standard CI, cache and publish workflows for a lecture repository.
- [Container guide](../CONTAINER-GUIDE.md): the two images, and moving a workflow onto them.
- [Migration guide](../MIGRATION-GUIDE.md): moving a lecture repository onto these actions.

How the project itself is designed, tested and maintained is in the [developer docs](../dev/README.md).
