# deploy-release

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

A reusable workflow that deploys one of the repository's releases to GitHub Pages: the site [`publish-gh-pages`](../actions/publish-gh-pages.md) attached to it as an archive, a checksum and a manifest. It runs in two jobs, and a third for a series that serves its notebooks from a companion repository:

- **`upload`** restores the release's site with [`restore-gh-pages`](../actions/restore-gh-pages.md), which checks the archive's SHA-256 before extracting it, and uploads it with `publish-gh-pages`' `mode: upload`. It has read access alone.
- **`deploy`** deploys that upload with `publish-gh-pages`' `mode: deploy`, in the `github-pages` environment, and does nothing else. If the deploy fails, **Re-run failed jobs** re-runs this job alone, and it finds the one upload, which is kept for a day; after that, dispatch the tag again.
- **`notebooks`**, only with `notebooks-repository`, after the deploy: restores the release again and makes the companion repository hold exactly the site's notebooks and a README it writes, pushing with the `notebooks-token` secret, which no other job receives. See [The notebooks](#the-notebooks).

None of them runs repository or notebook code. A repository calls it from a short workflow of its own, [`deploy-release.yml`](https://github.com/QuantEcon/actions/blob/main/templates/deploy-release.yml), which runs it in two cases:

- **A release is published** for a tag that starts with `publish-`: that release is deployed. A release for any other tag deploys nothing.
- **A dispatch names a tag:** that tag's release is deployed. Deploying an earlier release this way is the rollback, and every past publish is a point to roll back to.

## When to use it

Use it when the site is built somewhere else and reaches the repository as a release: once QuantEcon's lecture monorepo, QuantEcon/lectures, builds a lecture series, it creates the series repository's release with the built site, and this workflow serves it.

- **Not for a repository that builds its own site.** That one publishes with [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) and puts an earlier release back with [`restore.yml`](https://github.com/QuantEcon/actions/blob/main/templates/restore.yml), as [`restore-gh-pages`](../actions/restore-gh-pages.md) describes.
- **Not beside another deploy on the same tags.** A release creates its tag, so a `publish.yml` that runs on the push of a `publish*` tag would build the frozen source and deploy over this workflow's deploy. Disable it first: removing the file protects only tags on later commits, since a tag made at an older commit still carries it.
- **A companion notebooks repository.** A series whose "Open in Colab" links open notebooks in a repository of their own, such as `QuantEcon/lecture-python-intro.notebooks`, names it in `notebooks-repository` and passes a token for it as `notebooks-token`, and each release then mirrors its notebooks there. A series with none passes neither.

## Requirements

- **Runner.** GitHub's hosted `ubuntu-latest`, which both jobs name. `restore-gh-pages` needs the GitHub CLI `gh`, which the QuantEcon images do not have.
- **Node.** None.
- **Permissions.** The calling job grants what the workflow's jobs may have, and a called workflow gets no more than that: `contents: read` to read the release, and `pages: write` and `id-token: write` for the deploy. The template's job sets all three.
- **Secrets.** None, unless `notebooks-repository` is set: then `notebooks-token`, a token that can push to that repository, such as a fine-grained token with **Contents** read and write on it alone. The caller passes it by name, under `secrets:`, never with `secrets: inherit`. The release is read with each job's own token.
- **Files in your repository.** The caller, `.github/workflows/deploy-release.yml`, and releases that hold the site, as `publish-gh-pages`' `mode: release` makes them. With `notebooks-repository`, the site's notebooks are under `_notebooks/` in it, as `build-lectures`' `html-copy-notebooks` puts them.
- **A companion repository,** with `notebooks-repository`: one that exists and is public, as Colab needs, with a default branch. The job clones it without a token.
- **Repository settings.** Under **Settings**, **Pages**, **Source** is **GitHub Actions**. Under **Settings**, **Environments**, `github-pages`, **Deployment branches and tags** admits the tag pattern `publish*` beside the default branch: a release event runs on its tag, and a dispatch on the default branch.
- **Who makes the release.** A release that a workflow creates with `GITHUB_TOKEN` starts no workflow, so the release must come from a person, a GitHub App or another token.
- **Setup outside GitHub.** None.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from .github/workflows/deploy-release.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `tag` | no | `''` | The tag of the release to deploy, such as `publish-2026-11-27`. Empty, the default, takes the tag of the release whose `published` event started the run. A run started by a release whose tag does not start with `publish-` deploys nothing, whatever this says. Only letters, digits, `.`, `_` and `-`, starting with a letter or a digit: any other tag, this input's or the release's, fails the job before anything is downloaded. |
| `asset-name` | no | `''` | The start of the release's asset names, as `restore-gh-pages` takes it. Empty, the default, takes the release's one archive for the tag. |
| `notebooks-repository` | no | `''` | A companion repository that serves the site's notebooks to Colab, as `owner/name`, such as `QuantEcon/lecture-python-intro.notebooks`. After the deploy, the `notebooks` job makes its default branch hold exactly the release's `_notebooks/`, at its root, and a README the job writes: a notebook the release no longer has is deleted. It needs the `notebooks-token` secret. Empty, the default, pushes no notebooks, and the job is skipped. Any value that is not `owner/name` fails the job. |

<!-- END GENERATED -->

## Secrets

<!-- BEGIN GENERATED: secrets. scripts/generate-docs.py writes this from .github/workflows/deploy-release.yml: edit that, not this. -->

| Secret | Required | Description |
|---|---|---|
| `notebooks-token` | no | A token that can push to `notebooks-repository`, such as a fine-grained token with Contents read and write on that repository alone. Only the `notebooks` job receives it. Required with `notebooks-repository`, and not used without it. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from .github/workflows/deploy-release.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `page-url` | The URL of the deployed site, as GitHub Pages reports it. |
| `commit` | The full SHA of the commit the deployed site was built from, as the release's manifest records it. Empty when the manifest gives none. |

<!-- END GENERATED -->

## Examples

### Minimal

```yaml
name: Deploy Release

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      tag:
        description: 'The tag of the release to deploy'
        required: true
        type: string

jobs:
  deploy:
    permissions:
      contents: read
      pages: write
      id-token: write
    uses: quantecon/actions/.github/workflows/deploy-release.yml@v0
    with:
      tag: ${{ inputs.tag }}
```

On a release event `inputs.tag` is empty, and the workflow takes the release's own tag.

### With a companion notebooks repository

```yaml
name: Deploy Release

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      tag:
        description: 'The tag of the release to deploy'
        required: true
        type: string

jobs:
  deploy:
    permissions:
      contents: read
      pages: write
      id-token: write
    uses: quantecon/actions/.github/workflows/deploy-release.yml@v0
    with:
      tag: ${{ inputs.tag }}
      notebooks-repository: QuantEcon/lecture-python-intro.notebooks
    secrets:
      notebooks-token: ${{ secrets.QUANTECON_SERVICES_PAT }}
```

The calling job's `contents: read` covers the `notebooks` job, which reads the release and needs nothing more: it pushes with the secret.

### In the templates

[`deploy-release.yml`](https://github.com/QuantEcon/actions/blob/main/templates/deploy-release.yml) is the caller to copy, with its prerequisites in its header.

## Behaviour

### The actions it runs are the latest release

Inside a called workflow, `./` paths name the caller's checkout, so this workflow names its actions as `quantecon/actions/<action>@v0`. Whatever ref a caller names for the workflow, `@v0` or `@v0.N.0`, the workflow's own jobs are that version's, and the actions they run are the latest release. A change that needs both a new action and a new workflow ships the action first, and the workflow after `v0` has moved.

### The notebooks

With `notebooks-repository`, the `notebooks` job runs once the deploy has succeeded, so the companion repository's notebooks never run ahead of the site. It restores the release again with `restore-gh-pages`, with its checksum check, and then:

1. **Mirrors the notebooks.** In a shallow clone of the companion repository's default branch, everything but `.git` goes. Then every `*.ipynb` under the site's `_notebooks/` comes in, at the same path from the repository's root, which is where the theme's "Open in Colab" links look. Nothing else from the site reaches the repository. So a notebook the release no longer has is deleted there, and so is any other file: the first mirror of a repository that holds an `environment.yml` or a Binder README beside its notebooks deletes them.
2. **Writes a README:** the repository's name, the site's address (the `deploy` job's `page-url`), the release's tag, the source repository and the commit the manifest names, and a line saying that each release replaces all of it, so an edit made there is lost at the next.
3. **Commits only if something changed,** as `github-actions[bot]`, with the message `Notebooks of <tag>, built from <repository>@<commit>`, and logs how many notebooks were added, changed and deleted, and any other file it added or deleted.
4. **Pushes** to the default branch with `notebooks-token`, without `--force`.

- **A rollback** dispatches an earlier tag, and its notebooks go back with the site.
- **A release with no notebook** under `_notebooks/` fails the job before anything is pushed, since a mirror of it would empty the repository. The site is deployed by then, so the site is back and the notebooks are still the last ones pushed.
- **The token** reaches git on the push alone, through that command's environment, so it is in no file, on no command line and in no other step.

### Concurrency

The deploy job joins the `pages` concurrency group, without cancelling, the group `publish.yml` and `restore.yml` use, so no two deploys overlap. A caller should not use that group itself, at its top level or on the calling job: GitHub's documentation says that a called workflow and its caller sharing a group with `cancel-in-progress: true` cancels the run already going, and does not say what the same group does without it. The template sets none.

The `notebooks` job joins `deploy-release-notebooks-<notebooks-repository>`, without cancelling, so two releases' pushes to one repository never overlap, and a caller should not use that group either. A push that a newer one still beats fails rather than overwrite it: re-run the job, or dispatch the newer tag.

## Troubleshooting

- **A release was published and nothing deployed.** Check that its tag starts with `publish-`, that whoever created it was not a workflow's `GITHUB_TOKEN`, and that `deploy-release.yml` exists at the commit the tag points at: a release event runs the caller from the tagged commit.
- **The deploy job is rejected by environment protection.** The `github-pages` environment does not admit the run's ref: add the tag pattern `publish*` for a release event, or run the dispatch on the default branch.
- **The `notebooks` job fails with "holds no notebook under `_notebooks/`".** The release's site has no notebooks: build them, and copy them in with `build-lectures`' `html-copy-notebooks`, before the release is made. The site itself is deployed.
- **The `notebooks` job fails with "no notebooks-token secret".** The calling job sets `notebooks-repository` and passes no `notebooks-token` under `secrets:`, or passes a secret the repository doesn't have, which reads as empty.
- **The push is refused.** A 403 means the token cannot write to the companion repository. A rejected non-fast-forward push means another push landed first: re-run the job.
- **`restore-gh-pages` finds no archive, or two.** See its [troubleshooting](../actions/restore-gh-pages.md#troubleshooting); `asset-name` picks one of two archives.
