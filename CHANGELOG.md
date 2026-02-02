# Changelog

All notable changes to the QuantEcon Actions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **BREAKING**: Renamed `deploy-netlify` → `preview-netlify` to better reflect its purpose as a PR preview action (not production deployment)

### Added
- **Container Infrastructure** (`ghcr.io/quantecon/quantecon:latest`)
  - Ubuntu 24.04 LTS + TexLive (latest) + Miniconda + Python 3.13
  - Anaconda 2025.12 metapackage (numpy, scipy, pandas, matplotlib, jupyter)
  - Jupyter Book 1.0.4post1 + sphinx extensions
  - Weekly automated builds (Monday 2am UTC)
  - CPU-focused for initial rollout
- `setup-environment` - Flexible environment setup
  - Optional `install-latex` (default: false) for ubuntu-latest workflows
  - Works in containers, ubuntu-latest, or custom AMI
  - Conda environment caching (~5-6 min savings)
- Container documentation (`containers/quantecon/README.md`)

### Changed
- **BREAKING**: Renamed `setup-lecture-env-full` → `setup-environment`
- **BREAKING**: Deprecated `setup-lecture-env` and `setup-latex`
- Optimized container environment.yml to use Anaconda metapackage
- LaTeX versions from Ubuntu repos (no version pins) for automatic security updates
- Lecture-specific packages (quantecon, cvxpy) installed from each lecture's environment.yml

### Fixed
- Conda environment activation on cache hits
- `jb: command not found` error with cached environments

### Removed
- LaTeX apt caching (permission restrictions)
- GPU container and AMI infrastructure (deferred to future)

### Performance
- Container setup: ~2-3 min (vs ~7-8 min ubuntu-latest)
- Container includes pre-installed LaTeX (saves 2-3 min)
- Container includes Anaconda base (saves 3-4 min)
- Overall: 60-70% faster environment setup

## [1.0.0] - TBD

### Release Notes
First stable release of QuantEcon Actions with unified environment setup.

**Key Features:**
- Unified `setup-environment` action
- Conda environment caching (~5-6 min savings)
- Multi-builder support (HTML, PDF, Jupyter notebooks)
- Netlify preview deployments
- GitHub Pages publishing with release assets
- Comprehensive error handling and execution reports

**Tested Across:**
- test-lecture-python-intro (validation testing)

**Time Savings:**
- ~5-6 minutes per build with Conda cache hit
- Setup: ~7-8 min (cached) vs ~12 min (fresh)

**Future Direction:**
- Docker-based architecture planned for v2.0
- Target: Sub-1 minute environment setup
- See NEXT-STEPS.md for implementation plan

---

## Version History

- **v1**: Initial stable release
- **Unreleased**: Development version with latest features

## Migration from Legacy Workflows

See [docs/MIGRATION-GUIDE.md](docs/MIGRATION-GUIDE.md) for step-by-step instructions on migrating from repository-specific workflows to these centralized actions.

## Testing

See [TESTING.md](TESTING.md) for comprehensive testing strategy and validation procedures.
