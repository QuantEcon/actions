# QuantEcon Actions

Reusable composite GitHub Actions for building QuantEcon lecture repositories.

## Overview

This repository provides a set of composite actions that standardize and optimize the build process for QuantEcon lecture websites. These actions include intelligent caching strategies that significantly reduce build times.

## Available Actions

### 🐍 [`setup-lecture-env`](./setup-lecture-env)
Sets up Conda environment with Python, pip packages, and optional ML libraries (JAX, PyTorch).

**Time Savings:** 3-5 minutes per run (via conda/pip caching)

### 📝 [`setup-latex`](./setup-latex)
Installs LaTeX packages via apt-get with intelligent caching.

**Time Savings:** 2-3 minutes per run (after first install)

### 📚 [`build-lectures`](./build-lectures)
Builds Jupyter Book lectures (HTML, PDF, notebooks) with unified error handling.

**Features:** Cached builds, execution reports, multi-format support

### 🌐 [`deploy-netlify`](./deploy-netlify)
Deploys preview builds to Netlify for pull requests.

### 🚀 [`publish-gh-pages`](./publish-gh-pages)
Publishes production builds to GitHub Pages with release asset creation.

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
      
      - uses: quantecon/actions/setup-lecture-env@v1
        with:
          install-ml-libs: 'false'
      
      - uses: quantecon/actions/setup-latex@v1
      
      - uses: quantecon/actions/build-lectures@v1
        with:
          build-html: 'true'
          build-pdf: 'true'
      
      - uses: quantecon/actions/deploy-netlify@v1
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Expected Time Savings

| Optimization | Time Saved | Applies To |
|--------------|-----------|------------|
| Conda environment caching | 3-5 minutes | All workflows |
| pip package caching | 2-4 minutes | Workflows with ML libs |
| LaTeX caching | 2-3 minutes | Workflows building PDFs |
| **Total per workflow run** | **~8-12 minutes** | First run after cache miss |

After caching: **Setup completes in ~30-60 seconds** instead of 8-12 minutes!

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
