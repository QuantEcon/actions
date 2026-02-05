# Build Lectures Action

Builds QuantEcon lectures using Jupyter Book.

> **Note:** For caching, use the dedicated cache actions:
> - [`build-jupyter-cache`](../build-jupyter-cache) - Weekly cache generation on main branch
> - [`restore-jupyter-cache`](../restore-jupyter-cache) - Read-only restore for PR workflows

## Features

- 📚 **Multi-builder support** (HTML, PDF, Jupyter notebooks)
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
| `html-copy-pdf` | Copy PDFs to `_build/html/_pdf/` (HTML only) | No | `false` |
| `html-copy-notebooks` | Copy notebooks to `_build/html/_notebooks/` (HTML only) | No | `false` |
| `upload-failure-reports` | Upload execution reports on failure | No | `false` |

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

## Caching

For caching notebook execution and build outputs, use the dedicated cache actions:

- **[`build-jupyter-cache`](../build-jupyter-cache)** - Weekly cache generation on main branch
- **[`restore-jupyter-cache`](../restore-jupyter-cache)** - Read-only restore for PR workflows

See the [cache actions documentation](../build-jupyter-cache/README.md) for setup instructions.

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
3. Use `--keep-going` to see all errors
4. Enable `upload-failure-reports: true` for detailed reports

### Missing Artifacts

**Symptom:** `build-path` directory empty or missing

**Solutions:**
1. Check builder output in logs
2. Verify source directory exists
3. Check for build errors in previous step

### Slow Builds

**Symptom:** Builds taking too long

**Solutions:**
1. Use cache actions (`restore-jupyter-cache`) to restore previous builds
2. Consider splitting large notebooks
3. Check if notebooks are re-executing unnecessarily

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
