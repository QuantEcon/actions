# preview-netlify

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Deploys a pull request's built site to a Netlify site as a preview, under the alias `pr-<number>`, so the preview's URL, `https://pr-<number>--<site>.netlify.app`, stays the same for every push to the pull request. It then posts one comment on the pull request, and updates it on each later push, with:

- the preview URL and the commit it shows;
- under "Changed Lectures", a link to the page of each lecture that differs between the pull request and its base branch;
- under "Build Info", a link to the workflow run.

It deploys only on `pull_request` events, and skips pull requests from forks and from Dependabot, whose runs get no secrets. The Netlify site's production deploy is never touched.

Netlify's dashboard calls a site a *project*. The action's input and secret keep the word *site*: `netlify-site-id` and `NETLIFY_SITE_ID` take the project's ID.

## When to use it

Use it in a pull request's build job, after [`build-lectures`](build-lectures.md), as [`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) does.

- **Not to publish the site.** [`publish-gh-pages`](publish-gh-pages.md) publishes to GitHub Pages, and [`deploy-cloudflare`](deploy-cloudflare.md) publishes a site that only members may see.
- **Or on Cloudflare.** [`preview-cloudflare`](preview-cloudflare.md) does the same on Cloudflare Pages. The table below compares the two.

### Netlify or Cloudflare?

| | `preview-netlify` | `preview-cloudflare` |
|---|---|---|
| Preview URL | `https://pr-<number>--<site>.netlify.app` | `https://pr-<number>.<project-name>.pages.dev` |
| A URL for each push | not reported, though Netlify keeps one for each deploy | yes, in `deployment-url` and in the comment |
| Repository secrets | `NETLIFY_AUTH_TOKEN`, `NETLIFY_SITE_ID` | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` |
| Other inputs it needs | none | `project-name` |
| CLI, installed each run | `netlify-cli`, which needs Node 22.13 or later | `wrangler`, which needs Node 22 or later |
| In `ci.yml` | the preview step | a commented alternative |

Both deploy the files `build-lectures` built, with no build on the provider's side, and neither needs the provider to be linked to the repository. For what each provider's plans allow, see its pricing page.

## Requirements

- **Runner.** Any, with `bash`, `git`, `python3` and `npm`, as GitHub-hosted runners and the QuantEcon images have. The job must be able to reach `registry.npmjs.org`: `netlify-cli` is installed each run from the lockfile beside the action.
- **Node.** 22.13 or later, which the pinned `netlify-cli` needs. The QuantEcon images carry Node 24. On a standard runner, set it up before this action with `actions/setup-node`; see [On a standard runner](#on-a-standard-runner).
- **Permissions.** `pull-requests: write`, for the comment. The job also needs `contents: read` for `actions/checkout`.
- **Secrets.** `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID`, from [Setting up Netlify](#setting-up-netlify).
- **Files in your repository.** None beyond the built site. The comment's lecture links need the pull request's base and head commits, which the action fetches if the checkout lacks them.
- **Setup outside GitHub.** A Netlify project, once: see [Setting up Netlify](#setting-up-netlify).

## Setting up Netlify

1. **Create a project that Netlify does not build.** In Netlify, add a new project with **Deploy manually**, and drop any folder on it as a placeholder. Such a project has no link to the repository, so Netlify neither builds your pull requests nor comments on them: this action deploys and comments instead.
2. **Create a personal access token**, under **User settings**, **Applications**, **Personal access tokens**. Give it a name that says what it is for, such as `github-actions`, and copy it when it is shown: Netlify shows it only once.
3. **Find the project ID**, under the project's configuration, **General**, in its details. It is a UUID, such as `a1b2c3d4-e5f6-…`.
4. **Add both as repository secrets**, under the repository's **Settings**, **Secrets and variables**, **Actions**:

   | Secret | Value |
   |---|---|
   | `NETLIFY_AUTH_TOKEN` | the token from step 2 |
   | `NETLIFY_SITE_ID` | the project ID from step 3 |

A project that is already linked to the repository builds each pull request itself, and comments on it, beside this action. What to do depends on the project:

| The Netlify project | Do this |
|---|---|
| New | Create it with **Deploy manually**, as above. |
| Linked to the repository | Unlink it. This is the usual choice. |
| Linked, and you want to keep Netlify's own builds | Turn off only its pull-request comments. |

All three settings are in the project's configuration:

- **Unlink the repository**, under **Build & deploy**, **Continuous deployment**. The project keeps serving, but Netlify no longer builds or comments.
- **Turn off Netlify's pull-request comments**, under **Notifications**: remove its GitHub commit and pull-request comments.
- **Turn off deploy previews** as well, if Netlify should not build pull requests at all: under **Build & deploy**, **Continuous deployment**, **Branches and deploy contexts**, set **Deploy Previews** to **None**.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from preview-netlify/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `netlify-auth-token` | yes | none | A Netlify personal access token, from a repository secret such as `secrets.NETLIFY_AUTH_TOKEN`. It reaches `netlify-cli` through the environment, never on its command line. |
| `netlify-site-id` | yes | none | The ID of the Netlify site to deploy to, from a repository secret such as `secrets.NETLIFY_SITE_ID`. |
| `build-dir` | yes | none | The directory that holds the built site, such as `_build/html`, which `build-lectures` gives in its `build-path` output. |
| `lectures-dir` | no | `lectures` | The directory of lecture `.md` files that change detection looks in, as a path from the repository root such as `lectures`, with no `./` or trailing slash: each lecture that differs from the base branch gets a link in the comment, and is listed in `changed-files`. Empty turns change detection off, and the comment gives only the preview URL. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from preview-netlify/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `deploy-url` | The preview's URL, `https://pr-<number>--<site>.netlify.app`, the same for every push to the pull request. Empty when nothing was deployed: on an event other than `pull_request`, and for a pull request from a fork or by Dependabot. |
| `changed-files` | The lecture files under `lectures-dir` that were added or modified between the tip of the pull request's base branch and its head, one path per line, so a lecture changed on the base branch since the pull request branched off is listed too. Empty when there are none, with `lectures-dir: ''`, on an event other than `pull_request`, and for a pull request from a fork or by Dependabot. |

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
      - uses: quantecon/actions/preview-netlify@v0
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: ${{ steps.build.outputs.build-path }}
```

### On a standard runner

Set up Node first:

```yaml
- uses: actions/setup-node@v7
  with:
    node-version: '24'
