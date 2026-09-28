# preview-netlify

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Deploys a pull request's built site to a Netlify site as a preview, under the alias `pr-<number>`, so the preview's URL, `https://pr-<number>--<site>.netlify.app`, stays the same for every push to the pull request. It then posts one comment on the pull request, and updates it on each later push, with:

- the preview URL and the commit it shows;
- a link to the page of each lecture the pull request adds or modifies, under "Changed Lectures".

It deploys only on `pull_request` events, and skips pull requests from forks and from Dependabot, whose runs get no secrets. The Netlify site's production deploy is never touched.

## When to use it

Use it in a pull request's build job, after [`build-lectures`](build-lectures.md), as [`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) does.

- **Not to publish the site.** [`publish-gh-pages`](publish-gh-pages.md) publishes to GitHub Pages, and [`deploy-cloudflare`](deploy-cloudflare.md) publishes a site that only members may see.
- **Or on Cloudflare.** [`preview-cloudflare`](preview-cloudflare.md) does the same on Cloudflare Pages. The table below compares the two.

### Netlify or Cloudflare?

| | `preview-netlify` | `preview-cloudflare` |
|---|---|---|
| Preview URL | `https://pr-<number>--<site>.netlify.app` | `https://pr-<number>.<project-name>.pages.dev` |
| A URL for each push | no | yes, in `deployment-url` and in the comment |
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
- **Setup outside GitHub.** A Netlify site, once: see [Setting up Netlify](#setting-up-netlify).

## Setting up Netlify

1. **Create a site that Netlify does not build.** In Netlify, add a new site with **Deploy manually**, and drop any folder on it as a placeholder. Such a site has no link to the repository, so Netlify neither builds your pull requests nor comments on them: this action does both.
2. **Create a personal access token**, under **User settings**, **Applications**, **Personal access tokens**. Give it a name that says what it is for, such as `github-actions`, and copy it when it is shown: Netlify shows it only once.
3. **Find the site ID**, under the site's **Site configuration**, **General**, **Site details**. It is a UUID, such as `a1b2c3d4-e5f6-…`.
4. **Add both as repository secrets**, under the repository's **Settings**, **Secrets and variables**, **Actions**:

   | Secret | Value |
   |---|---|
   | `NETLIFY_AUTH_TOKEN` | the token from step 2 |
   | `NETLIFY_SITE_ID` | the site ID from step 3 |

A site that is already linked to the repository builds each pull request itself, and comments on it, beside this action. To stop that, do one of these under the site's **Site configuration**:

- **Unlink the repository**, under **Build & deploy**, **Continuous deployment**. The site keeps serving, but Netlify no longer builds or comments.
- **Turn off Netlify's pull-request comments** only, under **Notifications**: remove its GitHub commit and pull-request comments.
- **Turn off deploy previews**, under **Build & deploy**, **Continuous deployment**, **Branches and deploy contexts**: set **Deploy Previews** to **None**.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from preview-netlify/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `netlify-auth-token` | yes | none | A Netlify personal access token, from a repository secret such as `secrets.NETLIFY_AUTH_TOKEN`. It reaches `netlify-cli` through the environment, never on its command line. |
| `netlify-site-id` | yes | none | The ID of the Netlify site to deploy to, from a repository secret such as `secrets.NETLIFY_SITE_ID`. |
| `build-dir` | yes | none | The directory that holds the built site, such as `_build/html`, which `build-lectures` gives in its `build-path` output. |
| `lectures-dir` | no | `lectures` | The directory of lecture `.md` files that change detection looks in: each one the pull request adds or modifies gets a link in the comment, and is listed in `changed-files`. Empty turns change detection off, and the comment gives only the preview URL. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from preview-netlify/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `deploy-url` | The preview's URL, `https://pr-<number>--<site>.netlify.app`, the same for every push to the pull request. Empty when nothing was deployed: on an event other than `pull_request`, and for a pull request from a fork or by Dependabot. |
| `changed-files` | The lecture files that the pull request adds or modifies under `lectures-dir`, one path per line. Empty when there are none, with `lectures-dir: ''`, on an event other than `pull_request`, and for a pull request from a fork or by Dependabot. |

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
2. **Changed lectures.** On a `pull_request` event with `lectures-dir` set, the action compares the pull request's base and head commits. It lists each `.md` file under `lectures-dir` that the pull request adds or modifies, except `<lectures-dir>/intro.md` and files whose path within `lectures-dir` starts with `_`. A renamed lecture counts as added; a deleted one is not listed.
3. **The CLI.** The `netlify-cli` version pinned in the action's [`package.json`](https://github.com/QuantEcon/actions/blob/main/preview-netlify/package.json) is installed with `npm ci`, into a temporary directory, and its `netlify` command is added to the `PATH` of the job's later steps.
4. **The deploy**, on `pull_request` events only:

   ```text
   netlify deploy --no-build --dir <build-dir> --alias pr-<number> --message "PR #<number> (<commit>)" --json
   ```

   The token and the site ID reach it through the environment. `--no-build` stops Netlify from running a build of its own, and without `--prod` the deploy is a preview, so the site's production deploy is untouched. Netlify's output is in the "Deployment Output" log group.
5. **The comment.** The action updates the pull request's comment that starts `## 📖 Netlify Preview Ready!`, or posts one. Each changed lecture links to `<deploy-url>/<path>.html`. `<path>` is the file's path without `.md`, and also without the `lectures-dir/` in front when `_toc.yml` is in `lectures-dir`, because Jupyter Book then builds the pages relative to it.

On any event but `pull_request`, such as `push`, `workflow_dispatch` or `schedule`, the action installs the CLI and does nothing else, and nothing in the log says so: the step succeeds, with an empty `deploy-url`. To know whether a preview was deployed, check `deploy-url`.

### What fails the job

- `npm ci` failing to install the pinned CLI.
- `netlify deploy` failing, or printing no deploy URL.
- The comment failing to post, for want of `pull-requests: write`.

## Security

Previews of pull requests from forks are not supported, and the action skips them. Do not run it from a `pull_request_target` workflow to get around that. A workflow triggered that way builds and runs the fork's notebooks with `NETLIFY_AUTH_TOKEN` and a write-scoped `GITHUB_TOKEN` within their reach, the pattern known as a "pwn request". It would not produce a preview either: the action deploys only on `pull_request` events.

## Troubleshooting

**`npm ci of the pinned netlify-cli failed — see the npm output above (it needs registry.npmjs.org)`.** The runner cannot reach the npm registry, or npm is missing.

**`netlify-cli installed but does not run — see the output above`.** Usually a Node older than 22.13. Set up Node 24 before this action.

**`netlify deploy failed (exit …) — see the Deployment Output group above`.** Netlify's own message is in that group. An authorisation error means the token is wrong, revoked or expired; a site that cannot be found means `NETLIFY_SITE_ID` is wrong. Check also that `build-dir` exists.

**`Resource not accessible by integration`, when commenting.** The job lacks `pull-requests: write`.

**The comment lists no changed lectures.** The pull request adds or modifies no `.md` file under `lectures-dir`, other than `intro.md` and files starting with `_`, or `lectures-dir` names the wrong directory. In a container job, git must also be able to read the checkout: `build-lectures` makes git trust it for the rest of the job, so run this action after it, or trust the workspace yourself with `git config --global --add safe.directory "$GITHUB_WORKSPACE"`.

**A lecture link leads to a missing page.** The links assume Jupyter Book's layout: pages relative to `lectures-dir` when `_toc.yml` is inside it, and relative to the repository root when it is not.

**Two comments on each pull request, one of them from Netlify.** The Netlify site is linked to the repository: see the end of [Setting up Netlify](#setting-up-netlify).

**A pull request from a fork got no preview.** Expected: its runs get no secrets, so the action skips them. See [Security](#security).
