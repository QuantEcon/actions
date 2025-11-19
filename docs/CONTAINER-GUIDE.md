# Container Implementation Guide

Quick guide for using QuantEcon container infrastructure.

## What's Available

**Container Image:** `ghcr.io/quantecon/quantecon:latest`

**Includes:**
- Ubuntu 24.04 LTS
- TexLive (latest from Ubuntu repos)
- Miniconda + Python 3.13
- Anaconda 2025.06 (numpy, scipy, pandas, matplotlib, jupyter)
- Jupyter Book 1.0.4post1 + extensions

**Updates:** Weekly automated builds (Monday 2am UTC)

## Usage

### In GitHub Actions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      
      # Install lecture-specific packages
      - name: Install dependencies
        run: conda env update -f environment.yml
      
      - name: Build lectures
        run: jupyter-book build lectures/
```

### Local Development

```bash
# Build lectures
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  bash -c "conda env update -f environment.yml && jupyter-book build lectures/"

# Interactive shell
docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  bash
```

## Performance

| Metric | ubuntu-latest | Container | Improvement |
|--------|--------------|-----------|-------------|
| Setup time | 7-8 min | 2-3 min | 60-70% |
| LaTeX | 2-3 min | 0 min | Pre-installed |
| Base packages | 3-4 min | 0 min | Pre-installed |

## Lecture Environment

Your lecture's `environment.yml` should only include lecture-specific packages:

```yaml
name: quantecon
channels:
  - conda-forge
dependencies:
  - quantecon>=0.7.2
  - cvxpy>=1.3.0
  # Add other lecture-specific packages
```

**Don't include:**
- Python version (3.13 in container)
- numpy, scipy, pandas, matplotlib (in Anaconda base)
- jupyter, jupyterbook (pre-installed)

## Troubleshooting

**Package conflicts:**
```bash
# Check installed packages
docker run --rm ghcr.io/quantecon/quantecon:latest conda list

# Check Python version
docker run --rm ghcr.io/quantecon/quantecon:latest python --version
```

**Container not found:**
- Ensure image name is correct: `ghcr.io/quantecon/quantecon:latest`
- No authentication required for public images

**Slow pulls:**
- First pull downloads ~2 GB
- Subsequent pulls use GitHub Actions runner cache (~10-20 sec)

## Building Containers

Containers build automatically via `.github/workflows/build-containers.yml`:
- Push to `main` (when container files change)
- Weekly schedule (Monday 2am UTC)
- Manual: Workflow dispatch

**Manual trigger:**
```bash
gh workflow run build-containers.yml
```

## See Also

- [containers/quantecon/README.md](../containers/quantecon/README.md) - Detailed container docs
- [FUTURE-DEVELOPMENT.md](./FUTURE-DEVELOPMENT.md) - GPU support plans
- [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md) - Migrating lecture repos
