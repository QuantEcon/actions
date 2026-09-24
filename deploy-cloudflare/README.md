# Deploy Cloudflare Action

Publishes a built site to an existing Cloudflare Worker behind Cloudflare Access, for sites only members should see, and fails the job unless the site is proven gated.

GitHub Pages stays the route for everything public ([`publish-gh-pages`](../publish-gh-pages)). What Pages cannot do on the org's Team plan is serve a site to members only, since Pages access control needs Enterprise Cloud. Cloudflare Access in front of a Worker's static assets does, for free at this scale. PR previews are a different action ([`preview-cloudflare`](../preview-cloudflare)).

## Features

- 🔒 **Proves the gate before uploading.** If an anonymous request to the Worker is not redirected to your Access team's login, nothing is uploaded. That refuses a Worker that does not exist, one that is public, and one gated by the wrong Access organisation.
- 🔁 **Proves it again after deploying**, on production and on the new version's own preview URL, each at the site root and at one real file from the build. A site that is silently public fails the job instead of passing it.
- 🗂️ **Optional preview alias**, for example `report-2026-08`: a permanent URL for this build alongside the moving production URL. The alias is gate-checked too.
- 📌 **Pinned wrangler**, installed with `npm ci` from a committed lockfile and kept current by Dependabot.
- 📝 **Job summary.** On `push`, `schedule` and `workflow_dispatch` there is no PR to comment on, so the result (including "refused" or "deployed but not gated") goes to the job summary.

## Usage

```yaml
name: Publish members dashboard
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 6 * * *'
  workflow_dispatch:

# One deploy at a time per site; a queued run deploys the newest build.
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

A monthly report that also keeps a permanent URL per month:

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
          alias: ${{ steps.month.outputs.alias }}   # report-2026-08
```

> **New in v0.12.0.** Pin `@v0.12.0` or later; `@v0` carries it once that release has moved the floating tag.

## Requirements

