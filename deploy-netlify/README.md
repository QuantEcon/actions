# Deploy Netlify Preview Action

Deploys QuantEcon lecture builds to Netlify for PR previews with smart comments showing direct links to changed pages.

## Features

- 🔍 **PR preview deployments** with predictable URLs (`pr-{number}`)
- 📚 **Changed lecture detection** - Direct links to modified pages in PR comments
- 💬 **Smart PR comments** - Updates existing comment instead of creating duplicates
- 🔒 **Security-aware** - Skips deployment for forks and dependabot
- ⚡ **Reliable** - Uses JSON output for accurate URL extraction

## Usage

```yaml
- uses: quantecon/actions/deploy-netlify@v1
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: _build/html
```

That's it! Changed lecture detection works automatically for files in the `lectures/` directory.

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
        uses: quantecon/actions/deploy-netlify@v1
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: _build/html
```

## Setup

### 1. Create Netlify Site

1. Go to [Netlify](https://app.netlify.com) and create a new site
2. You can create an empty site - we deploy via CLI, not Netlify's build

### 2. Get Credentials

**NETLIFY_AUTH_TOKEN:**
1. Netlify → User Settings → Applications → Personal access tokens
2. Create new token, copy it

**NETLIFY_SITE_ID:**
1. Netlify → Your Site → Site configuration → General → Site ID
2. Copy the site ID

### 3. Add GitHub Secrets

In your repository: Settings → Secrets and variables → Actions → New repository secret

Add both `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID`.

## Security

This action automatically skips deployment for:
- **Dependabot PRs** - Can't access secrets
- **Fork PRs** - Can't access secrets

A notification is logged when deployment is skipped.
