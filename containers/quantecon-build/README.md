# QuantEcon Build Container (Lean)

Optimized Docker container for building QuantEcon lectures in CI/CD pipelines.

## Container Image

```
ghcr.io/quantecon/quantecon-build:latest
```

**Contents:**
- Ubuntu 24.04 LTS
- Miniconda with Python 3.13
- Explicit package list (not full Anaconda), science stack pinned to the Anaconda 2026.07 baseline
- TeX Live: the same apt packages as the full container, except `texlive-luatex`
- Jupyter Book build tools

**Size:** 2.93 GB compressed pull, 7.32 GB on disk (full container: 3.33 GB compressed, 8.60 GB on disk)

**Use for:** CI/CD builds, GitHub Actions (a modestly smaller pull than the full container)

## What's Included

### Python Packages (Superset for all QuantEcon lectures)

Pinned to the Anaconda 2026.07 baseline, matching the versions the lecture repos
build against and the full image (every package here that the `anaconda`
metapackage also pins):
- numpy, scipy, pandas, matplotlib, seaborn, plotly
- sympy, numba, networkx, statsmodels, scikit-learn
- jupyter, jupyterlab, notebook, ipykernel, ipywidgets

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
      - uses: actions/checkout@v7
      
      - name: Setup Environment
        uses: quantecon/actions/setup-environment@v0
        with:
          environment-update: 'environment-update.yml'  # Install lecture-specific delta packages
      
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
| Size (compressed pull) | 3.33 GB | 2.93 GB |
| Size (on disk) | 8.60 GB | 7.32 GB |
| Anaconda | Full 2026.07 | Explicit list (science stack pinned to 2026.07) |
| TeX Live | Ubuntu 24.04 apt set, incl. `texlive-luatex` | Same set, without `texlive-luatex` |
| Best for | Development | CI/CD |

## Building

```bash
docker build -t ghcr.io/quantecon/quantecon-build:latest .
```
