# QuantEcon Container

Docker container for building QuantEcon lectures with pre-installed LaTeX and Python environments.

## Container Image

```
ghcr.io/quantecon/quantecon:latest
```

**Contents:**
- Ubuntu 24.04 LTS
- TexLive (latest from Ubuntu 24.04 repos)
- Miniconda with Python 3.13
- Anaconda 2025.12 (numpy, scipy, pandas, matplotlib, jupyter, etc.)
- Jupyter Book build tools
- LaTeX build tools (latexmk, xindy, dvipng)

**Use for:** All CPU-based lecture builds (HTML, PDF generation)

**Note:** Lecture-specific packages are installed from each lecture's `environment.yml`

> **Note:** GPU lectures are not currently supported via containers. See the roadmap for future GPU support options.

## Usage in GitHub Actions

### Basic Usage

```yaml
name: Build Lectures
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Build lectures
        run: jupyter-book build lectures/
```

### Private Repository Access

For private repositories, you need to provide credentials:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    steps:
      - uses: actions/checkout@v4
      # ... rest of your steps
```

## Local Usage

### Pull the Image

```bash
docker pull ghcr.io/quantecon/quantecon:latest
```

### Run Interactively

```bash
docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  /bin/bash
```

### Build Lectures Locally

```bash
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  jupyter-book build lectures/
```

## Environment Details

### Python Environment

The container activates the `quantecon` conda environment by default:

```bash
# Environment is already activated
python --version  # Python 3.13
conda list        # See all packages
```

### Installed Packages

**Base Environment (Anaconda 2025.12):**
- NumPy, SciPy, Pandas - Scientific computing
- Matplotlib, Seaborn - Visualization
- NetworkX - Network analysis
- SymPy - Symbolic mathematics
- Jupyter, JupyterLab, IPyWidgets - Notebook tools

**Jupyter Book Build Tools:**
- jupyter-book (1.0.4post1) - Document builder
- quantecon-book-theme (0.18.0) - Custom theme
- Sphinx extensions (tojupyter, rediraffe, exercise, proof, youtube, togglebutton, reredirects)
- quantecon-book-networks

**Note:** Lecture-specific packages (quantecon, cvxpy, etc.) are installed from each lecture's environment.yml

See `environment.yml` for complete list.

### LaTeX Distribution

TexLive (latest from Ubuntu 24.04 LTS repositories):
- texlive-latex-recommended
- texlive-latex-extra
- texlive-fonts-recommended
- texlive-fonts-extra
- texlive-xetex
- texlive-luatex
- Build tools: latexmk, xindy, dvipng, ghostscript, cm-super

**Note:** Version automatically stays current with Ubuntu 24.04 security updates

## Development

### Building Images

From the repository root:

```bash
docker build -t ghcr.io/quantecon/quantecon:latest \
  -f containers/quantecon/Dockerfile \
  containers/quantecon/
```

### Testing Images

```bash
# Test Python environment
docker run --rm ghcr.io/quantecon/quantecon:latest \
  python -c "import jupyter_book; print(jupyter_book.__version__)"

# Test LaTeX
docker run --rm ghcr.io/quantecon/quantecon:latest \
  pdflatex --version

# Test build tools
docker run --rm ghcr.io/quantecon/quantecon:latest \
  jupyter-book --version
