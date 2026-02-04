# Setup Environment

Flexible, container-aware environment setup action for QuantEcon lectures. Auto-detects if running inside the QuantEcon container and optimizes accordingly.

## What it does

**Container Mode** (when running in `ghcr.io/quantecon/quantecon` or `ghcr.io/quantecon/quantecon-build`):
1. Detects container via `/etc/quantecon-container` marker
2. Caches lecture-specific packages
3. Runs `conda env update` to install only delta packages (~30 seconds)
4. Skips LaTeX (pre-installed in container)

**Standard Mode** (ubuntu-latest or other runners):
1. Caches Conda environment based on `environment.yml` hash
2. Installs full Conda environment
3. Optional LaTeX installation via apt-get
4. Optional ML libraries (JAX/PyTorch)

## Key Benefits

- **Auto-detection** - Automatically optimizes for container vs standard runner
- **~5-6 minutes saved** with container mode (LaTeX + base packages pre-installed)
- **~5-6 minutes saved** with Conda cache hit in standard mode
- **Backwards compatible** - Works with existing workflows unchanged
- **Flexible** - Choose which components to install

## Usage

### With Container (Recommended - Fastest)

Two container variants are available:

| Container | Image | Size | Best For |
|-----------|-------|------|----------|
| **Full** | `ghcr.io/quantecon/quantecon:latest` | ~8GB | Max compatibility |
| **Lean** | `ghcr.io/quantecon/quantecon-build:latest` | ~3GB | CI builds (faster pull) |

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon-build:latest  # or quantecon:latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-environment@v1
        with:
          environment-file: 'environment.yml'  # Optional - adds packages on top
        # Auto-detects container, installs only lecture-specific packages
      
      - uses: quantecon/actions/build-lectures@v1
```

### Container with No environment.yml (Fastest)

If the container has all packages you need:

```yaml
container:
  image: ghcr.io/quantecon/quantecon-build:latest
steps:
  - uses: quantecon/actions/setup-environment@v1
    with:
      environment-file: ''  # Skip package installation entirely
```

### Standard Build (ubuntu-latest)

```yaml
- uses: quantecon/actions/setup-environment@v1
  with:
    python-version: '3.13'
    environment-file: 'environment.yml'
    install-latex: 'true'
    latex-requirements-file: 'latex-requirements.txt'
    environment-name: 'quantecon'
```

### With ML Libraries (GPU builds)

```yaml
- uses: quantecon/actions/setup-environment@v1
  with:
    install-latex: 'true'
    install-ml-libs: 'true'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `python-version` | Python version (ignored in container mode) | No | `3.13` |
| `environment-file` | Path to environment.yml | No | `environment.yml` |
| `environment-name` | Conda environment name | No | `quantecon` |
| `cache-version` | Cache version for manual invalidation | No | `v1` |
| `install-latex` | Install LaTeX packages (auto-disabled in container) | No | `false` |
| `latex-requirements-file` | Path to latex-requirements.txt | No | `latex-requirements.txt` |
| `install-ml-libs` | Install JAX/PyTorch with CUDA | No | `false` |
| `ml-libs-version` | ML libraries version tag | No | `jax062-torch-nightly-cuda12` |

## Outputs

| Output | Description |
|--------|-------------|
| `container-mode` | `true` if running in QuantEcon container |
| `conda-cache-hit` | `true` if Conda cache was restored (standard mode only) |

## Performance Comparison

| Setup Method | Setup Time | Notes |
|--------------|------------|-------|
| **Container + setup-environment** | ~1-2 min | Recommended for all CPU builds |
| Container (manual conda update) | ~1-2 min | Direct container usage |
| setup-environment (cached) | ~3-4 min | Standard mode with cache hit |
| setup-environment (no cache) | ~8-10 min | First run or cache miss |

## Cache Strategy

### Container Mode
- **Key**: `container-pkgs-{hash(environment.yml)}-{version}`
- **Path**: `/opt/conda/envs/{name}/lib/python*/site-packages`
- **What's cached**: Lecture-specific packages only

### Standard Mode
- **Key**: `conda-{os}-{hash(environment.yml)}-{version}`
- **Path**: `/home/runner/miniconda3/envs/{name}`, `/home/runner/conda_pkgs_dir`
- **What's cached**: Full Conda environment

## Lean environment.yml for Containers

When using containers, your `environment.yml` should only list lecture-specific packages not included in the container's Anaconda base:

```yaml
# Lean environment.yml (for container builds)
name: quantecon
channels:
  - conda-forge
dependencies:
  - quantecon        # Lecture-specific
  - wbgapi           # World Bank API
  - pip:
    - quantecon-book-theme
```

The container already includes: numpy, scipy, pandas, matplotlib, jupyter, jupyter-book, and 300+ other Anaconda packages.

## When to use what

| Scenario | Recommended Setup |
|----------|------------------|
| **Standard CPU lectures** | Container + `setup-environment` |
| **GPU lectures** | `setup-environment` with `install-ml-libs: true` |
| **Local development** | Container or full `setup-environment` |
| **Legacy workflows** | `setup-environment` with `install-latex: true` |

## How Container Detection Works

The action checks for `/etc/quantecon-container` marker file, which is created during container build:

```
quantecon-container
image=ghcr.io/quantecon/quantecon
build_date=2026-02-04T00:00:00+00:00
```

If found → Container mode (fast path)
If not found → Standard mode (full installation)
