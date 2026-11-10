# preview-workers

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Uploads a pull request's built site to an existing Cloudflare Worker as a preview: a new version of the Worker, with the alias `pr-<number>` pointed at it, so the preview's URL, `https://pr-<number>-<worker-name>.<account-subdomain>.workers.dev`, stays the same for every push to the pull request. Each version also gets a URL of its own, which goes on showing that one push. The upload never changes what the Worker serves in production. The action then posts one comment on the pull request, and updates it on each later push, with:

- the preview URL and the commit it shows;
- under "Changed Lectures", a link to the page of each lecture that differs between the pull request and its base branch;
- under "Build Info", a link to the workflow run, and the URL of this push's own version.

With `placeholder: 'true'`, in a job of its own, it uploads nothing and posts that comment within seconds of a push instead, before the build has finished, and the deploy's comment later replaces it: see [Before the build](#before-the-build).

It deploys on `pull_request` events, and skips pull requests from forks and from Dependabot, whose runs get no secrets. With `dispatch-alias` set, it also deploys a `workflow_dispatch` or `schedule` run's build, to that alias and with no comment: see [Outside a pull request](#outside-a-pull-request). On any other event it deploys nothing, and says why in a notice. Its `deployed` output tells the workflow which happened.

## When to use it

Use it in a job of its own that deploys a pull request's build, in place of the Netlify step in [`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml)'s `deploy` job, which carries this step as a comment. The build job runs [`build-lectures`](build-lectures.md) and uploads the site as an artifact, and the deploy job downloads it and runs this action, so that only the deploy job, which runs no notebook code, holds the Cloudflare token: see [A build job and a deploy job](#a-build-job-and-a-deploy-job).

- **Or on Cloudflare Pages, or Netlify.** [`preview-cloudflare`](preview-cloudflare.md) does the same on a Cloudflare Pages project, and [`preview-netlify`](preview-netlify.md) on Netlify, which is the one `ci.yml` uses. The three post the same comment, each with its own heading, and decide whether to deploy by the same rules.
- **Not to publish the site.** [`publish-gh-pages`](publish-gh-pages.md) publishes to GitHub Pages, and [`deploy-cloudflare`](deploy-cloudflare.md) publishes a site to a Worker's production URL, checking who can see it. This action never deploys to production.
- **To check the preview outside a pull request**, from a scheduled or dispatched run, set `dispatch-alias`: see [Outside a pull request](#outside-a-pull-request).

## Requirements

- **Runner.** Any, with `bash`, `git` and `npm`, as GitHub-hosted runners and the QuantEcon images have. The job must be able to reach `registry.npmjs.org`: `wrangler` is installed each run from the lockfile beside the action.
- **Node.** 22 or later, which the pinned `wrangler` needs. The QuantEcon images carry Node 24. On a standard runner, set it up before this action with `actions/setup-node`, as in [preview-netlify's example](preview-netlify.md#on-a-standard-runner).
- **Permissions.** `pull-requests: write`, for the comment. The job also needs `contents: read` for `actions/checkout`. A run outside a pull request posts no comment, so it needs only `contents: read`. A placeholder's job needs the same two, and no checkout: `pull-requests: write` for the comment and the pull request's changed files, and `contents: read` to look for `_toc.yml`.
- **Secrets.** `CLOUDFLARE_WORKERS_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, from [Setting up a Cloudflare Worker](#setting-up-a-cloudflare-worker). A placeholder needs neither, only `worker-name` and `account-subdomain`.
- **Files in your repository.** None beyond the built site: the action writes the Worker's wrangler configuration for each run. The comment's lecture links are found as [preview-cloudflare's](preview-cloudflare.md#requirements) are, from the pull request's history, and the same notes on shallow checkouts and private repositories apply.
- **Setup outside GitHub.** A Cloudflare Worker and a token for it, once: see [Setting up a Cloudflare Worker](#setting-up-a-cloudflare-worker).

## Setting up a Cloudflare Worker

1. **A Cloudflare account,** with a `workers.dev` subdomain. The dashboard's **Workers & Pages** overview shows it, as `<account-subdomain>.workers.dev`. That part before `.workers.dev` is the `account-subdomain` input.
2. **Create the Worker by hand, under its final name,** as a placeholder that holds no site, such as the dashboard's Hello World template. Its name is the `worker-name` input. The action uploads only new versions, and never creates a Worker: `wrangler versions upload` refuses a Worker that does not exist. What the Worker serves in production stays the placeholder, at `https://<worker-name>.<account-subdomain>.workers.dev`.
   - **Keep its preview URLs on,** in the Worker's **Settings**, under **Domains & Routes**. A version is served at its preview URLs only while they are on, and an upload does not turn them on: with them off, the upload fails the job, since its preview would not load.
   - **Its name's length.** A preview's hostname starts `<alias>-<worker-name>`, which Cloudflare requires to fit in 63 characters. A name of up to 54 characters leaves room for every pull request up to number 99999, and one of up to 34 for the longest `dispatch-alias`.
3. **Find the account ID.** It is in the dashboard's URL, `https://dash.cloudflare.com/<account-id>/…`, and on the **Workers & Pages** overview.
4. **Create an account-owned API token for this one Worker.** Under **Manage account**, **Account API tokens**, **Create token**, give it **Individual Workers Editor**, scoped to **Specified Workers** and this Worker alone. Copy it when it is shown: Cloudflare shows it only once. A token made under **My Profile** cannot be scoped to one Worker. This one can upload versions of this Worker but no other, and cannot create a Worker.
5. **Add both as repository secrets**, under the repository's **Settings**, **Secrets and variables**, **Actions**:

   | Secret | Value |
   |---|---|
   | `CLOUDFLARE_WORKERS_TOKEN` | the token from step 4 |
   | `CLOUDFLARE_ACCOUNT_ID` | the account ID from step 3 |

   The Worker's name and the account subdomain are not secret. A repository can keep them as variables, under the same page's **Variables** tab, and pass `${{ vars.… }}`, or write them into the workflow.

The previews then appear at these URLs:

| Version | URL |
|---|---|
| Pull request 5, newest push | `https://pr-5-<worker-name>.<account-subdomain>.workers.dev` |
| One push | `https://<first 8 characters of the version ID>-<worker-name>.<account-subdomain>.workers.dev` |
| The newest scheduled or dispatched run with `dispatch-alias: dispatch-canary` | `https://dispatch-canary-<worker-name>.<account-subdomain>.workers.dev` |
| The Worker's production URL, which the action leaves alone | `https://<worker-name>.<account-subdomain>.workers.dev` |

Who can open them is the Worker's to say: they are public unless the Worker is behind Cloudflare Access, which the action neither sets up nor checks.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from preview-workers/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `cloudflare-api-token` | no | `''` | An account-owned Cloudflare API token that can edit this one Worker, from a repository secret such as `secrets.CLOUDFLARE_WORKERS_TOKEN`. Required for a deploy: a run that would deploy without it fails before anything is installed. Leave it out with `placeholder: 'true'`. |
| `cloudflare-account-id` | no | `''` | The ID of the Cloudflare account that owns the Worker, from a repository secret such as `secrets.CLOUDFLARE_ACCOUNT_ID`. Required for a deploy, as `cloudflare-api-token` is. Leave it out with `placeholder: 'true'`. |
| `worker-name` | yes | none | The Worker to upload each preview to, which must already exist with its preview URLs on: lowercase letters, digits and dashes, not starting or ending with a dash. A preview's hostname starts `<alias>-<worker-name>`, which must fit in 63 characters, so a name of up to 54 characters leaves room for every pull request up to number 99999. `placeholder: 'true'` needs it too. |
| `account-subdomain` | yes | none | The account's `workers.dev` subdomain: `my-subdomain` for `*.my-subdomain.workers.dev`, which `my-subdomain.workers.dev` also gives. The preview URLs are built from it, and checked against the URL Cloudflare reports for each upload. `placeholder: 'true'` needs it too. |
| `build-dir` | no | `''` | The directory that holds the built site, such as `_build/html`, which `build-lectures` gives in its `build-path` output. Required for a deploy, as `cloudflare-api-token` is. |
| `lectures-dir` | no | `lectures` | The directory of lecture `.md` files that change detection looks in, as a path from the repository root such as `lectures`, with no `./` or trailing slash: each lecture the pull request added or modified gets a link in the comment, and is listed in `changed-files`. Empty turns change detection off, and the comment gives only the preview URL. |
| `dispatch-alias` | no | `''` | Deploys on `workflow_dispatch` and `schedule` events too, to this alias, such as `dispatch-canary`, at `https://<alias>-<worker-name>.<account-subdomain>.workers.dev`. It must start with `dispatch-`, which keeps it clear of every pull request's `pr-<number>`, and be lowercase letters and digits in words joined by single dashes, at most 28 characters in all, and `<alias>-<worker-name>` must fit in 63 characters. Any other value fails the job, on every event. Such a run has no comment and no changed lectures, and a pull request ignores the input. Empty, the default, deploys on `pull_request` only. |
| `placeholder` | no | `false` | `'true'` posts the pull request's preview comment at once, before there is a build to deploy, and deploys nothing. The comment has the preview's URL and links to the lectures the pull request changes, all built from its number, `worker-name` and `account-subdomain`, and says that they show the last deployed push until this one's deploy finishes; the deploy's comment then replaces it. It needs no checkout and no secret, so it runs in a job of its own, with no `needs:`. It posts only where a deploy would run, so not for a pull request from a fork or by Dependabot, nor on any other event. Any value but `'true'` or `'false'` fails the job. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from preview-workers/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `deployed` | `'true'` when this run deployed a preview, so that `deploy-url` is set, and `'false'` when it did not: then a notice or a warning in the log says why, or `placeholder` is `'true'`. A scheduled or dispatched check should assert `deployed == 'true'`, or it passes without testing the deploy. |
| `deploy-url` | The pull request's preview URL, `https://pr-<number>-<worker-name>.<account-subdomain>.workers.dev`, which always shows its newest push, so use it for anything a person will follow; on a `workflow_dispatch` or `schedule` run, `https://<dispatch-alias>-<worker-name>.<account-subdomain>.workers.dev`. It is built from the inputs, and set only when wrangler's record of the upload names the same URL: one that names another, or none, fails the job. When wrangler writes no record, it is set unchecked, with a warning. Empty when nothing was deployed. |
| `deployment-url` | The URL of this one version, `https://<first 8 characters of the version ID>-<worker-name>.<account-subdomain>.workers.dev`, which goes on showing this push after later ones, for as long as Cloudflare keeps the version. It is read from wrangler's record of the upload. Empty when the record does not name it in that form, and when nothing was deployed. |
| `changed-files` | The lecture files under `lectures-dir` that the pull request added or modified, one path per line, compared from the commit where it branched off. When a shallow checkout's history does not reach that commit within 1,024 commits, the comparison starts from the base branch's tip instead, with a warning, so a lecture changed only on the base branch is listed too. When git fails, the action warns and lists none. Empty when there are none, with `lectures-dir: ''`, on an event other than `pull_request`, for a pull request from a fork or by Dependabot, and with `placeholder: 'true'`. |

<!-- END GENERATED -->

## Examples

### A build job and a deploy job

A pull request's build in a container, and its deploy as a preview from a second job, which is the only one that holds the token. The build runs notebook code, so it gets no secrets and only read access, and the deploy job runs no notebook or repository code. [preview-netlify's example](preview-netlify.md#a-build-job-and-a-deploy-job) explains each step.

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
      - uses: quantecon/actions/preview-workers@v0
        with:
          cloudflare-api-token: ${{ secrets.CLOUDFLARE_WORKERS_TOKEN }}
          cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          worker-name: my-lectures
          account-subdomain: my-subdomain
          build-dir: _build/html
```

The deploy job is skipped when the build fails. A branch rule that requires the deploy to pass must therefore require `build` as well, because GitHub counts a skipped required check as passed.

### Outside a pull request

A scheduled or dispatched run deploys only with `dispatch-alias` set, here to `https://dispatch-canary-my-lectures.my-subdomain.workers.dev`, which always shows the newest such run. Check `deployed`: a run that deployed nothing still passes. In a workflow like [preview-netlify's](preview-netlify.md#outside-a-pull-request), the deploy job's last steps are:

```yaml
- uses: quantecon/actions/preview-workers@v0
  id: preview
  with:
    cloudflare-api-token: ${{ secrets.CLOUDFLARE_WORKERS_TOKEN }}
    cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    worker-name: my-lectures
    account-subdomain: my-subdomain
    build-dir: _build/html
    dispatch-alias: dispatch-canary
- name: Fail unless the preview was deployed
  if: steps.preview.outputs.deployed != 'true'
  run: |
    echo "::error::no preview was deployed"
    exit 1
```

### Before the build

A job with `placeholder: 'true'` posts the preview comment within seconds of a push, before the build has finished, as [preview-netlify's](preview-netlify.md#before-the-build) does. It needs `worker-name` and `account-subdomain`, which give the preview's URL, and no secret:

```yaml
  placeholder:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: quantecon/actions/preview-workers@v0
        with:
          placeholder: 'true'
          worker-name: my-lectures
          account-subdomain: my-subdomain
```

Its comment is headed `## ⏳ Cloudflare Workers Preview Building…`, and the deploy job's comment then replaces it in place. Before a pull request's first deploy, its links answer 404, as the comment says.

### In the templates

[`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) carries this action as a commented alternative to the `preview-netlify` step in its `deploy` job, and in its `placeholder` job. To use it, replace each of those steps with the comment's, set `worker-name` and `account-subdomain` in both, and add the two secrets. The `build` job stays as it is.

## Behaviour

1. **Whether to deploy.** The action decides first, by the same rules as [preview-netlify](preview-netlify.md#behaviour), and every later step follows the decision. It deploys a pull request from this repository to the alias `pr-<number>`, and a `workflow_dispatch` or `schedule` run with `dispatch-alias` set to the alias that input names; anything else, such as a pull request from a fork, any run by Dependabot, a `push` or a `pull_request_target`, deploys nothing. A run that deploys nothing stops here: it installs nothing, sets `deployed` to `'false'`, passes, and says why in a notice, such as `No Cloudflare Workers preview deployed: pull requests from forks get no secrets.` On `pull_request_target` the message is a warning, because of [Security](#security).
2. **The inputs.** On every event, `worker-name` must be a hostname label, `account-subdomain` must give one, and a `dispatch-alias` must fit in one hostname label with the Worker's name, so that a mistake shows on the next pull request. For a run that will deploy, `pr-<number>` must fit too, and a deploy needs `cloudflare-api-token`, `cloudflare-account-id` and `build-dir`. Each refusal fails the job before anything is installed.
3. **Changed lectures.** On a `pull_request` event with `lectures-dir` set, the action lists the lectures the pull request added or modified, compared from the commit where it branched off its base branch, by the same rules as [preview-netlify](preview-netlify.md#behaviour).
4. **The CLI.** The `wrangler` version pinned in the action's [`package.json`](https://github.com/QuantEcon/actions/blob/main/preview-workers/package.json) is installed with `npm ci`, into a temporary directory. It is not added to the job's `PATH`.
5. **The upload.** The action writes a wrangler configuration naming the Worker and `build-dir`'s absolute path as its static assets, the same configuration [`deploy-cloudflare`](deploy-cloudflare.md) deploys with, then runs:

   ```text
   wrangler versions upload --config <generated config> --preview-alias <alias> --message "<run> (<short commit>)"
   ```

   `<alias>` is `pr-<number>` or `dispatch-alias`, as step 1 decided. `<run>` is `PR #<number>`, or the event and branch, such as `workflow_dispatch on main`, and `<short commit>` is the first 7 characters of the commit. The token and the account ID reach the CLI through the environment. `versions upload` makes a new version and points the alias at it; sending production traffic to a version is `wrangler versions deploy`, which the action never runs. wrangler's output is in the "Upload Output" log group.
6. **The URLs.** `deploy-url` is built from the inputs, `https://<alias>-<worker-name>.<account-subdomain>.workers.dev`, which is the URL the placeholder's comment links to as well. wrangler appends a record of the upload to the file the step names in `WRANGLER_OUTPUT_FILE_PATH`, and its `version-upload` line names the URLs Cloudflare serves the alias and the version at. The log prints it, in the "wrangler's record of the upload" group. The action checks the built URL against it:
   - the same URL: `deploy-url` is set, and `deployment-url` is the record's version URL, when it is of the form in the Outputs table;
   - another URL, which a wrong `account-subdomain` gives: the job fails;
   - no URL, which a Worker with its preview URLs off gives: the job fails;
   - no record at all: `deploy-url` is set unchecked, `deployment-url` is empty, and the step warns.

   Outside a pull request, the preview's URL also goes in a notice, on the run's summary page.
7. **The comment**, on a pull request only. The action finds its own comment among all of the pull request's comments, and updates it, as [preview-netlify](preview-netlify.md#behaviour) does; if it has none, it posts a new one. Its own is a comment by `github-actions[bot]` that starts with the hidden line `<!-- quantecon-preview:workers -->`, or with `## ☁️ Cloudflare Workers Preview Ready!`. It never edits anyone else's comment, nor `preview-cloudflare`'s, so a repository moving from Pages to Workers keeps its Pages comment on its open pull requests beside the new one. Under Build Info, a "This deployment" line gives `deployment-url`, when there is one.
8. **With `placeholder: 'true'`**, the action decides, checks its inputs, installs nothing, uploads nothing and posts the pending comment, as [preview-netlify](preview-netlify.md#behaviour) does. Its preview URL is the one step 6 builds. It has no "This deployment" line, since there is no version yet.

To know whether a preview was deployed, check `deployed`. A scheduled or dispatched check should fail unless it is `'true'`, as in [Outside a pull request](#outside-a-pull-request): otherwise a run that deployed nothing, because `dispatch-alias` was left out, say, passes having tested nothing.

### What fails the job

- A `dispatch-alias` other than `dispatch-` followed by lowercase letters and digits in words joined by single dashes, at most 28 characters in all, or one that does not fit in one hostname label with `worker-name`, on any event.
- A `placeholder` other than `'true'` or `'false'`, on any event.
- A `worker-name` or `account-subdomain` that is not a hostname label, on any event.
- A run that would deploy, with a `worker-name` too long for `pr-<number>`, or without `cloudflare-api-token`, `cloudflare-account-id` or `build-dir`, before anything is installed.
- `npm ci` failing to install the pinned CLI, or the installed CLI failing to run.
- A `build-dir` that is not a directory.
- `wrangler versions upload` failing.
- wrangler's record of the upload naming another preview URL than `deploy-url`, or none.
- The comment failing to post, for want of `pull-requests: write`.

## Security

Previews of pull requests from forks are not supported, and the action skips them. Do not run it from a `pull_request_target` workflow to get around that: see [preview-cloudflare's Security](preview-cloudflare.md#security), which applies here too. The action never deploys on `pull_request_target`, and warns instead.

The token from [step 4](#setting-up-a-cloudflare-worker) can upload versions of one Worker, and deploy them to its production URL, but reaches no other Worker and cannot create one. Keep it in the deploy job, which runs no notebook code, as the examples do.

`dispatch-alias` does not widen who can deploy. A `workflow_dispatch` run needs write access to the repository, and a `schedule` run uses the workflow on the default branch, so either already has the repository's secrets.

## Troubleshooting

**`npm ci of the pinned wrangler failed — see the npm output above (it needs registry.npmjs.org)`.** The runner cannot reach the npm registry, or npm is missing.

**`wrangler installed but does not run — see the output above`.** Usually a Node older than 22. Set up Node 24 before this action.

**`A deploy needs cloudflare-api-token, cloudflare-account-id and build-dir, and this run has no …`.** The step does not pass them, or the repository has no such secret, which then reads as empty. A run that deploys nothing, such as a fork's pull request, is not checked. A placeholder's step needs none of the three: give it `placeholder: 'true'`.

**`cloudflare-api-token is not used with placeholder: 'true'`, or `cloudflare-account-id`, in a warning.** Take it out of the placeholder's step, so that its job holds no deploy secret. The comment is posted either way.

**`worker-name […] is not a valid workers.dev hostname label` or `account-subdomain […] is not a workers.dev subdomain`.** `worker-name` is the Worker's name as the dashboard shows it, and `account-subdomain` the part of its URL between the first `.` and `.workers.dev`.

**`… is too long for this preview` or `dispatch-alias […] is too long for this Worker`.** Cloudflare serves a preview at `<alias>-<worker-name>`, which must fit in 63 characters: use a shorter `dispatch-alias`, or a Worker with a shorter name.

**`wrangler versions upload failed (exit …) — see the Upload Output group above`.** wrangler's own message is in that group.

- An authentication or permission error: the token cannot edit this Worker, has expired, or belongs to another account than `CLOUDFLARE_ACCOUNT_ID`.
- `You cannot upload a new version of a Worker that does not yet exist`: `worker-name` must match the Worker's name exactly, in the account that `CLOUDFLARE_ACCOUNT_ID` names. Create the Worker first, as in [step 2](#setting-up-a-cloudflare-worker).

**`wrangler uploaded the version, but Cloudflare named no preview URL for it`.** The Worker's preview URLs are off, so the alias does not serve the new version. Turn them on, in the Worker's **Settings** under **Domains & Routes**, and run the job again.

**`Cloudflare serves this preview at […], not at …, which the inputs give`.** `account-subdomain` is wrong: the URL in the brackets is the right one, and its part before `.workers.dev`, after the Worker's name, is the account subdomain. The placeholder's links use the same input, so they were wrong too.

**`wrangler wrote no record of the upload`, in a warning.** The upload succeeded, but the pinned wrangler wrote no `version-upload` record of it, which would mean it has changed what it writes. `deploy-url` is then built from the inputs unchecked, and `deployment-url` is empty. It is a bug in the action: report it at [QuantEcon/actions](https://github.com/QuantEcon/actions/issues), with the warning and the Upload Output group.

**The preview URL answers 404.** A new alias can take a few seconds to appear; if the 404 lasts, check that `build-dir` holds an `index.html`. Before a pull request's first deploy, the placeholder's links answer 404 too.

**`Resource not accessible by integration`, when commenting.** The job lacks `pull-requests: write`.

**The comment lists no changed lectures, lists one the pull request did not change, or a link leads to a missing page.** See [preview-netlify's troubleshooting](preview-netlify.md#troubleshooting): the preview actions detect and link lectures the same way.

**The comment still says "Cloudflare Workers Preview Building…".** See [preview-netlify's troubleshooting](preview-netlify.md#troubleshooting).

**`No Cloudflare Workers preview deployed: …`, in a notice, or `dispatch-alias […] must be dispatch- followed by …`.** See [preview-netlify's troubleshooting](preview-netlify.md#troubleshooting): the preview actions decide whether to deploy the same way.

**A dispatched or scheduled run deployed, but posted no comment.** Expected: there is no pull request to comment on. The URL is in `deploy-url`, and in a notice on the run's summary page.

**`worker-name must be a single line`, `account-subdomain must be a single line`, `build-dir must be a single line` or `lectures-dir must be a single line`.** Each is one value, and a line break would end the line that prints it, and the runner reads a next line that starts with `::` as a workflow command. So the action fails in its first step, before it has done anything. A YAML block scalar (`|`), or an expression whose value spans lines, puts one there: write the value on one line. See [Security](../security.md#what-the-actions-themselves-do).
