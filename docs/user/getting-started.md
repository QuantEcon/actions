# Getting started

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

A QuantEcon lecture repository runs the actions from three workflows, which start as copies of the [templates](https://github.com/QuantEcon/actions/tree/main/templates): one builds the cache, one previews each pull request, and one publishes the site. This chapter sets them up in a new repository, and moves an existing one onto them. [How the actions compose](composition.md) explains the chain the three workflows run.

## What the repository needs

- **A Jupyter Book 1 book**, by default in `lectures/`, with its `_config.yml` and `_toc.yml`.
- **`execute_notebooks: cache`** under `execute:` in `_config.yml`. The caches depend on it: with Jupyter Book's default, `auto`, there is no execution cache to save or restore.
- **An environment file.** In a QuantEcon container, only the packages the image lacks, passed as `environment-update`; on a standard runner, the whole Conda environment, as `environment`. See [Containers](containers.md).
- **For previews,** a Netlify site, a Cloudflare Pages project or a Cloudflare Worker, set up as the [`preview-netlify`](actions/preview-netlify.md#setting-up-netlify), [`preview-cloudflare`](actions/preview-cloudflare.md#setting-up-cloudflare-pages) or [`preview-workers`](actions/preview-workers.md#setting-up-a-cloudflare-worker) chapter says.
- **For publishing,** GitHub Pages, with its source set to **GitHub Actions**. A site on a Cloudflare Worker uses [`deploy-cloudflare`](actions/deploy-cloudflare.md) instead, which no template covers yet.

## Choosing the actions

| You need | Use |
|---|---|
| The cache every other build starts from | [`build-jupyter-cache`](actions/build-jupyter-cache.md), in `cache.yml` |
| A build on a pull request or for publishing | [`setup-environment`](actions/setup-environment.md), [`restore-jupyter-cache`](actions/restore-jupyter-cache.md) and [`build-lectures`](actions/build-lectures.md), in that order |
| A preview of each pull request | [`preview-netlify`](actions/preview-netlify.md), [`preview-cloudflare`](actions/preview-cloudflare.md) or [`preview-workers`](actions/preview-workers.md); [Netlify or Cloudflare?](actions/preview-netlify.md#netlify-or-cloudflare) compares the first two |
| The public site on GitHub Pages | [`publish-gh-pages`](actions/publish-gh-pages.md) |
| A site on a Cloudflare Worker, private or public | [`deploy-cloudflare`](actions/deploy-cloudflare.md) |

Where the jobs run:

- **A GitHub-hosted runner with a QuantEcon container** suits most lecture repositories, and is what the templates use. The image carries Python, the scientific stack, Jupyter Book and LaTeX, so a job starts building once the image is pulled.
- **A GitHub-hosted runner without a container** builds the Conda environment in the job, and caches it. Use it when the image's environment does not fit the lectures.
- **A self-hosted runner,** such as a GPU machine, works like a container when its machine image carries the QuantEcon marker file: see [Running on your own host](actions/setup-environment.md#running-on-your-own-host).

## The templates

| Template | Runs on | What it does |
|---|---|---|
| [`cache.yml`](https://github.com/QuantEcon/actions/blob/main/templates/cache.yml) | Weekly on Sunday, on demand, and when `environment.yml` changes on the default branch | Builds every format from scratch with `build-jupyter-cache`, and saves the cache only if every build passes. A failed run files an issue, and uploads `_build` for inspection |
| [`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) | Every pull request to the default branch | Restores the cache and builds the HTML; then deploys a preview, and checks the PDF build |
| [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) | Every push to the default branch, and on demand | Restores the cache and builds the site; then deploys it to GitHub Pages. With a tag trigger and its commented `release-assets` job, it can also attach the site to the tag's release |
| [`restore.yml`](https://github.com/QuantEcon/actions/blob/main/templates/restore.yml) | By hand, on the default branch, with a release's tag | Puts the site back as that release holds it, with no build: downloads the release's archive, checks its checksum, and deploys it to GitHub Pages. It needs the releases that `publish.yml`'s `release-assets` job makes. See [`restore-gh-pages`](actions/restore-gh-pages.md) |

`ci.yml` runs in four jobs:

| Job | What it does | What it holds |
|---|---|---|
| `placeholder` | Comments on the pull request within seconds of a push, with the preview's link and the lectures the pull request changed, before the build has finished; `deploy`'s comment replaces it | `contents: read`, `pull-requests: write`, no secrets |
| `build` | Restores the execution cache, builds the HTML, executing only the notebooks the pull request changed, and uploads the site and the execution cache as artifacts | `contents: read`, no secrets |
| `deploy` | Downloads the site and deploys it as a preview, then comments on the pull request with its link and the lectures the pull request changed | The provider's secrets, `pull-requests: write` |
| `pdf-check` | Builds the PDF from the notebooks `build` executed, and fails the pull request's checks when the LaTeX build fails | `contents: read`, no secrets |

`placeholder` starts at once: it has no checkout and no container, reads the pull request's changed files from the API, and builds the preview's URL from the site's name, which it needs in `netlify-site-name`, or in `project-name` for Cloudflare. `deploy` and `pdf-check` start together when `build` has finished, so the preview never waits for the PDF. The deploy has a job of its own so that the provider's token is never in a job that runs notebook code: see [Security](security.md#each-deploy-runs-in-a-job-of-its-own). The site artifact is kept for one day; to run `deploy` again after that, use **Re-run all jobs**, which builds and uploads the site again.

`publish.yml` is split the same way, for the same reason:

| Job | What it does | What it holds |
|---|---|---|
| `build` | Restores the execution cache, builds the site, and uploads it as the run's `github-pages` artifact, with `publish-gh-pages`' `mode: upload` | `contents: read` |
| `deploy` | Deploys that artifact to GitHub Pages with `mode: deploy`, in the `github-pages` environment. It runs nothing else: no checkout, no container | `pages: write`, `id-token: write` |
| `release-assets`, commented out | On a tag, once the deploy has succeeded, attaches the site to the tag's release with `mode: release` | `contents: write` |

To make release assets, uncomment the `release-assets` job and the build job's step that uploads the site for it, add a tag trigger, such as `tags: ['publish*']` under `on.push`, and allow that tag pattern under **Settings**, **Environments**, **github-pages**, **Deployment branches and tags**. Without that last step, the environment's protection rules reject the deploy on a tag. [Release assets](actions/publish-gh-pages.md#release-assets) describes what is attached.

The templates run in the full `quantecon` image. [Containers](containers.md) covers the lean `quantecon-build` image, and when to choose it.

## Setting up a new repository

1. **Copy the templates.** Put `cache.yml`, `ci.yml` and `publish.yml` in `.github/workflows/`, and change `source-dir`, the environment inputs and the image where the repository differs from the defaults. In `ci.yml`, set the preview site's name in the `placeholder` job's `netlify-site-name`, the `<name>` in `<name>.netlify.app`.
2. **Add the preview secrets** under **Settings**, **Secrets and variables**, **Actions**: `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID`, or for Cloudflare `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. Publishing to GitHub Pages needs no secret.
3. **Set the Pages source** under **Settings**, **Pages**, **Source**, to **GitHub Actions**.
4. **Build the first cache.** Once `cache.yml` is on the default branch, run it from the **Actions** tab, with **Run workflow**. Until it has passed once, every pull request executes every notebook.
5. **Open a pull request** to check the preview. Its comment links the preview, and the lectures the pull request changed.
6. **Merge to the default branch** to publish.

## Changing the templates

### Downloads on the site

For download links to the PDF and the notebooks on every page:

1. In `cache.yml`, set `builders: 'jupyter,pdflatex,html'`, so the cache holds all three.
2. In `publish.yml`, uncomment the `jupyter` and `pdflatex` build steps, and set `html-copy-pdf: 'true'` and `html-copy-notebooks: 'true'` on the `html` build.
3. In `ci.yml`, do the same in the `build` job, if the previews should offer downloads too.

### The PDF check

`ci.yml`'s `pdf-check` job builds the PDF on every pull request, because malformed LaTeX can pass the HTML build and still break the PDF build, and with it the publish.

- **Switching it off.** A site that publishes no PDF sets `PDF_CHECK: 'false'` in the workflow's top-level `env:` block. The job is then reported as skipped, and `build` uploads nothing for it. The switch is in the file rather than a repository variable because a run for a pull request from a fork does not receive repository variables.
- **Blocking merges.** A failed `pdf-check` turns the checks red, but blocks nothing. To make a broken PDF block a merge, make `pdf-check` a required status check, under **Settings**, **Branches**, or in a ruleset, and require `build` as well: `pdf-check` is skipped whenever `build` fails, and GitHub counts a skipped required check as passed. For the same reason, a site that requires `deploy` must require `build` too.
- **What it builds from.** `build` uploads `_build/.jupyter_cache` after the site. That cache holds every lecture's outputs, those restored from the cache build and those the pull request's build executed, so `pdf-check` builds the PDF without executing anything, needs `execute_notebooks: cache`, and runs on `ubuntu-latest` even where `build` needs a GPU. It passes `build-lectures` the same arguments as the PDF builds in `cache.yml` and `publish.yml`, so it fails where they would. On a failure it uploads the LaTeX log as the `latex-log` artifact.
- **Running it again.** The hand-off artifact is kept for one day. After that, re-running `pdf-check` alone fails at the download; use **Re-run all jobs**, which runs `build` again and uploads a fresh one.

### A standard runner

Remove the `container:` block from each job that has one, and uncomment the standard-runner `with:` block under `setup-environment`; each template's comments say where. The `deploy` jobs in `ci.yml` and `publish.yml`, and `publish.yml`'s `release-assets` job, already run without a container. A `pdflatex` build on a standard runner installs LaTeX from `latex-requirements.txt` at the repository root, and fails if the file is missing: start from the [example](https://github.com/QuantEcon/actions/blob/main/templates/latex-requirements.txt), which lists the TeX packages and tools the two images have in common.

### A custom domain

Set it under **Settings**, **Pages**, **Custom domain**. The GitHub Actions deploy that `publish.yml` uses ignores a `CNAME` file. See [Custom domain](actions/publish-gh-pages.md#custom-domain).

### Cloudflare Pages instead of Netlify

In `ci.yml`, replace the Netlify step in both the `placeholder` and the `deploy` job with the Cloudflare Pages step in the comments below it, give both the same `project-name`, and add the Cloudflare secrets.

## Migrating an existing repository

A lecture repository with its own build steps moves onto the actions one workflow at a time, cache first, because the other two restore what it saves.

1. **Get the book ready.** Set `execute_notebooks: cache` in `_config.yml`. Decide between a container and a standard runner, and split the environment file to match: see [Containers](containers.md).
2. **Add `cache.yml`** in a pull request of its own, and merge it. A workflow can be run by hand only once it is on the default branch, and a cache saved there serves every branch and pull request, while one saved on another branch serves only that branch. Run it, and check that it passes: its job summary gives each builder's result, and the cache key it saved.
3. **Replace the pull-request workflow** with `ci.yml`, in a pull request. That pull request runs the new workflow itself, so it tests the change:
   - `restore-jupyter-cache`'s status report shows a restored cache, and the build executes only the lectures the pull request changed;
   - the preview matches the published site, downloads included if the site offers them.
4. **Replace the publish workflow** with `publish.yml`. A site that publishes by pushing to a `gh-pages` branch also changes its Pages source, as [Moving from a `gh-pages` branch](actions/publish-gh-pages.md#moving-from-a-gh-pages-branch) describes, and a site that makes release assets on a tag keeps them with `publish-gh-pages`' [release assets](actions/publish-gh-pages.md#release-assets), following the comments in the template. Once it has published, check that each page's "Last changed" date is its own: `publish.yml` checks out the full history for that, where `ci.yml`'s shallow checkout dates every preview page to its commit.
5. **Watch the first runs** of each workflow: the next scheduled cache build, the next pull requests, and the next publish.

**Check what makes a build fail.** `build-lectures` and `build-jupyter-cache` pass `-W --keep-going`, in `extra-args`, and `-n`, through `nitpick: 'true'`, by default, to every build: a warning fails it, and so does a reference Sphinx cannot resolve. A repository whose workflows already pass `-n` to `jb build`, alone or as in `-nW`, keeps what it has with the defaults, and needs no `-n` in any `extra-args` it sets, since `nitpick` passes it. One whose HTML build runs without `-n` today may have references that pass it now and fail under the actions. Find them before the move with `jb build lectures -n -W --keep-going`, and fix them, or set `nitpick: 'false'` on every `build-lectures` and `build-jupyter-cache` step until they are fixed: see [Unresolved references](actions/build-lectures.md#unresolved-references).

**Drop any interim prune of the restored `_build/html`** as you replace each workflow, such as a `jb clean . --html` step after the cache restore. The templates restore only the execution cache, and `restore-jupyter-cache` removes the HTML from a restored build cache itself, so a page or file deleted from the source is not published again.

**To roll back,** revert the pull request that changed the workflow: the repository's previous workflow comes back unchanged. If the publish move changed the Pages source, set it back to **Deploy from a branch** as well, which works only while the `gh-pages` branch still exists, so keep that branch until the new publish has run for a while.
