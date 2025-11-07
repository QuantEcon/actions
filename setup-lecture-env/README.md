# Setup Lecture Environment Action

Sets up a complete Conda environment for building QuantEcon lectures, including Python, Jupyter Book, and optional ML libraries (JAX, PyTorch).

## Features

- 🐍 **Conda environment setup** with configurable Python version
- 📦 **Intelligent caching** for conda packages (3-5 min → 30 sec)
- 🚀 **Optional ML libraries** (JAX, PyTorch, NumPyro, Pyro) with CUDA support
- 💾 **pip package caching** for fast ML library restoration
- 📊 **Cache hit reporting** for monitoring

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `python-version` | Python version | No | `3.13` |
| `environment-file` | Path to environment.yml | No | `environment.yml` |
| `environment-name` | Conda environment name | No | `quantecon` |
| `cache-version` | Manual cache invalidation | No | `v1` |
| `install-ml-libs` | Install JAX/PyTorch with CUDA | No | `false` |
| `ml-libs-version` | ML libraries cache key version | No | `jax062-torch-nightly-cuda12` |

## Usage

### Basic Usage (Standard Lectures)

```yaml
- uses: quantecon/actions/setup-lecture-env@v1
  with:
    python-version: '3.13'
    environment-file: 'environment.yml'
```

### With ML Libraries (lecture-python.myst)

```yaml
- uses: quantecon/actions/setup-lecture-env@v1
  with:
    python-version: '3.13'
    environment-file: 'environment.yml'
    install-ml-libs: 'true'
    ml-libs-version: 'jax062-torch-nightly-cuda12'
```

### Force Cache Rebuild

```yaml
- uses: quantecon/actions/setup-lecture-env@v1
  with:
    cache-version: 'v2'  # Bump from v1 to force rebuild
```

## Caching Behavior

### Conda Cache

**Cache Key:** `conda-{OS}-{hash(environment.yml)}-{cache-version}`

**Cached Paths:**
- `/usr/share/miniconda/envs/{environment-name}`
- `~/.conda/pkgs`

**Invalidation:**
- Changes to `environment.yml`
- Manual version bump (`cache-version`)

### pip Cache (ML Libraries)

**Cache Key:** `pip-{OS}-{ml-libs-version}-{hash(environment.yml)}-{cache-version}`

**Cached Paths:**
- `~/.cache/pip`

**Invalidation:**
- Changes to `ml-libs-version`
- Changes to `environment.yml`
- Manual version bump (`cache-version`)

## Performance

| Scenario | Time (First Run) | Time (Cached) |
|----------|------------------|---------------|
| Conda setup | 3-5 minutes | ~30 seconds |
| pip + ML libs | 3-5 minutes | ~30-60 seconds |
| **Total** | **6-10 minutes** | **~1 minute** |

## Troubleshooting

### Cache Not Working

Check cache hit status in logs:
```
Conda cache hit: true
Pip cache hit: true
```

If always `false`, verify:
1. `environment.yml` path is correct
2. Runner OS matches (Linux vs macOS)
3. Cache key format

### ML Libraries Not Installing

If `install-ml-libs: 'true'` but libraries missing:
1. Check step execution in logs
2. Verify CUDA availability (GPU runners only)
3. Check pip cache restoration

### Package Version Conflicts

If packages conflict after caching:
1. Bump `cache-version` to force fresh install
2. Pin versions in `environment.yml`
3. Update `ml-libs-version` if changing JAX/PyTorch

## Examples

See [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md) for complete workflow examples.