- **A Worker that already exists and is already behind Access.** The action never creates a Worker or turns Access on. See the [setup checklist](#setup-checklist).
- **Node.js 22 or later.** wrangler refuses to run below 22. If the runner has an older Node or none, the action sets up Node 24 itself. The QuantEcon containers (`ghcr.io/quantecon/quantecon`, `ghcr.io/quantecon/quantecon-build`) already carry Node 24.
- **`bash`, `curl` and `npm`**, all present on GitHub-hosted runners and in the QuantEcon containers.
- **Secrets** `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. Secrets are not passed to workflows triggered from forks or by Dependabot. The action then fails in validation, before any network call.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cloudflare-api-token` | Account-owned token with **Editor on this Worker only** (see the checklist) | Yes | - |
| `cloudflare-account-id` | Cloudflare account ID | Yes | - |
| `worker-name` | The Worker to deploy to, one per site. Lowercase letters, digits and dashes | Yes | - |
| `account-subdomain` | The account's `workers.dev` subdomain: `my-subdomain` for `*.my-subdomain.workers.dev` (`my-subdomain.workers.dev` is accepted too) | Yes | - |
| `team-domain` | The Access team's login domain, `<team>.cloudflareaccess.com` (a bare `<team>` is accepted) | Yes | - |
| `build-dir` | Directory with the built site | Yes | - |
| `alias` | Also upload this build as a named preview alias. Lowercase letters, digits and dashes, **starting with a letter** (`report-2026-08`, not `2026-08`), and `<alias>-<worker-name>` must fit in 63 characters | No | `''` |
| `require-access` | Check the gate before uploading, after deploying (production and the new version's preview URL) and on the alias. `false` skips every check, with a warning. Never set it for private content | No | `true` |

The output URLs are **constructed** from `worker-name`, `account-subdomain` and `alias`, never parsed from wrangler's output, following the same approach as `preview-cloudflare` (#131). The one address read from wrangler's output is the new version's preview URL, which is only probed and never handed out.

## Outputs

| Output | Description |
|--------|-------------|
| `deploy-url` | `https://{worker}.{subdomain}.workers.dev`. Set once the production deploy succeeds (even if the gate check after it then fails the job) |
| `alias-url` | `https://{alias}-{worker}.{subdomain}.workers.dev`. Empty when no alias is given or the upload did not happen |

## What the gate check proves

The check is [`scripts/check-access-gate.sh`](../scripts/check-access-gate.sh), taken from the probe verified in the status-projects pilot (QuantEcon/status-projects#35). It sends an unauthenticated request and **does not follow redirects**: following one would land on the login page and return `200`, making a gated site and a public one look the same.

| Response | Verdict |
|----------|---------|
| `301/302/303/307/308` to exactly `team-domain` | ✅ gated |
| Redirect to a different `*.cloudflareaccess.com` | ❌ gated by the **wrong Access organisation** |
| Redirect whose `Location` carries userinfo or a backslash | ❌ the real host is ambiguous, and Access never sends one |
| `2xx` | ❌ **the site is public** |
| `404` | ❌ no Worker answers on that hostname, or its `workers.dev` route is off |
| Anything else, or unreachable | ❌ the gate could not be verified. The check fails closed |

Every check probes the site root **and one non-HTML file from `build-dir`** (the first in sorted order with a URL-safe path, skipping dotfiles). A gate that protects only the entry point would be an easy mistake to make and invisible from the root. In the pilot, `data/latest.json` got the same redirect as `/`, as it should: Access covers every path on the hostname.

The action runs the check at three points:

1. **Before uploading.** This is prevention. Deploying content first and turning Access on afterwards would leave private data on a public hostname for the length of the setup.
2. **After deploying**, on production and on the new version's own preview URL. For production this is a regression guard: the pilot showed Access survives a redeploy, but the check is one request, and it guards against a private site silently going public. The preview URL is checked for the first time here. Every deploy gets one, `https://<first 8 of the version id>-{worker}.{subdomain}.workers.dev`, because the config enables preview URLs, and an Access setup that covers only the production hostname would leave it public. Its address comes from the `Current Version ID` line in wrangler's output; if that line is missing, the check fails rather than being skipped. The check also runs when `wrangler deploy` fails, because wrangler can exit with an error after the new version is already live.
3. **After the alias upload.** The alias is one more preview URL, so it gets its own check.

You can run the same check by hand:

```bash
bash scripts/check-access-gate.sh my-team.cloudflareaccess.com \
  https://members-dashboard.my-subdomain.workers.dev/
# PASS  302 -> my-team.cloudflareaccess.com  https://members-dashboard.my-subdomain.workers.dev/
```

## Setup checklist

### Once per Cloudflare account

1. **Zero Trust organisation.** The team name you choose gives the login domain `<team>.cloudflareaccess.com`, which is the `team-domain` input. The free tier covers 50 users.
2. **GitHub as the login method.** Create an OAuth App under the **organisation's** developer settings (GitHub → the org → Settings → Developer settings → OAuth Apps). An app created under the organisation itself needs no approval under the org's OAuth app access restrictions, while one under a personal account does.
   - Homepage URL: `https://<team>.cloudflareaccess.com`
   - Authorization callback URL: `https://<team>.cloudflareaccess.com/cdn-cgi/access/callback`

   Then add it in Zero Trust under Settings → Authentication → Login methods → GitHub.
3. **Make GitHub the only login method.** New Zero Trust accounts default to *Cloudflare account membership*, not one-time PIN. Remove that default.
4. **One reusable policy per audience.** Under Access controls → Policies, create an Allow policy with the **GitHub Organization** selector, the organisation `QuantEcon` and a **named team**, and reference it from each application. Use a team, not the whole organisation: org membership counted 82 accounts across 23 teams, including translation collaborators and course teams, which is the wrong audience for a grants dashboard. The pilot's policy is `QuantEcon Dashboards` (`QuantEcon` + team `dashboards`). Sessions can last up to one month.

### Once per site

1. **Create the Worker by hand, under its final name**, as a placeholder that holds no data (for example the dashboard's Hello World template). Keep its `workers.dev` route enabled: the action deploys to and checks `https://{worker}.{subdomain}.workers.dev`. Creating a Worker needs Admin at the Workers product scope, which the deploy token deliberately lacks ([Cloudflare docs](https://developers.cloudflare.com/workers/authorization/)).
2. **Turn Access on for the Worker with *All traffic*,** not *Previews only*. This protects the `workers.dev` hostname, every preview URL (so every alias), and any custom domain attached later. Attach the reusable policy and turn on instant authentication. Use this per-Worker setting rather than the account-wide "Protect all Workers" switch, because the same account hosts public lecture previews.
3. **Prove the gate on the placeholder** before the first real deploy:
   ```bash
   bash scripts/check-access-gate.sh <team>.cloudflareaccess.com https://<worker>.<subdomain>.workers.dev/
   ```
   The action repeats this check before every deploy and refuses if it fails, but proving it here first catches a setup mistake before any workflow depends on it.
4. **Create the deploy token:** an account-owned API token with **Editor on this one Worker** (Cloudflare's per-Worker roles), not the legacy account-wide *Workers Scripts: Edit*. It can deploy this Worker but cannot create one, so a mistyped `worker-name` fails instead of creating a new, ungated Worker. The gate check before uploading refuses that case too, whatever the token can do.
5. **Add the secrets to the consumer repository** (Settings → Secrets and variables → Actions):

   | Secret | Value |
   |--------|-------|
   | `CLOUDFLARE_API_TOKEN` | The per-Worker token from step 4 |
   | `CLOUDFLARE_ACCOUNT_ID` | Dashboard URL `https://dash.cloudflare.com/{account-id}/...`, or Workers & Pages → Overview |

### Why the action does not do this setup itself

The Access application is one-time per Worker, and the identity provider is one-time per account. Provisioning either from CI would put an `Access: Apps and Policies: Edit` token into every consumer repository for a step that runs once. For the same reason the action cannot create the Worker: its token can only deploy to one that exists. If the org ever wants the account under code, the Terraform resources `zero_trust_access_application` and `zero_trust_access_policy` cover it.

## Notes

- **Custom domains** are a per-Worker setting in the dashboard, and the Worker's Access application picks them up automatically. The action does not manage domains: its generated config declares no routes, so a deploy leaves dashboard-attached domains alone, and it always checks the `workers.dev` URL.
- **The generated config** ([`write-config.js`](write-config.js)) sets the name, a fixed `compatibility_date`, `assets.directory`, `workers_dev: true` and `preview_urls: true`. It is written to `RUNNER_TEMP` for each run, so consumer repositories need no wrangler config. `preview_urls: true` turns preview URLs on for the Worker at every deploy, even if they were turned off in the dashboard; the check after deploying covers the new version's preview URL for that reason. wrangler running in CI overwrites settings changed in the dashboard (such as the placeholder's script) without prompting. Dotfiles in `build-dir` (Sphinx's `.buildinfo`, for example) are uploaded like any other file unless listed in a `.assetsignore`.
- **A blank page after access is granted.** On the first load after access is granted or restored, cached Access redirects for `style.css`, `app.js` and data files can be served in place of the real assets. A plain refresh fixes it.
- **A user added to the team after being denied** may stay denied until they revoke the OAuth app in their GitHub settings and log in again. This is documented Cloudflare behaviour, though it did not reproduce on the path the pilot tested.
- **Limits.** Workers static assets allow 20,000 files and 25 MiB per file per version on the free plan (100,000 files on paid). The 1,000 most recent preview aliases are kept per Worker. Lecture-sized Jupyter Books are a few thousand files.

## Troubleshooting

### "Refusing to deploy: … is not behind Access"

Nothing was uploaded. The line above it says why:
- **`answered 404`**: no Worker by that name under that `account-subdomain`, or its `workers.dev` route is off. Check both, and create the Worker first if it is new.
- **`THE SITE IS PUBLIC`**: Access is off for the Worker, or set to *Previews only*. Turn it on with *All traffic*.
- **`wrong Access organisation`**: the Worker's Access application belongs to a different Zero Trust team, or `team-domain` is wrong.
- **`not to the Access login domain`**: the site redirected somewhere other than `team-domain`, or sent no `Location`, so Access is not answering for this hostname. Check that Access is on with *All traffic* and that `team-domain` is right.
- **`expected a redirect to the Access login domain`**: an unexpected status such as `401`, `403` or `5xx`. Check the Worker in the dashboard, then re-run the job.
- **`could not be reached`**: a network problem between the runner and Cloudflare. Re-run the job.

### "wrangler deploy failed"

wrangler's own error is printed above the annotation. An authentication or permission error usually means the token lacks Editor on this Worker, the account ID is wrong, or the token has expired. wrangler can fail after the new version is already live, so the job summary reports the gate check that ran after the failure.

### "A hostname serving this Worker is NOT behind Access"

This is the urgent one: the new build is live, or may be, and anonymous requests to production or to the new version's preview URL are not being redirected. The `FAIL` line above it names the hostname. Turn Access on for the Worker with *All traffic*, which covers production and every preview URL, or disable its `workers.dev` route. Then re-run the job to confirm.

### "wrangler's output named no 'Current Version ID'"

The new version's preview URL could not be worked out, so it was not checked, and the check fails. wrangler prints the ID only once every step after the upload has succeeded, so this follows most `wrangler deploy` failures; after a successful deploy it means a wrangler upgrade changed its output. Check the preview URL by hand with `scripts/check-access-gate.sh`, using the version ID from the dashboard.

### "The alias is uploaded but … is NOT behind Access"

Production is gated but previews are not. Set the Worker's Access to *All traffic*, which covers preview URLs.

### An alias is rejected before anything runs

Aliases must start with a lowercase letter and use only lowercase letters, digits and dashes, and `<alias>-<worker-name>` must fit in 63 characters. Use `report-2026-08`, not `2026-08`.
