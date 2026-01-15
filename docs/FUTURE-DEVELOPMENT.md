# Future Development

Planned enhancements for QuantEcon Actions.

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
