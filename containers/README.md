# QuantEcon Containers

This directory contains Docker container definitions for building QuantEcon lectures.

## Available Containers

| Container | Image | Size | Use Case |
|-----------|-------|------|----------|
| **quantecon** | `ghcr.io/quantecon/quantecon:latest` | 3.33 GB compressed, 8.60 GB on disk | Full compatibility - includes Anaconda + TexLive |
| **quantecon-build** | `ghcr.io/quantecon/quantecon-build:latest` | 2.93 GB compressed, 7.32 GB on disk | CI builds - explicit package list instead of the Anaconda metapackage |

Compressed is what a cold pull downloads; on disk is the unpacked image (measured 2026-09-23 on `ubuntu-latest`). The two share their TeX Live packages (the lean image drops only `texlive-luatex`), so the lean image is only ~12% smaller to pull.

## Container Comparison

### quantecon (Full)

**Best for:** Local development, maximum compatibility, running all lecture code

- Full Anaconda 2026.06 distribution
- TeX Live from the Ubuntu 24.04 apt packages (`texlive-latex-extra`, `texlive-fonts-extra`, XeLaTeX, LuaTeX)
- All Jupyter Book extensions
- ~450+ pre-installed packages

```yaml
container:
  image: ghcr.io/quantecon/quantecon:latest
```

### quantecon-build (Lean)

**Best for:** CI/CD pipelines, lecture HTML/PDF builds (a modestly smaller pull than the full image)

- Miniconda + explicit package list instead of the `anaconda` metapackage, with the science stack pinned to the Anaconda 2026.06 baseline
- The same TeX Live apt packages as the full image, except `texlive-luatex` (it adds `graphviz`)
- Jupyter Book build tools

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

GPU builds use RunsOn with a custom Ubuntu AMI (not a container). The AMI includes NVIDIA drivers while ML libraries (JAX, PyTorch) bundle their own CUDA toolkit.

**See:** [GPU-AMI-SETUP.md](../docs/dev/GPU-AMI-SETUP.md) for AMI build instructions and driver requirements.
