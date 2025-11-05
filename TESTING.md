# Testing Strategy for QuantEcon Actions

## Overview

Since QuantEcon lecture repositories manage **live production websites**, we need a careful testing strategy to validate changes to these composite actions without disrupting the live sites.

## Testing Principles

1. **Never test on production** - Always use feature branches
2. **Validate output** - Compare build artifacts with existing workflows
3. **Parallel testing** - Run new and old workflows side-by-side initially
4. **Staged rollout** - One repository at a time
5. **Quick rollback** - Keep old workflows until confident

---

## Testing Workflow

### Phase 1: Local Development & Action Testing

#### 1.1 Create Test Branch in Actions Repo

```bash
cd /Users/mmcky/work/quantecon/actions
git checkout -b feature/test-new-caching
# Make changes to composite actions
git add .
git commit -m "Add caching to setup-lecture-env"
git push origin feature/test-new-caching
```

#### 1.2 Reference Development Branch in Test Workflow

Create a test workflow in a lecture repository that references your development branch:

```yaml
# In lecture-python.myst: .github/workflows/test-new-actions.yml
name: Test New Actions (DO NOT MERGE)
on: 
  workflow_dispatch:  # Manual trigger only

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      # Reference the development branch
      - uses: quantecon/actions/setup-lecture-env@feature/test-new-caching
        with:
          install-ml-libs: 'true'
      
      - uses: quantecon/actions/build-lectures@feature/test-new-caching
        with:
          build-html: 'true'
```

### Phase 2: Controlled Testing in Lecture Repository

#### 2.1 Create Test Branch in Lecture Repo

```bash
cd /Users/mmcky/work/quantecon/lecture-python.myst
git checkout -b test/new-composite-actions
```

#### 2.2 Create Parallel Test Workflow

Don't modify existing workflows yet. Create a new test workflow:

```bash
# Copy existing ci.yml to test-ci.yml
cp .github/workflows/ci.yml .github/workflows/test-ci.yml
```

Modify `test-ci.yml`:
- Change name to `Test CI (New Actions)`
- Reference actions via `@main` or `@feature-branch`
- Add workflow dispatch trigger for manual testing
- **Do NOT trigger on pull_request** (prevent auto-runs)

```yaml
name: Test CI (New Actions)
on:
  workflow_dispatch:  # Manual trigger only
  
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      - uses: quantecon/actions/setup-lecture-env@main
        with:
          install-ml-libs: 'false'
      
      # ... rest of workflow
```

#### 2.3 Run Comparison Tests

Run both workflows and compare:

1. **Execution time** - Check if caching works
2. **Build artifacts** - Compare HTML output
3. **Error reports** - Check for new issues
4. **Cache behavior** - Verify cache hits/misses

### Phase 3: Validation Checklist

Before merging, verify:

- [ ] Workflow completes successfully
- [ ] Build time reduced (first run may be slower, second should be faster)
- [ ] HTML output is identical to production
- [ ] PDF output is identical to production  
- [ ] Notebooks are identical to production
- [ ] No new errors or warnings
- [ ] Cache is created and restored correctly
- [ ] Execution reports match expected format

---

## Testing Scenarios

### Scenario 1: Test Conda Caching

**Goal:** Verify conda environment is cached and restored

**Steps:**
1. Run workflow twice
2. First run: Should install conda packages (3-5 min)
3. Second run: Should restore from cache (~30 sec)

**Validation:**
```bash
# Check workflow logs for:
# First run: "Cache not found for input keys: conda-Linux-abc123-v1"
# Second run: "Cache restored from key: conda-Linux-abc123-v1"
```

### Scenario 2: Test LaTeX Caching

**Goal:** Verify LaTeX packages are cached

**Steps:**
1. Run workflow with PDF build
2. Check logs for apt-get installation
3. Run again, verify cache restore

**Validation:**
- First run: `apt-get install` runs (~2-3 min)
- Second run: Skips installation, restores cache (~10 sec)

### Scenario 3: Test ML Libraries (lecture-python.myst only)

**Goal:** Verify JAX/PyTorch installation with caching

