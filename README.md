# QuantEcon Actions

Reusable composite GitHub Actions for building QuantEcon lecture repositories.

## Overview

This repository provides a set of composite actions that standardize and optimize the build process for QuantEcon lecture websites. These actions include intelligent caching strategies that significantly reduce build times.

**Status:** Active development - Next-generation container-based CI system in development.

📋 **See:** [docs/ARCHITECTURE-SUMMARY.md](./docs/ARCHITECTURE-SUMMARY.md) for the finalized architecture and [docs/NEXT-STEPS-CONTAINERS.md](./docs/NEXT-STEPS-CONTAINERS.md) for the implementation roadmap.

## Available Actions

### 🚀 [`setup-lecture-env-full`](./setup-lecture-env-full) **[Recommended]**
**Unified environment setup** with Conda and LaTeX packages with optimized caching.

**Time Savings:** ~5-6 minutes per run (via Conda caching)

**Features:**
- Single action replaces both `setup-lecture-env` and `setup-latex`
- Conda environment caching for fast restores
- Simplified workflow configuration
- Automatic environment activation

### 📚 [`build-lectures`](./build-lectures)
Builds Jupyter Book lectures (HTML, PDF, notebooks) with unified error handling.

**Features:** Cached builds, execution reports, multi-format support

### 🌐 [`deploy-netlify`](./deploy-netlify)
Deploys preview builds to Netlify for pull requests.

### 🚀 [`publish-gh-pages`](./publish-gh-pages)
Publishes production builds to GitHub Pages with release asset creation.

---

### Deprecated Actions

The following actions have been replaced by `setup-lecture-env-full`:
- ~~`setup-lecture-env`~~ - Use `setup-lecture-env-full` instead
- ~~`setup-latex`~~ - Use `setup-lecture-env-full` instead

## Quick Start

### Example: CI Workflow

```yaml
name: Build Preview
on: [pull_request]

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      # Unified environment setup (replaces setup-lecture-env + setup-latex)
      - uses: quantecon/actions/setup-lecture-env-full@main
        with:
          python-version: '3.13'
          environment-file: 'environment.yml'
          latex-requirements-file: 'latex-requirements.txt'
          environment-name: 'quantecon'
          install-ml-libs: 'false'
      
      - uses: quantecon/actions/build-lectures@main
        with:
          builder: 'html'
          source-dir: 'lectures'
      
      - uses: quantecon/actions/deploy-netlify@main
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Expected Time Savings

| Optimization | Time Saved | Applies To |
|--------------|-----------|------------|
| Conda environment caching | ~5-6 minutes | All workflows |
| pip package caching | 2-4 minutes | Workflows with ML libs (optional) |
| LaTeX installation | ~2-3 minutes | Workflows building PDFs (unavoidable) |
| **Total per workflow run** | **~5-6 minutes** | With Conda cache hit |

After caching: **Setup completes in ~7-8 minutes** (cached) instead of ~12 minutes (fresh)!

**Current Architecture:**
- ✅ Conda cache: Restores complete environment (~30 seconds)
- ⚠️ LaTeX: Always installs fresh (~2-3 minutes) - system package limitations
- 📋 See [NEXT-STEPS.md](./NEXT-STEPS.md) for future Docker-based architecture plan

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

- **[NEXT-STEPS.md](./NEXT-STEPS.md)** - Current status, testing progress, and future Docker architecture plan
- **[TESTING.md](./TESTING.md)** - Testing strategy and validation approach
- **[docs/MIGRATION-GUIDE.md](./docs/MIGRATION-GUIDE.md)** - Step-by-step migration instructions
- **[docs/QUICK-REFERENCE.md](./docs/QUICK-REFERENCE.md)** - Quick reference for all actions
- **[docs/SETUP.md](./docs/SETUP.md)** - Initial setup and configuration

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
