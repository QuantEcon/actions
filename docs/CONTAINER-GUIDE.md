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

### GitHub-Hosted Runners

| Metric | ubuntu-latest | Container | Notes |
|--------|--------------|-----------|-------|
| Container init | N/A | ~2 min | Downloading image from GHCR |
| LaTeX install | 2-3 min | 0 min | Pre-installed in container |
| Base packages | 3-4 min | 0 min | Pre-installed in container |
| **Total setup** | **7-8 min** | **~2 min** | **60-70% faster** |

**Container initialization:** The 2-minute container load time is unavoidable on GitHub-hosted runners as the ~1.5-2GB image must be pulled from GHCR. However, this is still faster than installing LaTeX and Python packages separately.

**For faster startup times:** Consider self-hosted runners where the container can be pre-pulled and cached locally, reducing initialization to < 10 seconds.

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

## Self-Hosted Runners (Optional)

For high-frequency builds or faster startup times, consider self-hosted runners:

**Benefits:**
- Container pre-pulled and cached locally (~10s initialization vs 2min)
- Consistent performance across runs
- Custom hardware/resources

**Setup:**
```bash
# On your Ubuntu server
docker pull ghcr.io/quantecon/quantecon:latest

# Register as GitHub runner
./config.sh --url https://github.com/QuantEcon
./run.sh
```

**Workflow usage:**
```yaml
jobs:
  build:
    runs-on: self-hosted
    container:
      image: ghcr.io/quantecon/quantecon:latest
```

See [GitHub's self-hosted runner documentation](https://docs.github.com/en/actions/hosting-your-own-runners) for detailed setup.

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

**Slow initialization:**
- GitHub-hosted runners: ~2min pull time is normal for first run
- Subsequent runs on same runner may be cached (varies)
- For consistently fast startup: Use self-hosted runners (see above)

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
