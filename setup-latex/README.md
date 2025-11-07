# Setup LaTeX Action

Installs LaTeX packages required for Jupyter Book PDF builds with intelligent caching based on package requirements.

## Features

- 📦 **LaTeX package installation** via apt-get
- 💾 **Requirements-based caching** (2-3 min → 10 sec)
- 🎯 **File-based package tracking** (like `environment.yml`)
- ⚡ **Automatic cache invalidation** when packages change
- 📊 **Cache hit reporting** with time savings
- 🌍 **Global cache sharing** across all workflows

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cache-version` | Cache version (bump to invalidate) | No | `v1` |
| `latex-requirements-file` | Path to latex-requirements.txt | No | `latex-requirements.txt` |
| `packages` | DEPRECATED: Use latex-requirements-file | No | None |

## Setup

Create a `latex-requirements.txt` file in your repository root:

```
# LaTeX Requirements
# texlive-2024 packages

texlive-latex-recommended
texlive-latex-extra
texlive-fonts-recommended
texlive-fonts-extra
texlive-xetex
texlive-luatex
latexmk
xindy
dvipng
ghostscript
cm-super
```

## Usage

### Basic Usage (Recommended)

```yaml
- uses: quantecon/actions/setup-latex@v1
```

This will read packages from `latex-requirements.txt` in your repository root.

### Custom Requirements File

```yaml
- uses: quantecon/actions/setup-latex@v1
  with:
    latex-requirements-file: 'config/latex-packages.txt'
```

### Force Cache Rebuild

```yaml
- uses: quantecon/actions/setup-latex@v1
  with:
    cache-version: 'v2'  # Bump from v1 to force rebuild
```

### Legacy Usage (Deprecated)

```yaml
- uses: quantecon/actions/setup-latex@v1
  with:
    packages: 'texlive-latex-base texlive-fonts-recommended'
```

**Note:** This approach is deprecated. Migrate to `latex-requirements.txt` for better cache management.

## Caching Strategy

### Why Requirements-Based Caching?

LaTeX packages are **stable** and shared across all workflows. The cache should be:
1. **Global** - Shared by cache.yml, ci.yml, publish.yml (all use same packages)
2. **File-tracked** - Invalidates when packages or versions change
3. **Manual override** - Can be reset via cache-version bump

Using `hashFiles(latex-requirements-file)` ensures:
- Cache persists across all workflows and branches
- Cache invalidates automatically when packages change
- Texlive year changes (e.g., 2024→2025) invalidate cache
- No unnecessary reinstalls when workflows change

### Cache Key Format

```
latex-{OS}-{hash(latex-requirements.txt)}-{cache-version}
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

- **Package changes** - Adding/removing packages in `latex-requirements.txt`
- **Version changes** - Updating texlive year (e.g., `texlive-2024` → `texlive-2025`)
- **OS upgrade** - Runner OS changes (rare)

### Manual Invalidation

```yaml
with:
  cache-version: 'v2'  # Bump this to force cache rebuild
```

## Troubleshooting

### Cache Not Restoring

Check logs for cache status:
```
LaTeX cache hit: true
✅ Restored from cache (saved ~2-3 minutes)
```

If always `false`:
1. Verify `latex-requirements.txt` file exists
2. Check Runner OS matches (Linux only)
3. Confirm file contains valid package names

### Missing LaTeX Commands

If `pdflatex` or `xelatex` not found:
1. Check package list includes required packages (e.g., `texlive-xetex`)
2. Verify cache restoration completed successfully
3. Check `/usr/share/texlive` exists and populated

### PDF Build Fails

If Jupyter Book PDF build fails with missing package:
1. Check error message for specific missing package
2. Add to `latex-requirements.txt`
3. Commit changes (cache will auto-invalidate)

### Cache Size Issues

LaTeX cache is ~500MB-1GB. If hitting GitHub's 10GB limit:
1. Review all cached items across workflows
2. Use same `latex-requirements.txt` across all repos (ensures cache sharing)
3. Regularly clean old caches via GitHub UI

## Examples

### Standard Jupyter Book Build

Create `latex-requirements.txt`:
```
texlive-latex-recommended
texlive-latex-extra
texlive-fonts-recommended
texlive-fonts-extra
texlive-xetex
latexmk
xindy
dvipng
ghostscript
```

Then in workflow:
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

Create `latex-requirements.txt`:
```
texlive-latex-base
texlive-latex-recommended
```

Workflow:
```yaml
- uses: quantecon/actions/setup-latex@v1
```

See [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md) for complete workflow examples.
