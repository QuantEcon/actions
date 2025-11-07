# QuantEcon Actions - Development Guide

**Always reference these instructions first for context about this repository.**

## Repository Purpose

This repository contains **reusable GitHub Actions composite actions** for building and deploying QuantEcon lecture materials. These actions centralize common workflow patterns across 4 lecture repositories:

- `lecture-python.myst` (GPU, ML libraries, GitHub Pages)
- `lecture-python-programming.myst` (Standard, GitHub Pages) 
- `lecture-python-intro` (Standard, Netlify)
- `lecture-python-advanced.myst` (Standard, GitHub Pages)

## Current Status

**✅ COMPLETED (November 5, 2025):**
- All 5 composite actions created with complete `action.yml` files
- Individual README.md for each action (detailed documentation)
- Main repository documentation:
  - README.md (overview & quick start)
  - MIGRATION-GUIDE.md (step-by-step migration instructions)
  - TESTING.md (3-phase testing strategy)
  - QUICK-REFERENCE.md (cheat sheet)
  - CONTRIBUTING.md (development guidelines)
  - CHANGELOG.md (version history)
  - SETUP.md (GitHub repository initialization)
  - LICENSE (MIT)
  - .gitignore
- Git repository initialized
- GitHub repository created at `quantecon/actions`

**🧪 CURRENT PHASE: TESTING**
- **Status:** Testing phase - NO releases until testing is complete
- **Test Repository:** `QuantEcon/test-lecture-python-intro` (clone for testing)
- **Next:** Execute 3-phase testing strategy (see TESTING.md)
- Phase 1: Test in test-lecture-python-intro repository
- Phase 2: Convert workflows to use composite actions
- Phase 3: Validate full build and deployment cycle

**⏳ PENDING (Post-Testing):**
- Create v1.0.0 release (after successful testing)
- Migration of lecture repositories
- Performance validation

## Test Repository

**Test Repository:** `QuantEcon/test-lecture-python-intro`
- **URL:** https://github.com/QuantEcon/test-lecture-python-intro
- **Purpose:** Clone of lecture-python-intro for testing composite actions
- **Setup:**
  - `gh-pages` branch created for GitHub Pages deployment
  - CNAME removed (no custom domain - will use github.io)
  - Notebook syncing disabled (commented out in publish.yml)
  - Netlify secrets need configuration: `NETLIFY_AUTH_TOKEN`, `NETLIFY_SITE_ID`
- **Status:** Ready for workflow conversion and testing
- **Note:** Does NOT require `QUANTECON_SERVICES_PAT` for basic testing

## Repository Structure

```
quantecon/actions/
├── setup-lecture-env/      # Conda environment with ML libraries
│   ├── action.yml          # Caching: 3-5 min → 30 sec
│   └── README.md
├── setup-latex/            # LaTeX package installation
│   ├── action.yml          # Caching: 2-3 min → 10 sec
│   └── README.md
├── build-lectures/         # Jupyter Book builds
│   ├── action.yml          # Multi-builder: HTML/PDF/Jupyter
│   └── README.md
├── deploy-netlify/         # Netlify deployment
│   ├── action.yml          # Preview + Production, Auto PR comments
│   └── README.md
├── publish-gh-pages/       # GitHub Pages publishing
│   ├── action.yml          # Custom domain, orphan branch
│   └── README.md
├── README.md
├── MIGRATION-GUIDE.md
├── TESTING.md
├── QUICK-REFERENCE.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── SETUP.md
├── LICENSE
└── .gitignore
```

## Five Composite Actions

### 1. setup-lecture-env

**Purpose:** Sets up Conda environment with Python, Jupyter Book, and optional ML libraries

**Key Features:**
- Conda environment caching (saves 3-5 minutes)
- Optional JAX/PyTorch/CUDA support for lecture-python.myst
- pip package caching for ML libraries
- Configurable Python version

**Usage:**
```yaml
- uses: quantecon/actions/setup-lecture-env@v1
  with:
    install-ml-libs: 'true'  # Only for lecture-python.myst
```

### 2. setup-latex

**Purpose:** Installs LaTeX packages for PDF builds

**Key Features:**
- Workflow-based caching (saves 2-3 minutes)
- Cache invalidates only when workflow file changes
- Configurable package list

**Usage:**
```yaml
- uses: quantecon/actions/setup-latex@v1
```

### 3. build-lectures

**Purpose:** Builds lectures using Jupyter Book

**Key Features:**
- Multi-builder support (html, pdflatex, jupyter)
- Notebook execution caching for incremental builds
- Outputs build path for next steps

**Usage:**
```yaml
- uses: quantecon/actions/build-lectures@v1
  id: build
  with:
    builder: 'html'  # or 'pdflatex' or 'jupyter'
```

### 4. deploy-netlify

**Purpose:** Deploys to Netlify (used by lecture-python-intro for production, all repos for PR previews)

**Key Features:**
- Production and preview deployments
- Automatic PR comments with preview URLs
- Custom alias support (pr-123)

**Usage:**
```yaml
- uses: quantecon/actions/deploy-netlify@v1
  with:
    netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
    build-dir: ${{ steps.build.outputs.build-path }}
    production: 'false'  # true for production deploys
```

### 5. publish-gh-pages

**Purpose:** Publishes to GitHub Pages (used by lecture-python.myst, programming, advanced)