- uses: quantecon/actions/preview-netlify@v0
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: _build/html
```

### In the templates

[`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) deploys each pull request's build with this action, with `preview-cloudflare` as a commented alternative.

## Behaviour

1. **Who gets a preview.** A run by Dependabot, or for a pull request from a fork, stops here: it prints `⚠️ Netlify deployment skipped (untrusted actor or fork PR)`, deploys nothing, and passes.
2. **Changed lectures.** On a `pull_request` event with `lectures-dir` set, the action compares two commits: the pull request's base, which is the tip of its base branch, and its head. It lists each `.md` file under `lectures-dir` that was added or modified between them, except `<lectures-dir>/intro.md` and files whose path within `lectures-dir` starts with `_`. A renamed lecture counts as added; a deleted one is not listed.
   - Because the comparison starts from the base branch's tip, not from where the pull request branched off, a lecture changed on the base branch since then is listed too, although the pull request did not touch it. See [#215](https://github.com/QuantEcon/actions/issues/215).
   - `lectures-dir` is matched against paths from the repository root, as git writes them: give it as `lectures`, not `./lectures` or `lectures/`, which match nothing. Lectures at the repository root cannot be listed.
3. **The CLI.** The `netlify-cli` version pinned in the action's [`package.json`](https://github.com/QuantEcon/actions/blob/main/preview-netlify/package.json) is installed with `npm ci`, into a temporary directory, and its `netlify` command is added to the `PATH` of the job's later steps.
4. **The deploy**, on `pull_request` events only:

   ```text
   netlify deploy --no-build --dir <build-dir> --alias pr-<number> --message "PR #<number> (<short commit>)" --json
   ```

   `<short commit>` is the first 7 characters of the pull request's head commit. The token and the site ID reach the CLI through the environment. `--no-build` stops Netlify from running a build of its own, and without `--prod` the deploy is a preview, so the site's production deploy is untouched. Netlify's output is in the "Deployment Output" log group.
