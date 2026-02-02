# QuantEcon Actions - Development Guide

**Always reference these instructions first for context about this repository.**

## Repository Purpose

This repository contains **reusable GitHub Actions composite actions** for building and deploying QuantEcon lecture materials. These actions centralize common workflow patterns across 4 lecture repositories:

- `lecture-python.myst` (GPU, ML libraries, GitHub Pages)
- `lecture-python-programming.myst` (Standard, GitHub Pages) 
- `lecture-python-intro` (Standard, Netlify)
- `lecture-python-advanced.myst` (Standard, GitHub Pages)

## Current Status

**✅ COMPLETED (November 20, 2025):**
- Container infrastructure (`ghcr.io/quantecon/quantecon:latest`)
  - Ubuntu 24.04 LTS + TexLive + Miniconda + Python 3.13
  - Anaconda 2025.12 metapackage (base scientific stack)
  - Jupyter Book 1.0.4post1 + extensions
  - Weekly automated builds (Monday 2am UTC)
- Composite actions:
  - `setup-environment` - Flexible environment setup with optional LaTeX
  - `build-lectures` - Jupyter Book builds
  - `preview-netlify` - Netlify PR previews
  - `publish-gh-pages` - GitHub Pages publishing
- Documentation:
  - docs/CONTAINER-GUIDE.md - Container usage
  - docs/ARCHITECTURE.md - System design
  - docs/MIGRATION-GUIDE.md - Migration steps
  - docs/FUTURE-DEVELOPMENT.md - GPU roadmap
  - TESTING.md - Validation strategy

**🧪 NEXT: TESTING PHASE**
- **Test Repository:** `QuantEcon/test-lecture-python-intro`
- **Goal:** Validate container workflow with real lecture content
- **Metrics:** Compare build times, outputs, deployment
- **See:** TESTING.md for detailed validation steps

**⏳ PENDING:**
- Test container with test-lecture-python-intro
- Measure actual performance improvements
- Migrate CPU lecture repositories
- Document GPU support plans

## Testing Approach

**Test Repository:** `QuantEcon/test-lecture-python-intro`
- **Purpose:** Validate container workflow with real lecture content
- **Workflow:** Create container-based build workflow
- **Compare:** Build times, outputs, and deployment vs current ubuntu-latest approach
- **Validate:** 
  - Container pulls successfully from GHCR
  - LaTeX pre-installed (no 2-3 min install)
  - Anaconda base packages available
  - Lecture-specific packages install (1-2 min)
  - Build output matches production
  - Setup time reduced by 60-70%

**Testing Steps:**
1. Build container via GitHub Actions workflow
2. Create test workflow in test-lecture-python-intro
3. Compare build outputs (HTML artifacts)
4. Measure performance (setup time, build time, total time)
5. Validate deployment to Netlify

**Success Criteria:**
- Setup: 2-3 min (container) vs 7-8 min (ubuntu-latest)
- Output: Identical HTML artifacts
- No new errors or warnings

## Repository Structure

```
quantecon/actions/
├── containers/quantecon/          # Container infrastructure
│   ├── Dockerfile                 # Ubuntu 24.04 + LaTeX + Miniconda
│   ├── environment.yml            # Anaconda + Jupyter Book tools
│   └── README.md
├── .github/workflows/
│   └── build-containers.yml       # Weekly container builds
├── setup-environment/             # Flexible environment setup
│   ├── action.yml                 # Optional LaTeX, works anywhere
│   └── README.md
├── build-lectures/                # Jupyter Book builds
│   ├── action.yml
│   └── README.md
├── preview-netlify/                # Netlify PR previews
│   ├── action.yml
│   └── README.md
├── publish-gh-pages/              # GitHub Pages publishing
│   ├── action.yml
│   └── README.md
├── docs/
│   ├── CONTAINER-GUIDE.md         # Container usage
│   ├── ARCHITECTURE.md            # System design
│   ├── MIGRATION-GUIDE.md         # Migration steps
│   ├── FUTURE-DEVELOPMENT.md      # GPU roadmap
│   └── QUICK-REFERENCE.md
├── README.md
├── TESTING.md
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

## Core Components

### Container Infrastructure

**Image:** `ghcr.io/quantecon/quantecon:latest`

**Contents:**
- Ubuntu 24.04 LTS base
- TexLive (latest from Ubuntu repos)
- Miniconda + Python 3.13
- Anaconda 2025.12 (numpy, scipy, pandas, matplotlib, jupyter)
- Jupyter Book 1.0.4post1 + extensions

**Usage in workflows:**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: conda env update -f environment.yml
      - name: Build
        run: jupyter-book build lectures/
```

### Composite Actions

### 1. setup-environment

**Purpose:** Flexible environment setup for non-container workflows

**Key Features:**
- Optional `install-latex` (default: false)
- Conda caching (~5-6 min savings)
- Works in ubuntu-latest, containers, or custom AMI

**Usage:**
```yaml
- uses: quantecon/actions/setup-environment@main
  with:
    install-latex: 'true'
    environment-file: 'environment.yml'
```

**Note:** Not needed when using container (LaTeX + Anaconda already included).

### 2. build-lectures

**Purpose:** Builds lectures using Jupyter Book

**Usage:**
```yaml
- uses: quantecon/actions/build-lectures@main
  id: build
  with:
    builder: 'html'
```

### 3. preview-netlify

**Purpose:** Deploys to Netlify for PR previews

**Usage:**
```yaml
- uses: quantecon/actions/preview-netlify@main
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: lectures/_build/html/
```

### 4. publish-gh-pages

**Purpose:** Publishes to GitHub Pages

