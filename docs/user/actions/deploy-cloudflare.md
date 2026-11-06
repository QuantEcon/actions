# deploy-cloudflare

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Publishes a built site to a Cloudflare Worker, and proves who can see it. Each workflow declares the site's audience with `visibility`:

- **`private`**: the Worker sits behind Cloudflare Access, for a site that only members of a GitHub team may see, such as a dashboard or a report. Access sends every visitor to a GitHub login first, and lets in only those its policy allows.
- **`public`**: the Worker serves the site to anyone.

The Worker must already exist: the action never creates one. Nor does it turn Access on or off. The Worker's Access setting in the Cloudflare dashboard decides who can see the site. What the action does is check that setting against `visibility`, and fail the job when the two disagree:

- **Before anything is uploaded**, an anonymous request to a private site's Worker must be redirected to your Access team's login. A public site's Worker must not be behind any Access. If the check fails, nothing is uploaded.
- **After the deploy**, the same must hold for production and for the new version's own preview URL, and for the alias after its upload, if you give one. A public site must now be served: its pages answer an anonymous request directly.

So a private site that turns out to be public fails, and so does a public site that turns out to be gated. The first line of the log and the heading of the job summary name the mode. The result goes to the job summary, since a deploy on a push, a schedule or a manual run has no pull request to comment on.

## When to use it

Use it to publish a site that must not be public, or a public site that belongs on a Worker.

- **For a public lecture site, prefer [`publish-gh-pages`](publish-gh-pages.md).** GitHub Pages remains the default for public sites. GitHub Pages serves every site publicly unless the organisation is on GitHub Enterprise Cloud, so a private site needs this action; a Worker behind Access can be private on Cloudflare's free plans. `visibility: public` is for a site that should live on Cloudflare anyway, such as a public companion to a private dashboard.
- **Not for pull-request previews.** [`preview-cloudflare`](preview-cloudflare.md) gives each pull request a preview on Cloudflare Pages.

## Requirements

- **Runner.** Any with `bash`, `curl` and `npm`, as GitHub-hosted runners and the QuantEcon images have. The job must be able to reach `registry.npmjs.org`, from which `wrangler` is installed each run.
- **Node.** 22 or later, for `wrangler`. The action sets up Node 24 itself when the runner has an older one or none. The QuantEcon images carry Node 24.
- **Permissions.** None of its own: the action calls no GitHub API. The job needs `contents: read` for `actions/checkout`.
- **Secrets.** `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, from the [setup checklist](#setup-checklist). Runs from forks and by Dependabot get no secrets, and the action then fails before it contacts anything.
- **Files in your repository.** None beyond the built site: the action writes the Worker's wrangler configuration itself, for each run.
- **Setup outside GitHub.** A Worker, behind Access for a private site, set up once by a Cloudflare admin: see the [setup checklist](#setup-checklist).

## Setup checklist

A public site needs only the steps marked *private and public*. The rest set up the Access gate.

### Once per Cloudflare account, for private sites

1. **A Zero Trust organisation.** The team name you choose gives the login domain `<team>.cloudflareaccess.com`, which is the `team-domain` input. The free plan covers up to 50 users.
2. **GitHub as the login method.** Create an OAuth App under the GitHub organisation's own settings, **Settings**, **Developer settings**, **OAuth Apps**, rather than under a personal account: an app that the organisation owns needs no approval under the organisation's OAuth app access restrictions. Give it:
   - Homepage URL: `https://<team>.cloudflareaccess.com`
   - Authorization callback URL: `https://<team>.cloudflareaccess.com/cdn-cgi/access/callback`

   Then add it in Zero Trust, under **Settings**, **Authentication**, **Login methods**, **GitHub**.
3. **Make GitHub the only login method.** A new Zero Trust account starts with *Cloudflare account membership* as a login method. Remove it.
4. **One reusable policy per audience.** Under **Access controls**, **Policies**, create an Allow policy with the **GitHub Organization** selector, your organisation, and a named team. Reference it from each application. Use a team rather than the whole organisation: an organisation's members usually include people a private site is not meant for, such as members who joined for a translation or a course. A session can last up to a month.