**Key Features:**
- Custom domain support via CNAME
- Orphan branch option (no history)
- Automatic URL generation

**Usage:**
```yaml
- uses: quantecon/actions/publish-gh-pages@v1
  with:
    build-dir: ${{ steps.build.outputs.build-path }}
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

## Performance Expectations

### Time Savings per Workflow

**First Run (no cache):**
- Conda setup: 3-5 minutes
- LaTeX install: 2-3 minutes
- Total: 5-8 minutes

**Subsequent Runs (with cache):**
- Conda restore: ~30 seconds
- LaTeX restore: ~10 seconds
- Total: ~40 seconds

**Net savings: 8-12 minutes per workflow run**

### Build Times

- **HTML build:** 45-60 minutes (first), 5-30 min (incremental with cache)
- **PDF build:** 30-45 minutes (requires LaTeX)
- **Jupyter build:** 30-45 minutes

## Caching Strategy

### Conda Cache
- **Key:** `conda-{OS}-{hash(environment.yml)}-{cache-version}`
- **Invalidates:** When environment.yml changes or manual version bump
- **Size:** ~1-2GB (includes pip packages for ML libs)

### LaTeX Cache
- **Key:** `latex-{OS}-{hash(workflow-file)}-{cache-version}`
- **Invalidates:** When workflow file changes (rare) or manual bump
- **Size:** ~500MB-1GB

### Jupyter Execution Cache
- **Key:** `jupyter-cache-{OS}-{hash(lectures/**/*.md)}-{sha}`
- **Invalidates:** When lecture content changes
- **Size:** Varies by content

## Important Design Decisions

### 1. Why Composite Actions (not Reusable Workflows)?
- **Better visibility:** Each step appears in workflow logs
- **More flexible:** Can be mixed with custom steps
- **Easier testing:** Can test individual actions in isolation

### 2. Why Workflow-Based LaTeX Caching?
- LaTeX packages are stable; don't need to reinstall on every content change
- Cache invalidates only when workflow requirements change
- Provides maximum cache hits across branches

### 3. Why Separate deploy-netlify and publish-gh-pages?
- Different repositories use different deployment targets
- Allows flexibility (some use Netlify, some use GitHub Pages)
- Clear separation of concerns

### 4. Why Optional ML Libraries?
- Only lecture-python.myst needs JAX/PyTorch (GPU computations)
- Other repos are lighter weight
- Separate cache key prevents cache conflicts

## Next Steps (Priority Order)

**TESTING PHASE (Current):**

1. **Phase 1 Testing** - Test in test-lecture-python-intro
   - Set up Netlify site and configure secrets
   - Enable GitHub Pages on repository
   - Test current workflows work as-is
   - Verify baseline functionality

2. **Phase 2 Testing** - Convert workflows to use composite actions
   - Update publish.yml to use new actions
   - Update ci.yml to use new actions
   - Test builds with composite actions
   - Verify caching works correctly
   - Validate outputs and error handling

3. **Phase 3 Testing** - Full validation
   - Run full build cycle (HTML, PDF, Jupyter)
   - Test GitHub Pages deployment
   - Test Netlify deployment (preview and production)
   - Monitor cache performance and build times
   - Validate against production lecture-python-intro

**POST-TESTING (After successful validation):**

4. **Create v1.0.0 Release** - Only after all testing passes
5. **Migration** - Follow MIGRATION-GUIDE.md for each repo
6. **Monitor** - Track cache hit rates and performance in production

**⚠️ IMPORTANT: Do NOT create git tags or GitHub releases until testing is complete**

## Common Commands

### Testing in a Fork
```yaml
- uses: YOUR-USERNAME/actions/setup-lecture-env@test-branch
```

### Force Cache Rebuild
```yaml
- uses: quantecon/actions/setup-lecture-env@v1
  with:
    cache-version: 'v2'  # Bump from v1
```

### Check Cache Status
Look for in workflow logs:
```
Conda cache hit: true
LaTeX cache hit: true
```

## Known Issues / Limitations

1. **GPU runners** - JAX runs in CPU mode in most environments (expected)
2. **Network warnings** - Intersphinx warnings for external sites are normal
3. **Cache size limits** - GitHub has 10GB total per repo
4. **Build times** - First builds are still 45-60 min (can't cache everything)

## Files Reference

- **README.md** - Start here for overview
- **TESTING.md** - Testing strategy before production use
- **MIGRATION-GUIDE.md** - How to convert existing workflows
- **QUICK-REFERENCE.md** - Cheat sheet for common tasks
- **CONTRIBUTING.md** - Development guidelines
- **SETUP.md** - How to initialize GitHub repository
- **CHANGELOG.md** - Version history

## Questions to Address in Future Development

1. Should we add a `setup-python-only` action for simpler repos?
2. Can we optimize Jupyter execution caching further?
3. Should we add a `build-all` meta-action that combines common patterns?
4. How to handle cache eviction when hitting 10GB limit?
5. Should we version-pin the peaceiris/actions-gh-pages action?

## Contact & Support

- **Issues:** https://github.com/quantecon/actions/issues
- **Repository:** https://github.com/quantecon/actions
- **Maintainers:** QuantEcon team
- **Created:** November 5, 2025
- **Status:** Testing phase (v1.0.0 pending successful testing)
