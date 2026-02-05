# Preview Cloudflare Action

Deploys QuantEcon lecture builds to Cloudflare Pages for PR previews with smart comments showing direct links to changed pages.

## Features

- 🔍 **PR preview deployments** with predictable URLs (`pr-{number}.{project}.pages.dev`)
- 📚 **Changed lecture detection** - Direct links to modified pages in PR comments
- 💬 **Smart PR comments** - Updates existing comment instead of creating duplicates
- 🔒 **Security-aware** - Skips deployment for forks and dependabot
- ☁️ **Cloudflare Pages** - Fast global CDN, free tier supports private repos

## Usage

```yaml
- uses: quantecon/actions/preview-cloudflare@v1
  with:
    cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    project-name: my-lectures
    build-dir: _build/html
```

That's it! Changed lecture detection works automatically for files in the `lectures/` directory.

> **Note:** For changed lecture detection to work, your workflow must check out the repository with full git history using `actions/checkout@v4` with `fetch-depth: 0`. Without this, only the preview URL will be shown (no direct links to changed pages).

## Requirements

- **Node.js/npm:** Required for `wrangler` CLI installation
  - The QuantEcon container (`ghcr.io/quantecon/quantecon:latest`) includes Node.js
  - For other runners, use `actions/setup-node@v4` before this action
- **Git history:** Use `fetch-depth: 0` in checkout for change detection
- **Cloudflare secrets:** `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`
- **Cloudflare Pages project:** Must be created beforehand

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cloudflare-api-token` | Cloudflare API token | Yes | - |
| `cloudflare-account-id` | Cloudflare Account ID | Yes | - |
| `project-name` | Cloudflare Pages project name | Yes | - |
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

> ## ☁️ Cloudflare Preview Ready!
>
> **Preview URL:** https://pr-5.my-lectures.pages.dev
>
> **Commit:** [`abc1234`](https://github.com/...)
>
> ### 📚 Changed Lectures
>
> - [aiyagari](https://pr-5.my-lectures.pages.dev/aiyagari.html)
> - [mccall_model](https://pr-5.my-lectures.pages.dev/mccall_model.html)
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
          environment: environment.yml

      - name: Build Lectures
        run: jb build lectures --path-output ./

      - name: Deploy Preview
        uses: quantecon/actions/preview-cloudflare@v1
        with:
          cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          project-name: my-lectures
          build-dir: _build/html
```

## Cloudflare Setup Guide

### 1. Create Cloudflare Account

1. Go to [Cloudflare](https://dash.cloudflare.com/sign-up) and create a free account
2. Verify your email address

### 2. Create Cloudflare Pages Project

Create a project that uses **direct upload** (no Git integration):

1. Go to **Workers & Pages** in the Cloudflare dashboard
2. Click **Create** → **Pages** → **Upload assets**
3. Enter a project name (e.g., `my-lectures`) - this becomes part of your URL
4. Upload any placeholder file to create the project
5. Note the project name for the `project-name` input

This creates a project without GitHub integration, meaning:
- ✅ No automatic builds on push/PR
- ✅ No duplicate PR comments from Cloudflare
- ✅ Full control via our GitHub Action

### 3. Get Credentials

**CLOUDFLARE_ACCOUNT_ID:**
1. Cloudflare Dashboard → Any page → look at the URL
2. The URL format is: `https://dash.cloudflare.com/{account-id}/...`
3. Or go to **Workers & Pages** → **Overview** → Account ID is shown in the right sidebar

**CLOUDFLARE_API_TOKEN:**
1. Cloudflare Dashboard → **My Profile** (top right) → **API Tokens**
2. Click **Create Token**
3. Use the **Edit Cloudflare Workers** template, or create custom with:
   - **Permissions:** Account → Cloudflare Pages → Edit
   - **Account Resources:** Include → Your Account
4. Click **Continue to summary** → **Create Token**
5. Copy the token immediately (it won't be shown again)

### 4. Add GitHub Secrets

In your repository: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Secret | Value |
|--------|-------|
| `CLOUDFLARE_API_TOKEN` | Your API token |
| `CLOUDFLARE_ACCOUNT_ID` | Your account ID |

## Preview URL Structure

Cloudflare Pages creates predictable URLs based on the branch name:

| Deployment | URL |
|------------|-----|
| PR #5 | `https://pr-5.{project-name}.pages.dev` |
| PR #123 | `https://pr-123.{project-name}.pages.dev` |
| Production | `https://{project-name}.pages.dev` |

## Cloudflare vs Netlify

| Feature | Cloudflare Pages | Netlify |
|---------|------------------|---------|
| **Private repo support** | ✅ Free | ❌ Paid plans only |
| **Free tier** | Unlimited sites, 500 builds/month | 100GB bandwidth/month |
| **CLI tool** | `wrangler` | `netlify-cli` |
| **Preview URLs** | `pr-N.project.pages.dev` | `pr-N--site.netlify.app` |

Use `preview-cloudflare` for private repositories, `preview-netlify` for public repositories with existing Netlify setup.

## Security

This action automatically skips deployment for:
- **Dependabot PRs** - Can't access secrets
- **Fork PRs** - Can't access secrets (use `pull_request_target` if needed)

A notification is logged when deployment is skipped.

## Troubleshooting

### "Authentication error" or "Unauthorized"

- Verify `CLOUDFLARE_API_TOKEN` has Cloudflare Pages Edit permission
- Check that `CLOUDFLARE_ACCOUNT_ID` is correct
- Ensure the token hasn't expired

### "Project not found"

- Verify the `project-name` matches exactly (case-sensitive)
- Ensure the project was created in the correct Cloudflare account

### Preview URL returns 404

- Wait a few seconds - Cloudflare may take a moment to propagate
- Check the workflow logs for the actual deployed URL
- Verify the `build-dir` contains an `index.html`
