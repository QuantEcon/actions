# QuantEcon Actions

Reusable composite GitHub Actions for building QuantEcon lecture repositories.

## Overview

This repository provides a set of composite actions that standardize and optimize the build process for QuantEcon lecture websites. These actions include intelligent caching strategies that significantly reduce build times.

**Status:** Stable; current release `v0.8.0` (see the [CHANGELOG](./CHANGELOG.md)).

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

**Features:** Multi-format builds, asset assembly (PDF/notebooks into HTML), execution reports on failure

### 🌐 [`preview-netlify`](./preview-netlify)
Deploys preview builds to Netlify for pull requests with smart PR comments.

**Features:** Automatic changed-file detection, PR preview URLs, security-aware (skips forks)

### ☁️ [`preview-cloudflare`](./preview-cloudflare)
Deploys preview builds to Cloudflare Pages for pull requests.

**Features:** Free for public & private repos, predictable URLs (`pr-N.project.pages.dev`), changed lecture detection, smart PR comments

### 🚀 [`publish-gh-pages`](./publish-gh-pages)
Publishes production builds to GitHub Pages using native artifact-based deployment.

**Features:** Custom domain support, native GitHub Pages deployment (no gh-pages branch), optional release assets

### 💾 [`build-jupyter-cache`](./build-jupyter-cache)
Weekly cache generation for main branch builds.

**Features:** Multi-format builds (html, pdflatex, jupyter), validates all builds pass before saving, creates GitHub issues on failure, unique cache keys for safe updates

### 📥 [`restore-jupyter-cache`](./restore-jupyter-cache)
Read-only cache restore for PR workflows.

**Features:** Never saves (PRs can't corrupt cache), prefix matching for latest cache, detailed status logging, optional `fail-on-miss`

## Quick Start

### Example: CI Workflow with Cache

```yaml
name: Build Preview
on: [pull_request]

jobs:
  preview:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon-build:latest
    permissions:
      contents: read
      packages: read
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      # Restore cache from main branch builds
      - uses: quantecon/actions/restore-jupyter-cache@v0
        with:
          cache-type: 'build'
      
      # Build (uses restored cache for incremental build)
      - uses: quantecon/actions/build-lectures@v0
        id: build
      
      - uses: quantecon/actions/preview-netlify@v0
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: ${{ steps.build.outputs.build-path }}
```

### Example: Cache Generation Workflow

Run weekly on main branch to generate cache for PRs:

```yaml
name: Build Cache
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2am UTC
  workflow_dispatch:

jobs:
  cache:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    permissions:
      contents: read
      issues: write
      packages: read
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/build-jupyter-cache@v0
        with:
          builders: 'html'
          create-issue-on-failure: true
```

### Example: Standard Mode (No Container)

For projects with custom environment.yml that need full control:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-environment@v0
        with:
          python-version: '3.13'
          environment: 'environment.yml'  # Full installation from scratch
          install-latex: 'true'
          latex-requirements-file: 'latex-requirements.txt'
      
      - uses: quantecon/actions/build-lectures@v0
```

## Performance Architecture

### Container-Based Setup
- Pre-built container images with LaTeX and Python environment
- `ghcr.io/quantecon/quantecon:latest` - Full image (~8.3 GB on disk, ~3.2 GB compressed pull)
- `ghcr.io/quantecon/quantecon-build:latest` - Lean image (~7.1 GB on disk, ~2.9 GB compressed pull); drops the full Anaconda metapackage, so it's only modestly smaller
- Setup time: ~2-3 minutes (container pull + lecture-specific packages)
- Weekly automated builds (Monday 2am UTC) for security updates

### Jupyter Book Execution Caching
Use `build-jupyter-cache` and `restore-jupyter-cache` actions for execution caching:

| Scenario | Build Time | Details |
|----------|-----------|---------|
| Full build (no cache) | ~17 minutes | All notebooks executed |
| Incremental build (cached) | ~3-4 minutes | Only changed notebooks executed |
| Time saved | **~13 minutes** | ~80% reduction |

**How it works:**
1. Weekly `build-jupyter-cache` runs on main branch (e.g., Monday 2am UTC)
2. PR workflows use `restore-jupyter-cache` to get the cached execution state
3. Jupyter Book only re-executes notebooks that have changed since the cache

## Usage by Repository

The lecture repositories that consume these actions are tracked centrally in [QuantEcon/meta#321](https://github.com/QuantEcon/meta/issues/321) (avoids maintaining a duplicate list here).

## Versioning

We're in the `0.x` development phase (pre-1.0.0). Reference the actions with:

- `@v0` - Latest `0.x` release (recommended; floating tag, moved to each new release)
- `@v0.8.0` - Specific version (maximum reproducibility)
- `@main` - Latest development (use for testing only)

> ⚠️ During `0.x`, minor releases (`0.x.0`) may include breaking changes, so the floating
> `@v0` tag can move across a breaking change. Pin to an exact `@v0.x.y` tag if you need
> a guaranteed-stable reference. Floating major tags (`@v1`, `@v2`) will be introduced
> after the 1.0.0 release.

## Documentation

- **[docs/CONTAINER-GUIDE.md](./docs/CONTAINER-GUIDE.md)** - Quick start with containers
- **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)** - System design and rationale
- **[docs/MIGRATION-GUIDE.md](./docs/MIGRATION-GUIDE.md)** - Migrating lecture repositories
- **[docs/QUICK-REFERENCE.md](./docs/QUICK-REFERENCE.md)** - Action reference
- **[docs/GPU-AMI-SETUP.md](./docs/GPU-AMI-SETUP.md)** - Building RunsOn GPU AMI
- **[docs/FUTURE-DEVELOPMENT.md](./docs/FUTURE-DEVELOPMENT.md)** - GPU support and roadmap
- **[TESTING.md](./TESTING.md)** - Testing strategy
- **[PLAN.md](./PLAN.md)** - Current work plan, backlog, and rollout status

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
