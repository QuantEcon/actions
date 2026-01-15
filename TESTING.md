# Testing Strategy

## Current Status (2026-01-15)

**Container infrastructure complete.** Ready for production use.

---

## Local Test Fixtures

### `test-lecture-python-intro/` (git-ignored)

A local clone of `lecture-python-intro` used for testing workflows locally. This directory is excluded from version control via the `.gitignore` pattern `test-*/`.

**Purpose:**
- Test container builds locally
- Validate action changes before pushing
- Debug workflow issues

**Setup:**
```bash
# Clone test fixture (from actions repo root)
git clone https://github.com/QuantEcon/lecture-python-intro.git test-lecture-python-intro
```

**Usage with local scripts:**
```bash
# Test container builds
cd containers/quantecon/tests
./run-local-tests.sh
```

---

## Approach

**Test in isolation** using test fixtures before production rollout.

### Testing Principles

1. **Isolated testing** - Use test directories, not production repos
2. **Compare outputs** - Build artifacts must match current approach
3. **Measure performance** - Document actual vs expected timing
4. **Validate deployment** - Test Netlify and build artifacts
5. **Staged rollout** - One repository at a time after validation

---

## Testing Workflow

## Phase 1: Container Validation

### 1.1 Build Container

Trigger container build workflow:

```bash
# Manual trigger
gh workflow run build-containers.yml

# Or push to main (auto-triggers)
git push origin main
```

### 1.2 Verify Container Image

```bash
# Pull and inspect
docker pull ghcr.io/quantecon/quantecon:latest
docker run --rm ghcr.io/quantecon/quantecon:latest python --version
docker run --rm ghcr.io/quantecon/quantecon:latest conda list
docker run --rm ghcr.io/quantecon/quantecon:latest pdflatex --version
```

**Verify:**
- Python 3.13 installed
- Anaconda base packages available (numpy, scipy, pandas, matplotlib)
- Jupyter Book tools installed
- LaTeX commands work

## Phase 2: Test Repository Workflow

### 2.1 Update test-lecture-python-intro

Create container-based workflow:

```yaml
name: Build with Container
on:
  workflow_dispatch:
  push:
    branches: [test-container]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      
      # Install lecture-specific packages
      - name: Install dependencies
        run: conda env update -f environment.yml
      
      - name: Build lectures
        run: jupyter-book build lectures/
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: html
          path: lectures/_build/html/
```

### 2.2 Compare Builds

Run both container and ubuntu-latest workflows:

1. **Timing** - Measure setup time, build time, total time
2. **Artifacts** - Download and diff HTML outputs
3. **Errors** - Check for differences in warnings/errors
4. **Performance** - Verify 60-70% faster setup time

## Phase 3: Validation Checklist

Before production rollout:

- [ ] Container builds successfully via GitHub Actions
- [ ] Container image accessible from `ghcr.io/quantecon/quantecon:latest`
- [ ] Python 3.13 and Anaconda packages available in container
- [ ] LaTeX commands work in container
- [ ] Lecture-specific packages install successfully
- [ ] Build completes successfully
- [ ] HTML output matches current production
- [ ] Setup time reduced by 60-70% (target: 2-3 min vs 7-8 min)
- [ ] No new errors or warnings
- [ ] Deployment to Netlify works

---

## Validation Tests

### Test 1: Container Pull Performance

**Goal:** Verify container pulls quickly from GHCR

**Check workflow logs:**
- First pull: ~1-2 min (download ~2 GB)
- Subsequent pulls: ~10-20 sec (runner cache)

### Test 2: Environment Validation

**Goal:** Verify all required packages available

```bash
# In workflow, add diagnostic step:
- name: Validate environment
  run: |
    python --version
    conda list | grep -E "(numpy|scipy|pandas|matplotlib|jupyter)"
    jupyter-book --version
    pdflatex --version
```

### Test 3: Lecture Package Installation

**Goal:** Verify lecture-specific packages install correctly

**Check workflow logs:**
- `conda env update -f environment.yml` completes
- Packages like `quantecon`, `cvxpy` installed
- Installation time: ~1-2 min

