# Migration Guide: Converting Lecture Repos to Use QuantEcon Actions

This guide provides step-by-step instructions for migrating a QuantEcon lecture repository to use the centralized composite actions.

## Overview

**Goal:** Replace repetitive workflow setup code with reusable, cached composite actions.

**Benefits:**
- ⚡ 5-6 minute setup time reduction (via Conda caching)
- 🔧 Centralized maintenance (update once, benefit everywhere)
- 📊 Consistent build environments across all repos
- 🐛 Easier troubleshooting and updates
- 🎯 Unified environment setup (single action for Conda + LaTeX)

**Time Required:** ~1-2 hours per repository (including testing)

---

## Prerequisites

Before starting migration:

- [ ] Read [TESTING.md](./TESTING.md) for testing strategy
- [ ] Read [NEXT-STEPS.md](./NEXT-STEPS.md) for current status and future plans
- [ ] Ensure `quantecon/actions` repository is published
- [ ] Have a test branch ready in target repository
- [ ] Know which features your repo uses (ML libs, LaTeX, etc.)

---

## Quick Migration: Unified Action Approach

**Use this for new migrations (recommended as of 2025-11-07):**

### Before (Old Approach)
```yaml
- uses: quantecon/actions/setup-lecture-env@main
  with:
    python-version: '3.13'
    environment-file: 'environment.yml'
    
- uses: quantecon/actions/setup-latex@main
```

### After (Unified Action)
```yaml
- uses: quantecon/actions/setup-environment@main
  with:
    python-version: '3.13'
    environment-file: 'environment.yml'
    install-latex: 'true'
    latex-requirements-file: 'latex-requirements.txt'
    environment-name: 'quantecon'
```

**Benefits:** Simpler configuration, single cache, unified setup.

---

## Detailed Step-by-Step Migration

### Step 1: Identify Your Repository Type

Determine which features your repository needs:

| Repository | ML Libs (JAX/PyTorch) | LaTeX | Netlify | Notes |
|------------|----------------------|-------|---------|-------|
| lecture-python.myst | ✅ Yes | ✅ Yes | ✅ Yes | Most complex |
| lecture-python-programming.myst | ❌ No | ✅ Yes | ✅ Yes | Standard |
| lecture-python-intro | ❌ No | ✅ Yes | ✅ Yes | Standard |
| lecture-python-advanced.myst | ❌ No | ✅ Yes | ✅ Yes | Standard |

### Step 2: Create Test Branch

```bash
cd /path/to/your/lecture-repo
git checkout -b migrate/composite-actions
```

### Step 3: Backup Current Workflows

```bash
cp -r .github/workflows .github/workflows.backup
```

### Step 4: Update `ci.yml`

#### Before (example from lecture-python.myst):

```yaml
name: Build Project [using jupyter-book]
on: [pull_request]

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      - name: Setup Anaconda
        uses: conda-incubator/setup-miniconda@v3
        with:
          auto-update-conda: true
          auto-activate-base: true
          miniconda-version: 'latest'
          python-version: "3.13"
          environment-file: environment.yml
          activate-environment: quantecon
      
      - name: Install latex dependencies
        run: |
          sudo apt-get -qq update
          sudo apt-get install -y texlive-latex-recommended texlive-latex-extra ...
      
      # ... 40+ more lines of setup
      
      - name: Build HTML
        shell: bash -l {0}
        run: |
          jb build lectures --path-output ./ -n -W --keep-going
```

#### After:

