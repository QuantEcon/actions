# Build Jupyter Cache Action

Performs a fresh build of all lecture formats and saves to GitHub cache. Designed to run on the main branch (typically weekly) to generate the cache that PR workflows restore.

## Design Philosophy

This action follows the **"build first, save only on success"** pattern:

1. Build all requested formats (jupyter, pdflatex, html)
2. Verify ALL builds succeeded
3. Only then save to cache
4. If any build fails: existing cache is preserved, issue is created

This ensures PRs always have a working cache to restore, even when the weekly build encounters errors.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `builders` | Comma-separated builders: jupyter, pdflatex, html | No | `html` |
| `environment` | Path to environment.yml (non-container builds) | No | `environment.yml` |
| `environment-update` | Path to delta environment.yml for container builds | No | `''` |
| `source-dir` | Source directory for lectures | No | `lectures` |
| `upload-artifact` | Upload _build as artifact | No | `true` |
| `artifact-retention-days` | Days to retain artifact | No | `30` |
| `create-issue-on-failure` | Create GitHub issue on failure | No | `true` |
| `issue-assignees` | Comma-separated usernames for issue | No | `''` |
| `issue-labels` | Comma-separated labels for issue | No | `build-failure,automated` |

## Outputs

| Output | Description |
|--------|-------------|
| `cache-saved` | Whether new cache was saved (true only if all builds passed) |
| `build-success` | Whether all builds succeeded |
| `cache-key` | The cache key used |
| `jupyter-status` | Status of jupyter build (success/failure/skipped) |
| `pdflatex-status` | Status of pdflatex build (success/failure/skipped) |
| `html-status` | Status of html build (success/failure/skipped) |

## Cache Key Strategy

**Save key:** `build-{hash(environment.yml)}-{hash(environment-update.yml)}-{run_id}`

Each successful build creates a new cache entry. Old caches expire automatically after 7 days of no access (GitHub's default).

**Restore key pattern** (used by `restore-jupyter-cache`):
```yaml
restore-keys: |
  build-{hash(environment.yml)}-{hash(environment-update.yml)}-
  build-{hash(environment.yml)}-
  build-
```

This prefix matching ensures PRs always get the most recently saved cache.

## Usage

### Basic Usage (in cache.yml workflow)

```yaml
name: Build Cache
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly Sunday midnight UTC
  workflow_dispatch:
  push:
    branches: [main]
    paths: ['environment.yml']

jobs:
  cache:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/build-jupyter-cache@v1
```

### All Builders with PDF

```yaml
- uses: quantecon/actions/build-jupyter-cache@v1
  with:
    builders: 'jupyter,pdflatex,html'
```

### Custom Issue Settings

```yaml
- uses: quantecon/actions/build-jupyter-cache@v1
  with:
    builders: 'jupyter,html'
    create-issue-on-failure: true
    issue-assignees: 'maintainer1,maintainer2'
    issue-labels: 'build-failure,urgent'
```

### Without Issue Creation

```yaml
- uses: quantecon/actions/build-jupyter-cache@v1
  with:
    create-issue-on-failure: false
```

## Build Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Setup Environment                                        │
│    └── Auto-detects container vs standard runner           │
├─────────────────────────────────────────────────────────────┤
│ 2. Build All Formats (continue-on-error)                   │
│    ├── jupyter  (if in builders)                           │
│    ├── pdflatex (if in builders)                           │
│    └── html     (if in builders, copies pdf/notebooks)     │
├─────────────────────────────────────────────────────────────┤
│ 3. Verify Results                                          │
│    └── Check all requested builders succeeded              │
├─────────────────────────────────────────────────────────────┤
│ 4a. ALL PASSED                                             │
│     ├── Save build cache                                   │
│     ├── Save execution cache                               │
│     └── Upload artifact                                    │
├─────────────────────────────────────────────────────────────┤
│ 4b. ANY FAILED                                             │
│     ├── DO NOT save cache (preserve existing)              │
│     ├── Upload artifact (for debugging)                    │
│     ├── Create/update GitHub issue                         │
│     └── Fail workflow                                      │
└─────────────────────────────────────────────────────────────┘
```

## Failure Handling

When a build fails:

1. **Cache preserved** - Old cache remains for PRs
2. **Issue created** - Automatic GitHub issue with:
   - Link to failed workflow run
   - Table showing which builders failed
   - Debug instructions
3. **Artifact uploaded** - Full _build directory for inspection
4. **Workflow fails** - Clear signal that action is needed

### Duplicate Issue Prevention

The action checks for existing open issues with the `build-failure` label:
- If found: Adds comment to existing issue
- If not found: Creates new issue

This prevents issue spam from repeated failures.

## Container vs Standard Runner

The action works in both environments via `setup-environment`:

### Container (Recommended)

```yaml
jobs:
  cache:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/build-jupyter-cache@v1
```

Benefits:
- Faster setup (LaTeX pre-installed)
- Consistent with PR builds
- Reliable (no network installs)

### Standard Runner

```yaml
jobs:
  cache:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/build-jupyter-cache@v1
        with:
          builders: 'jupyter,pdflatex,html'
```

The `setup-environment` step auto-detects the environment and installs LaTeX if needed.

## Build Summary

The action generates a GitHub Actions summary showing:

- Cache key used
- Builder results (✅/❌/⏭️)
- Build output sizes
- Container mode status

## Workflow Templates

See [templates/](../templates/) for complete workflow examples:
- `cache.yml` - Using QuantEcon container
- `cache-standard.yml` - Using ubuntu-latest

## Related Actions

- **[restore-jupyter-cache](../restore-jupyter-cache/)** - Restore cache in PR workflows
- **[build-lectures](../build-lectures/)** - Individual build step (used internally)
- **[setup-environment](../setup-environment/)** - Environment setup (used internally)
