# Setup Environment

Flexible, container-aware environment setup action for QuantEcon lectures. Auto-detects if running inside the QuantEcon container and optimizes accordingly.

## What it does

**Container Mode** (when running in `ghcr.io/quantecon/quantecon` or `ghcr.io/quantecon/quantecon-build`):
1. Detects container via `/etc/quantecon-container` marker
2. If `environment-update` specified: runs `conda env update` with delta packages (~30-60 seconds)
3. If `environment-update` omitted (default): uses pre-installed packages only (fastest)
4. Skips LaTeX (pre-installed in container)

**Standard Mode** (ubuntu-latest or other runners):
1. Caches Conda environment based on `environment.yml` hash
2. Installs full Conda environment
3. Optional LaTeX installation via apt-get

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
        # environment-update defaults to '' - uses pre-installed packages
      
      - uses: quantecon/actions/build-lectures@v1
```

### Container with No Extra Packages (Fastest)

If the container has all packages you need:

```yaml
container:
  image: ghcr.io/quantecon/quantecon-build:latest
steps:
  - uses: quantecon/actions/setup-environment@v1
    # environment-update defaults to '' - uses pre-installed packages
```

### Container with Delta Packages

If you need a few extra packages not in the container:

```yaml
steps:
  - uses: quantecon/actions/setup-environment@v1
    with:
      environment-update: 'environment-update.yml'  # Delta packages only
```

Where `environment-update.yml` contains only the extras:

```yaml
name: quantecon
dependencies:
  - wbgapi  # Example: package not in container
```

### Standard Build (ubuntu-latest)

```yaml
- uses: quantecon/actions/setup-environment@v1
  with:
    python-version: '3.13'
    environment: 'environment.yml'
    install-latex: 'true'
    latex-requirements-file: 'latex-requirements.txt'
    environment-name: 'quantecon'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `python-version` | Python version (ignored in container mode) | No | `3.13` |
| `environment` | Path to environment.yml (non-container builds) | No | `environment.yml` |
| `environment-update` | Path to delta environment.yml for container builds | No | `''` |
| `environment-name` | Conda environment name | No | `quantecon` |
| `cache-version` | Cache version for manual invalidation | No | `v1` |
| `install-latex` | Install LaTeX packages (auto-disabled in container) | No | `false` |
| `latex-requirements-file` | Path to latex-requirements.txt | No | `latex-requirements.txt` |

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
- **No caching** - `actions/cache` runs on the host runner, not inside the container
- If `environment-update` specified: packages installed via `conda env update` (~30-60 seconds)
- If `environment-update` omitted: uses pre-installed packages (fastest path)
- See [issue #18](https://github.com/QuantEcon/actions/issues/18) for future caching improvements

### Standard Mode
- **Key**: `conda-{os}-{hash(environment.yml)}-{version}`
- **Path**: `/home/runner/miniconda3/envs/{name}`, `/home/runner/conda_pkgs_dir`
- **What's cached**: Full Conda environment

## Delta environment-update.yml for Containers

When using containers, create an `environment-update.yml` with only the lecture-specific packages not included in the container's base image:

```yaml
# environment-update.yml (delta packages for container builds)
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

**Note:** The full `environment.yml` is still used for non-container builds and for cache key computation.

## When to use what

| Scenario | Recommended Setup |
|----------|------------------|
| **Standard CPU lectures** | Container + `setup-environment` |
| **GPU lectures (RunsOn AMI)** | AMI with marker file + `environment-update` |
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

This detection also works with **custom AMIs** (e.g., RunsOn GPU instances). See below.

## RunsOn + Custom AMI (GPU Builds)

For GPU lectures running on EC2 via [RunsOn](https://runs-on.com) with a custom AMI, you can use the same container mode by adding the marker file to your AMI. This lets you use `environment-update` for delta package installs, avoiding full environment rebuilds on every run.

### AMI Requirements

When building your AMI (e.g., with Packer), ensure it includes:

1. **Marker file** — triggers container mode detection:
   ```bash
   echo "quantecon-container" > /etc/quantecon-container
   echo "image=ami-your-ami-id" >> /etc/quantecon-container
   echo "variant=gpu" >> /etc/quantecon-container
   echo "build_date=$(date -Iseconds)" >> /etc/quantecon-container
   ```

2. **Conda on PATH** — container mode calls `conda env update` directly (no `setup-miniconda`):
   ```bash
   # Miniconda or Anaconda installed, e.g.:
   /opt/conda/bin/conda  # or wherever your install lives
   ```

3. **Pre-installed base environment** — the scientific stack + GPU libraries:
   - Python 3.13, numpy, scipy, pandas, matplotlib, jupyter
   - Jupyter Book + extensions
   - CUDA toolkit, JAX, PyTorch (GPU-specific)
   - LaTeX (texlive)

### Workflow Example

```yaml
jobs:
  build:
    runs-on: [runs-on, gpu=1, image=your-gpu-ami]
    steps:
      - uses: actions/checkout@v4

      - uses: quantecon/actions/setup-environment@v1
        with:
          environment-update: 'environment-update.yml'  # Delta packages only
        # Detects /etc/quantecon-container → skips full install

      - uses: quantecon/actions/build-lectures@v1
```

### What Container Mode Skips on AMI

| Step | Container/AMI Mode | Standard Mode |
|------|-------------------|---------------|
| Miniconda install | Skipped (pre-installed) | Installed |
| Full conda env create | Skipped (pre-installed) | From `environment` |
| LaTeX install | Skipped (pre-installed) | If `install-latex: true` |
| Delta package update | If `environment-update` set | N/A |

### Advantage Over Containers

Unlike Docker containers, AMIs run on the host directly, so `actions/cache` works normally. This means cached conda environments, pip packages, and build caches all persist between runs — potentially even faster than container mode for repeated builds.
