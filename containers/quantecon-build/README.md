# QuantEcon Build Container (Lean)

Optimized Docker container for building QuantEcon lectures in CI/CD pipelines.

## Container Image

```
ghcr.io/quantecon/quantecon-build:latest
```

**Contents:**
- Ubuntu 24.04 LTS
- Miniconda with Python 3.13
- Explicit package list (not full Anaconda)
- Minimal TexLive (XeLaTeX + required packages)
- Jupyter Book build tools

**Size:** ~3GB (vs ~8GB for full container)

**Use for:** CI/CD builds, GitHub Actions, fast image pulls

## What's Included

### Python Packages (Superset for all QuantEcon lectures)

Core scientific stack:
- numpy, scipy, pandas, matplotlib, seaborn
- sympy, numba, networkx, statsmodels
- jupyter, jupyterlab, ipywidgets

Jupyter Book ecosystem:
- jupyter-book, quantecon-book-theme
- sphinx-tojupyter, sphinx-exercise, sphinx-proof
- sphinxcontrib-youtube, sphinx-togglebutton

### What's NOT Included

Lecture-specific packages that will be installed from `environment.yml`:
- quantecon (installed by lectures)
- wbgapi, yfinance (data APIs)
- jax, numpyro, pymc (ML/probabilistic - heavy)
- ortools (optimization)

## Usage

### GitHub Actions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon-build:latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Environment
        uses: quantecon/actions/setup-environment@main
        with:
          environment-file: 'environment.yml'  # Install lecture-specific packages
      
      - name: Build
        run: jupyter-book build lectures/
```

### Local Development

For local development with maximum compatibility, use the full `quantecon` container instead:
```bash
docker pull ghcr.io/quantecon/quantecon:latest
```

## Comparison with Full Container

| Feature | quantecon | quantecon-build |
|---------|-----------|-----------------|
| Size | ~8GB | ~3GB |
| Pull time | ~2-3 min | ~1 min |
| Packages | ~450 | ~100 |
| Anaconda | Full 2025.12 | Explicit list |
| TexLive | Full | Minimal |
| Best for | Development | CI/CD |

## Building

```bash
docker build -t ghcr.io/quantecon/quantecon-build:latest .
```
