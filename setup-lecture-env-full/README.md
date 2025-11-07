# Setup Complete Lecture Environment

This composite action sets up both the Conda environment and LaTeX packages required for QuantEcon lectures with optimized Conda caching.

## What it does

1. **Caches Conda environment** - Restores from cache based on `environment.yml` hash
2. **Installs Conda** - Sets up and activates environment (uses cache if available)
3. **Installs LaTeX** - Installs system packages via apt-get
4. **Optional ML libraries** - Installs JAX/PyTorch if requested

## Key Benefits

- **~5-6 minutes saved** with Conda cache hit
- **Simpler workflow** - One action instead of two separate actions
- **Unified environment setup** - Conda and LaTeX configured together
- **Independent caching** - Conda cache based on `environment.yml` only

## Why no LaTeX caching?

System packages installed in `/usr/share/texlive` and `/usr/share/texmf` cannot be cached due to permission restrictions in GitHub Actions. The apt package cache in `/var/cache/apt/archives` also requires root permissions and cannot be reliably cached.

LaTeX installation via `apt-get install` takes ~2-3 minutes but is unavoidable. The time is acceptable given that Conda caching saves 5-6 minutes.

## Usage

```yaml
- name: Setup Complete Environment
  uses: quantecon/actions/setup-lecture-env-full@main
  with:
    python-version: '3.13'
    environment-file: 'environment.yml'
    latex-requirements-file: 'latex-requirements.txt'
    environment-name: 'quantecon'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `python-version` | Python version to use | No | `3.13` |
| `environment-file` | Path to environment.yml | No | `environment.yml` |
| `latex-requirements-file` | Path to latex-requirements.txt | No | `latex-requirements.txt` |
| `environment-name` | Conda environment name | No | `quantecon` |
| `cache-version` | Cache version for manual invalidation | No | `v1` |
| `install-ml-libs` | Install JAX/PyTorch with CUDA | No | `false` |
| `ml-libs-version` | ML libraries version tag | No | `jax062-torch-nightly-cuda12` |

## Cache Strategy

### Conda Cache
- **Key**: `conda-{os}-{hash(environment.yml)}-{version}`
- **Path**: `/home/runner/miniconda3/envs/{name}`, `/home/runner/conda_pkgs_dir`
- **Invalidation**: Changes to `environment.yml` or manual `cache-version` bump

### LaTeX
- **No caching** - System packages installed fresh each run (~2-3 minutes)
- **Why**: Permission restrictions prevent caching apt archives or installed files

## Performance

| Scenario | Time | Details |
|----------|------|---------|
| First run (cache miss) | ~12 min | Full Conda install + LaTeX install |
| Conda cache hit | ~7-8 min | Restore Conda (~30s) + LaTeX install (~2-3 min) |

**Time savings**: ~5-6 minutes with Conda cache hit vs ~12 min fresh install

## Migration from separate actions

If you're currently using `setup-lecture-env` and `setup-latex` separately, you can replace both with this single action:

**Before:**
```yaml
- uses: quantecon/actions/setup-lecture-env@main
- uses: quantecon/actions/setup-latex@main
```

**After:**
```yaml
- uses: quantecon/actions/setup-lecture-env-full@main
```

This provides simpler workflow configuration and unified environment setup.
