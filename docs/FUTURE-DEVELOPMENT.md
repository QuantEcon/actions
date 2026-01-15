# Future Development

Planned enhancements for QuantEcon Actions.

## Feature Parity Checklist

Features needed to fully replace current `lecture-python.myst` workflows:

### High Priority

- [ ] **Execution Reports on Failure** (`build-lectures`)
  - Upload `_build/*/reports` as artifacts when build fails
  - Add `upload-reports-on-failure: 'true'` input
  - Separate report names per builder (html, latex, jupyter)

- [ ] **Asset Assembly** (`build-lectures` or new action)
  - Copy PDFs to `_build/html/_pdf/`
  - Copy notebooks to `_build/html/_notebooks/`
  - Add `copy-pdf-to-html: 'true'` and `copy-notebooks-to-html: 'true'` inputs

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

### Options Under Consideration

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

### Current GPU Workflow (Unchanged)

GPU lectures continue using existing approach:

```yaml
runs-on: [runs-on, gpu=1, image=your-ami]
steps:
  - uses: quantecon/actions/setup-environment@v1
    with:
      install-ml-libs: 'true'
```

**Benefit:** `setup-environment` action already works in any environment (validates architecture).

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
