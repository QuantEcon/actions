# QuantEcon Containers

This directory contains Docker container definitions for building QuantEcon lectures.

## Available Containers

| Container | Image | Size | Use Case |
|-----------|-------|------|----------|
| **quantecon** | `ghcr.io/quantecon/quantecon:latest` | ~8GB | Full compatibility - includes Anaconda + TexLive |
| **quantecon-build** | `ghcr.io/quantecon/quantecon-build:latest` | ~3GB | Optimized for CI builds - lean package set |

## Container Comparison

### quantecon (Full)

**Best for:** Local development, maximum compatibility, running all lecture code

- Full Anaconda 2025.12 distribution
- Complete TexLive installation
- All Jupyter Book extensions
- ~450+ pre-installed packages

```yaml
container:
  image: ghcr.io/quantecon/quantecon:latest
```

### quantecon-build (Lean)

**Best for:** CI/CD pipelines, faster image pulls, lecture HTML/PDF builds

- Miniconda + explicit package list (only what's needed)
- Minimal TexLive (XeLaTeX + required packages)
- Jupyter Book build tools only
- ~100 packages, ~60% smaller

```yaml
container:
  image: ghcr.io/quantecon/quantecon-build:latest
```

## Choosing a Container

| Scenario | Recommended |
|----------|-------------|
| GitHub Actions CI builds | `quantecon-build` |
| Local development | `quantecon` |
| Running lecture notebooks interactively | `quantecon` |
| Building HTML/PDF only | `quantecon-build` |
| Testing new packages | `quantecon` |

## Package Coverage

The `quantecon-build` container includes packages used across all QuantEcon lecture series:
- [lecture-python-intro](https://github.com/QuantEcon/lecture-python-intro)
- [lecture-python.myst](https://github.com/QuantEcon/lecture-python.myst)
- [lecture-python-advanced.myst](https://github.com/QuantEcon/lecture-python-advanced.myst)
- [lecture-python-programming.myst](https://github.com/QuantEcon/lecture-python-programming.myst)

Lecture-specific packages not in the container are installed at build time via `environment.yml`.

## Building Locally

```bash
# Build full container
cd containers/quantecon
docker build -t ghcr.io/quantecon/quantecon:latest .

# Build lean container
cd containers/quantecon-build
docker build -t ghcr.io/quantecon/quantecon-build:latest .
```

## Container Detection

Both containers include a marker file at `/etc/quantecon-container` that allows the `setup-environment` action to detect container mode and skip redundant installations.

## GPU Support

GPU containers (for JAX/PyTorch CUDA) are not yet available. See [FUTURE-DEVELOPMENT.md](../docs/FUTURE-DEVELOPMENT.md) for roadmap.
