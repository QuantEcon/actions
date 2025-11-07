# QuantEcon Actions

Reusable composite GitHub Actions for building QuantEcon lecture repositories.

## Overview

This repository provides a set of composite actions that standardize and optimize the build process for QuantEcon lecture websites. These actions include intelligent caching strategies that significantly reduce build times.

## Available Actions

### � [`setup-lecture-env-full`](./setup-lecture-env-full) **[Recommended]**
**Unified environment setup** with Conda and LaTeX packages with optimized caching.

**Time Savings:** 6-8 minutes per run (via Conda and apt caching)

**Features:**
- Single action replaces both `setup-lecture-env` and `setup-latex`
- Separate Conda and LaTeX apt caches for optimal performance
- Simpler workflow configuration

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
| Conda environment caching | 5-6 minutes | All workflows |
| pip package caching | 2-4 minutes | Workflows with ML libs |
| LaTeX apt caching | 1-2 minutes | Workflows building PDFs |
| **Total per workflow run** | **~6-8 minutes** | With both caches hit |

After caching: **Setup completes in ~4-5 minutes** instead of 12 minutes fresh!

**Cache Strategy:**
- **Conda cache**: Restores complete environment (~30 seconds)
- **LaTeX apt cache**: Skips package downloads, only installs (~3 minutes)
- Both caches invalidate independently based on `environment.yml` and `latex-requirements.txt`

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

See [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md) for step-by-step instructions on migrating a lecture repository to use these actions.

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
