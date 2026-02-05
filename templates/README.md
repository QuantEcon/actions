# Workflow Templates

This directory contains GitHub Actions workflow templates for QuantEcon lecture repositories.

## Available Templates

### [cache.yml](cache.yml) (Recommended)

Build cache generation workflow using the **QuantEcon container**.

**Features:**
- Uses `ghcr.io/quantecon/quantecon:latest` container
- Fast setup (LaTeX pre-installed)
- Reliable (no network package installs)
- Weekly scheduled builds + manual trigger + env change trigger
- Automatic issue creation on failure
- Upload artifact for debugging

**Setup:**
1. Copy to your repository as `.github/workflows/cache.yml`
2. Ensure your CI workflow also uses the same container
3. Run manually once to generate initial cache

### [cache-standard.yml](cache-standard.yml)

Build cache generation workflow using **ubuntu-latest** (no container).

**Features:**
- Uses `setup-environment` action to install Conda/LaTeX
- No container dependency
- Slower setup (~7-8 min vs ~2-3 min for container)
- Same caching and failure handling as container version

**When to use:**
- Repositories that can't use containers
- Testing without container infrastructure

## Usage in PR Workflows

After setting up the cache workflow, use `restore-jupyter-cache` in your PR workflow:

```yaml
# .github/workflows/ci.yml
name: CI
on:
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest  # Match cache workflow!
    
    steps:
      - uses: actions/checkout@v4
      
      # Restore cache from main branch
      - uses: quantecon/actions/restore-jupyter-cache@v1
      
      # Incremental build (only re-runs changed notebooks)
      - uses: quantecon/actions/build-lectures@v1
        with:
          cache-notebook-execution: false  # Cache already restored
```

## Cache Strategy

```
┌────────────────────────────────────────────────────────┐
│ cache.yml (weekly on main)                             │
│                                                        │
│  build-jupyter-cache                                   │
│   ├── Build jupyter, pdflatex, html                   │
│   ├── If ALL pass → Save new cache                    │
│   └── If ANY fail → Keep old cache, create issue      │
│                                                        │
│  Cache Key: build-{env-hash}-{run-id}                 │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│ ci.yml (PRs)                                           │
│                                                        │
│  restore-jupyter-cache                                 │
│   └── Restores most recent build-{env-hash}-* cache   │
│                                                        │
│  build-lectures                                        │
│   └── Incremental build (only changed notebooks)      │
└────────────────────────────────────────────────────────┘
```

## Adding New Templates

When adding new templates:
1. Include comprehensive comments explaining usage
2. Document all inputs and customization points
3. Add entry to this README
4. Ensure container and standard versions match behavior
