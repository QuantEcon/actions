# Changelog

All notable changes to the QuantEcon Actions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Architecture**: Simplified notebook deployment - notebooks now served from gh-pages
  instead of separate `.notebooks` repos
  - Eliminates 4 separate `.notebooks` repositories (one per lecture series)
  - Removes sync workflows from publish pipelines
  - Google Colab integration via direct gh-pages URLs
  - Requires `quantecon-book-theme` update (tracked in quantecon-book-theme#359)
  - Single source of truth for notebooks alongside HTML content

### Removed
- **`setup-environment`**: Remove `install-ml-libs` and `ml-libs-version` inputs ⚠️ **BREAKING**
  - ML/GPU libraries (JAX, PyTorch, numpyro) should be specified in each repo's
    `environment.yml` or `environment-update.yml` instead of being hardcoded in the action
  - JAX now bundles its own CUDA toolkit via pip (`jax[cuda13]`), so system-level
    CUDA installation is unnecessary — GPU drivers on the AMI are sufficient
  - Removes pip cache step and hardcoded install step for ML libraries
  - **Migration:** Repos using `install-ml-libs: 'true'` should move ML packages to
    their `environment-update.yml` and remove the `install-ml-libs` input

### Added
- **Documentation**: New GPU-AMI-SETUP.md guide for building RunsOn GPU AMI
  - Driver requirements (NVIDIA >= 580 for CUDA 13)
  - Packer template for automated AMI builds
  - Marker file setup for container detection
  - Architecture notes on JAX bundled CUDA

## [0.5.2] - 2026-02-06

### Added
- **`restore-jupyter-cache`**: New `save-cache` input for PR-scoped build caching (#24)
  - When `true`, saves build cache at job end using `actions/cache`
  - Subsequent pushes to the same PR restore the prior build, only re-executing changed notebooks
  - Cache is scoped to the PR branch (cannot affect other PRs or main)
  - Default `false` preserves existing read-only behavior

## [0.5.1] - 2026-02-06

### Fixed
- **`build-lectures`**: Stage PDF and notebooks *before* HTML build so Jupyter Book
  theme can detect them and activate download features (#23)
- **`preview-netlify`**: Replace `jq` with `python3` for JSON parsing (lean container
  does not include `jq`)
- **`quantecon-build` container**: Add `texlive-fonts-extra` (provides `bbm.sty`) and
  `xindy` for PDF builds

### Changed
- **`test-containers-lectures`**: Add `builder` dimension to test matrix
  (container × repo × builder) for parallel validation of all build types
- **`test-containers-lectures`**: Add `builder` input to `workflow_dispatch` for
  targeted manual testing

## [0.5.0] - 2026-02-06

### Changed
- Renamed `environment-file` input to `environment` across all actions
  - `setup-environment`: `environment-file` → `environment`
  - `build-jupyter-cache`: `environment-file` → `environment`
  - `restore-jupyter-cache`: `environment-file` → `environment`

### Added
- **`environment-update`** input for container-optimized builds
  - `setup-environment`: New `environment-update` input for delta package installs
  - `build-jupyter-cache`: New `environment-update` input (passed through to setup-environment)
  - `restore-jupyter-cache`: New `environment-update` input (for cache key computation)
  - Default `''` skips conda update entirely in container mode (fastest path)
  - When specified, installs only delta packages from a minimal environment file
- Cache key computation now includes both `environment` and `environment-update` file hashes
- Documentation for RunsOn + custom AMI setup for GPU builds
  - AMI requirements for container mode detection (marker file)
  - Workflow examples and comparison tables

## [0.4.0] - 2026-02-05

### Added
- **`build-jupyter-cache`** - Dedicated action for building and caching notebook execution
  - Runs on `main` branch (scheduled weekly or on push)
  - Full notebook execution with Jupyter Book
  - Saves execution cache with unique key (`build-{env-hash}-{run-id}`)
  - Verification step ensures cache validity before saving
  - Creates GitHub issue on build failure with duplicate prevention
  - Uploads execution reports as artifacts on failure

- **`restore-jupyter-cache`** - Dedicated action for restoring notebook execution cache
  - Runs on PR branches (read-only restore, never saves)
  - Prefix-based matching finds most recent cache
  - Detailed cache status output (hit/miss, matched key)
  - ~80% build time reduction when cache available (tested: 16m53s → 3m28s)

- **Workflow Templates** (`templates/`)
  - `cache.yml` - Container-based cache workflow for lecture repos
  - `cache-standard.yml` - Standard runner workflow (with LaTeX install)
  - `README.md` - Template documentation and usage instructions

### Changed
- **BREAKING**: Removed caching inputs from `build-lectures`
  - Removed `cache-notebook-execution` input
  - Removed `use-build-cache` input
  - Removed `build-cache-hit` output
  - **Migration**: Use dedicated `build-jupyter-cache` and `restore-jupyter-cache` actions

### Documentation
- Updated ARCHITECTURE.md with Layer 2 caching strategy
- Updated MIGRATION-GUIDE.md with cache workflow examples
- Updated QUICK-REFERENCE.md with cache action reference
- Added comprehensive README for both cache actions

## [0.3.0] - 2026-02-05

### Added
- **Lean Container** (`ghcr.io/quantecon/quantecon-build:latest`)
  - Optimized for CI builds (~3GB vs ~8GB full container)
  - Miniconda + Python 3.13 + Jupyter Book tooling
  - XeLaTeX with essential packages (no full TexLive)
  - Weekly automated builds alongside full container

- **Container Test Workflow** (`.github/workflows/test-container.yml`)
  - Automated validation of both containers after builds
  - XeLaTeX compilation tests
  - Jupyter Book HTML/PDF build tests

- **Lecture Validation Tests** (`.github/workflows/test-containers-lectures.yml`)
  - Full lecture builds against all 4 QuantEcon lecture repositories
  - Tests container's built-in environment (ignores lecture repo's environment.yml)
  - Matrix-based parallel testing across all containers × all repos (2×4 = 8 jobs)
  - Triggered automatically after container builds, or manually via workflow_dispatch
  - 120-minute timeout per build, artifacts retained for debugging
  - Validated: All 4 lecture repos build successfully on both containers

### Changed
- **`setup-environment`** - Now container-aware
  - Auto-detects QuantEcon containers via `/etc/quantecon-container` marker
  - Skips redundant LaTeX installation when running in container
  - Activates pre-installed `quantecon` conda environment in containers
  - Falls back to full setup on `ubuntu-latest` or other runners
  - Added `skip-latex` input for manual control

- **Container Infrastructure**
  - Added Chrome + kaleido for Plotly static image export (`fig.to_image()`)
  - Added Intel MKL for optimized linear algebra (2-3x faster for numerical computations)
  - Added scikit-learn for ML lectures
  - Added DejaVu fonts to both containers for XeLaTeX compatibility
  - Updated lean container to Miniconda py313_25.11.1-1
  - Uses `defaults` channel only (matches Anaconda metapackage behavior)

### Documentation
- Added container marker documentation
- Updated setup-environment README with container detection details

## [0.2.0] - 2026-02-03

### Added
- `preview-cloudflare` - Cloudflare Pages deployment for PR previews
  - Works with public and private repositories (free tier supports both)
  - Predictable preview URLs (`pr-{number}.{project}.pages.dev`)
  - Changed lecture detection with direct links in PR comments
  - Smart PR comments (updates existing instead of duplicates)
  - Security-aware (skips forks and dependabot)

### Changed
- **BREAKING**: Renamed `deploy-netlify` → `preview-netlify` to better reflect its purpose as a PR preview action (not production deployment)

## [0.1.1] - 2026-01-16

### Changed
- Improved failure logging with clear summary
  - Add prominent error message on build failure
  - Display build configuration summary
  - Provide instructions for downloading execution reports

### Documentation
- Add comprehensive Netlify setup guide
  - CLI-only site creation instructions
  - How to disable duplicate PR comments
  - Decision table for different scenarios

## [0.1.0] - 2026-01-16

### Added
- **Core Actions:**
  - `setup-environment` - Conda/LaTeX/ML environment setup with caching
  - `build-lectures` - Jupyter Book builds with execution caching
  - `deploy-netlify` - PR preview deployment with smart comments
  - `publish-gh-pages` - Native GitHub Pages deployment (OIDC-based)

- **Container Infrastructure** (`ghcr.io/quantecon/quantecon:latest`)
  - Ubuntu 24.04 LTS + TexLive (latest) + Miniconda + Python 3.13
  - Anaconda 2025.12 metapackage (numpy, scipy, pandas, matplotlib, jupyter)
  - Jupyter Book 1.0.4post1 + sphinx extensions
  - Weekly automated builds (Monday 2am UTC)

- **Build Features:**
  - Asset assembly (`html-copy-pdf`, `html-copy-notebooks`)
  - Execution reports on failure
  - GitHub native build cache for fast PR builds
  - Multi-format support (HTML, PDF, Jupyter notebooks)

### Performance
- Container setup: ~2-3 min (vs ~7-8 min ubuntu-latest)
- Conda environment caching (~5-6 min savings)
- Overall: 60-70% faster environment setup

---

## Version History

- **v0**: Tracks latest stable release (currently v0.1.1)
- **v0.x.x**: Development/testing releases

## Migration from Legacy Workflows

See [docs/MIGRATION-GUIDE.md](docs/MIGRATION-GUIDE.md) for step-by-step instructions on migrating from repository-specific workflows to these centralized actions.

## Testing

See [TESTING.md](TESTING.md) for comprehensive testing strategy and validation procedures.
