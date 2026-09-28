# deploy-cloudflare

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Publishes a built site to a Cloudflare Worker that sits behind Cloudflare Access, for a site that only members of a GitHub team may see, such as a dashboard or a report. Access sends every visitor to a GitHub login first, and lets in only those its policy allows.

The Worker must already exist and already be behind Access: the action never creates one, and never turns Access on. What it does is prove the gate works, and fail the job when it cannot:

- **Before anything is uploaded**, an anonymous request to the Worker must be redirected to your Access team's login. If it is not, nothing is uploaded.
- **After the deploy**, the same must hold for production and for the new version's own preview URL, and for the alias after its upload, if you give one.

The result goes to the job summary, since a deploy on a push, a schedule or a manual run has no pull request to comment on.

## When to use it

Use it to publish a site that must not be public.

- **Not for a public site.** [`publish-gh-pages`](publish-gh-pages.md) publishes to GitHub Pages, which serves every site publicly unless the organisation is on GitHub Enterprise Cloud. A Worker behind Access can be private on Cloudflare's free plans.
- **Not for pull-request previews.** [`preview-cloudflare`](preview-cloudflare.md) gives each pull request a preview on Cloudflare Pages.

## Requirements

- **Runner.** Any with `bash`, `curl` and `npm`, as GitHub-hosted runners and the QuantEcon images have. The job must be able to reach `registry.npmjs.org`, from which `wrangler` is installed each run.
- **Node.** 22 or later, for `wrangler`. The action sets up Node 24 itself when the runner has an older one or none. The QuantEcon images carry Node 24.
- **Permissions.** None of its own: the action calls no GitHub API. The job needs `contents: read` for `actions/checkout`.
- **Secrets.** `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, from the [setup checklist](#setup-checklist). Runs from forks and by Dependabot get no secrets, and the action then fails before it contacts anything.
- **Files in your repository.** None beyond the built site: the action writes the Worker's wrangler configuration itself, for each run.
- **Setup outside GitHub.** A Worker behind Access, set up once by a Cloudflare admin: see the [setup checklist](#setup-checklist).

## Setup checklist

### Once per Cloudflare account

1. **A Zero Trust organisation.** The team name you choose gives the login domain `<team>.cloudflareaccess.com`, which is the `team-domain` input. The free plan covers up to 50 users.
2. **GitHub as the login method.** Create an OAuth App under the GitHub organisation's own settings, **Settings**, **Developer settings**, **OAuth Apps**, rather than under a personal account: an app that the organisation owns needs no approval under the organisation's OAuth app access restrictions. Give it:
   - Homepage URL: `https://<team>.cloudflareaccess.com`
   - Authorization callback URL: `https://<team>.cloudflareaccess.com/cdn-cgi/access/callback`

   Then add it in Zero Trust, under **Settings**, **Authentication**, **Login methods**, **GitHub**.
3. **Make GitHub the only login method.** A new Zero Trust account starts with *Cloudflare account membership* as a login method. Remove it.
4. **One reusable policy per audience.** Under **Access controls**, **Policies**, create an Allow policy with the **GitHub Organization** selector, your organisation, and a named team. Reference it from each application. Use a team rather than the whole organisation: an organisation's members usually include people a private site is not meant for, such as members who joined for a translation or a course. A session can last up to a month.

### Once per site

