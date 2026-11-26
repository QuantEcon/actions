# deploy-release

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

A reusable workflow that deploys one of the repository's releases to GitHub Pages: the site [`publish-gh-pages`](../actions/publish-gh-pages.md) attached to it as an archive, a checksum and a manifest. It runs in two jobs:

- **`upload`** restores the release's site with [`restore-gh-pages`](../actions/restore-gh-pages.md), which checks the archive's SHA-256 before extracting it, and uploads it with `publish-gh-pages`' `mode: upload`. It has read access alone.
- **`deploy`** deploys that upload with `publish-gh-pages`' `mode: deploy`, in the `github-pages` environment, and does nothing else. If the deploy fails, **Re-run failed jobs** re-runs this job alone, and it finds the one upload, which is kept for a day; after that, dispatch the tag again.

Neither job runs repository or notebook code. A repository calls it from a short workflow of its own, [`deploy-release.yml`](https://github.com/QuantEcon/actions/blob/main/templates/deploy-release.yml), which runs it in two cases:

- **A release is published** for a tag that starts with `publish-`: that release is deployed. A release for any other tag deploys nothing.
- **A dispatch names a tag:** that tag's release is deployed. Deploying an earlier release this way is the rollback, and every past publish is a point to roll back to.

## When to use it

Use it when the site is built somewhere else and reaches the repository as a release: once QuantEcon's lecture monorepo, QuantEcon/lectures, builds a lecture series, it creates the series repository's release with the built site, and this workflow serves it.

- **Not for a repository that builds its own site.** That one publishes with [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) and puts an earlier release back with [`restore.yml`](https://github.com/QuantEcon/actions/blob/main/templates/restore.yml), as [`restore-gh-pages`](../actions/restore-gh-pages.md) describes.
- **Not beside another deploy on the same tags.** A release creates its tag, so a `publish.yml` that runs on the push of a `publish*` tag would build the frozen source and deploy over this workflow's deploy. Disable it first: removing the file protects only tags on later commits, since a tag made at an older commit still carries it.
- **It does not push notebooks.** A series that serves its notebooks to Colab from a `.notebooks` repository pushes them as it does today. #356 tracks a push in a job of its own.

## Requirements

- **Runner.** GitHub's hosted `ubuntu-latest`, which both jobs name. `restore-gh-pages` needs the GitHub CLI `gh`, which the QuantEcon images do not have.
- **Node.** None.
- **Permissions.** The calling job grants what the workflow's jobs may have, and a called workflow gets no more than that: `contents: read` to read the release, and `pages: write` and `id-token: write` for the deploy. The template's job sets all three.
- **Secrets.** None. It reads the release with the job's own token.
- **Files in your repository.** The caller, `.github/workflows/deploy-release.yml`, and releases that hold the site, as `publish-gh-pages`' `mode: release` makes them.
- **Repository settings.** Under **Settings**, **Pages**, **Source** is **GitHub Actions**. Under **Settings**, **Environments**, `github-pages`, **Deployment branches and tags** admits the tag pattern `publish*` beside the default branch: a release event runs on its tag, and a dispatch on the default branch.
- **Who makes the release.** A release that a workflow creates with `GITHUB_TOKEN` starts no workflow, so the release must come from a person, a GitHub App or another token.
- **Setup outside GitHub.** None.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from .github/workflows/deploy-release.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `tag` | no | `''` | The tag of the release to deploy, such as `publish-2026-11-27`. Empty, the default, takes the tag of the release whose `published` event started the run. A run started by a release whose tag does not start with `publish-` deploys nothing, whatever this says. |
| `asset-name` | no | `''` | The start of the release's asset names, as `restore-gh-pages` takes it. Empty, the default, takes the release's one archive for the tag. |

<!-- END GENERATED -->

## Secrets

<!-- BEGIN GENERATED: secrets. scripts/generate-docs.py writes this from .github/workflows/deploy-release.yml: edit that, not this. -->

This workflow takes no secrets.

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

### In the templates

[`deploy-release.yml`](https://github.com/QuantEcon/actions/blob/main/templates/deploy-release.yml) is the caller to copy, with its prerequisites in its header.

## Behaviour

### The actions it runs are the latest release

Inside a called workflow, `./` paths name the caller's checkout, so this workflow names its actions as `quantecon/actions/<action>@v0`. Whatever ref a caller names for the workflow, `@v0` or `@v0.N.0`, the workflow's own jobs are that version's, and the actions they run are the latest release. A change that needs both a new action and a new workflow ships the action first, and the workflow after `v0` has moved.

### Concurrency

The deploy job joins the `pages` concurrency group, without cancelling, the group `publish.yml` and `restore.yml` use, so no two deploys overlap. A caller should not use that group itself, at its top level or on the calling job: GitHub's documentation does not say how a called job's group meets its caller's, and the template sets none.

## Troubleshooting

- **A release was published and nothing deployed.** Check that its tag starts with `publish-`, that whoever created it was not a workflow's `GITHUB_TOKEN`, and that `deploy-release.yml` exists at the commit the tag points at: a release event runs the caller from the tagged commit.
- **The deploy job is rejected by environment protection.** The `github-pages` environment does not admit the run's ref: add the tag pattern `publish*` for a release event, or run the dispatch on the default branch.
- **`restore-gh-pages` finds no archive, or two.** See its [troubleshooting](../actions/restore-gh-pages.md#troubleshooting); `asset-name` picks one of two archives.
