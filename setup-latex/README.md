# Setup LaTeX Action

Installs LaTeX packages required for Jupyter Book PDF builds with intelligent caching based on workflow stability.

## Features

- 📦 **LaTeX package installation** via apt-get
- 💾 **Workflow-based caching** (2-3 min → 10 sec)
- 🎯 **Configurable package list** for different build requirements
- ⚡ **Automatic cache invalidation** when workflow changes
- 📊 **Cache hit reporting** with time savings

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cache-version` | Cache version (bump to invalidate) | No | `v1` |
| `workflow-file` | Workflow file path for cache key | No | `.github/workflows/ci.yml` |
| `packages` | Space-separated LaTeX packages | No | See below |

### Default Packages

```
texlive-latex-extra texlive-fonts-extra texlive-xetex latexmk xindy texlive-luatex dvipng ghostscript
```

## Usage

### Basic Usage

```yaml
- uses: quantecon/actions/setup-latex@v1
```

### Custom Packages

```yaml
- uses: quantecon/actions/setup-latex@v1
  with:
    packages: 'texlive-latex-base texlive-fonts-recommended texlive-latex-recommended'
```

### Custom Workflow File

```yaml
- uses: quantecon/actions/setup-latex@v1
  with:
    workflow-file: '.github/workflows/pdf.yml'
```

### Force Cache Rebuild

```yaml
- uses: quantecon/actions/setup-latex@v1
  with:
    cache-version: 'v2'  # Bump from v1 to force rebuild
```

## Caching Strategy

### Why Workflow-Based Caching?

LaTeX packages are **stable** across builds. The cache should only invalidate when:
1. The workflow requirements change (different packages needed)
2. Manual cache reset is required

Using `hashFiles(workflow-file)` ensures:
- Cache persists across branches with same workflow
- Cache invalidates only when workflow is modified
- No unnecessary reinstalls from lecture content changes

### Cache Key Format

```
latex-{OS}-{hash(workflow-file)}-{cache-version}
```

**Example:**
```
latex-Linux-a7f3b2c1d-v1
```

### Cached Paths

- `/usr/share/texlive` - Main LaTeX installation
- `/usr/share/texmf` - TeX formats and packages
- `/var/lib/texmf` - TeX configuration

## Performance

| Scenario | Time (First Run) | Time (Cached) |
|----------|------------------|---------------|
| apt-get update | ~30 seconds | ⏭️ Skipped |
| Package install | 2-3 minutes | ⏭️ Skipped |
| Cache restore | N/A | ~10 seconds |
| **Total** | **~3 minutes** | **~10 seconds** |

## Cache Invalidation Scenarios

### Automatic Invalidation

✅ **Workflow file changes**
```yaml
# .github/workflows/ci.yml modified
- uses: quantecon/actions/setup-latex@v1
# Cache key changes automatically via hashFiles()
```

### Manual Invalidation

✅ **Bump cache version**
```yaml
- uses: quantecon/actions/setup-latex@v1
  with:
    cache-version: 'v2'  # Was 'v1'
```

### Does NOT Invalidate

❌ **Lecture content changes** - Cache remains valid
❌ **Branch changes** - Cache shared across branches
❌ **environment.yml changes** - Only affects conda cache

## Troubleshooting

### Cache Not Restoring

Check logs for cache status:
```
LaTeX cache hit: true
✅ Restored from cache (saved ~2-3 minutes)
```

If always `false`:
1. Verify `workflow-file` path is correct
2. Check Runner OS matches (Linux only)
3. Confirm workflow file exists at specified path

### Missing LaTeX Commands

If `pdflatex` or `xelatex` not found:
1. Check package list includes required packages
2. Verify cache restoration completed successfully
3. Check `/usr/share/texlive` exists and populated

### PDF Build Fails

If Jupyter Book PDF build fails:
1. Check specific missing package in error message
2. Add to `packages` input
3. Bump `cache-version` to rebuild cache

### Cache Size Issues

LaTeX cache is ~500MB-1GB. If hitting GitHub's 10GB limit:
1. Review all cached items across workflows
2. Consider shorter cache retention
3. Use more specific cache keys to avoid duplicates

## Examples

### Standard Jupyter Book Build

```yaml
jobs:
  build-pdf:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-lecture-env@v1
      
      - uses: quantecon/actions/setup-latex@v1
      
      - uses: quantecon/actions/build-lectures@v1
        with:
          builder: 'pdflatex'
```

### Minimal LaTeX Install

```yaml
- uses: quantecon/actions/setup-latex@v1
  with:
    packages: 'texlive-latex-base texlive-latex-recommended'
```

See [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md) for complete workflow examples.
