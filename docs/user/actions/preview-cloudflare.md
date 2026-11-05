# preview-cloudflare

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Deploys a pull request's built site to a Cloudflare Pages project as a preview, on the branch `pr-<number>`, so the preview's URL, `https://pr-<number>.<project-name>.pages.dev`, stays the same for every push to the pull request. Each deployment also gets a URL of its own, which goes on showing that one push. The action then posts one comment on the pull request, and updates it on each later push, with:

- the preview URL and the commit it shows;
- under "Changed Lectures", a link to the page of each lecture that differs between the pull request and its base branch;
- under "Build Info", a link to the workflow run, and the URL of this push's own deployment.

It deploys on `pull_request` events, and skips pull requests from forks and from Dependabot, whose runs get no secrets. With `dispatch-alias` set, it also deploys a `workflow_dispatch` or `schedule` run's build, on that branch and with no comment: see [Outside a pull request](#outside-a-pull-request). On any other event it deploys nothing, and says why in a notice. Its `deployed` output tells the workflow which happened. The project's production site is never touched.

## When to use it

Use it in a pull request's build job, after [`build-lectures`](build-lectures.md), in place of the Netlify step in [`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml), which carries this step as a comment.

- **Or on Netlify.** [`preview-netlify`](preview-netlify.md) does the same on Netlify, and is the one `ci.yml` uses. [Netlify or Cloudflare?](preview-netlify.md#netlify-or-cloudflare) compares the two.
- **Not to publish the site.** [`publish-gh-pages`](publish-gh-pages.md) publishes to GitHub Pages, and [`deploy-cloudflare`](deploy-cloudflare.md) publishes a site that only members may see.
- **To check the preview outside a pull request**, from a scheduled or dispatched run, set `dispatch-alias`: see [Outside a pull request](#outside-a-pull-request).

## Requirements

- **Runner.** Any, with `bash`, `git` and `npm`, as GitHub-hosted runners and the QuantEcon images have. The job must be able to reach `registry.npmjs.org`: `wrangler` is installed each run from the lockfile beside the action.
- **Node.** 22 or later, which the pinned `wrangler` needs. The QuantEcon images carry Node 24. On a standard runner, set it up before this action with `actions/setup-node`, as in [preview-netlify's example](preview-netlify.md#on-a-standard-runner).
- **Permissions.** `pull-requests: write`, for the comment. The job also needs `contents: read` for `actions/checkout`. A run outside a pull request posts no comment, so it needs only `contents: read`.
- **Secrets.** `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, from [Setting up Cloudflare Pages](#setting-up-cloudflare-pages).
- **Files in your repository.** None beyond the built site. The comment's lecture links compare the pull request's head with the commit where it branched off its base branch. A checkout with `fetch-depth: 0` has that commit, and nothing is fetched. From a shallow checkout, such as `actions/checkout`'s default of one commit, the action fetches history until it finds it, up to 1,024 commits behind the pull request's base and head: see [preview-netlify's Behaviour](preview-netlify.md#behaviour).
- **Setup outside GitHub.** A Cloudflare Pages project, once: see [Setting up Cloudflare Pages](#setting-up-cloudflare-pages).

## Setting up Cloudflare Pages

1. **A Cloudflare account.** A free one is enough to start.
2. **Create a project that Cloudflare does not build.** In the dashboard, under **Workers & Pages**, create a Pages project with **Upload assets**, which is direct upload, and upload any file as a placeholder. Such a project has no link to the repository, so Cloudflare neither builds your pull requests nor comments on them: this action deploys and comments instead.
   - Its name is the `project-name` input.
   - **Check its address.** The action builds the preview URL, and every lecture link in the comment, as `https://pr-<number>.<project-name>.pages.dev`. Cloudflare can give a project a `pages.dev` address other than its name, as it does when that name is already taken, and those URLs would then be wrong. After creating the project, check that it is served at exactly `https://<project-name>.pages.dev`; if not, create one under a name that is free. See [#216](https://github.com/QuantEcon/actions/issues/216).
3. **Find the account ID.** It is in the dashboard's URL, `https://dash.cloudflare.com/<account-id>/…`, and on the **Workers & Pages** overview.
4. **Create an API token** under **My Profile**, **API Tokens**, as a custom token with a single permission, **Account**, **Cloudflare Pages**, **Edit**, for the account that owns the project. Copy it when it is shown: Cloudflare shows it only once.
5. **Add both as repository secrets**, under the repository's **Settings**, **Secrets and variables**, **Actions**:

   | Secret | Value |
   |---|---|
   | `CLOUDFLARE_API_TOKEN` | the token from step 4 |
   | `CLOUDFLARE_ACCOUNT_ID` | the account ID from step 3 |

The previews then appear at:

| Deployment | URL |
|---|---|
| Pull request 5, newest push | `https://pr-5.<project-name>.pages.dev` |
| One push | `https://<hash>.<project-name>.pages.dev` |
| The newest scheduled or dispatched run with `dispatch-alias: dispatch-canary` | `https://dispatch-canary.<project-name>.pages.dev` |
| The project's production site, which the action leaves alone | `https://<project-name>.pages.dev` |

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from preview-cloudflare/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `cloudflare-api-token` | yes | none | A Cloudflare API token that can edit Cloudflare Pages in the account, from a repository secret such as `secrets.CLOUDFLARE_API_TOKEN`. |
| `cloudflare-account-id` | yes | none | The ID of the Cloudflare account that owns the Pages project, from a repository secret such as `secrets.CLOUDFLARE_ACCOUNT_ID`. |
| `project-name` | yes | none | The Cloudflare Pages project to deploy to, which must already exist. Its name is part of every preview URL, as in `<project-name>.pages.dev`. |
| `build-dir` | yes | none | The directory that holds the built site, such as `_build/html`, which `build-lectures` gives in its `build-path` output. |
| `lectures-dir` | no | `lectures` | The directory of lecture `.md` files that change detection looks in, as a path from the repository root such as `lectures`, with no `./` or trailing slash: each lecture the pull request added or modified gets a link in the comment, and is listed in `changed-files`. Empty turns change detection off, and the comment gives only the preview URL. |
| `dispatch-alias` | no | `''` | Deploys on `workflow_dispatch` and `schedule` events too, to this branch, such as `dispatch-canary`, at `https://<alias>.<project-name>.pages.dev`. It must start with `dispatch-`, which keeps it clear of every pull request's `pr-<number>`, and be lowercase letters and digits in words joined by single dashes, at most 28 characters in all. Any other value fails the job, on every event. Such a run has no comment and no changed lectures, and a pull request ignores the input. Empty, the default, deploys on `pull_request` only. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from preview-cloudflare/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `deployed` | `'true'` when this run deployed a preview, so that `deploy-url` is set, and `'false'` when it did not, and then a notice or a warning in the log says why. A scheduled or dispatched check should assert `deployed == 'true'`, or it passes without testing the deploy. |
| `deploy-url` | The pull request's preview URL, `https://pr-<number>.<project-name>.pages.dev`, which always shows its newest push, so use it for anything a person will follow; on a `workflow_dispatch` or `schedule` run, `https://<dispatch-alias>.<project-name>.pages.dev`. Empty when nothing was deployed. |
| `deployment-url` | The URL of this one deployment, `https://<hash>.<project-name>.pages.dev`, which goes on showing this push after later ones. Empty when wrangler's output does not name it, and when nothing was deployed. |
| `changed-files` | The lecture files under `lectures-dir` that the pull request added or modified, one path per line, compared from the commit where it branched off. When a shallow checkout's history does not reach that commit within 1,024 commits, the comparison starts from the base branch's tip instead, with a warning, so a lecture changed only on the base branch is listed too. When git fails, the action warns and lists none. Empty when there are none, with `lectures-dir: ''`, on an event other than `pull_request`, and for a pull request from a fork or by Dependabot. |

<!-- END GENERATED -->

## Examples

### Minimal

A pull request's build in a container, deployed as a preview:

```yaml
name: Preview
on:
  pull_request:

jobs:
  preview:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon-build:latest
    permissions:
      contents: read
      pull-requests: write   # the preview comment
      packages: read         # the image pull, as the templates grant it
    steps:
      - uses: actions/checkout@v7
      - uses: quantecon/actions/setup-environment@v0
      - uses: quantecon/actions/build-lectures@v0
        id: build
      - uses: quantecon/actions/preview-cloudflare@v0
        with:
          cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          project-name: my-lectures
          build-dir: ${{ steps.build.outputs.build-path }}
```

### Outside a pull request

A scheduled or dispatched run deploys only with `dispatch-alias` set, here to `https://dispatch-canary.my-lectures.pages.dev`, which always shows the newest such run. Check `deployed`: a run that deployed nothing still passes. In a workflow like [preview-netlify's](preview-netlify.md#outside-a-pull-request), the steps are:

```yaml
- uses: quantecon/actions/preview-cloudflare@v0
  id: preview
  with:
    cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    project-name: my-lectures
    build-dir: ${{ steps.build.outputs.build-path }}
    dispatch-alias: dispatch-canary
- name: Fail unless the preview was deployed
  if: steps.preview.outputs.deployed != 'true'
  run: |
    echo "::error::no preview was deployed"
    exit 1
```

### In the templates

[`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) carries this action as a commented alternative to its `preview-netlify` step. To use it, replace that step with the comment's, set `project-name`, and add the two secrets.

## Behaviour

1. **Whether to deploy.** The action decides first, by the same rules as [preview-netlify](preview-netlify.md#behaviour), and every later step follows the decision. It deploys a pull request from this repository to the branch `pr-<number>`, and a `workflow_dispatch` or `schedule` run with `dispatch-alias` set to the branch that input names; anything else, such as a pull request from a fork, any run by Dependabot, a `push` or a `pull_request_target`, deploys nothing. A run that deploys nothing stops here: it installs nothing, sets `deployed` to `'false'`, passes, and says why in a notice, such as `No Cloudflare preview deployed: pull requests from forks get no secrets.` On `pull_request_target` the message is a warning, because of [Security](#security). A `dispatch-alias` that breaks the input's rules fails the job, on every event.
2. **Changed lectures.** On a `pull_request` event with `lectures-dir` set, the action lists the lectures the pull request added or modified, compared from the commit where it branched off its base branch, by the same rules as [preview-netlify](preview-netlify.md#behaviour). That section also says how much history a shallow checkout fetches, and what the action does when git fails.
3. **The CLI.** The `wrangler` version pinned in the action's [`package.json`](https://github.com/QuantEcon/actions/blob/main/preview-cloudflare/package.json) is installed with `npm ci`, into a temporary directory, and its `wrangler` command is added to the `PATH` of the job's later steps.
4. **The deploy:**

   ```text
   wrangler pages deploy <build-dir> --project-name <project-name> --branch <branch> --commit-hash <commit> --commit-message "<run> (<short commit>)"
   ```

   `<branch>` is `pr-<number>` or `dispatch-alias`, as step 1 decided. `<commit>` is the pull request's head commit, or the commit a dispatched or scheduled run is on, and `<short commit>` is its first 7 characters. `<run>` is `PR #<number>`, or the event and branch, such as `workflow_dispatch on main`. The token and the account ID reach the CLI through the environment. A branch other than the project's production branch makes the deployment a preview, so the production site is untouched. wrangler's output is in the "Deployment Output" log group.
5. **The URLs.** `deploy-url` is not read from wrangler's output but built from the inputs: `https://<branch>.<project-name>.pages.dev` is the alias Cloudflare gives the newest deployment of the branch, as long as the project's own address is `<project-name>.pages.dev`. Both kinds of branch are already in the form Cloudflare uses for an alias, lowercase letters, digits and dashes, so the alias is the branch name unchanged. `deployment-url` is the first other `pages.dev` address in wrangler's output. Outside a pull request, the preview's URL also goes in a notice, on the run's summary page.
6. **The comment**, on a pull request only. The action finds its own comment among all of the pull request's comments, and updates it, as [preview-netlify](preview-netlify.md#behaviour) does; if it has none, it posts a new one. Its own is a comment by `github-actions[bot]` that contains the hidden line `<!-- quantecon-preview:cloudflare -->`, or that starts with `## ☁️ Cloudflare Preview Ready!`, as its comments did before that line was added. It never edits anyone else's comment. Its lecture links are built as in preview-netlify's. Under Build Info, a "This deployment" line gives `deployment-url`, when wrangler's output named one.

To know whether a preview was deployed, check `deployed`. A scheduled or dispatched check should fail unless it is `'true'`, as in [Outside a pull request](#outside-a-pull-request): otherwise a run that deployed nothing, because `dispatch-alias` was left out, say, passes having tested nothing.

### What fails the job

- A `dispatch-alias` other than `dispatch-` followed by lowercase letters and digits in words joined by single dashes, at most 28 characters in all, on any event.
- `npm ci` failing to install the pinned CLI, or the installed CLI failing to run.
- `wrangler pages deploy` failing.
- The comment failing to post, for want of `pull-requests: write`.

## Security

Previews of pull requests from forks are not supported, and the action skips them. Do not run it from a `pull_request_target` workflow to get around that. A workflow triggered that way builds and runs the fork's notebooks with `CLOUDFLARE_API_TOKEN` and a write-scoped `GITHUB_TOKEN` within their reach, the pattern known as a "pwn request". It would not produce a preview either: the action never deploys on `pull_request_target`, whatever `dispatch-alias` says, and warns instead.

`dispatch-alias` does not widen who can deploy. A `workflow_dispatch` run needs write access to the repository, and a `schedule` run uses the workflow on the default branch, so either already has the repository's secrets.

## Troubleshooting

**`npm ci of the pinned wrangler failed — see the npm output above (it needs registry.npmjs.org)`.** The runner cannot reach the npm registry, or npm is missing.

**`wrangler installed but does not run — see the output above`.** Usually a Node older than 22. Set up Node 24 before this action.

**`wrangler pages deploy failed (exit …) — see the Deployment Output group above`.** wrangler's own message is in that group.

- An authentication error: the token lacks **Cloudflare Pages**, **Edit**, has expired, or belongs to another account than `CLOUDFLARE_ACCOUNT_ID`.
- `The Pages project "…" does not exist.`: `project-name` must match the project's name exactly, in the account that `CLOUDFLARE_ACCOUNT_ID` names. The action never creates a project.

**The preview URL answers 404, or shows another site.** Check first that the project is served at exactly `https://<project-name>.pages.dev`: if Cloudflare gave it another address, the URLs the action builds are wrong, as [Setting up Cloudflare Pages](#setting-up-cloudflare-pages) explains. The comment's "This deployment" link, read from wrangler's output, is right either way. Otherwise, a new alias can take a few seconds to appear; if the 404 lasts, check that `build-dir` holds an `index.html`.

**`Resource not accessible by integration`, when commenting.** The job lacks `pull-requests: write`.

**The comment lists no changed lectures, lists one the pull request did not change, or a link leads to a missing page.** See [preview-netlify's troubleshooting](preview-netlify.md#troubleshooting): the two actions detect and link lectures the same way.

**The comment has no "This deployment" line.** wrangler's output named no per-deployment URL, so `deployment-url` is empty. The preview URL is not affected.

**`No Cloudflare preview deployed: …`, in a notice, or `dispatch-alias […] must be dispatch- followed by …`.** See [preview-netlify's troubleshooting](preview-netlify.md#troubleshooting): the two actions decide whether to deploy the same way.

**A dispatched or scheduled run deployed, but posted no comment.** Expected: there is no pull request to comment on. The URL is in `deploy-url`, and in a notice on the run's summary page.
