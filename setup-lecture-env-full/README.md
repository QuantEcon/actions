# Setup Complete Lecture Environment

This composite action sets up both the Conda environment and LaTeX packages required for QuantEcon lectures with optimized caching for maximum performance.

## What it does

1. **Caches Conda environment** - Restores from cache based on `environment.yml` hash
2. **Caches apt packages** - Caches downloaded `.deb` files for LaTeX to avoid re-downloading (~1GB)
3. **Installs Conda** - Only if cache miss
4. **Installs LaTeX** - Always installs but uses cached `.deb` files if available
5. **Optional ML libraries** - Installs JAX/PyTorch if requested

## Key Benefits

- **~5-6 minutes saved** with Conda cache hit
- **~1-2 minutes saved** with LaTeX apt cache hit (download time)
- **Combined ~6-8 minutes saved** vs fresh install (~12 min)
- **Separate caching** allows Conda changes without re-downloading LaTeX and vice versa

## Why not cache installed LaTeX?

System packages installed in `/usr/share/texlive` and `/usr/share/texmf` cannot be cached due to permission restrictions in GitHub Actions. Attempting to restore these paths results in "Operation not permitted" errors.

Instead, we cache the **downloaded `.deb` packages** in `/var/cache/apt/archives`, which significantly speeds up the `apt-get install` step by avoiding the ~1-2 minute download time.

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

### LaTeX apt Cache
- **Key**: `apt-latex-{os}-{hash(latex-requirements.txt)}-{version}`
- **Path**: `/var/cache/apt/archives`
- **Invalidation**: Changes to `latex-requirements.txt` or manual `cache-version` bump

## Performance

| Scenario | Time | Details |
|----------|------|---------|
| First run (all cache miss) | ~12 min | Full Conda + LaTeX install |
| Conda cache hit only | ~7 min | Restore Conda (~30s) + LaTeX download+install (~6 min) |
| Both caches hit | ~4-5 min | Restore Conda (~30s) + LaTeX install (~3 min, no download) |
| LaTeX apt cache hit only | ~10 min | Full Conda install + LaTeX install (no download) |

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

This provides better caching and simpler workflow configuration.