5. **The comment.** Among the pull request's first 30 comments, the action looks for one that contains `## 📖 Netlify Preview Ready!`, and updates it; if there is none, it posts a new one. Each changed lecture links to `<deploy-url>/<path>.html`. `<path>` is the file's path without `.md`, and also without the `lectures-dir/` in front when `_toc.yml` is in `lectures-dir`, because Jupyter Book then builds the pages relative to it.

   For a pull request that changes two lectures, the comment's Markdown is:

   ````markdown
   ## 📖 Netlify Preview Ready!

   **Preview URL:** https://pr-5--<site>.netlify.app

   **Commit:** [`abc1234`](https://github.com/<owner>/<repository>/commit/<full commit>)

   ### 📚 Changed Lectures

   - [aiyagari](https://pr-5--<site>.netlify.app/aiyagari.html)
   - [mccall_model](https://pr-5--<site>.netlify.app/mccall_model.html)

   ---
   <details><summary>Build Info</summary>

   - **Workflow:** [<workflow>](https://github.com/<owner>/<repository>/actions/runs/<run id>)
   </details>
   ````

On any event but `pull_request`, such as `push`, `workflow_dispatch` or `schedule`, the action installs the CLI and does nothing else, and nothing in the log says so: the step succeeds, with an empty `deploy-url`. To know whether a preview was deployed, check `deploy-url`. The one exception is a run by Dependabot, which prints the skip message and installs nothing.

### What fails the job

- `npm ci` failing to install the pinned CLI, or the installed CLI failing to run.
- `netlify deploy` failing, or printing no deploy URL.
- The comment failing to post, for want of `pull-requests: write`.

## Security

Previews of pull requests from forks are not supported, and the action skips them. Do not run it from a `pull_request_target` workflow to get around that. A workflow triggered that way builds and runs the fork's notebooks with `NETLIFY_AUTH_TOKEN` and a write-scoped `GITHUB_TOKEN` within their reach, the pattern known as a "pwn request". It would not produce a preview either: the action deploys only on `pull_request` events.

## Troubleshooting

**`npm ci of the pinned netlify-cli failed — see the npm output above (it needs registry.npmjs.org)`.** The runner cannot reach the npm registry, or npm is missing.

**`netlify-cli installed but does not run — see the output above`.** Usually a Node older than 22.13. Set up Node 24 before this action.

**`netlify deploy failed (exit …) — see the Deployment Output group above`.** Netlify's own message is in that group:

- `Authentication required. NETLIFY_AUTH_TOKEN is not set`: the secret is missing, or empty in this repository.
- Any other authorisation error: the token is wrong, revoked or expired.
- A project that cannot be found: `NETLIFY_SITE_ID` is wrong.

Check also that `build-dir` exists.

**`no deploy URL in netlify's --json output — see the raw output above`.** The deploy ran, but its output had no `deploy_url`, so the action cannot comment. The raw output is printed above the error. It usually means a new `netlify-cli` changed its output: please report it as an issue in this repository.

**`Resource not accessible by integration`, when commenting.** The job lacks `pull-requests: write`.

**The comment lists no changed lectures.** Check, in this order:

- The pull request adds or modifies no lecture that is listed: see [Behaviour](#behaviour) for the files it skips, `<lectures-dir>/intro.md` and paths within `lectures-dir` that start with `_`.
- `lectures-dir` names the wrong directory, or is written as `./lectures` or `lectures/`: give it as `lectures`.
- git cannot read the checkout, which makes change detection find nothing without a word. That happens in a container job whose image does not trust every directory; both QuantEcon images do. `build-lectures` makes git trust the checkout for the rest of the job, so run this action after it, or trust the workspace yourself with `git config --global --add safe.directory "$GITHUB_WORKSPACE"`.

**The comment lists a lecture the pull request did not change.** The lecture was changed on the base branch after the pull request branched off: see [Behaviour](#behaviour).

**A lecture link leads to a missing page.** The links assume Jupyter Book's layout: pages relative to `lectures-dir` when `_toc.yml` is inside it, and relative to the repository root when it is not.

**Two comments on each pull request, one of them from Netlify.** The Netlify project is linked to the repository: see the end of [Setting up Netlify](#setting-up-netlify).

**A new preview comment on every push.** The pull request has more than 30 comments before the preview's, so the action does not find its own comment, and posts another.

**A pull request from a fork got no preview.** Expected: its runs get no secrets, so the action skips them. See [Security](#security).