1. **Create the Worker by hand, under its final name,** as a placeholder that holds no data, such as the dashboard's Hello World template. Keep its `workers.dev` route on: the action deploys to `https://<worker-name>.<account-subdomain>.workers.dev`, and checks that URL. Creating a Worker needs Admin on the Workers product, which the deploy token deliberately lacks; see Cloudflare's [authorization docs](https://developers.cloudflare.com/workers/authorization/).
2. **Turn Access on for the Worker with *All traffic*,** not *Previews only*. That covers the `workers.dev` hostname and every preview URL, and so every alias. A custom domain needs a check of its own: see [What the generated configuration means for the Worker](#what-the-generated-configuration-means-for-the-worker). Attach the reusable policy, and turn on instant authentication. Use this setting on the Worker, not the account-wide "Protect all Workers" switch, if the account also serves public sites.
3. **Prove the gate on the placeholder** before the first real deploy, with [`check-access-gate.sh`](https://github.com/QuantEcon/actions/blob/main/scripts/check-access-gate.sh) from a clone of this repository:

   ```bash
   bash scripts/check-access-gate.sh <team>.cloudflareaccess.com https://<worker-name>.<account-subdomain>.workers.dev/
   ```

   The action repeats this check before every deploy, and refuses to deploy if it fails, but proving it now catches a setup mistake before any workflow depends on the site.
4. **Create the deploy token**: an account-owned API token with **Editor** on this one Worker, from Cloudflare's per-Worker roles, not the account-wide *Workers Scripts: Edit*. It can deploy this Worker but cannot create one, so a mistyped `worker-name` fails instead of creating a new Worker with nothing in front of it. The check before the upload refuses that case too, whatever the token can do.
5. **Add the secrets to the repository** that deploys the site, under **Settings**, **Secrets and variables**, **Actions**:

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
| `worker-name` | yes | none | The Worker to deploy to, one per site: lowercase letters, digits and dashes, not starting or ending with a dash, at most 63 characters. It must already exist, with its `workers.dev` route on, and already be behind Access. |
| `account-subdomain` | yes | none | The account's `workers.dev` subdomain: `my-subdomain` for `*.my-subdomain.workers.dev`, which `my-subdomain.workers.dev` also gives. The URLs are built from it, never read from wrangler's output. |
| `team-domain` | yes | none | The Access team's login domain, `<team>.cloudflareaccess.com`; a bare `<team>` is accepted too. Every gate check requires an anonymous request to be redirected to exactly this host. |
| `build-dir` | yes | none | The directory that holds the built site. The job fails if it is missing or holds no files, and warns if it has no `index.html`, since the site's root would then answer 404. |
| `alias` | no | `''` | Also uploads the same build as a named preview alias, such as `report-2026-08`, for a permanent URL beside the production one, which moves with each deploy. Lowercase letters, digits and dashes, starting with a letter and not ending with a dash, and `<alias>-<worker-name>` must fit in 63 characters. Empty, the default, uploads no alias. |
| `require-access` | no | `true` | `'true'`, the default, proves the site is gated: before anything is uploaded, after the deploy, on production and on the new version's own preview URL, and on the alias after its upload, an anonymous request must be redirected to `team-domain`. `'false'` skips every check, with a warning: never use it for private content. Any other value fails the job. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from deploy-cloudflare/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `deploy-url` | The production URL, `https://<worker-name>.<account-subdomain>.workers.dev`. Set once the deploy succeeds, even if the gate check after it then fails the job. |
| `alias-url` | The alias's URL, `https://<alias>-<worker-name>.<account-subdomain>.workers.dev`. Empty when no `alias` is given, or when its upload failed or did not run. |

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
          team-domain: my-team.cloudflareaccess.com
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
    team-domain: my-team.cloudflareaccess.com
    build-dir: _build/html
    alias: ${{ steps.month.outputs.alias }}   # report-2026-08, for example
```

### In the templates

No template uses this action: a private site is a choice made per site, not the default for a lecture repository.

## Behaviour

1. **Inputs.** Every input is checked before anything else runs: the secrets must be set, the names must be valid hostname labels, `team-domain` must be an Access login domain, and `build-dir` must hold at least one file. The action also picks the file to probe besides the site's root: see [The gate check](#the-gate-check).
2. **The check before the deploy.** With `require-access: 'true'`, the production URL must be gated. If it is not, the job fails with nothing uploaded. That refuses a Worker that does not exist, as a mistyped name would be, one that is public, and one gated by another Access organisation.
3. **wrangler.** The action sets up Node 24 if the runner lacks Node 22 or later, and installs the `wrangler` version pinned in its [`package.json`](https://github.com/QuantEcon/actions/blob/main/deploy-cloudflare/package.json) with `npm ci`, into a temporary directory.
4. **The configuration.** It writes a wrangler configuration for this one run, with the Worker's name, a fixed compatibility date, `build-dir` as the assets directory, and `workers_dev` and `preview_urls` both on. It declares no routes.
5. **The deploy.** `wrangler deploy` publishes `build-dir` to production. Every version also gets its own preview URL, `https://<first 8 characters of the version ID>-<worker-name>.<account-subdomain>.workers.dev`, read from the `Current Version ID` line of wrangler's output.
6. **The check after the deploy**, on production and on the new version's preview URL. It runs even when `wrangler deploy` fails, because wrangler can fail after the new version is already live.
7. **The alias**, if given, and only once the deploy and the check after it have passed: `wrangler versions upload --preview-alias <alias>` uploads the same build as a preview, then its URL is checked too.
8. **The job summary** gives each URL and the result of its check, or says why nothing was deployed. Production and the new version's preview URL share one result, that of the check after the deploy.

With `require-access: 'false'`, none of the three checks runs, and a warning says that the site is not checked.

### The gate check

Each check is [`check-access-gate.sh`](https://github.com/QuantEcon/actions/blob/main/scripts/check-access-gate.sh), which sends an anonymous request and does not follow redirects: following one would land on the login page, which answers `200`, and a gated site would look the same as a public one. The answer decides:

| Response | Verdict |
|---|---|
| `301`, `302`, `303`, `307` or `308`, to exactly `team-domain` | gated |
| A redirect to another `*.cloudflareaccess.com` | fails: gated by the wrong Access organisation |
| A redirect whose `Location` carries a user name or a backslash | fails: the real host is ambiguous, and Access never sends one |
| `2xx` | fails: **the site is public** |
| `404` | fails: no Worker answers on that hostname, or its `workers.dev` route is off |
| Anything else, or no answer | fails: the gate could not be verified |

Each check requests the site's root and one file from `build-dir` that is not HTML: the first in byte order with a URL-safe path, skipping any path with a part that starts with a dot, and the `_headers`, `_redirects` and `_worker.js` control files. If no file qualifies, only the root is requested. A gate that protected only the root would otherwise pass. Access covers every path on a hostname, so a correct gate redirects both.

### What the generated configuration means for the Worker

- **Preview URLs are on** after every deploy, even if they were turned off in the dashboard, which is why the check after the deploy covers the new version's preview URL.
- **The deploy replaces the Worker's code**, such as the placeholder's script, without asking. Other settings changed in the dashboard can be overwritten too.
- **Custom domains** are a setting on the Worker in the dashboard. The configuration declares no routes, so a deploy leaves them alone. The action checks only the `workers.dev` hostname and preview URLs, so check a custom domain yourself with `check-access-gate.sh`, once it is attached and after any change to Access.
- **Dotfiles** in `build-dir`, such as Sphinx's `.buildinfo`, are uploaded like any other file, unless a `.assetsignore` file in `build-dir` lists them.

### Limits

On the free plan a Worker's static assets can hold 20,000 files per version, and 25 MiB per file; paid plans allow 100,000 files. A Worker keeps its 1,000 most recent preview aliases. A lecture-sized Jupyter Book is a few thousand files.

## Troubleshooting

**`Refusing to deploy: … is not behind Access for …`.** Nothing was uploaded. The `FAIL` line above it says why:

- `answered 404`: no Worker by that name answers under `account-subdomain`, or its `workers.dev` route is off. Check both, and create the Worker first if it is new.
- `THE SITE IS PUBLIC`: Access is off for the Worker, or set to *Previews only*. Turn it on with *All traffic*.
- `the Worker is attached to the wrong Access organisation`: the Worker's Access application belongs to another Zero Trust team, or `team-domain` is wrong.
- `not to the Access login domain`: the site redirected elsewhere, sent no `Location`, or sent one whose host is ambiguous, so Access is not answering for this hostname. Check that Access is on with *All traffic*, and that `team-domain` is right.
- `expected a redirect to the Access login domain`: another status, such as `401`, `403` or a `5xx`. Check the Worker in the dashboard, then re-run the job.
- `could not be reached`: a network problem between the runner and Cloudflare. Re-run the job.

**`wrangler deploy failed (exit …)`.** wrangler's own error is printed above it. An authentication or permission error usually means the token lacks Editor on this Worker, the account ID is wrong, or the token has expired. wrangler can fail after the new version is live, so the job summary gives the check that ran after the failure.

**`A hostname serving this Worker is NOT behind Access for …`.** The urgent one: the new build is live, or may be, and an anonymous request to production or to the new version's preview URL was not redirected. The `FAIL` line above names the hostname. Turn Access on for the Worker with *All traffic*, which covers production and every preview URL, then re-run the job to confirm. Until you can, turn off both the Worker's `workers.dev` route and its preview URLs in the dashboard: with the route off, preview URLs stay on, and wrangler itself warns that they may be public. A re-run is then refused, with `answered 404`, until the route is back on.

**`wrangler's output named no 'Current Version ID'`.** The new version's preview URL could not be worked out, so it was not checked, and the check fails rather than pass unseen. wrangler prints the ID only once every step after the upload has succeeded, so this usually follows a failed `wrangler deploy`. After a successful one it means a wrangler update changed its output. Check the preview URL by hand with `check-access-gate.sh`, with the version ID from the dashboard.

**`The alias is uploaded but … is NOT behind Access for …`.** Production is gated but previews are not. Set the Worker's Access to *All traffic*, which covers preview URLs.

**An alias is refused before anything runs.** It must start with a lowercase letter and hold only lowercase letters, digits and dashes, and `<alias>-<worker-name>` must fit in 63 characters. Use `report-2026-08`, not `2026-08`.

**`cloudflare-api-token is empty`.** The secret is missing, or the run came from a fork or from Dependabot, which get no secrets.

**A blank page after access is granted.** On the first load after Access lets a visitor in, cached redirects can be served in place of the page's stylesheets, scripts and data. Reloading the page fixes it.

**A person added to the team is still refused.** Cloudflare documents that a user refused before joining can stay refused until they revoke the OAuth app in their GitHub settings, under **Applications**, and log in again.