```yaml
name: Build Project [using jupyter-book]
on: [pull_request]

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      # Setup environment with caching
      - uses: quantecon/actions/setup-lecture-env@v1
        with:
          python-version: '3.13'
          environment-file: 'environment.yml'
          install-ml-libs: 'false'  # Set to 'true' for lecture-python.myst
          cache-version: 'v1'
      
      # Setup LaTeX with caching
      - uses: quantecon/actions/setup-latex@v1
        with:
          cache-version: 'v1'
      
      # Download cached build
      - name: Download "build" folder (cache)
        uses: dawidd6/action-download-artifact@v11
        with:
          workflow: cache.yml
          branch: main
          name: build-cache
          path: _build
      
      # Build lectures
      - uses: quantecon/actions/build-lectures@v1
        with:
          source-dir: 'lectures'
          build-html: 'true'
          build-pdf: 'true'
          build-notebooks: 'true'
          cache-workflow: 'cache.yml'
          cache-branch: 'main'
      
      # Deploy preview
      - uses: quantecon/actions/deploy-netlify@v1
        if: github.event_name == 'pull_request'
        with:
          publish-dir: '_build/html/'
          production-branch: 'main'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
```

**Key Changes:**
- Replaced ~60 lines with ~10 lines
- Added caching automatically
- Unified error handling
- Clearer intent with named actions

### Step 5: Update `cache.yml`

#### Before:

```yaml
name: Build Cache [using jupyter-book]
on:
  schedule:
    - cron: '0 3 * * 1'
  workflow_dispatch:

jobs:
  cache:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      - name: Setup Anaconda
        uses: conda-incubator/setup-miniconda@v3
        with:
          auto-update-conda: true
          # ... many lines
      
      - name: Build HTML
        shell: bash -l {0}
        run: |
          jb build lectures --path-output ./ -W --keep-going
      
      - name: Upload "_build" folder (cache)
        uses: actions/upload-artifact@v5
        with:
          name: build-cache
          path: _build
```

#### After:

```yaml
name: Build Cache [using jupyter-book]
on:
  schedule:
    - cron: '0 3 * * 1'
  workflow_dispatch:

jobs:
  cache:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      - uses: quantecon/actions/setup-lecture-env@v1
        with:
          install-ml-libs: 'false'  # Adjust per repo
      
      - uses: quantecon/actions/setup-latex@v1
      
      - uses: quantecon/actions/build-lectures@v1
        with:
          build-html: 'true'
          cache-workflow: ''  # Don't download cache in cache workflow
      
      - name: Upload "_build" folder (cache)
        uses: actions/upload-artifact@v5
        with:
          name: build-cache
          path: _build
          include-hidden-files: true
```

### Step 6: Update `publish.yml`

#### Before:

```yaml
name: Build & Publish to GH Pages
on:
  push:
    tags:
      - 'publish*'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5
      
      - name: Setup Anaconda
        uses: conda-incubator/setup-miniconda@v3
        # ... many lines
      
      - name: Build HTML
        shell: bash -l {0}
        run: |
          jb build lectures --path-output ./ -n -W --keep-going
      
      - name: Deploy to gh-pages
        uses: peaceiris/actions-gh-pages@v4
        # ...
```

#### After:

```yaml
name: Build & Publish to GH Pages
on:
  push:
    tags:
      - 'publish*'

jobs:
  publish:
    if: github.event_name == 'push' && startsWith(github.event.ref, 'refs/tags')
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5
      
      - uses: quantecon/actions/setup-lecture-env@v1
        with:
          install-ml-libs: 'false'  # Adjust per repo
      
      - uses: quantecon/actions/setup-latex@v1
      
      - name: Download "build" folder (cache)
        uses: dawidd6/action-download-artifact@v11
        with:
          workflow: cache.yml
          branch: main
          name: build-cache
          path: _build
      
      - uses: quantecon/actions/build-lectures@v1
        with:
          build-html: 'true'
          build-pdf: 'true'
          build-notebooks: 'true'
      
      # Repository-specific: Notebook sync
      - name: Sync notebooks to separate repo
        shell: bash -l {0}
        env:
          QE_SERVICES_PAT: ${{ secrets.QUANTECON_SERVICES_PAT }}
        run: |
          # Your custom notebook sync logic here
          # (This varies by repository)
      
      - uses: quantecon/actions/publish-gh-pages@v1
        with:
          html-dir: '_build/html/'
          cname: 'python.quantecon.org'  # Adjust per repo
          create-release-assets: 'true'
          github-token: ${{ secrets.GITHUB_TOKEN }}
          tag-name: ${{ github.ref_name }}
```

