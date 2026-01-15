# Build Lectures Action

Builds QuantEcon lectures using Jupyter Book with intelligent notebook execution caching.

## Features

- 📚 **Multi-builder support** (HTML, PDF, Jupyter notebooks)
- 💾 **Execution caching** for faster incremental builds
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

## Outputs

| Output | Description |
|--------|-------------|
| `build-path` | Full path to build artifacts |

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
