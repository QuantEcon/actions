# preview-netlify

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Deploys a pull request's built site to a Netlify site as a preview, under the alias `pr-<number>`, so the preview's URL, `https://pr-<number>--<site>.netlify.app`, stays the same for every push to the pull request. It then posts one comment on the pull request, and updates it on each later push, with:

- the preview URL and the commit it shows;
- under "Changed Lectures", a link to the page of each lecture that differs between the pull request and its base branch;
- under "Build Info", a link to the workflow run.

It deploys on `pull_request` events, and skips pull requests from forks and from Dependabot, whose runs get no secrets. With `dispatch-alias` set, it also deploys a `workflow_dispatch` or `schedule` run's build, under that alias and with no comment: see [Outside a pull request](#outside-a-pull-request). On any other event it deploys nothing, and says why in a notice. Its `deployed` output tells the workflow which happened. The Netlify site's production deploy is never touched.

Netlify's dashboard calls a site a *project*. The action's input and secret keep the word *site*: `netlify-site-id` and `NETLIFY_SITE_ID` take the project's ID.

## When to use it

Use it in a job of its own that deploys a pull request's build, as [`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) does: the build job runs [`build-lectures`](build-lectures.md) and uploads the site as an artifact, and the deploy job downloads it and runs this action. Building runs notebook code, which can reach anything the job holds, so only the deploy job should hold the Netlify token: see [A build job and a deploy job](#a-build-job-and-a-deploy-job). The action also works as a step after `build-lectures` in the same job, as it always has.