### Step 7: Repository-Specific Adjustments

#### For `lecture-python.myst` (with GPU/ML libs):

```yaml
# In ci.yml, cache.yml, publish.yml:
- uses: quantecon/actions/setup-lecture-env@v1
  with:
    install-ml-libs: 'true'  # Enable ML libraries
    ml-libs-version: 'jax062-torch-nightly-cuda12'  # For cache key

# Also update runner if needed:
jobs:
  preview:
    runs-on: "runs-on=${{ github.run_id }}/family=g4dn.2xlarge/..."
```

#### For `collab.yml` (Google Colab container):

This workflow uses a different container and may need custom handling:

```yaml
# collab.yml may need to stay as-is or use partial actions
# The Google Colab container environment is different from standard Ubuntu

# Option 1: Keep as-is for now
# Option 2: Use only build-lectures action
- uses: quantecon/actions/build-lectures@v1
  with:
    build-html: 'true'
    cache-workflow: 'cache.yml'
```

### Step 8: Testing

Follow the testing guide in [TESTING.md](./TESTING.md):

1. **Create test workflow** (don't modify existing yet):
   ```bash
   cp .github/workflows/ci.yml .github/workflows/test-ci.yml
   ```

2. **Modify test-ci.yml** to use actions and manual trigger:
   ```yaml
   name: Test CI (New Actions)
   on: workflow_dispatch  # Manual trigger only
   ```

3. **Push test branch and run workflow**:
   ```bash
   git add .github/workflows/test-ci.yml
   git commit -m "Add test workflow with composite actions"
   git push origin migrate/composite-actions
   ```

4. **Manually trigger** the workflow from GitHub Actions UI

5. **Compare results**:
   - Build time (should improve on second run)
   - Build artifacts (should be identical)
   - Execution reports

### Step 9: Validation Checklist

Before merging, verify:

- [ ] Test workflow completes successfully
- [ ] Build time reduced on cached runs
- [ ] HTML output identical to production build
- [ ] PDF output identical (if applicable)
- [ ] Notebooks identical (if applicable)
- [ ] No new errors or warnings
- [ ] Cache created and restored properly
- [ ] All secrets still work (Netlify, GitHub tokens)

### Step 10: Merge and Monitor

1. **Update actual workflows** (not test ones):
   ```bash
   # Copy working test-ci.yml to ci.yml
   cp .github/workflows/test-ci.yml .github/workflows/ci.yml
   # Remove test workflow
   rm .github/workflows/test-ci.yml
   ```

2. **Create PR**:
   ```bash
   git add .github/workflows/
   git commit -m "Migrate to quantecon/actions composite actions

   - Adds caching for conda, pip, and LaTeX
   - Reduces setup time from 8-12 min to ~1 min (cached)
   - Centralizes workflow logic for easier maintenance
   - Tested with manual workflow runs"
   
   git push origin migrate/composite-actions
   ```

3. **Review and merge**

4. **Monitor first 5 workflow runs**:
   - Check execution times
   - Verify caching behavior
   - Watch for any errors

5. **Clean up after 1 week**:
   ```bash
   # Remove backup if everything is working
   rm -rf .github/workflows.backup
   ```

---

## Repository-Specific Notes

### lecture-python.myst

**Special requirements:**
- GPU runners: `runs-on: "runs-on=${{ github.run_id }}/family=g4dn.2xlarge/..."`
- ML libraries: Set `install-ml-libs: 'true'`
- CUDA support: Uses JAX 0.6.2 with CUDA 12

**Example ci.yml excerpt:**
```yaml
jobs:
  preview:
    runs-on: "runs-on=${{ github.run_id }}/family=g4dn.2xlarge/image=quantecon_ubuntu2404/disk=large"
    steps:
      - uses: actions/checkout@v5
      
      - uses: quantecon/actions/setup-lecture-env@v1
        with:
          install-ml-libs: 'true'
          ml-libs-version: 'jax062-torch-nightly-cuda12'
```

### lecture-python-programming.myst

**Standard setup** - no special requirements

**Example ci.yml excerpt:**
```yaml
jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      - uses: quantecon/actions/setup-lecture-env@v1
        with:
          install-ml-libs: 'false'
```

### lecture-python-intro

**Standard setup** - no special requirements  
Same as lecture-python-programming.myst

### lecture-python-advanced.myst

**Standard setup** - no special requirements  
Same as lecture-python-programming.myst

---

## Troubleshooting

### Issue: Cache not working

**Symptom:** Every run installs packages from scratch

**Check:**
1. Verify cache key format matches
2. Check runner OS (cache keys include OS)
3. Verify paths are correct

**Solution:**
```yaml
# Add debug step
- name: Debug cache info
  run: |
    echo "OS: ${{ runner.os }}"
    echo "Hash: ${{ hashFiles('environment.yml') }}"
```

### Issue: Build output differs

**Symptom:** HTML/PDF differs from production

**Check:**
1. Package versions (conda list, pip list)
2. Jupyter Book version
3. Build commands

**Solution:** Pin versions in environment.yml

### Issue: Secrets not working

**Symptom:** Netlify/GitHub Pages deployment fails

**Check:**
1. Secret names match (case-sensitive)
2. Secrets are set in repository settings
3. Permissions are correct

**Solution:** Verify in repository Settings → Secrets and variables → Actions

---

## Rollback Procedure

If issues occur after migration:

### Emergency Rollback

```bash
# Restore from backup
rm -rf .github/workflows
cp -r .github/workflows.backup .github/workflows
git add .github/workflows
git commit -m "Rollback to pre-migration workflows"
git push origin main
```

### Partial Rollback

```yaml
# In affected workflow file, comment out action and restore original:

# - uses: quantecon/actions/setup-lecture-env@v1

- name: Setup Anaconda
  uses: conda-incubator/setup-miniconda@v3
  with:
    # ... original configuration
```

---

## Getting Help

If you encounter issues during migration:

1. Check [TESTING.md](./TESTING.md) for debugging tips
2. Review action README files for configuration options
3. Open an issue in `quantecon/actions` with:
   - Repository name
   - Workflow file
   - Error logs
   - What you've tried

---

## Post-Migration

After successful migration:

1. **Document the change**:
   - Update repository README if needed
   - Note in changelog

2. **Share lessons learned**:
   - Update this guide with any issues found
   - Add troubleshooting tips

3. **Monitor metrics**:
   - Track build times (should improve significantly)
   - Watch for any degradation

4. **Update other repositories**:
   - Use this experience to migrate next repo
   - Refine process each time

---

## Migration Checklist Template

Copy this for each repository:

```markdown
## Migration: [Repository Name]

### Preparation
- [ ] Read TESTING.md
- [ ] Identify repo type (ML libs? LaTeX? etc.)
- [ ] Create test branch
- [ ] Backup workflows

### Migration
- [ ] Update ci.yml
- [ ] Update cache.yml
- [ ] Update publish.yml
- [ ] Update other workflows (linkcheck, collab, etc.)
- [ ] Adjust for repository-specific needs

### Testing
- [ ] Create test workflow
- [ ] Run test workflow successfully
- [ ] Compare build artifacts
- [ ] Verify caching works
- [ ] Run 3+ times to confirm stability

### Deployment
- [ ] Update actual workflows
- [ ] Create PR with detailed description
- [ ] Code review
- [ ] Merge to main
- [ ] Monitor first 5 runs

### Cleanup
- [ ] Remove test workflows
- [ ] Remove backups (after 1 week)
- [ ] Update documentation
- [ ] Share lessons learned

### Metrics
- Build time before: _____ min
- Build time after (first run): _____ min
- Build time after (cached): _____ min
- Issues encountered: _____
- Resolution time: _____
```
