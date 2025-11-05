# Deploy to Netlify Action

Deploys QuantEcon lecture builds to Netlify for preview or production deployments with automatic PR comments.

## Features

- 🚀 **Production & preview deployments**
- 💬 **Automatic PR comments** with preview URLs
- 🔗 **Custom aliases** for predictable preview URLs
- 📊 **Deployment logging** with URL outputs
- ⚡ **Fast deployments** using Netlify CLI

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `netlify-auth-token` | Netlify auth token (from secrets) | Yes | - |
| `netlify-site-id` | Netlify site ID (from secrets) | Yes | - |
| `build-dir` | Directory with built site | Yes | - |
| `production` | Deploy to production (true/false) | No | `false` |
| `alias` | Deploy alias for previews | No | - |
| `message` | Deployment message | No | `Deployed via GitHub Actions` |

## Outputs

| Output | Description |
|--------|-------------|
| `deploy-url` | URL of deployed site |
| `logs-url` | URL to Netlify deployment logs |

## Usage

### Preview Deployment (Pull Requests)

```yaml
- uses: quantecon/actions/deploy-netlify@v1
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: '_build/html'
```

### Production Deployment

```yaml
- uses: quantecon/actions/deploy-netlify@v1
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: '_build/html'
    production: 'true'
    message: 'Production deployment v1.2.3'
```

### Preview with Custom Alias

```yaml
- uses: quantecon/actions/deploy-netlify@v1
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: '_build/html'
    alias: 'pr-${{ github.event.pull_request.number }}'
```

### Using Deployment URL

```yaml
- uses: quantecon/actions/deploy-netlify@v1
  id: netlify
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: '_build/html'

- name: Run tests against deployment
  run: |
    curl -f ${{ steps.netlify.outputs.deploy-url }}
    # Or use playwright, cypress, etc.
```

## Setup Requirements

### Netlify Secrets

Add these secrets to your GitHub repository:

1. **NETLIFY_AUTH_TOKEN**
   - Go to Netlify → User Settings → Applications
   - Create new access token
   - Add to GitHub: Settings → Secrets → New repository secret

2. **NETLIFY_SITE_ID**
   - Go to Netlify → Site Settings → General
   - Copy "Site ID" under Site information
   - Add to GitHub: Settings → Secrets → New repository secret

### Netlify Site Setup

1. Create site on Netlify (or use existing)
2. Configure build settings (optional - we build in Actions)
3. Set custom domain (for production)
4. Enable branch deploys (for previews)

## Deployment Types

### Production Deployment

**Triggered by:** Main branch commits, releases

**URL:** Custom domain (e.g., `python.quantecon.org`)

**Characteristics:**
- Permanent
- Indexed by search engines
- No automatic deletion

**Example:**
```yaml
on:
  push:
    branches: [main]
    
jobs:
  deploy:
    steps:
      - uses: quantecon/actions/deploy-netlify@v1
        with:
          production: 'true'
```

### Preview Deployment

**Triggered by:** Pull requests, feature branches

**URL:** Random subdomain (e.g., `5f3a8b2c--site.netlify.app`)

**Characteristics:**
- Temporary
- Not indexed
- Auto-deleted after inactivity

**Example:**
```yaml
on:
  pull_request:
    
jobs:
  preview:
    steps:
      - uses: quantecon/actions/deploy-netlify@v1
        # production defaults to 'false'
```

### Aliased Preview

**Triggered by:** Pull requests with custom alias

**URL:** Predictable subdomain (e.g., `pr-123--site.netlify.app`)

**Characteristics:**
- Temporary
- Predictable URL
- Easier for review

**Example:**
```yaml
- uses: quantecon/actions/deploy-netlify@v1
  with:
    alias: 'pr-${{ github.event.pull_request.number }}'
```

## PR Comment Format

For pull request previews, the action automatically comments:

```markdown
## 🔍 Preview Deployment

✅ **Deployed successfully!**

🔗 **Preview URL:** https://5f3a8b2c--site.netlify.app
📊 **Logs:** https://app.netlify.com/sites/site/deploys/5f3a8b2c

---

**Build Info:**
- Commit: `a7f3b2c`
- Branch: `refs/heads/feature-branch`
- Workflow: [CI](https://github.com/org/repo/actions/runs/123456)
```

## Troubleshooting

### Authentication Errors

**Symptom:** `Error: Authentication failed`

**Solutions:**
1. Verify `NETLIFY_AUTH_TOKEN` secret exists
2. Check token hasn't expired
3. Regenerate token in Netlify settings
4. Ensure token has correct permissions

### Site Not Found

**Symptom:** `Error: Site not found`

**Solutions:**
1. Verify `NETLIFY_SITE_ID` secret exists
2. Check site ID matches Netlify dashboard
3. Ensure token has access to this site
4. Verify site hasn't been deleted

### Build Directory Empty

**Symptom:** `Error: No files to deploy`

**Solutions:**
1. Verify `build-dir` path is correct
2. Check build step completed successfully
3. Ensure build artifacts exist: `ls -la _build/html`
4. Use absolute path if needed

### Deployment Timeout

**Symptom:** Deployment hangs or times out

**Solutions:**
1. Check build directory size (should be <1GB)
2. Verify network connectivity
3. Check Netlify status page
4. Retry deployment

### PR Comment Not Posted

**Symptom:** Preview deployed but no PR comment

**Solutions:**
1. Verify workflow runs on `pull_request` event
2. Check GitHub token permissions
3. Ensure `actions/github-script@v7` has access
4. Check if comment already exists

## Performance

| Step | Time |
|------|------|
| Install Netlify CLI | ~10 seconds |
| Deploy (preview) | ~30-60 seconds |
| Deploy (production) | ~30-60 seconds |
| Post PR comment | ~2 seconds |
| **Total** | **~45-75 seconds** |

## Examples

### Complete CI Workflow with Preview

```yaml
name: CI

on:
  pull_request:

jobs:
  build-and-preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-lecture-env@v1
      
      - uses: quantecon/actions/build-lectures@v1
        id: build
      
      - uses: quantecon/actions/deploy-netlify@v1
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: ${{ steps.build.outputs.build-path }}
          alias: 'pr-${{ github.event.pull_request.number }}'
```

### Publish Workflow with Production

```yaml
name: Publish

on:
  push:
    tags: ['publish-*']

jobs:
  deploy-production:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-lecture-env@v1
      
      - uses: quantecon/actions/build-lectures@v1
        id: build
      
      - uses: quantecon/actions/deploy-netlify@v1
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: ${{ steps.build.outputs.build-path }}
          production: 'true'
          message: 'Production deployment ${{ github.ref_name }}'
```

See [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md) for complete workflow examples.