- **Not to publish the site.** [`publish-gh-pages`](publish-gh-pages.md) publishes to GitHub Pages, and [`deploy-cloudflare`](deploy-cloudflare.md) publishes a site that only members may see.
- **Or on Cloudflare.** [`preview-cloudflare`](preview-cloudflare.md) does the same on Cloudflare Pages. The table below compares the two.
- **To check the preview outside a pull request**, from a scheduled or dispatched run, set `dispatch-alias`: see [Outside a pull request](#outside-a-pull-request).

### Netlify or Cloudflare?

| | `preview-netlify` | `preview-cloudflare` |
|---|---|---|
| Preview URL | `https://pr-<number>--<site>.netlify.app` | `https://pr-<number>.<project-name>.pages.dev` |
| A URL for each push | not reported, though Netlify keeps one for each deploy | yes, in `deployment-url` and in the comment |
| Repository secrets | `NETLIFY_AUTH_TOKEN`, `NETLIFY_SITE_ID` | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` |
| Other inputs it needs | none | `project-name` |
| CLI, installed each run | `netlify-cli`, which needs Node 22.13 or later | `wrangler`, which needs Node 22 or later |
| In `ci.yml` | the `deploy` job's preview step | a commented alternative |

Both deploy the files `build-lectures` built, with no build on the provider's side, and neither needs the provider to be linked to the repository. For what each provider's plans allow, see its pricing page.

## Requirements

- **Runner.** Any, with `bash`, `git`, `python3` and `npm`, as GitHub-hosted runners and the QuantEcon images have. The job must be able to reach `registry.npmjs.org`: `netlify-cli` is installed each run from the lockfile beside the action.
- **Node.** 22.13 or later, which the pinned `netlify-cli` needs. The QuantEcon images carry Node 24. On a standard runner, set it up before this action with `actions/setup-node`; see [On a standard runner](#on-a-standard-runner).
- **Permissions.** `pull-requests: write`, for the comment. The job also needs `contents: read` for `actions/checkout`. A run outside a pull request posts no comment, so it needs only `contents: read`.
- **Secrets.** `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID`, from [Setting up Netlify](#setting-up-netlify).
- **Files in your repository.** None beyond the built site. The comment's lecture links compare the pull request's head with the commit where it branched off its base branch. A checkout with `fetch-depth: 0` has that commit, and nothing is fetched. From a shallow checkout, such as `actions/checkout`'s default of one commit, the action fetches history until it finds it, up to 1,024 commits behind the pull request's base and head: see [Behaviour](#behaviour). That fetch uses whatever credentials `actions/checkout` left in the checkout, and with `persist-credentials: false`, as `ci.yml` sets, it has none. A public repository needs none. A private repository checks out with `fetch-depth: 0`, so that nothing is fetched.
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
| `lectures-dir` | no | `lectures` | The directory of lecture `.md` files that change detection looks in, as a path from the repository root such as `lectures`, with no `./` or trailing slash: each lecture the pull request added or modified gets a link in the comment, and is listed in `changed-files`. Empty turns change detection off, and the comment gives only the preview URL. |
| `dispatch-alias` | no | `''` | Deploys on `workflow_dispatch` and `schedule` events too, to this alias, such as `dispatch-canary`, at `https://<alias>--<site>.netlify.app`. It must start with `dispatch-`, which keeps it clear of every pull request's `pr-<number>`, and be lowercase letters and digits in words joined by single dashes, at most 28 characters in all. Any other value fails the job, on every event. Such a run has no comment and no changed lectures, and a pull request ignores the input. Empty, the default, deploys on `pull_request` only. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from preview-netlify/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `deployed` | `'true'` when this run deployed a preview, so that `deploy-url` is set, and `'false'` when it did not, and then a notice or a warning in the log says why. A scheduled or dispatched check should assert `deployed == 'true'`, or it passes without testing the deploy. |
| `deploy-url` | The preview's URL, `https://pr-<number>--<site>.netlify.app`, the same for every push to the pull request, or `https://<dispatch-alias>--<site>.netlify.app` on a `workflow_dispatch` or `schedule` run. Empty when nothing was deployed. |
| `changed-files` | The lecture files under `lectures-dir` that the pull request added or modified, one path per line, compared from the commit where it branched off. When a shallow checkout's history does not reach that commit within 1,024 commits, the comparison starts from the base branch's tip instead, with a warning, so a lecture changed only on the base branch is listed too. When git fails, the action warns and lists none. Empty when there are none, with `lectures-dir: ''`, on an event other than `pull_request`, and for a pull request from a fork or by Dependabot. |

<!-- END GENERATED -->

## Examples

### A build job and a deploy job

A pull request's build in a container, and its deploy as a preview from a second job, which is the only one that holds the token. Building the lectures runs notebook cells, packages installed at build time and network fetches, and code that runs earlier in a job can reach what the job's later steps are given. So the build job has no secrets and only read access, and the deploy job runs no notebook or repository code. It checks out the repository only for the comment's links to changed lectures. Neither job leaves its token in git's config for later steps (`persist-credentials: false`). `upload-artifact` leaves out files whose names start with a dot unless told otherwise, so `include-hidden-files` makes the deploy publish every file the build wrote.

```yaml
name: Preview
on:
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon-build:latest
    permissions:
      contents: read
      packages: read         # the image pull, as the templates grant it
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - uses: quantecon/actions/setup-environment@v0
      - uses: quantecon/actions/build-lectures@v0
        id: build
      - uses: actions/upload-artifact@v7
        with:
          name: html
          path: ${{ steps.build.outputs.build-path }}
          include-hidden-files: true
          if-no-files-found: error

  deploy:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write   # the preview comment
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
          # fetch-depth: 0   # a private repository: see Requirements
      - uses: actions/setup-node@v7
        with:
          node-version: '24'
      - uses: actions/download-artifact@v8
        with:
          name: html
          path: _build/html
      - uses: quantecon/actions/preview-netlify@v0
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: _build/html
```

The deploy job is skipped when the build fails. A branch rule that requires the deploy to pass must therefore require `build` as well, because GitHub counts a skipped required check as passed.

### On a standard runner

The deploy job above runs on a standard runner, so it sets up Node before the action. Any job on a standard runner does the same:

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

### Outside a pull request

A scheduled or dispatched run deploys only with `dispatch-alias` set, here to `https://dispatch-canary--<site>.netlify.app`, which each run replaces. Check `deployed`: a run that deployed nothing still passes.

Start from the workflow in [A build job and a deploy job](#a-build-job-and-a-deploy-job), and change three things. It runs on a schedule or by hand, in place of `pull_request`:

```yaml
on:
  schedule:
    - cron: '0 6 * * 1'
  workflow_dispatch:
```

The deploy job needs only `contents: read`, since there is no pull request to comment on. Its last steps are:

```yaml
- uses: quantecon/actions/preview-netlify@v0
  id: preview
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: _build/html
    dispatch-alias: dispatch-canary
- name: Fail unless the preview was deployed
  if: steps.preview.outputs.deployed != 'true'
  run: |
    echo "::error::no preview was deployed"
    exit 1
```

### In the templates

[`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) builds each pull request in its `build` job and deploys it with this action from its `deploy` job, as in [A build job and a deploy job](#a-build-job-and-a-deploy-job), with `preview-cloudflare` as a commented alternative.

## Behaviour

1. **Whether to deploy.** The action decides first, and every later step follows the decision:

   | The run | Deploys to | Changed lectures and comment |
   |---|---|---|
   | `pull_request`, from this repository | `pr-<number>`, whatever `dispatch-alias` says | yes |
   | `workflow_dispatch` or `schedule`, with `dispatch-alias` set | `dispatch-alias` | no |
   | `pull_request` from a fork; any run by Dependabot | nothing | no |
   | `workflow_dispatch` or `schedule` without `dispatch-alias` | nothing | no |
   | any other event, such as `push` or `pull_request_target` | nothing | no |

   A run that deploys nothing stops here: it installs nothing, sets `deployed` to `'false'`, passes, and says why in a notice, such as `No Netlify preview deployed: pull requests from forks get no secrets.` On `pull_request_target` the message is a warning, because of [Security](#security). A `dispatch-alias` that breaks the input's rules fails the job, on every event.
2. **Changed lectures.** On a `pull_request` event with `lectures-dir` set, the action compares the pull request's head with the commit where it branched off its base branch, the merge base, as `git diff <base>...<head>` does. It lists each `.md` file under `lectures-dir` that was added or modified between them, except `<lectures-dir>/intro.md` and files whose path within `lectures-dir` starts with `_`. A renamed lecture counts as added; a deleted one is not listed. A lecture changed only on the base branch, after the pull request branched off, is not listed.
   - A shallow checkout may not have the merge base. The action then fetches the history behind the pull request's base and head, 64 commits behind each and then twice as many each time, until it finds the merge base. If it has not found it 1,024 commits behind each, or cannot fetch more, it logs a warning and compares from the tip of the base branch instead, so a lecture changed only on the base branch is listed too. A checkout that has the merge base, such as one with `fetch-depth: 0`, fetches nothing.
   - If git cannot read the checkout, fetch the two commits, or compare them, the action logs a warning with git's own message, lists no lectures, and goes on to deploy.
   - `lectures-dir` is matched against paths from the repository root, as git writes them: give it as `lectures`, not `./lectures` or `lectures/`, which match nothing. Lectures at the repository root cannot be listed.
3. **The CLI.** The `netlify-cli` version pinned in the action's [`package.json`](https://github.com/QuantEcon/actions/blob/main/preview-netlify/package.json) is installed with `npm ci`, into a temporary directory, and its `netlify` command is added to the `PATH` of the job's later steps.
4. **The deploy:**

   ```text
   netlify deploy --no-build --dir <build-dir> --alias <alias> --message "<run> (<short commit>)" --json
   ```

   `<alias>` is `pr-<number>` or `dispatch-alias`, as step 1 decided. `<run>` is `PR #<number>`, or the event and branch, such as `workflow_dispatch on main`. `<short commit>` is the first 7 characters of the pull request's head commit, or of the commit a dispatched or scheduled run is on. The token and the site ID reach the CLI through the environment. `--no-build` stops Netlify from running a build of its own, and without `--prod` the deploy is a preview, so the site's production deploy is untouched. Netlify's output is in the "Deployment Output" log group. Outside a pull request, the preview's URL also goes in a notice, on the run's summary page.
5. **The comment**, on a pull request only. The action reads all of the pull request's comments, and updates its own; if it has none, it posts a new one. Its own is a comment by `github-actions[bot]` that starts with the hidden line `<!-- quantecon-preview:netlify -->`, or with `## 📖 Netlify Preview Ready!`, as its comments did before that line was added. If there are several, it updates the newest. It never edits anyone else's comment, even one that quotes the preview's. Each changed lecture links to `<deploy-url>/<path>.html`. `<path>` is the file's path without `.md`, and also without the `lectures-dir/` in front when `_toc.yml` is in `lectures-dir`, because Jupyter Book then builds the pages relative to it.

   For a pull request that changes two lectures, the comment's Markdown is as follows. GitHub does not show its first line.

   ````markdown
   <!-- quantecon-preview:netlify -->
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

To know whether a preview was deployed, check `deployed`. A scheduled or dispatched check should fail unless it is `'true'`, as in [Outside a pull request](#outside-a-pull-request): otherwise a run that deployed nothing, because `dispatch-alias` was left out, say, passes having tested nothing.

### What fails the job

- A `dispatch-alias` other than `dispatch-` followed by lowercase letters and digits in words joined by single dashes, at most 28 characters in all, on any event.
- `npm ci` failing to install the pinned CLI, or the installed CLI failing to run.
- `netlify deploy` failing, or printing no deploy URL.
- The comment failing to post, for want of `pull-requests: write`.

## Security

Previews of pull requests from forks are not supported, and the action skips them. Do not run it from a `pull_request_target` workflow to get around that. A workflow triggered that way builds and runs the fork's notebooks with `NETLIFY_AUTH_TOKEN` and a write-scoped `GITHUB_TOKEN` within their reach, the pattern known as a "pwn request". It would not produce a preview either: the action never deploys on `pull_request_target`, whatever `dispatch-alias` says, and warns instead.

`dispatch-alias` does not widen who can deploy. A `workflow_dispatch` run needs write access to the repository, and a `schedule` run uses the workflow on the default branch, so either already has the repository's secrets.

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
- git cannot read the checkout, and the log has the warning `git cannot read the checkout, so no changed lectures are listed`, followed by git's message, such as `detected dubious ownership`. That happens in a container job whose image does not trust every directory; both QuantEcon images do. `build-lectures` makes git trust the checkout for the rest of the job, so run this action after it, or trust the workspace yourself with `git config --global --add safe.directory "$GITHUB_WORKSPACE"`.
- git cannot fetch the pull request's commits, and the log has the warning `Could not fetch the pull request's base and head commits`, followed by git's message. The action fetches with the credentials `actions/checkout` leaves in the checkout, so a shallow checkout of a private repository made with `persist-credentials: false`, as `ci.yml`'s is, cannot fetch. Check out with `fetch-depth: 0` instead, and nothing needs fetching.

**The comment lists a lecture the pull request did not change.** The log has the warning `Found no merge base within 1024 commits of the pull request's base and head`. The checkout is shallow, and the pull request branched off its base branch too long ago for the action to find where, so it compared from the base branch's tip: see [Behaviour](#behaviour). Update the pull request's branch from its base branch, or check out with `fetch-depth: 0`. With the warning `The pull request's base and head share no history`, the two have no commit in common.

**A lecture link leads to a missing page.** The links assume Jupyter Book's layout: pages relative to `lectures-dir` when `_toc.yml` is inside it, and relative to the repository root when it is not.

**Two comments on each pull request, one of them from Netlify.** The Netlify project is linked to the repository: see the end of [Setting up Netlify](#setting-up-netlify).

**A pull request from a fork got no preview.** Expected: its runs get no secrets, so the action skips them. See [Security](#security).

**`No Netlify preview deployed: …`, in a notice.** The run deployed nothing by design, and the rest of the message says why: see the table in [Behaviour](#behaviour). For a scheduled or dispatched run, set `dispatch-alias`.

**`dispatch-alias […] must be dispatch- followed by lowercase letters and digits …`.** Give a short lowercase name that starts with `dispatch-`, such as `dispatch-canary`: not `canary`, `dispatch_canary` or `Dispatch-Canary`. The job fails on this even on a pull request, which does not use the input, so that a typo shows before the first scheduled run.

**A dispatched or scheduled run deployed, but posted no comment.** Expected: there is no pull request to comment on. The URL is in `deploy-url`, and in a notice on the run's summary page.
