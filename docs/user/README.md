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
| [`build-lectures`](actions/build-lectures.md) | Builds the lectures with Jupyter Book, as the website, the PDF or notebooks. When the build fails it prints each failing notebook's traceback, and can upload the execution reports. |
| [`build-jupyter-cache`](actions/build-jupyter-cache.md) | Builds the lectures from scratch in each format you list, and saves the result as the cache that pull requests and publishing start from, but only if every build passes. A failed run keeps the last good cache and files an issue. |
| [`restore-jupyter-cache`](actions/restore-jupyter-cache.md) | Restores the cache that `build-jupyter-cache` saved, so a pull request or publish build re-executes only the notebooks that changed. It only restores by default, and can also save a cache for the later runs of the same pull request. |
| [`preview-netlify`](actions/preview-netlify.md) | Deploys a pull request's built site to Netlify as a preview, at a URL that stays the same for every push, and comments on the pull request with it and with links to the lectures it changes. |
| [`preview-cloudflare`](actions/preview-cloudflare.md) | Deploys a pull request's built site to Cloudflare Pages as a preview, at a URL that stays the same for every push, and comments on the pull request with it and with links to the lectures it changes. |
| [`publish-gh-pages`](actions/publish-gh-pages.md) | Publishes a built site to GitHub Pages with GitHub's own Pages deploy, so no gh-pages branch is needed. On a tag it can also attach the site to the release, as an archive with its checksum and a manifest. |
| [`deploy-cloudflare`](actions/deploy-cloudflare.md) | Publishes a built site to an existing Cloudflare Worker behind Cloudflare Access, for a site only members may see, and fails unless the site is proven gated before and after the deploy. |

<!-- END GENERATED -->

## Other guides

- [Workflow templates](https://github.com/QuantEcon/actions/tree/main/templates): the standard CI, cache and publish workflows for a lecture repository.
- [Container guide](../CONTAINER-GUIDE.md): the two images, and moving a workflow onto them.
- [Migration guide](../MIGRATION-GUIDE.md): moving a lecture repository onto these actions.

How the project itself is designed, tested and maintained is in the [developer docs](../dev/README.md).
