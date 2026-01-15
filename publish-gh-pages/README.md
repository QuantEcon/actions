# Publish to GitHub Pages Action

Publishes QuantEcon lecture builds to GitHub Pages using native GitHub Pages deployment.

## Features

- 📄 **Native GitHub Pages deployment** - No gh-pages branch needed
- 🌐 **Custom domain support** via CNAME file
- � **Release assets** - Optional HTML archive, checksum, and manifest
- �📊 **Deployment statistics** (file count, size)
- 🔗 **Automatic URL generation** from GitHub
- ⚡ **No repo bloat** - Eliminates gh-pages branch history issues

## Why Native Deployment?

This action uses GitHub's native Pages deployment (via artifacts) instead of pushing to a gh-pages branch:

| Aspect | Native (this action) | Branch-based (old) |
|--------|---------------------|-------------------|
| gh-pages branch | ❌ Not needed | ✅ Required |
| Repo size growth | ❌ None | ⚠️ Grows over time |
| GitHub support | ✅ First-party | Third-party |
| Concurrency | ✅ Built-in | Manual |

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `build-dir` | Directory with built site | Yes | - |
| `cname` | Custom domain | No | - |
| `create-release-assets` | Create and upload release assets | No | `false` |
| `asset-name` | Base name for assets (e.g., "lecture-python-html") | No | `<repo>-html` |
| `github-token` | Token for uploading release assets | If creating assets | - |

**Note:** `github-token` is only needed when `create-release-assets: 'true'`.

## Outputs

| Output | Description |
|--------|-------------|
| `page-url` | URL of deployed site |
| `asset-url` | URL of uploaded release asset (if created) |

## Usage

### Basic Deployment

```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  with:
    build-dir: '_build/html'
```

### With Custom Domain

```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  with:
    build-dir: '_build/html'
    cname: 'python.quantecon.org'
```

### Using Page URL

```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  id: pages
  with:
    build-dir: '_build/html'

- name: Verify deployment
  run: |
    echo "Site deployed to: ${{ steps.pages.outputs.page-url }}"
```

### With Release Assets

Create downloadable archives attached to GitHub releases:

```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  with:
    build-dir: '_build/html'
    cname: 'python.quantecon.org'
    create-release-assets: 'true'
    asset-name: 'lecture-python-html'
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

This creates and uploads to the release:
- `lecture-python-html-<tag>.tar.gz` - Complete site archive
- `lecture-python-html-checksum.txt` - SHA256 checksum
- `lecture-python-html-manifest.json` - Metadata (commit, timestamp, size)

**Note:** Requires `contents: write` permission for release uploads.

## Setup Requirements

### Required Workflow Permissions

The workflow must have these permissions:

```yaml
permissions:
  contents: write  # For release assets (read is enough without assets)
  pages: write
  id-token: write
```

### Enable GitHub Pages

1. Go to repository Settings → Pages
2. Set Source to **"GitHub Actions"** (not "Deploy from a branch")
3. Save

### Concurrency (Recommended)

Add to your workflow to prevent deployment conflicts:

```yaml
concurrency:
  group: "pages"
  cancel-in-progress: false
```

### Custom Domain Setup

If using custom domain:

1. Add `cname` to action inputs
2. Configure DNS records at your domain provider:
   - CNAME record: `python → quantecon.github.io`
   - Or A records to GitHub's IPs
3. Enable HTTPS in repository settings (automatic after DNS propagation)

## Troubleshooting

### Deployment Fails with Permissions Error

**Solutions:**
1. Ensure workflow has `pages: write` and `id-token: write` permissions
2. Verify GitHub Pages source is set to "GitHub Actions" in repo settings

### Build Directory Not Found

**Symptom:** `❌ Error: Build directory not found`

**Solutions:**
1. Verify `build-dir` path is correct
2. Check build step completed successfully
3. Use output from build action: `${{ steps.build.outputs.build-path }}`

### Page Not Loading

**Symptom:** 404 error on GitHub Pages URL

**Solutions:**
1. Wait 1-2 minutes for propagation
2. Verify GitHub Pages source is "GitHub Actions" in settings
3. Verify index.html exists in root

### Custom Domain Not Working

**Symptom:** CNAME configured but domain not resolving

**Solutions:**
1. Verify DNS records at domain provider
2. Wait for DNS propagation (up to 24 hours)
3. Check CNAME file exists in deployed site
4. Enable HTTPS in repository settings

## Performance

| Step | Time |
|------|------|
| Prepare build | ~2 seconds |
| Upload artifact | ~10-30 seconds |
| Deploy to Pages | ~30-60 seconds |
| **Total** | **~45-90 seconds** |

## Examples

### Complete Publish Workflow

```yaml
name: Publish

on:
  push:
    tags: ['publish-*']

permissions:
  contents: write  # For release assets
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  publish:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page-url }}
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-environment@v1
        with:
          install-latex: 'true'
      
      - uses: quantecon/actions/build-lectures@v1
        id: build
      
      - uses: quantecon/actions/publish-gh-pages@v1
        id: deploy
        with:
          build-dir: ${{ steps.build.outputs.build-path }}
          cname: 'python.quantecon.org'
          create-release-assets: 'true'
          asset-name: 'lecture-python-html'
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Conditional Deployment

Deploy only on main branch:

```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  if: github.ref == 'refs/heads/main'
  with:
    build-dir: '_build/html'
```

## Migration from Branch-Based Deployment

If migrating from peaceiris/actions-gh-pages or similar:

1. **Update workflow permissions:**
   ```yaml
   permissions:
     contents: read
     pages: write
     id-token: write
   ```

2. **Change GitHub Pages source:**
   - Go to Settings → Pages
   - Change from "Deploy from a branch" to "GitHub Actions"

3. **Update action usage:**
   ```yaml
   # Before
   - uses: quantecon/actions/publish-gh-pages@v0
     with:
       build-dir: '_build/html'
       github-token: ${{ secrets.GITHUB_TOKEN }}
       target-branch: 'gh-pages'
   
   # After
   - uses: quantecon/actions/publish-gh-pages@v1
     with:
       build-dir: '_build/html'
   ```

4. **Optional: Delete gh-pages branch** to reclaim repo space

See [docs/MIGRATION-GUIDE.md](../docs/MIGRATION-GUIDE.md) for complete workflow examples.
