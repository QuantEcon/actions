# Changelog

All notable changes to the QuantEcon Actions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `setup-lecture-env-full` - Unified action combining Conda and LaTeX setup
- Comprehensive NEXT-STEPS.md with future Docker architecture plan
- Improved documentation across all actions

### Changed
- **BREAKING**: Deprecated `setup-lecture-env` and `setup-latex` in favor of `setup-lecture-env-full`
- Fixed critical bug: Conda environment now activates correctly on cache hits
- Removed LaTeX apt caching due to permission restrictions
- Simplified workflow configuration (one action instead of two)

### Fixed
- Conda environment activation when restoring from cache
- `jb: command not found` error on cache hits
- Apt cache permission errors during save operations

### Removed
- `setup-lecture-env` action (use `setup-lecture-env-full` instead)
- `setup-latex` action (use `setup-lecture-env-full` instead)
- LaTeX apt package caching (system package limitations)

### Performance
- Conda cache hit: ~5-6 minutes saved
- Total workflow time: ~7-8 min (cached) vs ~12 min (fresh)
- LaTeX: ~2-3 min install time (unavoidable with current architecture)

## [1.0.0] - TBD

### Release Notes
First stable release of QuantEcon Actions with unified environment setup.

**Key Features:**
- Unified `setup-lecture-env-full` action
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
