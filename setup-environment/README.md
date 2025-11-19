# Setup Environment

Flexible environment setup action with optional Conda, LaTeX, and ML libraries for QuantEcon lectures.

## What it does

1. **Caches Conda environment** - Restores from cache based on `environment.yml` hash
2. **Installs Conda** - Sets up and activates environment (uses cache if available)
3. **Optional LaTeX** - Installs system packages via apt-get (when `install-latex: true`)
4. **Optional ML libraries** - Installs JAX/PyTorch with CUDA support (when `install-ml-libs: true`)

## Key Benefits

- **~5-6 minutes saved** with Conda cache hit
- **Flexible** - Choose which components to install
- **Container-friendly** - Skip LaTeX when using pre-built containers (default)
- **Environment-agnostic** - Works in containers, ubuntu-latest, or custom AMI

## Usage

### Standard Build (ubuntu-latest, full setup)
```yaml
- uses: quantecon/actions/setup-environment@main
  with:
    python-version: '3.13'
    environment-file: 'environment.yml'
    install-latex: 'true'
    latex-requirements-file: 'latex-requirements.txt'
    environment-name: 'quantecon'
```

### With Container (LaTeX already included)
```yaml
container:
  image: ghcr.io/quantecon/quantecon:latest
steps:
  # Container already has LaTeX + Anaconda base packages
  # Only install lecture-specific packages
  - name: Install lecture dependencies
    run: conda env update -f environment.yml
```

**Note:** When using `ghcr.io/quantecon/quantecon:latest` container, the `setup-environment` action is not needed. The container includes LaTeX, Miniconda, and Anaconda 2025.06 base packages. Only lecture-specific packages need installation.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `python-version` | Python version to use | No | `3.13` |
| `environment-file` | Path to environment.yml | No | `environment.yml` |
| `environment-name` | Conda environment name | No | `quantecon` |
| `cache-version` | Cache version for manual invalidation | No | `v1` |
| `install-latex` | Install LaTeX packages | No | `false` |
| `latex-requirements-file` | Path to latex-requirements.txt (only used if install-latex is true) | No | `latex-requirements.txt` |
| `install-ml-libs` | Install JAX/PyTorch with CUDA | No | `false` |
| `ml-libs-version` | ML libraries version tag | No | `jax062-torch-nightly-cuda12` |

## Cache Strategy

### Conda Cache
- **Key**: `conda-{os}-{hash(environment.yml)}-{version}`
- **Path**: `/home/runner/miniconda3/envs/{name}`, `/home/runner/conda_pkgs_dir`
- **Invalidation**: Changes to `environment.yml` or manual `cache-version` bump
- **Restore time**: ~30 seconds

### LaTeX (when enabled)
- **No caching** - System packages installed fresh each run (~2-3 minutes)
- **Why**: Permission restrictions prevent caching apt archives or installed files
- **Recommendation**: Use containers instead for ~2-3 min savings

## Performance Comparison

| Setup Method | Time | Best For |
|--------------|------|----------|
| Container (LaTeX pre-installed) | ~1 min | CPU lectures, standard builds |
| setup-environment (Conda only) | ~6-7 min | GPU builds with custom AMI |
| setup-environment (Conda + LaTeX) | ~8-9 min | Standard ubuntu-latest builds |
| First run (no cache) | ~12 min | Initial setup |

**Recommendation**: Use containers when possible for best performance.

## Migration from separate actions

If you're currently using `setup-lecture-env` and `setup-latex` separately, you can replace both with this single action:

**Before:**
```yaml
- uses: quantecon/actions/setup-lecture-env@main
- uses: quantecon/actions/setup-latex@main
```

**After:**
```yaml
- uses: quantecon/actions/setup-environment@main
  with:
    install-latex: 'true'  # Enable LaTeX installation
```

## When to use what

| Scenario | Recommended Setup |
|----------|------------------|
| **Standard CPU lectures** | Use container (`ghcr.io/quantecon/quantecon:latest`) |
| **GPU lectures (RunsOn + custom AMI)** | `setup-environment` with `install-ml-libs: true` |
| **Local development** | Use container or `setup-environment` with full options |
| **Legacy workflows** | `setup-environment` with `install-latex: true` |

**Future direction**: Containers are preferred for speed and consistency.
