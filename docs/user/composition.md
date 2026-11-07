# How the actions compose

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

The actions are steps in one chain. A cache build on the default branch executes every lecture and saves the result. Every other build restores that result, so it executes only the lectures that changed. Then one action delivers the site. Executing notebooks is where most of a lecture build's time goes, so the cache is what keeps pull-request and publish builds short.

## The chain

1. **Cache build.** [`build-jupyter-cache`](actions/build-jupyter-cache.md) runs on the default branch: weekly, on demand, and when the environment file changes. It builds every format you list from scratch, and saves two caches, but only if every build passes. A failed run keeps the last good cache and files an issue. It runs `setup-environment` and `build-lectures` itself, so its job needs nothing else.
2. **Environment.** In every other job that builds, [`setup-environment`](actions/setup-environment.md) comes first. In a QuantEcon container it uses the image's environment, adding any packages you list. On a standard runner it builds a cached Conda environment, and installs LaTeX if you ask it to.
3. **Restore.** [`restore-jupyter-cache`](actions/restore-jupyter-cache.md) restores the cache build's `_build` directory, before the build.
4. **Build.** [`build-lectures`](actions/build-lectures.md) builds one format per step. Jupyter Book re-executes only the notebooks whose code has changed since the cache build.
5. **Delivery.** One of:
   - [`preview-netlify`](actions/preview-netlify.md) or [`preview-cloudflare`](actions/preview-cloudflare.md): a preview of a pull request, linked from a comment on it, which the same action can also post before the build, with `placeholder`;
   - [`publish-gh-pages`](actions/publish-gh-pages.md): the site on GitHub Pages, with the release assets on a tag;
   - [`deploy-cloudflare`](actions/deploy-cloudflare.md): the site on a Cloudflare Worker, private behind Cloudflare Access or public.

[Getting started](getting-started.md) shows how the templates lay these steps out in workflows and jobs.

## What passes between them

| From | To | What | How |
|---|---|---|---|
| `build-jupyter-cache` | `restore-jupyter-cache` | The whole `_build` directory (the build cache), and `_build/.jupyter_cache` alone (the execution cache) | GitHub Actions caches. Each key starts with a hash of what the cache depends on and ends with the saving run's id; a restore takes the newest cache whose key starts with the same hash |
| `setup-environment` | `build-lectures` | The Python environment | The job itself: the container's environment, or on a standard runner the Conda environment, which `build-lectures` activates in a login shell |
| `build-lectures`, `jupyter` and `pdflatex` | `build-lectures`, `html` | The notebooks and the PDF, for download from the site | `_build/jupyter` and `_build/latex`, in the same job. The `html` step copies them in with `html-copy-notebooks` and `html-copy-pdf` |
| `build-lectures`, `html` | The delivery action | The site | Its `build-path` output, such as `./_build/html`, given as the delivery action's `build-dir`. When the delivery runs in a job of its own, as both templates' deploys do, the build job uploads that directory as an artifact for it: for a preview, an artifact the deploy job downloads; for GitHub Pages, the Pages artifact that `publish-gh-pages`' `mode: upload` makes and `mode: deploy` deploys |

Three settings have to agree across the chain:

- **`execute_notebooks: cache`** under `execute:` in the book's `_config.yml`. Without it Jupyter Book executes the notebooks without jupyter-cache, and there is no execution cache to save or restore.
- **The environment files.** Both caches' keys hash `environment` and `environment-update`, so give `restore-jupyter-cache` the same files as `build-jupyter-cache`. A different `environment` file restores nothing, on purpose: the old outputs were made with other packages.
- **`source-dir`.** The execution cache's key hashes the lectures under it, and every action that builds needs the same book.

## Formats

`build-lectures` builds one format per step, and the `html` build comes last, because it copies in the notebooks and the PDF that the earlier steps wrote. `build-jupyter-cache` runs its builders in the same order, `jupyter`, then `pdflatex`, then `html`, whatever order `builders` lists them in.

A pull-request preview usually builds only `html`. A publish build builds what the site offers for download, from the same restored cache.

## When a step fails

- **The cache build.** Nothing is saved, so every build carries on from the last good cache, and an issue is filed. See [`build-jupyter-cache`](actions/build-jupyter-cache.md#when-a-build-fails).
- **No cache to restore.** The build executes every notebook, which is slow but correct. With `fail-on-miss: 'true'`, `restore-jupyter-cache` fails the job instead.
- **A build.** `build-lectures` fails its step when `jb build` fails, and, with its default `error-outputs: fail`, when an executed notebook holds a traceback that `-W` let through. The job's later steps, the delivery among them, then do not run. Its log shows each failed notebook's traceback, and with `upload-failure-reports: 'true'` it uploads the execution reports.
- **The delivery.** Each delivery action fails its job when the deploy fails. The preview actions pass, deploying nothing, when a run cannot or should not deploy, such as a pull request from a fork, and their `deployed` output says which happened.

## In a container, or not

The chain is the same either way. `setup-environment` detects a QuantEcon image and adds only what the image lacks; on a standard runner it builds the whole environment. [Containers](containers.md) covers which image to use.
