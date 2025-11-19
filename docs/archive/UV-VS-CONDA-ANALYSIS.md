# UV vs Anaconda/Mamba Analysis

**Date:** 19 November 2025  
**Purpose:** Evaluate `uv` as a faster alternative to Conda/Mamba for QuantEcon lecture builds

---

## What is UV?

[UV](https://github.com/astral-sh/uv) is an extremely fast Python package installer and resolver written in Rust by Astral (creators of Ruff).

**Key features:**
- 🚀 **10-100x faster** than pip/pip-tools
- 🚀 **Significantly faster** than Conda
- 📦 Drop-in replacement for pip, pip-tools, virtualenv
- 🔒 Reliable dependency resolution
- 🐍 Supports Python 3.8+
- 💾 Global caching across projects
- 🔄 Lock file support (`uv.lock`)

**Installation:**
```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or via pip (if you already have Python)
pip install uv

# Or via Homebrew (macOS)
brew install uv

# Or via winget (Windows)
winget install --id=astral-sh.uv -e
```

---

## 🚨 Critical Consideration: User Installation Experience

### The Anaconda Advantage

**Why we currently use Anaconda:**
```bash
# Users install Anaconda/Miniconda ONCE
# Then for each lecture:
conda env create -f environment.yml
conda activate quantecon
# Done! Everything works.
```

**What Anaconda provides:**
1. ✅ **Python itself** - Users don't need Python pre-installed
2. ✅ **All packages** - Scientific stack, Jupyter, everything
3. ✅ **Cross-platform** - Same experience on Windows/Mac/Linux
4. ✅ **One-stop shop** - Single installation for everything
5. ✅ **Familiar** - Well-known in scientific Python community

### The UV Challenge

**UV installation requires Python first:**
```bash
# Step 1: User must have Python installed (UV doesn't include Python)
# Option A: Install from python.org
# Option B: Install via system package manager
# Option C: Use system Python (might be old)

# Step 2: Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh  # or pip install uv

# Step 3: Use UV
uv venv
uv pip install -r requirements.txt
```

**Key differences:**

| Aspect | Anaconda/Miniconda | UV |
|--------|-------------------|-----|
| **Includes Python?** | ✅ Yes, any version | ❌ No, requires Python |
| **Installation steps** | 1 (download + install) | 2+ (Python + UV) |
| **Cross-platform** | ✅ Consistent experience | ⚠️ Varies by OS |
| **User familiarity** | ✅ Well-known in data science | ❌ New tool (2023) |
| **Beginner friendly** | ✅ Very | ⚠️ Assumes Python knowledge |
| **Setup instructions** | Simple, one command | More complex |

### User Installation Comparison

#### Scenario: New student with no Python installed

**With Anaconda (current approach):**
```bash
# 1. Install Miniconda (one download)
# 2. Create environment
conda env create -f environment.yml
conda activate quantecon
# Ready to go!
```

**With UV (would require):**
```bash
# 1. Install Python 3.13
#    - macOS: brew install python@3.13 OR download from python.org
#    - Linux: apt install python3.13 OR dnf install python3.13
#    - Windows: Download from python.org OR winget install Python.Python.3.13

# 2. Install UV
#    - macOS/Linux: curl -LsSf https://astral.sh/uv/install.sh | sh
#    - Windows: winget install astral-sh.uv OR pip install uv

# 3. Create environment
uv venv
uv pip install -r requirements.txt
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
# Ready to go!
```

**Complexity score:**
- Anaconda: ⭐ (1 step)
- UV: ⭐⭐⭐ (3 steps, varies by platform)

### UV's Installation Advantages (for developers)

**UV is simpler IF Python is already installed:**
```bash
# Already have Python? UV is trivial:
pip install uv
# or
curl -LsSf https://astral.sh/uv/install.sh | sh

# Then use it:
uv venv && uv pip install -r requirements.txt
# Much faster than Conda!
```

**Good for:**
- ✅ CI/CD (Python pre-installed in GitHub Actions)
- ✅ Docker containers (Python in base image)
- ✅ Developers who already have Python
- ✅ Power users comfortable with tooling

**Not ideal for:**
- ❌ Students/beginners new to Python
- ❌ Workshops where "just works" is critical
- ❌ Mixed audience with varying technical skills
- ❌ Non-technical users

---

## Speed Comparison

### Benchmarks (from Astral documentation)

**Installing Django + dependencies:**
```
pip:           45 seconds
pip-tools:     40 seconds
conda:         120 seconds (2 minutes)
mamba:         25 seconds
uv:            1.5 seconds ⚡
```

**Creating environment + installing packages:**
```
python -m venv + pip install:  ~60 seconds
conda env create:              ~120 seconds
mamba env create:              ~30 seconds
uv venv + uv pip install:      ~3 seconds ⚡
```

### Our Use Case Estimate

For QuantEcon lecture environments (~50-70 packages including Jupyter, pandas, matplotlib, etc.):

| Tool | First Install | Cached Install | Notes |
|------|---------------|----------------|-------|
| **Conda** | ~240 sec (4 min) | ~180 sec (3 min) | Slow solver |
| **Mamba** | ~120 sec (2 min) | ~60 sec (1 min) | Faster solver |
| **UV** | ~10-20 sec | ~3-5 sec | Rust-based, highly optimized |

**Potential time savings:** ~2-4 minutes per build

---

## UV vs Conda/Mamba: Feature Comparison

| Feature | Conda/Mamba | UV |
|---------|-------------|-----|
| **Speed** | Slow / Medium | Very Fast ⚡ |
| **Python version management** | ✅ Built-in | ❌ Requires system Python |
| **Non-Python packages** | ✅ (e.g., LaTeX, system libs) | ❌ Python only |
| **Cross-platform binaries** | ✅ Compiled packages | ⚠️ Depends on wheels |
| **Environment isolation** | ✅ Full isolation | ✅ Virtual environments |
| **Lock files** | ❌ No built-in | ✅ `uv.lock` |
| **Reproducibility** | ⚠️ Can drift | ✅ Strong with lock files |
| **Package ecosystem** | conda-forge (large) | PyPI (largest) |
| **Scientific packages** | ✅ Optimized (MKL, etc.) | ⚠️ Depends on wheels |
| **Disk usage** | High (duplicates) | Low (shared cache) |
| **CI/CD friendly** | Medium | High ⚡ |

---

## UV for QuantEcon: Pros & Cons

### Pros ✅

1. **Massive speed improvement**
   - 10-100x faster than pip
   - 5-10x faster than Mamba
   - Could reduce setup from 2-4 min to 10-20 sec

2. **Better isolation per lecture**
   - Easy to create separate environments per lecture
   - Test each lecture independently
   - No cross-contamination

3. **Lock file support**
   - `uv pip compile` creates `requirements.txt` with exact versions
   - `uv.lock` ensures reproducibility
   - Better than Conda's environment.yml (which can drift)

4. **Excellent CI/CD integration**
   - Setup in seconds, not minutes
   - Global cache works across builds
   - No need for complex caching strategies

5. **Modern tooling**
   - Active development (Astral/Ruff team)
   - Growing adoption in Python community
   - Compatible with existing PyPI ecosystem

### Cons ❌

1. **Python version management**
   - UV doesn't install Python itself
   - Need `actions/setup-python` or pre-installed Python
   - Conda provides full Python version control

2. **No non-Python packages**
   - Can't install LaTeX via UV
   - Can't install system libraries
   - Still need separate LaTeX installation

3. **Scientific package considerations**
   - Depends on PyPI wheels being available
   - May not have optimized binaries (MKL) like Conda
   - Some packages might not have wheels for all platforms

4. **Newer tool, less proven**
   - Released in 2023, relatively new
   - Smaller community than Conda/Mamba
   - Less established in scientific computing

5. **Migration effort**
   - Need to convert `environment.yml` to `requirements.txt` or `pyproject.toml`
   - Different workflow patterns
   - Team learning curve

---

## Hybrid Approach: UV + System Python + LaTeX

### Architecture

```yaml
# Proposed workflow
jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      
      # 1. Setup Python (GitHub's cached Python)
      - uses: actions/setup-python@v5
        with:
          python-version: '3.13'
      
      # 2. Install UV
      - name: Install UV
        run: curl -LsSf https://astral.sh/uv/install.sh | sh
      
      # 3. Install LaTeX (still needed)
      - name: Install LaTeX
        run: |
          sudo apt-get update
          sudo apt-get install -y texlive-full
      
      # 4. Create environment with UV (FAST!)
      - name: Setup Python environment
        run: |
          uv venv .venv
          source .venv/bin/activate
          uv pip install -r requirements.txt
      
      # 5. Build lectures
      - name: Build
        run: |
          source .venv/bin/activate
          jupyter-book build lectures/
```

**Time estimate:**
- Setup Python: ~5 sec (cached)
- Install UV: ~2 sec
- Install LaTeX: ~120 sec (2 min, unavoidable)
- UV environment + packages: ~10-20 sec
- **Total setup: ~2.5 min** (vs 7-8 min with Conda)

---

## Comparison with Container Approach

| Approach | Setup Time (Cached) | Setup Time (Fresh) | Complexity | Pros |
|----------|---------------------|-------------------|------------|------|
| **Current (Conda + Cache)** | ~7-8 min | ~12 min | Medium | Established, works |
| **UV + System Python** | ~2.5 min | ~3 min | Low | Fast, simple, modern |
| **Containers (proposed)** | <1 min | ~3-5 min | High | Fastest (cached), full isolation |

### UV vs Containers: When to Use What?

**Use UV if:**
- ✅ Want simplicity over maximum speed
- ✅ Don't want container complexity
- ✅ Testing multiple environments (each lecture isolated)
- ✅ Need fast iteration during development
- ✅ Comfortable with PyPI ecosystem

**Use Containers if:**
- ✅ Need absolute fastest cached builds (<1 min)
- ✅ Want complete environment reproducibility
- ✅ Need system-level dependencies beyond LaTeX
- ✅ Want local dev environment to match CI exactly
- ✅ Willing to manage container complexity

---

## Recommendation: Split Strategy Based on Use Case

### ⚠️ Key Insight: Different Users, Different Needs

**For end users (students, researchers):**
- Keep Anaconda/Miniconda
- Installation simplicity is paramount
- `conda env create -f environment.yml` just works

**For CI/CD (GitHub Actions):**
- Use UV or containers
- Speed matters most
- Python is pre-installed
- Users never see it

**For developers (lecture maintainers):**
- Either works, personal preference
- UV is faster for quick testing
- Conda is more familiar

### Recommended Approach: **Dual Environment Support**

Support both Anaconda AND UV/pip, let users choose:

#### For End Users (Keep Simple)
```bash
# README installation instructions:
# Option 1: Anaconda (Recommended for beginners)
conda env create -f environment.yml
conda activate quantecon

# Option 2: UV (Faster, requires Python 3.13+)
uv venv
uv pip install -r requirements.txt
source .venv/bin/activate
```

**Maintain both:**
- `environment.yml` (for Conda users)
- `requirements.txt` (for UV/pip users)

#### For CI/CD (Use UV for Speed)

```yaml
# .github/workflows/ci.yml - invisible to users
- uses: astral-sh/setup-uv@v1
- run: uv venv
- run: uv pip install -r requirements.txt
- run: jupyter-book build lectures/
```

**Benefits of dual approach:**
- ✅ Users get simple Anaconda experience
- ✅ CI gets UV speed (5 min savings)
- ✅ Advanced users can use UV if preferred
- ✅ No breaking changes for existing users
- ✅ Future-proof (modern tooling)

---

## Migration Path: Conda → UV

### Step 1: Convert environment.yml to requirements.txt

**Option A: Manual conversion**
```bash
# Extract pip packages from environment.yml
grep -A 100 "pip:" environment.yml | grep "    - " | sed 's/    - //' > requirements.txt
```

**Option B: Use existing environment**
```bash
conda activate quantecon
pip freeze > requirements.txt
```

**Option C: Use uv pip compile (recommended)**
```bash
# Create pyproject.toml with dependencies
# Then:
uv pip compile pyproject.toml -o requirements.txt
```

### Step 2: Test locally

```bash
# Create UV environment
uv venv
source .venv/bin/activate

# Install dependencies
uv pip install -r requirements.txt

# Test
jupyter-book build lectures/
```

### Step 3: Update CI workflow

```diff
# .github/workflows/ci.yml
-     - name: Setup Lecture Environment
-       uses: quantecon/actions/setup-lecture-env-full@main
-       with:
-         environment-file: 'environment.yml'
-         environment-name: 'quantecon'

+     - uses: astral-sh/setup-uv@v1
+     
+     - name: Setup environment
+       run: |
+         uv venv
+         uv pip install -r requirements.txt
+     
+     - name: Activate environment
+       run: echo "VIRTUAL_ENV=$PWD/.venv" >> $GITHUB_ENV
+              echo "$PWD/.venv/bin" >> $GITHUB_PATH
```

### Step 4: Measure and validate

- Compare build times
- Verify output matches
- Check for missing dependencies

---

## UV + Per-Lecture Isolation

One of UV's strengths is making it trivial to test each lecture in its own environment:

```bash
# Test lecture-python-intro
cd lecture-python-intro
uv venv
uv pip install -r requirements.txt
jupyter-book build lectures/

# Test lecture-python-programming (separate environment)
cd ../lecture-python-programming
uv venv  # Fresh environment
uv pip install -r requirements.txt
jupyter-book build lectures/

# No cross-contamination!
```

**Benefits:**
- Catch dependency conflicts early
- Ensure each lecture is self-contained
- Faster than recreating Conda envs

---

## Performance Projection

### Current State (Conda + Cache)
```
Setup breakdown:
- Conda environment: ~5-6 min (cached)
- LaTeX install:     ~2-3 min (ALWAYS, can't cache)
Total setup:  7-8 min (cached) / 12 min (fresh)
Build:        8-10 min
Total:        15-18 min
```

### With UV (Python packages faster, but LaTeX still slow)
```
Setup breakdown:
- UV environment:    ~10-20 sec (fast!)
- LaTeX install:     ~2-3 min (STILL SLOW, can't cache)
Total setup:  2.5-3 min (LaTeX dominates!)
Build:        8-10 min
Total:        10-13 min
Time saved:   ~5 min per build (30% faster)
```

### With Containers (Pre-installed LaTeX!)
```
Setup breakdown (cached):
- Pull image:        ~10-20 sec (LaTeX already in image!)
- Start container:   ~5 sec
Total setup:  <1 min (LaTeX problem SOLVED!)
Build:        8-10 min
Total:        9-11 min (cached)

Setup breakdown (fresh build):
- Build image:       ~3-5 min (one-time or scheduled)
Total:        13-15 min (fresh)
```

## 🎯 Key Insight: LaTeX is the Real Bottleneck

**The problem UV can't solve:**
- UV makes Python packages fast (~10-20 sec vs 5-6 min)
- But LaTeX still takes 2-3 min EVERY TIME
- We can't cache LaTeX system files (permission issues)
- UV saves ~5 min, but we're still doing 2-3 min of LaTeX install

**Why containers are different:**
- LaTeX is pre-installed in the image
- Pull cached image = get LaTeX instantly
- This is the ONLY way to cache LaTeX effectively
- Saves the most painful 2-3 minutes

**Time savings comparison:**
```
Current (Conda):           7-8 min setup
UV (fast Python):          2-3 min setup (saves ~5 min)
Containers (cached):       <1 min setup  (saves ~7 min) ← Best!
```

**Conclusion:** Containers solve the LaTeX problem that neither Conda nor UV can fix

---

## Questions to Consider

1. **Do we need Conda's non-Python packages?**
   - Currently: Only LaTeX (can install separately)
   - Answer: Not really, UV + apt is sufficient

2. **Are all our packages available on PyPI with wheels?**
   - Need to verify: quantecon, jupyter-book, sphinx extensions
   - Most scientific packages now have wheels
   - Action: Test migration with one lecture

3. **Do we value simplicity or maximum speed?**
   - UV: Simpler, good speed improvement
   - Containers: Maximum speed, more complex
   - Could use both: UV for dev, containers for CI

4. **How important is per-lecture isolation?**
   - If important: UV makes this trivial
   - If not: Either approach works

5. **Migration effort vs benefit?**
   - UV migration: Low effort, good benefit
   - Container migration: High effort, maximum benefit
   - Could do UV first, containers later

---

## Recommended Action Plan

### Phase 1: Experiment with UV (1 week)

1. Pick one lecture repo (e.g., test-lecture-python-intro)
2. Create `requirements.txt` from `environment.yml`
3. Test local build with UV
4. Update CI workflow to use UV
5. Compare performance and output

**Success criteria:**
- ✅ Build output matches Conda version
- ✅ Setup time < 3 min
- ✅ All dependencies resolve correctly

### Phase 2: Evaluate Results (1 week)

- Measure actual time savings
- Check for any issues or missing packages
- Get team feedback on new workflow
- Decide: rollout UV or proceed with containers

### Phase 3: Scale or Pivot (2-3 weeks)

**Option A: UV works great → rollout**
- Migrate remaining lecture repos to UV
- Update documentation
- Deprecate Conda-based actions

**Option B: Issues found → stick with Conda or try containers**
- Document issues
- Either fix UV issues or proceed with container approach
- Keep Conda as fallback

---

## Final Recommendation

### **Containers for CI/CD, Keep Anaconda for Users** ✅

Given that LaTeX is the real bottleneck, containers are the right choice:

#### 1. CI/CD: Implement Containers (Best Long-term Solution)
**Why:**
- ✅ **Only way to cache LaTeX** (2-3 min savings per build)
- ✅ Total ~7 min savings when cached
- ✅ Full environment reproducibility
- ✅ Users never see the complexity
- ✅ Action-managed approach keeps it simple for lecture repos

**Action (from CONTAINER-ARCHITECTURE.md plan):**
- Week 1: Build base image with LaTeX + Miniconda
- Week 2: Implement `setup-container-env` composite action
- Week 3: Test with one lecture repo
- Week 4: Documentation
- Week 5-6: Rollout to all lectures

#### 2. User Documentation: Keep Recommending Anaconda
**Why:**
- ✅ Simpler for beginners (Python included)
- ✅ Well-known in scientific Python
- ✅ No breaking changes for existing users
- ✅ "Just works" experience
- ✅ Nothing changes for end users

**Action:**
- Keep `environment.yml` as primary for users
- CI uses containers (invisible to users)
- No migration needed for user workflows

#### 3. Optional: UV for Developers (Local Testing)
**Why:**
- ✅ Developers can use UV for fast local testing if they want
- ✅ Much faster than Conda for iteration
- ✅ Good for testing per-lecture isolation
- ✅ Complementary to containers

**Action:**
- Add `requirements.txt` for developers who want UV
- Document as advanced option
- Not required, just available

### Why Containers > UV for CI

**The LaTeX problem:**
```
Current:    7-8 min (2-3 min is LaTeX, unavoidable)
With UV:    2-3 min (LaTeX still takes 2-3 min!)
Containers: <1 min  (LaTeX pre-installed!)
```

**UV can't solve LaTeX, containers can:**
- UV only optimizes Python packages (~5 min → ~20 sec)
- LaTeX remains a 2-3 min bottleneck with UV
- Containers pre-install LaTeX, eliminating the bottleneck entirely
- This is the ONLY way to cache LaTeX effectively

### Implementation Priority

**High Priority (Do Now - Next 6 Weeks):**
1. ✅ Implement container approach per CONTAINER-ARCHITECTURE.md
2. ✅ Build base image with LaTeX + Miniconda
3. ✅ Create action-managed `setup-container-env` action
4. ✅ Test and rollout to all lecture repos

**Medium Priority (Optional Enhancement):**
5. ⏳ Add `requirements.txt` for developers who want UV locally
6. ⏳ Document UV as advanced option for fast local testing
7. ⏳ Keep both environment.yml (users) and requirements.txt (UV devs)

**Low Priority (Future):**
8. ⏸ Consider UV in containers (base image could use UV internally)
9. ⏸ Pre-build images on schedule for even faster cached pulls

### UV vs Containers: Which to Prioritize?

**UV approach:**
- ✅ Simpler implementation (update workflows)
- ✅ No Docker complexity
- ✅ Good speed improvement (~5 min savings)
- ✅ Can test today
- ❌ **Still stuck with 2-3 min LaTeX install every time**
- ❌ Doesn't solve the real bottleneck

**Container approach:**
- ✅ **Solves LaTeX problem** (pre-installed in image)
- ✅ Maximum speed (~7 min savings when cached)
- ✅ Full environment reproducibility
- ✅ Only way to cache LaTeX effectively
- ⚠️ More complex (build images, manage GHCR)
- ⚠️ Takes longer to implement (~2-3 weeks)

**The LaTeX factor changes everything:**

```
Without considering LaTeX:
- UV saves ~5 min (Python packages)
- Containers save ~6 min (similar benefit)
- UV is simpler → Choose UV

WITH LaTeX bottleneck:
- UV saves ~5 min BUT still wastes 2-3 min on LaTeX
- Containers save ~7 min AND eliminate LaTeX wait
- Containers solve the unsolvable problem → Choose Containers
```

**Verdict:** Containers are worth the complexity because they're the ONLY solution for LaTeX caching

---

## Resources

- [UV GitHub](https://github.com/astral-sh/uv)
- [UV Documentation](https://docs.astral.sh/uv/)
- [UV vs pip benchmarks](https://github.com/astral-sh/uv#benchmarks)
- [GitHub Actions UV setup](https://github.com/astral-sh/setup-uv)
- [UV in CI/CD Guide](https://docs.astral.sh/uv/guides/integration/github/)

---

## Conclusion: Containers Win Due to LaTeX

### The Decision Matrix

| Criteria | Conda (Current) | UV | Containers |
|----------|----------------|-----|------------|
| Setup time (cached) | 7-8 min | 2-3 min | <1 min ✅ |
| **LaTeX caching** | ❌ Can't cache | ❌ Can't cache | ✅ **Pre-installed** |
| User simplicity | ✅ Simple | Complex | ✅ Invisible |
| CI complexity | Low | Low | Medium |
| Implementation time | N/A | Days | Weeks |
| **Total time saved** | Baseline | ~5 min | **~7 min** ✅ |

### Why LaTeX Makes Containers Essential

**The math:**
- Current setup: 7-8 min (5-6 min Conda + 2-3 min LaTeX)
- UV optimizes Conda: 2-3 min total (20 sec UV + 2-3 min LaTeX)
- Containers pre-install LaTeX: <1 min total

**LaTeX is ~30-40% of setup time and UV can't help with it.**

Only containers solve this problem.

### Combined Approach: Containers + Optional UV

**Best of all worlds:**

1. **CI uses containers** (action-managed, LaTeX pre-installed)
   - Fastest possible builds
   - Users never see it
   - Solves the LaTeX problem

2. **Users use Anaconda** (current, no changes)
   - Keep environment.yml
   - Simple installation
   - Well-known tooling

3. **Developers can optionally use UV** (for local speed)
   - Add requirements.txt
   - Fast iteration
   - Personal choice

## Next Steps

**Recommendation:** Proceed with container implementation as designed in CONTAINER-ARCHITECTURE.md

**This analysis confirms:**
- ✅ Containers are the right choice for CI/CD
- ✅ LaTeX caching is the key benefit UV can't provide
- ✅ Action-managed approach keeps lecture repos simple
- ✅ UV is useful as optional tool for developers, not replacement
- ✅ Keep Anaconda for users (no changes needed)

**Optional:** Add requirements.txt to lecture repos for developers who want to use UV locally for fast testing, but this is secondary to the container implementation.