### Once per site

1. **Create the Worker by hand, under its final name** (*private and public*), as a placeholder that holds no data, such as the dashboard's Hello World template. Keep its `workers.dev` route on: the action deploys to `https://<worker-name>.<account-subdomain>.workers.dev`, and checks that URL. Creating a Worker needs Admin on the Workers product, which the deploy token deliberately lacks; see Cloudflare's [authorization docs](https://developers.cloudflare.com/workers/authorization/).
2. **Set the Worker's Access** (*private and public*).
   - **Private:** turn Access on for the Worker with *All traffic*, not *Previews only*. That covers the `workers.dev` hostname and every preview URL, and so every alias. A custom domain needs a check of its own: see [What the generated configuration means for the Worker](#what-the-generated-configuration-means-for-the-worker). Attach the reusable policy, and turn on instant authentication. Use this setting on the Worker, not the account-wide "Protect all Workers" switch, if the account also serves public sites.
   - **Public:** leave Access off for the Worker, and make sure the account-wide "Protect all Workers" switch is off too. Either would gate the site, and the action would then refuse to deploy it.
3. **Check the placeholder** (*private and public*) before the first real deploy, with [`check-access-gate.sh`](https://github.com/QuantEcon/actions/blob/main/scripts/check-access-gate.sh) from a clone of this repository. For a private site, prove the gate:

   ```bash
   bash scripts/check-access-gate.sh <team>.cloudflareaccess.com https://<worker-name>.<account-subdomain>.workers.dev/
   ```

   For a public site, prove it is served:

   ```bash
   bash scripts/check-access-gate.sh --public https://<worker-name>.<account-subdomain>.workers.dev/
   ```

   The action repeats the check before every deploy, and refuses to deploy if it fails, but checking now catches a setup mistake before any workflow depends on the site.
4. **Create the deploy token** (*private and public*): an account-owned API token with **Editor** on this one Worker, from Cloudflare's per-Worker roles, not the account-wide *Workers Scripts: Edit*. It can deploy this Worker but cannot create one, so a mistyped `worker-name` fails instead of creating a new Worker with nothing in front of it. For a private site the check before the upload refuses that case too, whatever the token can do. For a public site it does not, so the token is what stops it.
5. **Add the secrets to the repository** (*private and public*) that deploys the site, under **Settings**, **Secrets and variables**, **Actions**:

   | Secret | Value |
   |---|---|
   | `CLOUDFLARE_API_TOKEN` | the per-Worker token from step 4 |
   | `CLOUDFLARE_ACCOUNT_ID` | from the dashboard's URL, `https://dash.cloudflare.com/<account-id>/…`, or the **Workers & Pages** overview |

### Why the action does not do this setup itself

The Access application is set up once per Worker, and the login method once per account. Doing either from a workflow would put a token that can edit Access applications and policies into every repository that deploys, for a step that runs once. For the same reason the action cannot create the Worker: its token can deploy only to one that exists. An organisation that wants its Cloudflare account under code can manage the same settings with Terraform, whose resources `cloudflare_zero_trust_access_application` and `cloudflare_zero_trust_access_policy` cover them.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from deploy-cloudflare/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `cloudflare-api-token` | yes | none | An account-owned Cloudflare API token with Editor on this one Worker, from a repository secret such as `secrets.CLOUDFLARE_API_TOKEN`. It can deploy the Worker but not create one, so a mistyped `worker-name` fails instead of creating a new Worker that nothing gates. The job fails if the token is empty, as it is on runs from forks and by Dependabot. |
| `cloudflare-account-id` | yes | none | The ID of the Cloudflare account that owns the Worker, from a repository secret such as `secrets.CLOUDFLARE_ACCOUNT_ID`. The job fails if it is empty. |
| `worker-name` | yes | none | The Worker to deploy to, one per site: lowercase letters, digits and dashes, not starting or ending with a dash, at most 63 characters. It must already exist, with its `workers.dev` route on, and, for a private site, already be behind Access. |
| `account-subdomain` | yes | none | The account's `workers.dev` subdomain: `my-subdomain` for `*.my-subdomain.workers.dev`, which `my-subdomain.workers.dev` also gives. The URLs are built from it, never read from wrangler's output. |
| `visibility` | yes | none | Who may see the site: `private` or `public`. The site is checked against it before anything is uploaded, after the deploy, and on the alias after its upload. `private`: an anonymous request must be redirected to the Access login at `team-domain`, which is required. `public`: an anonymous request must be served the site, with no redirect to any Access login, and `team-domain` must be empty. Leaving it out, or any other value, fails the job. |
| `team-domain` | no | `''` | The Access team's login domain, `<team>.cloudflareaccess.com`; a bare `<team>` is accepted too. Required for a private site, whose every check requires an anonymous request to be redirected to exactly this host. Must be empty for a public site, so that a workflow copied from a private site fails rather than publish it. |
| `build-dir` | yes | none | The directory that holds the built site. The job fails if it is missing or holds no files, and warns if it has no `index.html`, since the site's root would then answer 404. A public site must hold an `index.html` or a file that is not HTML, for the check to request. |
| `alias` | no | `''` | Also uploads the same build as a named preview alias, such as `report-2026-08`, for a permanent URL beside the production one, which moves with each deploy. Lowercase letters, digits and dashes, starting with a letter and not ending with a dash, and `<alias>-<worker-name>` must fit in 63 characters. Empty, the default, uploads no alias. |
| `require-access` | no | `''` | Removed: use `visibility`. Any value but an empty one fails the job, with a message that says which `visibility` replaces it. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from deploy-cloudflare/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `deploy-url` | The production URL, `https://<worker-name>.<account-subdomain>.workers.dev`. Set once the deploy succeeds, even if the gate check after it then fails the job. |
| `alias-url` | The alias's URL, `https://<alias>-<worker-name>.<account-subdomain>.workers.dev`. Empty when no `alias` is given, or when its upload failed or did not run. |
| `visibility` | Who the site is checked as visible to: `private` or `public`, as `visibility` gives it. Set once every input is valid, even if a check then fails the job. Empty when an input is rejected. |

<!-- END GENERATED -->

Both URLs are built from `worker-name`, `account-subdomain` and `alias`, never read from wrangler's output.

## Examples

### Minimal

Rebuilds a members-only dashboard on each push to `main` and every morning, one deploy at a time:

```yaml
name: Publish members dashboard
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 6 * * *'
  workflow_dispatch:

concurrency:
  group: deploy-cloudflare-${{ github.workflow }}
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v7
      - name: Build
        run: ./build.sh   # writes the site to _site/
      - uses: quantecon/actions/deploy-cloudflare@v0
        with:
          cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          worker-name: members-dashboard
          account-subdomain: my-subdomain          # *.my-subdomain.workers.dev
          visibility: private
          team-domain: my-team.cloudflareaccess.com
          build-dir: _site
```

### A public site

The same, for a site anyone may see. There is no `team-domain`: setting one fails the job, since it is what a workflow copied from a private site would carry over.

```yaml
- uses: quantecon/actions/deploy-cloudflare@v0
  with:
    cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    worker-name: public-dashboard
    account-subdomain: my-subdomain
    visibility: public
    build-dir: _site
```

### A permanent URL for each month

A monthly report can keep each month's build at a URL of its own, beside the production URL, which always shows the latest:

```yaml
- name: Name this month's alias
  id: month
  run: echo "alias=report-$(date -u +%Y-%m)" >> "$GITHUB_OUTPUT"
- uses: quantecon/actions/deploy-cloudflare@v0
  with:
    cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    worker-name: monthly-report
    account-subdomain: my-subdomain
    visibility: private
    team-domain: my-team.cloudflareaccess.com
    build-dir: _build/html
    alias: ${{ steps.month.outputs.alias }}   # report-2026-08, for example
```

### In the templates

No template uses this action: a site on a Worker, private or public, is a choice made per site, not the default for a lecture repository.

## Behaviour

1. **Inputs.** Every input is checked before anything else runs. `visibility` is required, and must be `private` or `public`; `require-access`, which it replaced, is refused. `team-domain` must be an Access login domain for a private site and empty for a public one. The secrets must be set, the names must be valid hostname labels, and `build-dir` must hold at least one file. The action also picks the file to probe besides the site's root: see [The gate check](#the-gate-check). The first line of the log names the mode: `PRIVATE site, gated by <team>.cloudflareaccess.com` or `PUBLIC site, served anonymously`.
2. **The check before the deploy**, on the production URL. If it fails, the job fails with nothing uploaded.
   - **Private:** the URL must be gated. That refuses a Worker that does not exist, as a mistyped name would be, one that is public, and one gated by another Access organisation.
   - **Public:** the URL must not be behind any Access. That refuses a private site's Worker named by mistake, and a site declared public that is in fact gated, before anything is overwritten. A `404` passes here, since the version live now need not hold this build's files; a Worker that does not exist then fails at the deploy, because the token cannot create one.
3. **wrangler.** The action sets up Node 24 if the runner lacks Node 22 or later, and installs the `wrangler` version pinned in its [`package.json`](https://github.com/QuantEcon/actions/blob/main/deploy-cloudflare/package.json) with `npm ci`, into a temporary directory.
4. **The configuration.** It writes a wrangler configuration for this one run, with the Worker's name, a fixed compatibility date, `build-dir` as the assets directory, and `workers_dev` and `preview_urls` both on. It declares no routes.
5. **The deploy.** `wrangler deploy` publishes `build-dir` to production. Every version also gets its own preview URL, `https://<first 8 characters of the version ID>-<worker-name>.<account-subdomain>.workers.dev`, read from the `Current Version ID` line of wrangler's output.
6. **The check after the deploy**, on production and on the new version's preview URL: gated for a private site, served for a public one. It runs even when `wrangler deploy` fails, because wrangler can fail after the new version is already live.
7. **The alias**, if given, and only once the deploy and the check after it have passed: `wrangler versions upload --preview-alias <alias>` uploads the same build as a preview, then its URL is checked too.
8. **The job summary**, headed with the mode, gives each URL and the result of its check, or says why nothing was deployed. Production and the new version's preview URL share one result, that of the check after the deploy.

No input turns the checks off: every deploy is checked as `private` or `public`.

### The gate check

Each check is [`check-access-gate.sh`](https://github.com/QuantEcon/actions/blob/main/scripts/check-access-gate.sh), which sends an anonymous request and does not follow redirects: following one would land on the login page, which answers `200`, and a gated site would look the same as a public one. For a private site, the answer decides:

| Response | Verdict |
|---|---|
| `301`, `302`, `303`, `307` or `308`, to exactly `team-domain` | gated |
| A redirect to another `*.cloudflareaccess.com` | fails: gated by the wrong Access organisation |
| A redirect whose `Location` carries a user name or a backslash | fails: the real host is ambiguous, and Access never sends one |
| `2xx` | fails: **the site is public** |
| `404` | fails: no Worker answers on that hostname, or its `workers.dev` route is off |
| Anything else, or no answer | fails: the gate could not be verified |

For a public site, run with `--public`, the verdicts invert:

| Response | Verdict |
|---|---|
| `2xx` | served |
| A redirect to any `*.cloudflareaccess.com` | fails: **the site is behind Access** |
| Any other redirect | fails: the site was not served |
| `404` | fails after the deploy: the hostname does not serve this build. Passes before the deploy, where it shows only that nothing is gating the hostname |
| Anything else, or no answer | fails: the site could not be shown to be served |

Each check requests the site's root and one file from `build-dir` that is not HTML: the first in byte order with a URL-safe path, skipping any path with a part that starts with a dot, and the `_headers`, `_redirects` and `_worker.js` control files. If no file qualifies, only the root is requested. A gate that protected only the root would otherwise pass. Access covers every path on a hostname, so a correct gate redirects both.

A `build-dir` with no `index.html` answers `404` at its root, even when it is served. For a public site the checks after the deploy then request the file alone, and the root only before it. A public `build-dir` with neither an `index.html` nor a file that qualifies fails the job before anything runs, since nothing could show that it is served.

### What the generated configuration means for the Worker

- **Preview URLs are on** after every deploy, even if they were turned off in the dashboard, which is why the check after the deploy covers the new version's preview URL.
- **The deploy replaces the Worker's code**, such as the placeholder's script, without asking. Other settings changed in the dashboard can be overwritten too.
- **Custom domains** are a setting on the Worker in the dashboard. The configuration declares no routes, so a deploy leaves them alone. The action checks only the `workers.dev` hostname and preview URLs, so check a custom domain yourself with `check-access-gate.sh`, once it is attached and after any change to Access.
- **Dotfiles** in `build-dir`, such as Sphinx's `.buildinfo`, are uploaded like any other file, unless a `.assetsignore` file in `build-dir` lists them.

### Limits

On the free plan a Worker's static assets can hold 20,000 files per version, and 25 MiB per file; paid plans allow 100,000 files. A Worker keeps its 1,000 most recent preview aliases. A lecture-sized Jupyter Book is a few thousand files.

## Moving from `require-access`

`visibility` replaced `require-access`, which v0.12.0 shipped, and is required. A workflow that passes `require-access`, with any value but an empty one, fails in the action's first step, before anything is checked or uploaded. So does one that leaves out `visibility`, which `require-access`'s default used to make a private site.

| Your workflow passes | Change it to |
|---|---|
| neither input | `visibility: private` |
| `require-access: 'true'` | `visibility: private` |
| `require-access: 'false'`, for a public site | `visibility: public`, and remove `team-domain` |
| `require-access: 'false'`, for a gated site | `visibility: private` |
| both inputs | `visibility` alone |

`visibility: public` is not a renamed `require-access: 'false'`: it checks the site rather than skip the checks, and fails if the Worker is behind Access.

## Troubleshooting

**`visibility is required`.** Add `visibility: private` for a site behind Access, or `visibility: public`: see [Moving from `require-access`](#moving-from-require-access).

**`visibility must be private or public`.** Only those two values, in lower case.

**`require-access has been removed`.** Remove `require-access`. If the workflow already sets `visibility`, the message says to keep it. If not, it says which `visibility` replaces each value: see [Moving from `require-access`](#moving-from-require-access).

**`team-domain is set, but visibility is public`**, or **`visibility is private, so team-domain is required`.** Each kind of site refuses the other's `team-domain`, so that a workflow copied from a private site to a public one, or the reverse, fails rather than check the wrong thing. Pass `team-domain` for a private site only.

**`build-dir has no index.html and no file that is not HTML`.** For a public site, the check after the deploy needs something to request: the root, which answers `404` without an `index.html`, or another file. Add an `index.html`.

**`Refusing to deploy: … is not behind Access for …`.** Nothing was uploaded. The `FAIL` line above it says why:

- `answered 404`: no Worker by that name answers under `account-subdomain`, or its `workers.dev` route is off. Check both, and create the Worker first if it is new.
- `THE SITE IS PUBLIC`: Access is off for the Worker, or set to *Previews only*. Turn it on with *All traffic*.
- `the Worker is attached to the wrong Access organisation`: the Worker's Access application belongs to another Zero Trust team, or `team-domain` is wrong.
- `not to the Access login domain`: the site redirected elsewhere, sent no `Location`, or sent one whose host is ambiguous, so Access is not answering for this hostname. Check that Access is on with *All traffic*, and that `team-domain` is right.
- `expected a redirect to the Access login domain`: another status, such as `401`, `403` or a `5xx`. Check the Worker in the dashboard, then re-run the job.
- `could not be reached`: a network problem between the runner and Cloudflare. Re-run the job.

**`Refusing to deploy: visibility is public, but … did not answer an anonymous request as a public site`.** Nothing was uploaded. The `FAIL` line above it says why:

- `THE SITE IS BEHIND ACCESS`: the Worker is gated, by the Worker's own Access setting or the account-wide "Protect all Workers" switch. First check `worker-name`: it may name a private site's Worker. If the Worker is the right one, either turn its Access off, or, if the site is meant to be private, set `visibility: private` and `team-domain`.
- `instead of serving the site`, or another status: the Worker answered with something other than a page. Check it in the dashboard, then re-run the job.
- `could not be reached`: a network problem between the runner and Cloudflare. Re-run the job.

**`wrangler deploy failed (exit …)`.** wrangler's own error is printed above it. An authentication or permission error usually means the token lacks Editor on this Worker, the account ID is wrong, or the token has expired. wrangler can fail after the new version is live, so the job summary gives the check that ran after the failure.

**`A hostname serving this Worker is NOT behind Access for …`.** The urgent one: the new build is live, or may be, and an anonymous request to production or to the new version's preview URL was not redirected. The `FAIL` line above names the hostname. Turn Access on for the Worker with *All traffic*, which covers production and every preview URL, then re-run the job to confirm. Until you can, turn off both the Worker's `workers.dev` route and its preview URLs in the dashboard: with the route off, preview URLs stay on, and wrangler itself warns that they may be public. A re-run is then refused, with `answered 404`, until the route is back on.

**`wrangler's output named no 'Current Version ID'`.** The new version's preview URL could not be worked out, so it was not checked, and the check fails rather than pass unseen. wrangler prints the ID only once every step after the upload has succeeded, so this usually follows a failed `wrangler deploy`. After a successful one it means a wrangler update changed its output. Check the preview URL by hand with `check-access-gate.sh`, with the version ID from the dashboard.

**`The alias is uploaded but … is NOT behind Access for …`.** Production is gated but previews are not. Set the Worker's Access to *All traffic*, which covers preview URLs.

**`visibility is public, but a hostname serving this Worker did not serve the new build`.** The new build is deployed, but an anonymous request to production or to the new version's preview URL was not served it. The `FAIL` line above names the hostname. `THE SITE IS BEHIND ACCESS` means the Worker, or only its previews, is gated: turn Access off for it if the site is meant to be public, or set `visibility: private`. `answered 404` means the hostname does not serve this build: check that the Worker's `workers.dev` route and preview URLs are on. The same goes for **`The alias is uploaded, but visibility is public`**, for the alias's URL.

**An alias is refused before anything runs.** It must start with a lowercase letter and hold only lowercase letters, digits and dashes, and `<alias>-<worker-name>` must fit in 63 characters. Use `report-2026-08`, not `2026-08`.

**`cloudflare-api-token is empty`.** The secret is missing, or the run came from a fork or from Dependabot, which get no secrets.

**A blank page after access is granted.** On the first load after Access lets a visitor in, cached redirects can be served in place of the page's stylesheets, scripts and data. Reloading the page fixes it.

**A person added to the team is still refused.** Cloudflare documents that a user refused before joining can stay refused until they revoke the OAuth app in their GitHub settings, under **Applications**, and log in again.

**`<input> must be a single line`.** Every input but the two secrets is one value, and a line break would end the line that prints it, and the runner reads a next line that starts with `::` as a workflow command. So the action fails in its first step, before it has done anything. A YAML block scalar (`|`), or an expression whose value spans lines, puts one there: write the value on one line. See [Security](../security.md#what-the-actions-themselves-do).
