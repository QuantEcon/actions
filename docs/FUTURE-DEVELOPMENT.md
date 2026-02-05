# Future Development

Planned enhancements for QuantEcon Actions.

## Feature Parity Checklist

Features needed to fully replace current `lecture-python.myst` workflows:

### High Priority

All high priority items completed! ✅

### Medium Priority

- [ ] **Download Notebooks Artifact**
  - Create zip of built notebooks for download
  - Add `create-notebooks-zip: 'true'` to `build-lectures`
  - Or add `notebooks-zip` option to `publish-gh-pages` release assets

### Low Priority (Repo-Specific)

- [ ] **Notebook Repository Sync**
  - Sync notebooks to separate `.notebooks` repo
  - Too repo-specific for generic action
  - Document as manual workflow steps

### Completed ✅

- [x] **Execution Reports on Failure** (`build-lectures`)
  - `upload-failure-reports: 'true'` uploads reports and cache on failure
  - Artifact name: `execution-reports-{builder}`
  - Includes `_build/*/reports/` and `_build/.jupyter_cache/`
- [x] **Asset Assembly** (`build-lectures`)
  - `html-copy-pdf: 'true'` copies PDFs to `_build/html/_pdf/`
  - `html-copy-notebooks: 'true'` copies notebooks to `_build/html/_notebooks/`
  - HTML builder only, requires prior pdflatex/jupyter builds
- [x] **Build Cache for Fast PR Builds** (`build-lectures`)
  - Uses GitHub native cache (faster than artifact-based)
  - Cache key: `build-${{ hashFiles('environment.yml') }}`
  - Auto-invalidates when environment changes
  - Documented `cache.yml` pattern for cache generation
  - Weekly scheduled + push trigger on env changes
- [x] Native GitHub Pages deployment (no gh-pages branch)
- [x] Release assets (tarball, checksum, manifest)
- [x] Auto-generated asset names from repo
- [x] Netlify PR preview deployment
- [x] Changed file detection for PR comments
- [x] Conda environment caching
- [x] LaTeX installation
- [x] JAX/PyTorch ML libs installation
- [x] Multi-builder support (html, pdflatex, jupyter)

---

## GPU Support

### Current Approach: RunsOn + Custom AMI

GPU lectures use [RunsOn](https://runs-on.com) with a custom AMI that has CUDA, LaTeX, Python, and GPU libraries pre-installed. The AMI includes the `/etc/quantecon-container` marker file, enabling `setup-environment` to detect it as a pre-built environment and use the fast container mode path.

**How it works:**
- AMI built with Packer, includes marker file + full scientific stack + GPU libs
- `setup-environment` detects marker → skips full install
- `environment-update` input applies delta packages (~30-60 seconds)
- `actions/cache` works normally on AMI (unlike Docker containers)

```yaml
runs-on: [runs-on, gpu=1, image=your-gpu-ami]
steps:
  - uses: quantecon/actions/setup-environment@v1
    with:
      environment-update: 'environment-update.yml'  # Delta packages only
```

See [setup-environment/README.md](../setup-environment/README.md#runson--custom-ami-gpu-builds) for AMI requirements and setup details.

### Other Options Under Consideration

**1. Custom AMI with RunsOn**
- Pre-configured GPU instances with CUDA, LaTeX, Python environment
- Built with Packer, stored in AWS
- Works with RunsOn GitHub Actions provider
- Best for: GPU-heavy lectures (JAX, PyTorch training)

**2. GitHub GPU Runners**
- Wait for official GPU runner support (currently beta)
- Simpler than custom AMI approach
- Timeline: Unknown

**3. GPU Container (nvidia/cuda base)**
- Similar to CPU container but with CUDA support
- Requires GPU-enabled runners
- Would need RunsOn or GitHub GPU runners

### Current GPU Workflow

GPU lectures use RunsOn with a custom AMI:

```yaml
runs-on: [runs-on, gpu=1, image=your-gpu-ami]
steps:
  - uses: quantecon/actions/setup-environment@v1
    with:
      environment-update: 'environment-update.yml'
```

**Benefits:**
- `setup-environment` detects AMI marker file and uses fast path
- Delta package installs via `environment-update` (~30-60 seconds)
- Full `actions/cache` support (unlike Docker containers)
- Pre-installed CUDA + GPU libraries eliminate setup overhead

## Build Action Enhancements

### Intelligent Caching
- Automatic `_build/` directory caching in `build-lectures` action
- Cache key based on lecture content hash
- Eliminate manual cache configuration

### Multi-format Builds
- Parallel HTML + PDF generation
- Conditional format selection based on branch
- Artifact management

## Performance Optimizations

### Container Layer Caching
- GitHub Actions runner caches container layers
- Near-instant pulls after first use
- Already implemented, measure actual performance

### Conda Package Caching
- Pre-download lecture-specific packages in container
- Or: Layer conda cache into container image
- Trade-off: Container size vs install time

## Documentation Improvements

### Video Tutorials
- Container workflow walkthrough
- Migration guide screencast
- Troubleshooting common issues

### Interactive Examples
- Live demo repositories
- Pre-configured test cases
- Performance benchmarks

## Monitoring & Analytics

### Build Metrics
- Track setup time, build time, total time
- Compare container vs ubuntu-latest
- Identify performance regressions

### Usage Statistics
- Which actions are most used
- Common configuration patterns
- Error rates by action

## Repository Templates

### Standard Lecture Template
- Pre-configured container workflow
- Common environment.yml patterns
- Best practices embedded

### Quick Start Scripts
- One-command migration tool
- Automated workflow generation
- Validation checks