**Steps:**
1. Run with `install-ml-libs: 'true'`
2. Verify pip cache is created
3. Run again, verify restore

**Expected:**
- First run: Downloads ~2GB of packages (3-5 min)
- Second run: Restores from cache (~1 min)

### Scenario 4: Test Cache Invalidation

**Goal:** Verify cache updates when dependencies change

**Steps:**
1. Run workflow, establish cache
2. Modify `environment.yml` (add a package)
3. Run again, verify new cache is created

**Expected:**
- Cache key changes (hash of environment.yml changes)
- New packages installed
- New cache saved

---

## Rollout Strategy

### Stage 1: Single Repository (Non-Production)

Pick a test repository or create a fork:

```bash
# Option 1: Use lecture-python-programming.myst (lower traffic)
# Option 2: Create a fork for testing
```

1. Merge test workflow into `main`
2. Monitor for 1 week
3. Collect metrics (build times, success rate)

### Stage 2: Staged Migration

Migrate repositories in this order:

1. **lecture-python-programming.myst** (simplest, no ML libs)
2. **lecture-python-intro** (similar to above)
3. **lecture-python-advanced.myst** (similar patterns)
4. **lecture-python.myst** (most complex, has ML libs)

### Stage 3: Production Migration

For each repository:

1. Create migration PR
2. Update workflows to use `@v1` (stable release)
3. Keep old workflows commented out for 1 week
4. Monitor for issues
5. Remove old workflows after confirmation

---

## Rollback Plan

If issues occur after migration:

### Quick Rollback (Emergency)

```yaml
# In affected workflow file, change:
- uses: quantecon/actions/setup-lecture-env@v1

# To: (revert to manual setup)
- name: Setup Anaconda
  uses: conda-incubator/setup-miniconda@v3
  with:
    # ... original configuration
```

### Controlled Rollback

1. Revert the workflow file commit
2. Push to main
3. Wait for next workflow run to confirm
4. Investigate issue in actions repository

---

## Monitoring & Metrics

Track these metrics before and after migration:

### Build Time Metrics

| Metric | Before | After (First Run) | After (Cached) |
|--------|--------|-------------------|----------------|
| Conda setup | 3-5 min | 3-5 min | ~30 sec |
| pip install | 2-4 min | 2-4 min | ~30 sec |
| LaTeX install | 2-3 min | 2-3 min | ~10 sec |
| Total setup | 8-12 min | 8-12 min | ~1 min |
| Full workflow | 45-60 min | 45-60 min | 10-15 min |

### Success Rate

- Workflow completion rate (target: >95%)
- Cache hit rate (target: >80% after initial runs)
- Build artifact consistency (target: 100%)

---

## Debugging Failed Tests

### Common Issues

#### Issue: Cache not restoring

**Symptom:** Every run installs packages from scratch

**Debug:**
```yaml
- name: Debug cache
  run: |
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

---

## Testing Checklist Template

Use this checklist for each repository migration:

```markdown
## Migration Test: [Repository Name]

### Pre-Migration
- [ ] Document current build times
- [ ] Save current workflow files
- [ ] Create test branch
- [ ] Create test workflow

### Testing Phase  
- [ ] Test workflow runs successfully
- [ ] Compare build artifacts
- [ ] Verify caching works
- [ ] Test cache invalidation
- [ ] Run 3+ times to confirm cache stability

### Validation
- [ ] Build time improved after cache
- [ ] Artifacts identical to production
- [ ] No new errors
- [ ] Team review completed

### Migration
- [ ] Update workflows to use actions@v1
- [ ] Merge to main
- [ ] Monitor first 5 production runs
- [ ] Document any issues

### Cleanup
- [ ] Remove test workflow after 1 week
- [ ] Remove old workflow comments after 1 week
- [ ] Update documentation
```

---

## Contact & Support

For testing questions or issues:

1. Open issue in `quantecon/actions` repository
2. Tag with `testing` label
3. Include workflow run logs
4. Include comparison results

## Continuous Improvement

After each migration:
1. Document lessons learned
2. Update this testing guide
3. Improve validation scripts
4. Enhance error messages in actions
