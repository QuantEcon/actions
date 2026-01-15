# Build Lectures Action

Builds QuantEcon lectures using Jupyter Book with intelligent notebook execution caching.

## Features

- 📚 **Multi-builder support** (HTML, PDF, Jupyter notebooks)
- 💾 **Execution caching** for faster incremental builds
- 🚀 **Build cache restore** from GitHub cache for fast PR builds
- 📦 **Asset assembly** - copy PDFs and notebooks into HTML build
- 🔍 **Execution reports** - upload reports on build failure
- ⚙️ **Configurable build options** via extra arguments
- 📊 **Build summary reporting** with artifact paths
- 🎯 **Output path detection** based on builder type

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `builder` | Jupyter Book builder (html/pdflatex/jupyter) | No | `html` |
| `source-dir` | Directory containing lecture files | No | `lectures` |
| `output-dir` | Base output directory | No | `./` |
| `extra-args` | Extra jupyter-book build arguments | No | `-W --keep-going` |
| `cache-notebook-execution` | Enable execution caching | No | `true` |
| `use-build-cache` | Restore `_build` from GitHub cache | No | `false` |
| `html-copy-pdf` | Copy PDFs to `_build/html/_pdf/` (HTML only) | No | `false` |
| `html-copy-notebooks` | Copy notebooks to `_build/html/_notebooks/` (HTML only) | No | `false` |
| `upload-failure-reports` | Upload execution reports on failure | No | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `build-path` | Full path to build artifacts |
| `build-cache-hit` | Whether build cache was restored |

## Usage

### HTML Build (Default)

```yaml
- uses: quantecon/actions/build-lectures@v1
```

### PDF Build

```yaml
- uses: quantecon/actions/build-lectures@v1
  with:
    builder: 'pdflatex'
```

### Jupyter Notebook Build

```yaml
- uses: quantecon/actions/build-lectures@v1
  with:
    builder: 'jupyter'
```

### Custom Build Arguments

```yaml
- uses: quantecon/actions/build-lectures@v1
  with:
    builder: 'html'
    extra-args: '-W --keep-going -v'
```

### Disable Execution Caching

```yaml
- uses: quantecon/actions/build-lectures@v1
  with:
    cache-notebook-execution: 'false'
```

### Fast PR Builds (with Build Cache)

```yaml
- uses: quantecon/actions/build-lectures@v1
  with:
    use-build-cache: true
```

### Using Build Output

```yaml
- uses: quantecon/actions/build-lectures@v1
  id: build

- name: Upload artifacts
  uses: actions/upload-artifact@v4
  with:
    name: html-build
    path: ${{ steps.build.outputs.build-path }}
```

### Multi-Format Build with Asset Assembly

Build PDF and notebooks first, then HTML with asset assembly:

```yaml
# Build PDF
- uses: quantecon/actions/build-lectures@v1
  with:
    builder: 'pdflatex'

# Build notebooks  
- uses: quantecon/actions/build-lectures@v1
  with:
    builder: 'jupyter'

# Build HTML and assemble all assets
- uses: quantecon/actions/build-lectures@v1
  id: build
  with:
    builder: 'html'
    html-copy-pdf: true
    html-copy-notebooks: true
```

Result:
```
_build/html/
├── index.html
├── _pdf/
│   └── quantecon-lectures.pdf
└── _notebooks/
    ├── intro.ipynb
    └── ...
```

### Upload Reports on Build Failure

```yaml
- uses: quantecon/actions/build-lectures@v1
  with:
    upload-failure-reports: true
```

On failure, uploads:
- `_build/*/reports/` - Jupyter Book execution reports
- `_build/.jupyter_cache/` - Cache state for debugging

Artifact name: `execution-reports-{builder}`

## Execution Caching

### Cache Strategy

The action caches notebook execution results to avoid re-running unchanged notebooks:

**Cache Key:** `jupyter-cache-{OS}-{hash(lectures/**/*.md)}-{commit-sha}`

**Cached Path:** `_build/.jupyter_cache`

**Invalidation:**
- Any change to lecture content (`lectures/**/*.md`)
- Different commit (via `github.sha`)

**Restore Keys:** Attempts to restore from:
1. Same content hash (different commit)
2. Any previous cache (partial restore)

### Performance Impact

| Scenario | First Build | Incremental (Cache Hit) |
|----------|-------------|-------------------------|
| Small change | 45-60 min | 5-10 min |
| No changes | 45-60 min | 2-5 min |
| Major changes | 45-60 min | 20-30 min |

### When Cache Helps

✅ **Pull request updates** - Re-runs only changed notebooks
✅ **Minor fixes** - Skips execution of unchanged content
✅ **Branch switching** - Restores similar execution state

### When Cache Doesn't Help

❌ **Fresh branches** - No previous cache to restore
❌ **Complete rewrites** - All notebooks need re-execution
❌ **Environment changes** - May need clean execution

## Build Cache (Fast PR Builds)

The `use-build-cache` option enables fast incremental builds for PRs by restoring the entire `_build` directory from GitHub's cache.

### How It Works

**Cache Key:** `build-${{ hashFiles('environment.yml') }}`

This means:
- Cache auto-invalidates when `environment.yml` changes
- PRs without env changes get fast incremental builds
- PRs with env changes trigger full rebuilds (tests new dependencies)

### Setting Up Build Cache

To use build caching, your repository needs a **cache generation workflow** that creates the cache for PRs to restore.

#### Step 1: Create Cache Workflow

Create `.github/workflows/cache.yml`:

