# QuantEcon Actions

Reusable composite GitHub Actions for building QuantEcon lecture repositories.

## Overview

This repository provides a set of composite actions that standardize and optimize the build process for QuantEcon lecture websites. These actions include intelligent caching strategies that significantly reduce build times.

**Status:** Container infrastructure complete. Ready for testing with lecture repositories.

📋 **See:** [docs/CONTAINER-GUIDE.md](./docs/CONTAINER-GUIDE.md) for quick start, [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) for design overview.

## Available Actions

### 🚀 [`setup-environment`](./setup-environment) **[Recommended]**
**Flexible environment setup** with optional Conda, LaTeX, and ML libraries.

**Time Savings:** ~5-6 minutes per run (container mode or cached Conda)

**Features:**
- **Container-aware**: Auto-detects QuantEcon container and optimizes setup
- Single action replaces both `setup-lecture-env` and `setup-latex`
- Conda environment caching for fast restores
- Simplified workflow configuration

### 📚 [`build-lectures`](./build-lectures)
Builds Jupyter Book lectures (HTML, PDF, notebooks) with unified error handling.

**Features:** Cached builds, execution reports, multi-format support

### 🌐 [`preview-netlify`](./preview-netlify)
Deploys preview builds to Netlify for pull requests with smart PR comments.

**Features:** Automatic changed-file detection, PR preview URLs, security-aware (skips forks)

### ☁️ [`preview-cloudflare`](./preview-cloudflare)
Deploys preview builds to Cloudflare Pages for pull requests.

**Features:** Free for public & private repos, predictable URLs (`pr-N.project.pages.dev`), changed lecture detection, smart PR comments

### 🚀 [`publish-gh-pages`](./publish-gh-pages)
Publishes production builds to GitHub Pages using native artifact-based deployment.

**Features:** Custom domain support, native GitHub Pages deployment (no gh-pages branch), optional release assets

## Quick Start

### Example: CI Workflow

```yaml
name: Build Preview
on: [pull_request]

jobs:
  preview:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon-build:latest  # Or quantecon:latest for full
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Required for preview-netlify change detection
      
      # Container-aware environment setup (auto-detects container)
      - uses: quantecon/actions/setup-environment@main
        with:
          environment-file: 'environment.yml'  # Optional - adds packages on top
      
      - uses: quantecon/actions/build-lectures@main
        with:
          builder: 'html'
          source-dir: 'lectures'
      
      - uses: quantecon/actions/preview-netlify@main
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: _build/html
```

### Example: Standard Mode (No Container)

For projects with custom environment.yml that need full control:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-environment@main
        with:
          python-version: '3.13'
          environment-file: 'environment.yml'  # Full installation from scratch
          install-latex: 'true'
          latex-requirements-file: 'latex-requirements.txt'
      
      - uses: quantecon/actions/build-lectures@main
```

## Expected Time Savings

| Optimization | Time Saved | Applies To |
|--------------|-----------|------------|
| Conda environment caching | ~5-6 minutes | All workflows |
| pip package caching | 2-4 minutes | Workflows with ML libs (optional) |
| LaTeX installation | ~2-3 minutes | Workflows building PDFs (unavoidable) |
| **Total per workflow run** | **~5-6 minutes** | With Conda cache hit |

After caching: **Setup completes in ~7-8 minutes** (cached) instead of ~12 minutes (fresh)!

**Container-Based Architecture (Available Now):**
- 🚀 Pre-built container images with LaTeX and Python environment included
- 📦 `ghcr.io/quantecon/quantecon:latest` - CPU-optimized container (Ubuntu 24.04 + TexLive + Miniconda)
- ⚡ Expected setup time: ~2-3 minutes (container pull + lecture-specific packages)
- 📋 See [containers/quantecon/README.md](./containers/quantecon/README.md) for container usage
- 🔄 Weekly automated builds (Monday 2am UTC) for security updates

## Usage by Repository

- **lecture-python.myst** - Requires ML libraries (JAX, PyTorch)
- **lecture-python-programming.myst** - Standard environment
- **lecture-python-intro** - Standard environment  
- **lecture-python-advanced.myst** - Standard environment

## Versioning

We use semantic versioning with Git tags:

- `@v1` - Latest stable v1.x.x release (recommended for production)
- `@v1.0.0` - Specific version (maximum stability)
- `@main` - Latest development (use for testing only)

## Migration Guide

## Documentation

- **[docs/CONTAINER-GUIDE.md](./docs/CONTAINER-GUIDE.md)** - Quick start with containers
- **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)** - System design and rationale
- **[docs/MIGRATION-GUIDE.md](./docs/MIGRATION-GUIDE.md)** - Migrating lecture repositories
- **[docs/QUICK-REFERENCE.md](./docs/QUICK-REFERENCE.md)** - Action reference
- **[docs/FUTURE-DEVELOPMENT.md](./docs/FUTURE-DEVELOPMENT.md)** - GPU support and roadmap
- **[TESTING.md](./TESTING.md)** - Testing strategy

## Getting Started

See [docs/MIGRATION-GUIDE.md](./docs/MIGRATION-GUIDE.md) for step-by-step instructions on migrating a lecture repository to use these actions.

## Testing

See [TESTING.md](./TESTING.md) for our testing strategy and validation procedures.

## Contributing

1. Create a feature branch
2. Make changes to composite actions
3. Test using `@main` reference in a lecture repository
4. Create a pull request with test results
5. After merge, create a new version tag

## License

MIT License - see LICENSE file for details

## Support

For issues or questions, please open an issue in this repository or contact the QuantEcon development team.