### Test 4: Build Output Comparison

**Goal:** Verify builds produce identical output

**Steps:**
1. Build with container workflow
2. Build with current ubuntu-latest workflow
3. Download both HTML artifacts
4. Compare:
   ```bash
   diff -r container-html/ ubuntu-html/
   ```

**Expected:** No differences (or only timestamp differences)

### Test 5: Performance Measurement

**Goal:** Document actual performance improvements

**Measure:**
- Setup time (container pull + package install)
- Build time (jupyter-book build)
- Total workflow time

**Compare to baseline:**
- ubuntu-latest setup: 7-8 min
- Container setup target: 2-3 min
- Improvement: 60-70%

---

## Rollout Plan

### Stage 1: Test Repository

Pick a test repository or create a fork:

```bash
# Option 1: Use lecture-python-programming.myst (lower traffic)
# Option 2: Create a fork for testing
```

1. Merge test workflow into `main`
2. Monitor for 1 week
3. Collect metrics (build times, success rate)

Complete testing with test-lecture-python-intro, validate all metrics.

### Stage 2: CPU Lecture Repositories

After successful testing, migrate CPU-based lecture repositories:

1. **lecture-python-intro** (Netlify, similar to test repo)
2. **lecture-python-programming.myst** (GitHub Pages)
3. **lecture-python-advanced.myst** (GitHub Pages)
4. **lecture-python.myst** - CPU builds only (defer GPU workflows)

### Stage 3: Production Validation

For each repository:
1. Create migration PR with container workflow
2. Test in PR (manual trigger)
3. Compare outputs with current workflow
4. Merge after validation
5. Monitor first production build

**Rollback:** Revert workflow commit if issues occur.

---

## Success Metrics

Track before/after migration:

| Metric | Current (ubuntu-latest) | Target (Container) |
|--------|-------------------------|-------------------|
| Setup time | 7-8 min | 2-3 min |
| Build time | 8-10 min | 8-10 min (same) |
| Total time | 15-18 min | 10-13 min |
| LaTeX install | 2-3 min | 0 min (pre-installed) |
| Base packages | 3-4 min | 0 min (pre-installed) |

**Success criteria:**
- Build output matches current production (100%)
- Setup time reduced by 60-70%
- No new errors or warnings

---

## Troubleshooting

### Container not found

**Issue:** `Error: failed to pull image`

**Solution:** 
- Verify image name: `ghcr.io/quantecon/quantecon:latest`
- Check container build workflow ran successfully
- Ensure image is public (no auth required)

### Package conflicts

**Issue:** Conda solve fails or package conflicts

**Debug:**
    echo "Cache key: conda-${{ runner.os }}-${{ hashFiles('environment.yml') }}-v1"
    ls -la ~/.conda/pkgs || echo "No conda cache"
```

**Solution:** Check cache key format, verify paths

#### Issue: Build output differs

**Symptom:** HTML/PDF differs from production

**Debug:**
1. Download both artifacts
2. Compare with `diff -r`
3. Check for version differences in packages

**Solution:** Pin package versions in environment.yml

#### Issue: Workflow timeout

**Symptom:** Workflow exceeds time limit

**Debug:** Check if cache is working, verify runner specs

**Solution:** Increase timeout or investigate slow steps

```yaml
- name: Debug environment
  run: |
    conda list
    python -c "import quantecon; print(quantecon.__version__)"
```

**Check:**
- Verify lecture's `environment.yml` doesn't conflict with container base
- Try updating conda: `conda update -n base conda`

### Build differences

**Issue:** Container build differs from ubuntu-latest

**Debug:**
- Compare Python versions
- Check package versions: `conda list > versions.txt`
- Diff HTML outputs to identify specific differences
- Look for timestamp-only changes vs content changes

---

## See Also

- [docs/CONTAINER-GUIDE.md](./docs/CONTAINER-GUIDE.md) - Container usage
- [docs/MIGRATION-GUIDE.md](./docs/MIGRATION-GUIDE.md) - Migration steps
- [containers/quantecon/README.md](./containers/quantecon/README.md) - Container details
