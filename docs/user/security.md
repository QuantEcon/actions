# Security

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Building the lectures runs code the repository does not fully control: every notebook cell, the packages installed at build time, and whatever those fetch from the network. Code that runs earlier in a job can affect every step after it. So the question for each job is what that code could reach: deploy tokens, write permissions, and the job's own `GITHUB_TOKEN`. The actions and the templates keep that to what the job needs.

To report a vulnerability, see [SECURITY.md](https://github.com/QuantEcon/actions/blob/main/SECURITY.md): privately, through the repository's Security tab, not in an issue.

## Who gets the secrets

- **A pull request from a fork,** and **any run by Dependabot,** gets none of the repository's secrets. The preview actions skip such runs: they deploy nothing, pass, and say why in a notice, so the checks stay green on a fork's pull request. [`deploy-cloudflare`](actions/deploy-cloudflare.md) fails instead, since it has no token. Previews of a fork's pull requests are not supported.
- **Do not use `pull_request_target`** to give a fork's pull request a preview. A workflow triggered that way runs with the base repository's secrets and a write-scoped `GITHUB_TOKEN`, so building the fork's notebooks puts both within their reach: the pattern known as a "pwn request". The preview actions never deploy on `pull_request_target`, and warn when run from it.
- **A `workflow_dispatch` run** needs write access to the repository, and **a `schedule` run** uses the workflow on the default branch, so `dispatch-alias`, which lets either deploy a preview, does not widen who can deploy.

## Each job holds only what it needs

The templates set `permissions:` on each job, so no job has more than its own steps use:

| Job | Permissions | Secrets |
|---|---|---|
| `cache.yml` | `contents: read`, `issues: write` for the failure issue, `packages: read` for the image | None |
| `ci.yml`, `placeholder` | `contents: read`, `pull-requests: write` for the early comment | None |
| `ci.yml`, `build` | `contents: read`, `packages: read` | None |
| `ci.yml`, `deploy` | `contents: read`, `pull-requests: write` for the comment | The preview provider's token |
| `ci.yml`, `pdf-check` | `contents: read`, `packages: read` | None |
| `publish.yml`, `build` | `contents: read`, `packages: read` | None |
| `publish.yml`, `deploy` | `pages: write` and `id-token: write`, for the Pages deploy | None |
| `publish.yml`, `release-assets`, commented out | `contents: write`, for the release upload | None |
| `restore.yml`, `restore` | `contents: read` for the release, and `pages: write` and `id-token: write` for the Pages deploy, in one job, since it runs no notebook or repository code | None |

Every checkout in the templates sets `persist-credentials: false`, so no job leaves its `GITHUB_TOKEN` in git's configuration, where any later step could read it.

## Each deploy runs in a job of its own

In both `ci.yml` and `publish.yml`, the job that builds the site and the job that deploys it are separate, so whatever can deploy is never in a job that runs notebook code. Each split protects the credential, not the site: the deploy publishes whatever the build produced.

### The preview

In `ci.yml`, the provider's token is held only by `deploy`:

- **`build`** runs the notebooks, with `contents: read` and no secrets. It ends by uploading `_build/html` as the `html` artifact.
- **`deploy`** holds the provider's secret and `pull-requests: write`, and runs no notebook or repository code: no container, no `setup-environment`, no build. It checks out the repository, downloads the artifact, and runs the preview action.
- **`placeholder`** posts the early comment with `pull-requests: write` and no secret. It runs no repository code either: it has no checkout, and reads the pull request's changed files from the API. Like a deploy, it posts nothing on a fork's or Dependabot's pull request.

[A build job and a deploy job](actions/preview-netlify.md#a-build-job-and-a-deploy-job), in the `preview-netlify` chapter, shows the two jobs on their own.

`deploy` checks out the repository only for the comment's links to the lectures the pull request changed, which come from comparing the pull request with its base branch in git. From a shallow checkout the preview action fetches the history it needs, which a public repository serves without credentials. A private repository does not, so with `persist-credentials: false` that fetch fails, and the comment lists no lectures, with a warning. A private repository sets `fetch-depth: 0` on `deploy`'s checkout instead, as the comment there says.

### GitHub Pages

In `publish.yml`, the Pages permissions are held only by `deploy`, through [`publish-gh-pages`](actions/publish-gh-pages.md)' `mode` input:

- **`build`** runs the notebooks with `contents: read`, and ends with `mode: upload`, which uploads the site as the run's `github-pages` artifact.
- **`deploy`** holds `pages: write` and `id-token: write`, and runs nothing but `mode: deploy`: no checkout, no container. The deploy needs no stored secret: it authenticates with a short-lived OIDC token. It runs in the `github-pages` environment, whose protection rules decide which branches and tags may deploy, by default only the default branch.
- **`release-assets`**, commented out in the template, holds `contents: write`, which the release upload needs and neither job above should. It runs `mode: release` on a tag, once the deploy has succeeded, from a copy of the site that `build` uploads for it.

[A build job and a deploy job](actions/publish-gh-pages.md#a-build-job-and-a-deploy-job), in the `publish-gh-pages` chapter, shows the split on its own.

## A private site

[`deploy-cloudflare`](actions/deploy-cloudflare.md) publishes a site that only signed-in members may read, behind Cloudflare Access. With `visibility: private`, it checks before the upload, and again after the deploy, that an anonymous request is sent to the Access login, and refuses to upload to a Worker that anyone can read. The [setup checklist](actions/deploy-cloudflare.md#setup-checklist) covers the Access application and the token, which can deploy that one Worker but not create one.

## What the actions themselves do

- **Pinned tools.** Third-party actions, such as `conda-incubator/setup-miniconda`, are pinned by commit SHA; GitHub's own `actions/*` by major version. The deploy CLIs, `netlify-cli` and `wrangler`, are installed from a lockfile in each action, so a run installs the version reviewed here.
- **Tokens stay off the command line.** The three deploy actions pass the provider's token to its CLI through the environment, never as an argument.
- **Notebook output is not a workflow command.** `build-lectures` prints failed notebooks' tracebacks between `stop-commands` markers, so text in a notebook's output, such as a line starting `::error::`, is printed as it is rather than acted on.
- **Inputs are read as values, never as shell.** Each action passes its inputs to its scripts through the environment. An input that is one value, which is every input but `build-lectures`' `extra-args`, `build-jupyter-cache`'s `builders`, `issue-labels`, `issue-assignees` and `extra-args`, and `setup-latex`'s `packages`, must be a single line: the action fails in its first step on a line break, before anything prints the value, because the runner reads a printed line that starts with `::` as a workflow command. Tokens and IDs passed as secrets are not checked: no action prints them. A value printed in an error or a warning is escaped as the runner expects, so it stays in that one annotation.
- **Failure issues use the job's own token,** with only `issues: write`.
