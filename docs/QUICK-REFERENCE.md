# QuantEcon Actions - Quick Reference

A cheat sheet for using QuantEcon composite actions in your workflows.

## 📦 Available Actions

| Action | Purpose | Time Savings |
|--------|---------|--------------|
| `setup-environment` | Conda + Python + LaTeX + ML libs | ~5-6 min (cached) |
| `build-lectures` | Jupyter Book builds | Varies (cached execution) |
| `preview-netlify` | PR preview deployment | ~1 min |
| `publish-gh-pages` | GitHub Pages deployment | ~30 sec |

## 🚀 Quick Start

### Minimal CI Workflow

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

### Add ML Libraries (JAX/PyTorch)

```yaml
- uses: quantecon/actions/setup-environment@v1
  with:
    install-ml-libs: 'true'
```

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

### Fast PR Builds (with Build Cache)

```yaml
- uses: quantecon/actions/build-lectures@v1
  with:
    use-build-cache: true  # Restore from main's cache
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
| `setup-environment` | `conda-{OS}-{hash(env.yml)}-{version}` | env.yml changes, manual bump |
| `build-lectures` (exec) | `jupyter-cache-{OS}-{hash(lectures)}-{sha}` | lecture changes, new commit |
| `build-lectures` (build) | `build-{hash(environment.yml)}` | environment.yml changes |

## 🎯 Inputs Quick Reference

### setup-environment

```yaml
python-version: '3.13'           # Python version
environment-file: 'environment.yml'  # Conda env file
environment-name: 'quantecon'    # Conda env name
cache-version: 'v1'              # Manual cache control
install-latex: 'false'           # Install LaTeX packages
latex-requirements-file: 'latex-requirements.txt'  # LaTeX packages list
install-ml-libs: 'false'         # JAX/PyTorch/CUDA
ml-libs-version: 'jax062-...'    # ML cache key
```

### build-lectures

```yaml
builder: 'html'                  # html|pdflatex|jupyter
source-dir: 'lectures'           # Source directory
output-dir: './'                 # Output base
extra-args: '-W --keep-going'    # JB arguments
cache-notebook-execution: 'true' # Enable exec cache
use-build-cache: 'false'         # Restore _build from GitHub cache
html-copy-pdf: 'false'           # Copy PDFs to _build/html/_pdf/
html-copy-notebooks: 'false'     # Copy notebooks to _build/html/_notebooks/
upload-failure-reports: 'false'  # Upload reports on failure
```

### preview-netlify

```yaml
netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}  # Required
netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}        # Required
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
# Check execution cache enabled
cache-notebook-execution: 'true'
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
- uses: quantecon/actions/setup-environment@v1
  with:
    install-latex: 'true'
    install-ml-libs: 'true'  # JAX + PyTorch
```

### lecture-python-programming.myst

```yaml
# Standard setup (no ML libs)
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
