# QuantEcon Actions - Quick Reference

A cheat sheet for using QuantEcon composite actions in your workflows.

## 📦 Available Actions

| Action | Purpose | Time Savings |
|--------|---------|--------------|
| `setup-environment` | Conda + Python + LaTeX | ~5-6 min (cached) |
| `build-lectures` | Jupyter Book builds | Varies (cached execution) |
| `build-jupyter-cache` | Weekly cache generation (main branch) | Enables 80% faster CI |
| `restore-jupyter-cache` | Read-only cache restore (PRs) | ~14 min (avoids full rebuild) |
| `preview-netlify` | PR preview deployment (Netlify) | ~1 min |
| `preview-cloudflare` | PR preview deployment (Cloudflare) | ~1 min |
| `publish-gh-pages` | GitHub Pages deployment | ~30 sec |

## 🚀 Quick Start

### Container CI Workflow (Recommended - Fastest)

Two container options:
- `ghcr.io/quantecon/quantecon:latest` (~8GB) - Full Anaconda, max compatibility
- `ghcr.io/quantecon/quantecon-build:latest` (~3GB) - Lean, faster CI pulls

```yaml
name: CI
on: [pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon-build:latest  # Lean container for CI
    permissions:
      contents: read
      packages: read
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: quantecon/actions/setup-environment@v1
        with:
          environment-update: 'environment-update.yml'  # Optional - delta packages for container
        # Auto-detects container, installs only lecture-specific packages
      - uses: quantecon/actions/restore-jupyter-cache@v1
        with:
          cache-type: 'build'
      - uses: quantecon/actions/build-lectures@v1
        id: build
      - uses: quantecon/actions/preview-netlify@v1
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: ${{ steps.build.outputs.build-path }}
```

### Standard CI Workflow (No Container)

```yaml
name: CI
on: [pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: quantecon/actions/setup-environment@v1
        with:
          install-latex: 'true'
      - uses: quantecon/actions/build-lectures@v1
        id: build
      - uses: quantecon/actions/preview-netlify@v1
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: ${{ steps.build.outputs.build-path }}
```

### Minimal Publish Workflow

```yaml
name: Publish
on:
  push:
    tags: ['publish-*']

permissions:
  contents: read
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
```

## 🔧 Common Customizations

### Build PDF

```yaml
- uses: quantecon/actions/setup-environment@v1
  with:
    install-latex: 'true'

- uses: quantecon/actions/build-lectures@v1
  with:
    builder: 'pdflatex'
```

### Build Jupyter Notebooks

```yaml
- uses: quantecon/actions/build-lectures@v1
  with:
    builder: 'jupyter'
```

### Fast PR Builds (with Execution Cache)

Add `restore-jupyter-cache` before `build-lectures` to restore cached execution state:

```yaml
- uses: quantecon/actions/restore-jupyter-cache@v1
  with:
    cache-type: 'build'

- uses: quantecon/actions/build-lectures@v1
  id: build
```

