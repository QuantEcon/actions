# Changelog

All notable changes to the QuantEcon Actions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of QuantEcon Actions repository
- `setup-lecture-env` action for Conda environment setup
- `setup-latex` action for LaTeX package installation
- `build-lectures` action for Jupyter Book builds
- `deploy-netlify` action for Netlify deployments
- `publish-gh-pages` action for GitHub Pages publishing
- Comprehensive documentation for each action
- Testing strategy guide (TESTING.md)
- Migration guide for existing repositories (MIGRATION-GUIDE.md)

### Features
- Intelligent caching for Conda environments (3-5 min → 30 sec)
- Workflow-based LaTeX caching (2-3 min → 10 sec)
- Notebook execution caching for incremental builds
- Automatic PR comments for Netlify previews
- Multi-builder support (HTML, PDF, Jupyter notebooks)
- ML library support (JAX, PyTorch, NumPyro, Pyro)
- Custom domain support for GitHub Pages
- Time savings: 8-12 minutes per workflow

## [1.0.0] - TBD

### Release Notes
First stable release of QuantEcon Actions. Tested across:
- lecture-python.myst
- lecture-python-programming.myst
- lecture-python-intro
- lecture-python-advanced.myst

Estimated time savings: 8-12 minutes per build across 4 repositories.

---

## Version History

- **v1**: Initial stable release
- **Unreleased**: Development version with latest features

## Migration from Legacy Workflows

See [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md) for step-by-step instructions on migrating from repository-specific workflows to these centralized actions.

## Testing

See [TESTING.md](TESTING.md) for comprehensive testing strategy and validation procedures.