```

### Updating Dependencies

1. Edit `environment.yml` to add/update packages
2. Commit and push to `main` branch
3. GitHub Actions will automatically build and push new images
4. Images are tagged with both `:latest` and `:main-<sha>`

## Automated Builds

Images are automatically built via GitHub Actions:

- **Trigger:** Push to `main` branch or weekly schedule (Monday 2am UTC)
- **Workflow:** `.github/workflows/build-containers.yml`
- **Registry:** GitHub Container Registry (ghcr.io)
- **Visibility:** Public (free for public repositories)

### Build Status

Check the Actions tab in the repository for build status and logs.

## Performance

### Time Savings with Container

The container eliminates setup time by pre-installing Python/conda and LaTeX:

| Component | Traditional Setup | Container |
|-----------|-------------------|-----------|
| Miniconda install | 2-3 min | Pre-installed |
| Conda env create | 3-5 min | Pre-installed |
| LaTeX install | 2-3 min | Pre-installed |
| **Setup overhead** | **7-11 min** | **< 30 sec** |

### Build Performance with Caching

Combined with GitHub's cache for `_build/`, the container enables fast incremental builds:

| Build Type | Description | Typical Time |
|------------|-------------|--------------|
| Full build (no cache) | First run, all notebooks execute | 30-90 min* |
| PR build (with cache) | Cached `_build/` restored, only changed files re-execute | 5-15 min* |
| HTML only (with cache) | Just HTML generation from cached execution | 2-5 min |

*Varies significantly by lecture repository size and complexity

**Benefits:**
- ⚡ Setup overhead reduced from ~10 min to ~30 sec
- 🎯 Consistent environment across all builds
- 📦 LaTeX pre-installed (no apt-get during builds)
- 🔄 Simple workflow configuration
- 💾 Works seamlessly with GitHub cache for `_build/` directory

## Testing

The container includes a test suite to verify LaTeX and Jupyter Book functionality.

### Running Tests

To run all tests:

```bash
cd containers/quantecon
./tests/test-container.sh
```

The test script will:
1. Pull the latest container from GHCR
2. Test XeLaTeX compilation with fontspec and unicode
3. Test Jupyter Book HTML build
4. Test Jupyter Book PDF build via pdflatex

### Test Files

- `tests/test-xelatex.tex` - Minimal XeLaTeX document testing fonts and unicode
- `tests/minimal-jupyter-book/` - Minimal Jupyter Book project for build testing
- `tests/test-container.sh` - Automated test script for Docker container
- `tests/run-local-tests.sh` - Local test script for macOS development

### Local Testing (macOS)

For development on macOS without Docker:

```bash
cd containers/quantecon/tests
./run-local-tests.sh
```

**Prerequisites:**
- MacTeX (for xelatex)
- jupyter-book (`pip install jupyter-book`)
- DejaVu Serif fonts (`brew install --cask font-dejavu`)

The script runs the same tests as the container test suite locally.

### Manual Testing

Test XeLaTeX compilation:
```bash
cd containers/quantecon
docker run --rm -v $(pwd):/workspace -w /workspace/tests \
  ghcr.io/quantecon/quantecon:latest \
  xelatex test-xelatex.tex
```

Test Jupyter Book HTML build:
```bash
cd containers/quantecon
docker run --rm -v $(pwd):/workspace -w /workspace/tests \
  ghcr.io/quantecon/quantecon:latest \
  bash -c "cd minimal-jupyter-book && jb build . --builder html"
```

Test Jupyter Book PDF build:
```bash
cd containers/quantecon
docker run --rm -v $(pwd):/workspace -w /workspace/tests \
  ghcr.io/quantecon/quantecon:latest \
  bash -c "cd minimal-jupyter-book && jb build . --builder pdflatex"
```

### Expected Output

All tests should complete successfully with:
- `tests/test-xelatex.pdf` generated
- `tests/minimal-jupyter-book/_build/html/` directory with HTML output
- `tests/minimal-jupyter-book/_build/latex/test-book.pdf` generated

### GitHub Actions Testing

The container is automatically tested after each successful build via the `test-container.yml` workflow. Tests can also be triggered manually from the Actions tab.

## Troubleshooting

### Permission Issues

If you encounter permission errors:

```yaml
container:
  image: ghcr.io/quantecon/quantecon:latest
  options: --user root  # Add this line
```

### Authentication Failures

For private repositories, ensure `GITHUB_TOKEN` has package read permissions:

```yaml
permissions:
  packages: read
```

### Image Pull Failures

If the image fails to pull:
1. Check image exists: https://github.com/orgs/QuantEcon/packages
2. Verify image name is correct
3. Check container registry status

### Old Image Cached

To force pull the latest image:

```yaml
- name: Pull latest image
  run: docker pull ghcr.io/quantecon/quantecon:latest
```

## Support

For issues or questions:
- **Repository:** https://github.com/QuantEcon/actions
- **Documentation:** See `docs/` directory
- **Container Registry:** https://github.com/orgs/QuantEcon/packages

## License

MIT License - See LICENSE file in repository root.