**Note:** Requires a `cache.yml` workflow to generate the cache. See [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md#step-5-update-cacheyml).

### Preview with Custom URL

```yaml
- uses: quantecon/actions/preview-netlify@v1
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: '_build/html'
    alias: 'pr-${{ github.event.pull_request.number }}'
```

### Force Cache Rebuild

```yaml
- uses: quantecon/actions/setup-environment@v1
  with:
    cache-version: 'v2'  # Bump from v1
```

## 💾 Cache Keys Reference

| Action | Cache Key | Invalidates On |
|--------|-----------|----------------|
| `setup-environment` (container) | No caching | N/A |
| `setup-environment` (standard) | `conda-{OS}-{hash(env.yml)}-{version}` | env.yml changes, manual bump |
| `build-jupyter-cache` | `build-{hash(env.yml)}-{hash(env-update.yml)}-{run-id}` | env file changes, each run |
| `restore-jupyter-cache` | `build-{hash(env.yml)}-{hash(env-update.yml)}-` (prefix) | env file changes |

## 🎯 Inputs Quick Reference

### setup-environment

```yaml
python-version: '3.13'           # Python version (ignored in container mode)
environment: 'environment.yml'       # Conda env file (non-container mode)
environment-update: ''               # Delta env file for container mode (empty = skip)
environment-name: 'quantecon'    # Conda env name
cache-version: 'v1'              # Manual cache control
install-latex: 'false'           # Install LaTeX (auto-disabled in container)
latex-requirements-file: 'latex-requirements.txt'  # LaTeX packages list
```

**Outputs:** `container-mode`, `conda-cache-hit`

### build-lectures

```yaml
builder: 'html'                  # html|pdflatex|jupyter
source-dir: 'lectures'           # Source directory
output-dir: './'                 # Output base
extra-args: '-W --keep-going'    # JB arguments
html-copy-pdf: 'false'           # Copy PDFs to _build/html/_pdf/
html-copy-notebooks: 'false'     # Copy notebooks to _build/html/_notebooks/
upload-failure-reports: 'false'  # Upload reports on failure
```

**Note:** Caching is handled separately via `build-jupyter-cache` and `restore-jupyter-cache`.

### preview-netlify

```yaml
netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}  # Required
netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}        # Required
build-dir: '_build/html'         # Required
lectures-dir: 'lectures'         # For change detection (default)
```

### preview-cloudflare

```yaml
cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}  # Required
cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}  # Required
project-name: 'my-lectures'      # Required - Cloudflare Pages project name
build-dir: '_build/html'         # Required
lectures-dir: 'lectures'         # For change detection (default)
```

### publish-gh-pages

```yaml
build-dir: '_build/html'         # Required
cname: ''                        # Custom domain (optional)
```

**Note:** Uses native GitHub Pages deployment. Requires workflow permissions:
```yaml
permissions:
  pages: write
  id-token: write
```

## 📊 Outputs Quick Reference

### build-lectures

```yaml
- id: build
  uses: quantecon/actions/build-lectures@v1

# Access: ${{ steps.build.outputs.build-path }}
```

### preview-netlify

```yaml
- id: netlify
  uses: quantecon/actions/preview-netlify@v1

# Access:
# - ${{ steps.netlify.outputs.deploy-url }}
# - ${{ steps.netlify.outputs.changed-files }}
```

### publish-gh-pages

```yaml
- id: pages
  uses: quantecon/actions/publish-gh-pages@v1

# Access: ${{ steps.pages.outputs.page-url }}
```

## 🔍 Debugging Tips

### Check Cache Hits

Look for in logs:
```
Conda cache hit: true
LaTeX cache hit: true
Jupyter cache hit: false
```

### Common Issues

**Cache not working?**
```yaml
# Bump cache version
cache-version: 'v2'
```

**Build too slow?**
```yaml
# Use restore-jupyter-cache before build-lectures
- uses: quantecon/actions/restore-jupyter-cache@v1
  with:
    cache-type: 'build'
```

**Netlify auth failing?**
```bash
# Verify secrets exist
gh secret list
```

**Pages 404?**
```yaml
# Ensure permissions set
permissions:
  contents: write
```

## 📚 Full Documentation

- **README.md** - Repository overview
- **ARCHITECTURE.md** - Architecture overview
- **CONTAINER-GUIDE.md** - Container usage guide
- **MIGRATION-GUIDE.md** - Migration steps
- **FUTURE-DEVELOPMENT.md** - Future plans
- **{action}/README.md** - Detailed action docs

## 🎓 Repository-Specific Notes

### lecture-python.myst (GPU)

```yaml
# ML packages (JAX, PyTorch) specified in repo's environment.yml
- uses: quantecon/actions/setup-environment@v1
  with:
    environment-update: 'environment-update.yml'
```

### lecture-python-programming.myst

```yaml
# Standard setup
- uses: quantecon/actions/setup-environment@v1
  with:
    install-latex: 'true'
```

### lecture-python-intro

```yaml
# Netlify only (no GH Pages)
- uses: quantecon/actions/preview-netlify@v1
```

### lecture-python-advanced.myst

```yaml
# Same as programming (standard setup)
- uses: quantecon/actions/setup-environment@v1
  with:
    install-latex: 'true'
```

## 🔗 Links

- **Repository:** https://github.com/quantecon/actions
- **Issues:** https://github.com/quantecon/actions/issues
- **Releases:** https://github.com/quantecon/actions/releases

---

**💡 Pro Tip:** Start with the minimal workflow and add customizations as needed!
