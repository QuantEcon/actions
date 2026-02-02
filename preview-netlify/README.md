# Preview Netlify Action

Deploys QuantEcon lecture builds to Netlify for PR previews with smart comments showing direct links to changed pages.

## Features

- 🔍 **PR preview deployments** with predictable URLs (`pr-{number}`)
- 📚 **Changed lecture detection** - Direct links to modified pages in PR comments
- 💬 **Smart PR comments** - Updates existing comment instead of creating duplicates
- 🔒 **Security-aware** - Skips deployment for forks and dependabot
- ⚡ **Reliable** - Uses JSON output for accurate URL extraction

## Usage

```yaml
- uses: quantecon/actions/preview-netlify@v1
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: _build/html
```

That's it! Changed lecture detection works automatically for files in the `lectures/` directory.

> **Note:** For changed lecture detection to work, your workflow must check out the repository with full git history using `actions/checkout@v4` with `fetch-depth: 0`. Without this, only the preview URL will be shown (no direct links to changed pages).

## Requirements

- **Node.js/npm:** Required for `netlify-cli` installation
  - The QuantEcon container (`ghcr.io/quantecon/quantecon:latest`) includes Node.js
  - For other runners, use `actions/setup-node@v4` before this action
- **jq:** For parsing Netlify JSON output (included in ubuntu-latest and QuantEcon container)
- **Git history:** Use `fetch-depth: 0` in checkout for change detection
- **Netlify secrets:** `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID`

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `netlify-auth-token` | Netlify auth token | Yes | - |
| `netlify-site-id` | Netlify site ID | Yes | - |
| `build-dir` | Directory with built site | Yes | - |
| `lectures-dir` | Lectures directory for change detection | No | `lectures` |

To disable changed file detection, set `lectures-dir: ''`.

## Outputs

| Output | Description |
|--------|-------------|
| `deploy-url` | URL of deployed preview |
| `changed-files` | List of changed lecture files |

## Example PR Comment

When a PR modifies lecture files, the action posts a comment like:

> ## 📖 Netlify Preview Ready!
>
> **Preview URL:** https://pr-5--site.netlify.app
>
> **Commit:** [`abc1234`](https://github.com/...)
>
> ### 📚 Changed Lectures
>
> - [aiyagari](https://pr-5--site.netlify.app/aiyagari.html)
> - [mccall_model](https://pr-5--site.netlify.app/mccall_model.html)
>
> ---
> <details><summary>Build Info</summary>
>
> - **Workflow:** [Build Preview](...)
> </details>

## Complete Workflow Example

```yaml
name: Build Preview
on:
  pull_request:

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Environment
        uses: quantecon/actions/setup-environment@v1
        with:
          environment-file: environment.yml

      - name: Build Lectures
        run: jb build lectures --path-output ./

      - name: Deploy Preview
        uses: quantecon/actions/preview-netlify@v1
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: _build/html
```

## Netlify Setup Guide

### 1. Create Netlify Site (CLI-only mode)

For best results, create a site that uses **CLI deployment only** (no automatic builds):

1. Go to [Netlify](https://app.netlify.com) and click **Add new site** → **Deploy manually**
2. Drag any folder to create the site (this creates an empty placeholder)
3. Note the site name (e.g., `jade-tarsier-d98a19`)

This creates a site without GitHub integration, meaning:
- ✅ No automatic builds on push/PR
- ✅ No duplicate PR comments from Netlify
- ✅ Full control via our GitHub Action

### 2. Get Credentials

**NETLIFY_AUTH_TOKEN:**
1. Netlify → User Settings → Applications → Personal access tokens
2. Create new token with descriptive name (e.g., `github-actions`)
3. Copy the token immediately (it won't be shown again)

**NETLIFY_SITE_ID:**
1. Netlify → Your Site → Site configuration → General → Site details
2. Copy the **Site ID** (a UUID like `a1b2c3d4-e5f6-...`)

### 3. Add GitHub Secrets

In your repository: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Secret | Value |
|--------|-------|
| `NETLIFY_AUTH_TOKEN` | Your personal access token |
| `NETLIFY_SITE_ID` | Your site ID |

### 4. (Optional) Disable Netlify GitHub Integration

If you previously linked your repo to Netlify and are seeing **duplicate PR comments**, disable Netlify's built-in integration:

**Option A: Unlink Repository (Recommended)**
1. Netlify → Your Site → **Site configuration** → **Build & deploy** → **Continuous deployment**
2. Click **Unlink** to disconnect the GitHub repo
3. Your site remains active, but Netlify won't auto-build or comment

**Option B: Disable PR Comments Only**
1. Netlify → Your Site → **Site configuration** → **Notifications**
2. Find **GitHub notifications** section
3. Delete or disable:
   - "GitHub commit comments"
   - "GitHub PR comments"

**Option C: Disable Deploy Previews**
1. Netlify → Your Site → **Site configuration** → **Build & deploy** → **Continuous deployment**
2. Under **Branches and deploy contexts**, set **Deploy Previews** to "None"

### Which setup to use?

| Scenario | Recommendation |
|----------|----------------|
| New project | Create site via "Deploy manually" (no GitHub link) |
| Existing linked site | Unlink repository in Netlify settings |
| Want Netlify builds + our action | Disable Netlify PR comments only |

## Security

This action automatically skips deployment for:
- **Dependabot PRs** - Can't access secrets
- **Fork PRs** - Can't access secrets (use `pull_request_target` if needed)

A notification is logged when deployment is skipped.

