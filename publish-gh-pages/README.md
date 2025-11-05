# Publish to GitHub Pages Action

Publishes QuantEcon lecture builds to GitHub Pages with automated deployment and custom domain support.

## Features

- 📄 **GitHub Pages deployment** with orphan branch support
- 🌐 **Custom domain support** via CNAME file
- 📊 **Deployment statistics** (file count, size)
- 🔗 **Automatic URL generation** based on repository
- ⚡ **Fast deployment** using peaceiris/actions-gh-pages

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `build-dir` | Directory with built site | Yes | - |
| `github-token` | GitHub token (use secrets.GITHUB_TOKEN) | Yes | - |
| `target-branch` | Branch to deploy to | No | `gh-pages` |
| `cname` | Custom domain | No | - |
| `force-orphan` | Force orphan branch | No | `true` |
| `commit-message` | Deployment commit message | No | `Deploy to GitHub Pages` |

## Outputs

| Output | Description |
|--------|-------------|
| `page-url` | URL of deployed site |

## Usage

### Basic Deployment

```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  with:
    build-dir: '_build/html'
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### With Custom Domain

```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  with:
    build-dir: '_build/html'
    github-token: ${{ secrets.GITHUB_TOKEN }}
    cname: 'python.quantecon.org'
```

### Custom Branch and Message

```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  with:
    build-dir: '_build/html'
    github-token: ${{ secrets.GITHUB_TOKEN }}
    target-branch: 'docs'
    commit-message: 'Deploy version ${{ github.ref_name }}'
```

### Using Page URL

```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  id: pages
  with:
    build-dir: '_build/html'
    github-token: ${{ secrets.GITHUB_TOKEN }}

- name: Verify deployment
  run: |
    echo "Site deployed to: ${{ steps.pages.outputs.page-url }}"
    curl -f ${{ steps.pages.outputs.page-url }}
```

## Setup Requirements

### Enable GitHub Pages

1. Go to repository Settings → Pages
2. Set Source to "Deploy from a branch"
3. Select branch: `gh-pages` (or your target branch)
4. Select folder: `/ (root)`
5. Save

### Custom Domain Setup

If using custom domain:

1. Add CNAME to action inputs
2. Configure DNS records at your domain provider:
   - CNAME record: `python → <username>.github.io`
   - Or A records to GitHub's IPs
3. Enable HTTPS in repository settings (automatic after DNS propagation)

### GitHub Token Permissions

The default `GITHUB_TOKEN` needs write permissions:

```yaml
permissions:
  contents: write
```

Add to workflow file if deployment fails with permissions error.

## Deployment Behavior

### Orphan Branch (Default)

**Setting:** `force-orphan: 'true'`

**Behavior:**
- Creates fresh commit each time
- No deployment history
- Smaller repository size
- Faster deployments

**Use when:** You don't need deployment history

### Normal Branch

**Setting:** `force-orphan: 'false'`

**Behavior:**
- Preserves deployment history
- Git history shows changes over time
- Larger repository size
- Useful for auditing

**Use when:** You want to track deployment changes

## URL Generation

### With Custom Domain

**Input:** `cname: 'python.quantecon.org'`
**Output:** `https://python.quantecon.org`

### Without Custom Domain

**Repository:** `quantecon/lecture-python.myst`
**Output:** `https://quantecon.github.io/lecture-python.myst`

## Troubleshooting

### Deployment Fails

**Symptom:** `Error: Action failed with "The process '/usr/bin/git' failed with exit code 128"`

**Solutions:**
1. Check `GITHUB_TOKEN` permissions (needs `contents: write`)
2. Verify target branch doesn't have protection rules
3. Ensure build directory exists and isn't empty

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
2. Verify GitHub Pages is enabled in settings
3. Check correct branch is selected
4. Verify index.html exists in root

### Custom Domain Not Working

**Symptom:** CNAME configured but domain not resolving

**Solutions:**
1. Verify DNS records at domain provider
2. Wait for DNS propagation (up to 24 hours)
3. Check CNAME file exists in deployed site
4. Enable HTTPS in repository settings

### 422 Error

**Symptom:** `Error: Unprocessable Entity (HTTP 422)`

**Solutions:**
1. Check repository isn't archived
2. Verify you have write access
3. Ensure branch name is valid
4. Check GitHub Actions status

## Performance

| Step | Time |
|------|------|
| Prepare build | ~2 seconds |
| Deploy to branch | ~10-30 seconds |
| Generate URL | ~1 second |
| GitHub propagation | ~1-2 minutes |
| **Total** | **~15-35 seconds** |

**Note:** Propagation time (1-2 min) is after workflow completes.

## Examples

### Complete Publish Workflow

```yaml
name: Publish

on:
  push:
    tags: ['publish-*']

permissions:
  contents: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-lecture-env@v1
      
      - uses: quantecon/actions/build-lectures@v1
        id: build
      
      - uses: quantecon/actions/publish-gh-pages@v1
        with:
          build-dir: ${{ steps.build.outputs.build-path }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          cname: 'python.quantecon.org'
          commit-message: 'Deploy ${{ github.ref_name }}'
```

### Multi-Site Deployment

Deploy different builders to different branches:

```yaml
jobs:
  publish-html:
    steps:
      - uses: quantecon/actions/build-lectures@v1
        with:
          builder: 'html'
      
      - uses: quantecon/actions/publish-gh-pages@v1
        with:
          build-dir: '_build/html'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          target-branch: 'gh-pages'

  publish-notebooks:
    steps:
      - uses: quantecon/actions/build-lectures@v1
        with:
          builder: 'jupyter'
      
      - uses: quantecon/actions/publish-gh-pages@v1
        with:
          build-dir: '_build/jupyter'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          target-branch: 'notebooks'
          cname: 'notebooks.quantecon.org'
```

### Conditional Deployment

Deploy only on main branch:

```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  if: github.ref == 'refs/heads/main'
  with:
    build-dir: '_build/html'
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

See [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md) for complete workflow examples.