```yaml
name: Build Cache
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly Sunday midnight UTC
  workflow_dispatch:      # Manual trigger
  push:
    branches:
      - main
    paths:
      - 'environment.yml'  # Auto-rebuild when env changes

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Clear old cache to ensure fresh build
      - name: Clear existing cache
        run: gh cache delete "build-*" --repo ${{ github.repository }} || true
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      
      - uses: quantecon/actions/setup-environment@v1
      
      # Fresh build (no cache restore)
      - uses: quantecon/actions/build-lectures@v1
        id: build
      
      # Save to GitHub cache
      - uses: actions/cache/save@v4
        with:
          path: _build
          key: build-${{ hashFiles('environment.yml') }}
      
      # Upload artifact for inspection/reference
      - uses: actions/upload-artifact@v4
        with:
          name: build-cache-${{ hashFiles('environment.yml') }}
          path: _build
          retention-days: 90
```

#### Step 2: Use Cache in PR Workflow

In your CI workflow (e.g., `.github/workflows/ci.yml`):

```yaml
name: CI
on:
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-environment@v1
      
      - uses: quantecon/actions/build-lectures@v1
        with:
          use-build-cache: true  # Restore from main's cache
```

### Cache Generation Triggers

| Trigger | When | Purpose |
|---------|------|---------|
| `schedule` | Weekly (Sunday midnight) | Fresh build with latest dependencies |
| `workflow_dispatch` | Manual | On-demand rebuild |
| `push` (paths: environment.yml) | Env change merged to main | Update cache with new env |

### Cache Behavior

| Scenario | Cache Key Match | Result |
|----------|-----------------|--------|
| PR (no env change) | ✅ Exact match | Fast incremental build |
| PR (changes env) | ❌ Miss | Full rebuild (tests new deps) |
| After env merge | New key | Cache rebuilt automatically |

### Build Cache vs Execution Cache

| Feature | Build Cache | Execution Cache |
|---------|-------------|-----------------|
| What's cached | Entire `_build/` (~150 MB) | Just `.jupyter_cache` |
| Restore speed | Very fast (content-addressable) | Fast |
| Invalidation | `environment.yml` hash | Lecture content hash |
| PR support | ✅ Cross-branch restore | ⚠️ Same branch only |
| Use case | Fast PR previews | Same-branch rebuilds |

**Recommendation:** Use `use-build-cache: true` for PR workflows, which automatically disables execution caching to avoid conflicts.

### Inspecting the Cache

GitHub cache is not directly downloadable, but the cache workflow uploads an artifact for inspection:

**List caches:**
```bash
gh cache list --repo your-org/your-repo
```

**Delete caches:**
```bash
gh cache delete "build-*" --repo your-org/your-repo
```

**Download artifact:** Go to Actions → Cache workflow → Download artifact

## Builder Types

### HTML Builder

**Command:** `jb build lectures --path-output ./ -W --keep-going`

**Output:** `_build/html/`

**Use for:**
- Website deployment
- Netlify previews
- GitHub Pages

### PDF Builder

**Command:** `jb build lectures --builder pdflatex --path-output ./ -n -W --keep-going`

**Output:** `_build/latex/`

**Requirements:**
- LaTeX packages (use `setup-latex` action)
- ~30-45 minutes build time

**Use for:**
- PDF downloads
- Print versions

### Jupyter Builder

**Command:** `jb build lectures --path-output ./ --builder=custom --custom-builder=jupyter -n -W --keep-going`

**Output:** `_build/jupyter/`

**Use for:**
- Downloadable notebooks
- Direct execution
- Binder integration

## Build Arguments

### Default Arguments

`-W --keep-going`

- `-W`: Treat warnings as errors
- `--keep-going`: Continue on errors

### Common Extra Arguments

**Verbose output:**
```yaml
extra-args: '-W --keep-going -v'
```

**Nitpick mode:**
```yaml
extra-args: '-W --keep-going -n'
```

**Quiet mode:**
```yaml
extra-args: '-W --keep-going -q'
```

**Fresh build (ignore cache):**
```yaml
extra-args: '-W --keep-going --all'
```

## Troubleshooting

### Build Failures

**Symptom:** Build fails with notebook execution error

**Solutions:**
1. Check specific notebook in build logs
2. Run locally: `jb build lectures`
3. Disable caching: `cache-notebook-execution: 'false'`
4. Use `--keep-going` to see all errors

### Stale Cache

**Symptom:** Build uses old notebook outputs

**Solutions:**
1. Clear cache via GitHub Actions UI
2. Change cache key by modifying lecture content
3. Disable caching temporarily

### Missing Artifacts

**Symptom:** `build-path` directory empty or missing

**Solutions:**
1. Check builder output in logs
2. Verify source directory exists
3. Check for build errors in previous step

### Slow Builds

**Symptom:** Cached builds still take too long

**Solutions:**
1. Check cache hit rate in logs
2. Verify `jupyter-cache` directory populated
3. Review which notebooks are re-executing
4. Consider splitting large notebooks

## Examples

### Full CI Workflow

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-environment@v1
        with:
          install-latex: 'true'
      
      - uses: quantecon/actions/build-lectures@v1
        id: build
      
      - uses: actions/upload-artifact@v4
        with:
          name: html
          path: ${{ steps.build.outputs.build-path }}
```

### Multi-Format Build

```yaml
jobs:
  build-html:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/setup-environment@v1
      - uses: quantecon/actions/build-lectures@v1
        with:
          builder: 'html'

  build-pdf:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/setup-environment@v1
        with:
          install-latex: 'true'
      - uses: quantecon/actions/build-lectures@v1
        with:
          builder: 'pdflatex'
```

See [docs/MIGRATION-GUIDE.md](../docs/MIGRATION-GUIDE.md) for complete workflow examples.