**Usage:**
```yaml
- uses: quantecon/actions/publish-gh-pages@main
  with:
    build-dir: lectures/_build/html/
    github-token: ${{ secrets.GITHUB_TOKEN }}
    cname: 'python.quantecon.org'
```

## Deployment Patterns by Repository

### lecture-python.myst
- **CI (PRs):** Netlify previews (optional - currently not used)
- **Publish (tags):** GitHub Pages to `python.quantecon.org`
- **Special:** GPU runners, JAX/PyTorch, PDF builds, notebook sync

### lecture-python-programming.myst
- **CI (PRs):** Netlify previews
- **Publish (tags):** GitHub Pages to `python-programming.quantecon.org`

### lecture-python-intro
- **CI (PRs):** Netlify previews
- **Publish (tags):** Netlify production (no GitHub Pages)

### lecture-python-advanced.myst
- **CI (PRs):** Netlify previews  
- **Publish (tags):** GitHub Pages to `python-advanced.quantecon.org`

## Performance Targets

### Setup Time Comparison

| Environment | Setup Time | Details |
|-------------|-----------|---------|
| ubuntu-latest | 7-8 min | Conda + LaTeX install fresh each time |
| Container | 2-3 min | Pull container + install lecture packages |
| Improvement | 60-70% | LaTeX pre-installed, base packages included |

### Breakdown

**ubuntu-latest:**
- Conda setup: 3-4 min
- LaTeX install: 2-3 min
- Package install: 1-2 min
- Total: 7-8 min

**Container:**
- Container pull: 20 sec (first), 10 sec (cached)
- Lecture packages: 1-2 min (conda env update)
- Total: 2-3 min

### Build Times

Build times unchanged (depends on content):
- **HTML build:** 8-10 minutes
- **PDF build:** 8-10 minutes (with LaTeX)
- **Total workflow:** 10-13 min (container) vs 15-18 min (ubuntu-latest)

## Key Decisions

### Why Containers?

LaTeX installation is unavoidable bottleneck:
- Takes 2-3 min with any package manager
- Cannot be meaningfully cached
- **Solution:** Pre-install in container, reuse across all builds

### Why Global Container?

Single container for all CPU lectures:
- All lectures share same scientific Python stack
- Simpler to maintain than per-lecture containers
- Disk space cheap (~2 GB acceptable)
- Updates centralized (one PR affects all)

### Why Anaconda Metapackage?

Anaconda 2025.12 includes most common packages:
- numpy, scipy, pandas, matplotlib, jupyter
- Eliminates explicit dependencies
- Faster conda solve times
- Lecture-specific packages (quantecon, cvxpy) installed separately

### GPU Support Deferred

Phase 1 focuses on CPU lecture builds:
- Simpler implementation and testing
- GPU options (RunsOn AMI, GitHub GPU runners) explored in future
- See docs/FUTURE-DEVELOPMENT.md for plans

## Next Steps

**CURRENT: Testing Phase**

1. **Build Container**
   - Trigger `.github/workflows/build-containers.yml`
   - Verify image at `ghcr.io/quantecon/quantecon:latest`
   - Test locally: `docker pull ghcr.io/quantecon/quantecon:latest`

2. **Test with test-lecture-python-intro**
   - Create container-based workflow
   - Compare build times and outputs with ubuntu-latest
   - Validate 60-70% setup time reduction
   - Ensure HTML output identical

3. **Migration** (after validation)
   - lecture-python-intro
   - lecture-python-programming.myst
   - lecture-python-advanced.myst
   - lecture-python.myst (CPU builds)

**See:** TESTING.md for detailed validation steps

## Common Tasks

### Test Container Locally

```bash
# Pull image
docker pull ghcr.io/quantecon/quantecon:latest

# Check environment
docker run --rm ghcr.io/quantecon/quantecon:latest python --version
docker run --rm ghcr.io/quantecon/quantecon:latest conda list
docker run --rm ghcr.io/quantecon/quantecon:latest pdflatex --version

# Build lectures locally
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  bash -c "conda env update -f environment.yml && jupyter-book build lectures/"
```

### Trigger Container Rebuild

```bash
gh workflow run build-containers.yml
```

### ⚠️ CRITICAL: GitHub CLI Output

**ALWAYS write `gh` command output to a file** - gh CLI is interactive and won't display in terminal:

```bash
# View workflow runs
gh run list --limit 10 > /tmp/gh-runs.txt && cat /tmp/gh-runs.txt

# View specific run logs
gh run view RUN_ID --log > /tmp/gh-logs.txt && cat /tmp/gh-logs.txt

# View failed logs only
gh run view RUN_ID --log-failed > /tmp/gh-failed.txt && cat /tmp/gh-failed.txt
```

**Never run `gh` commands without redirecting to a file first.**

## Known Limitations

1. **GPU support deferred** - Phase 1 CPU only, GPU plans in docs/FUTURE-DEVELOPMENT.md
2. **Container size** - ~2 GB (acceptable for CI, one-time download)
3. **Weekly builds** - Security updates via automated Monday 2am UTC builds

## Documentation Reference

- **docs/CONTAINER-GUIDE.md** - Container usage and local development
- **docs/ARCHITECTURE.md** - System design rationale
- **docs/MIGRATION-GUIDE.md** - Repository migration steps
- **docs/FUTURE-DEVELOPMENT.md** - GPU support and roadmap
- **TESTING.md** - Validation strategy with test-lecture-python-intro
- **CHANGELOG.md** - Version history

## Status

- **Created:** November 2025
- **Current Phase:** Container infrastructure complete, ready for testing
- **Container:** ghcr.io/quantecon/quantecon:latest (weekly builds)
- **Test Repo:** test-lecture-python-intro
- **Next:** Validate container workflow with real lecture builds
