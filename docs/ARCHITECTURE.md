# QuantEcon Actions: Finalized Architecture

## The Three-Pillar Approach

Our next-generation CI/CD system combines three complementary elements:

### 1. 🐳 Containerized Environment

**Pre-built Docker images solve the LaTeX bottleneck:**

- **Images:** `ghcr.io/quantecon/quantecon:latest` (full) and `ghcr.io/quantecon/quantecon-build:latest` (lean) — CPU only
- **Contents:** Ubuntu 24.04 LTS + TexLive (latest) + Miniconda + Anaconda 2025.12 base + Jupyter Book tools
- **Build:** Weekly automated builds via GitHub Actions (Monday 2am UTC)
- **Registry:** GitHub Container Registry (GHCR) - free for public repos
- **Size:** full ~8.3 GB / lean ~7.1 GB on disk (~3 GB compressed pull, fetched each run on GitHub-hosted runners)

**Performance impact:**
- ❌ Current: LaTeX setup takes 2-3 minutes every build
- ✅ Container: LaTeX pre-installed, base scientific packages included
- ✅ Only lecture-specific packages need installation (quantecon, cvxpy, etc.)
- **Savings: ~5-6 minutes per build (60-70% faster setup)**

**Note:** GPU support deferred to future phase - focuses on CPU lecture builds initially.

### 2. 🧩 Modular Actions

**Separate, focused actions that compose together:**

```
build-jupyter-cache/  → Generate and save execution cache (main branch, weekly)
restore-jupyter-cache/→ Restore execution cache (PR workflows)
build-lectures/       → Build Jupyter Book (multi-format, asset assembly)
preview-netlify/      → Deploy to Netlify for PR previews
preview-cloudflare/   → Deploy to Cloudflare Pages for PR previews
publish-gh-pages/     → Deploy to GitHub Pages
```

**Why modular over monolithic?**
- ✅ Clear responsibility boundaries
- ✅ Each action independently testable
- ✅ Flexible composition per-lecture
- ✅ Better error messages (know which step failed)
- ✅ Independent versioning and updates
- ✅ Follows GitHub Actions ecosystem standards

### 3. 💾 Two-Layer Caching

**Maximize speed through strategic caching:**

**Layer 1: Environment Cache (Container Image)**
- What: Python + LaTeX + all dependencies
- Where: GitHub Container Registry
- Size: ~7.1 GB (lean) / ~8.3 GB (full) on disk; ~3 GB compressed pull
- Lifespan: Weekly rebuilds
- Pull time: ~1-2 min on GitHub-hosted runners (~3 GB compressed, fetched each run); near-instant on self-hosted runners with the image pre-cached

**Layer 2: Build Cache (GitHub Actions Cache)**
- What: `_build/` directory from Jupyter Book
- Where: GitHub Actions cache API
- Size: ~50-200 MB per lecture
- Lifespan: 7 days
- Management: Via dedicated cache actions

**Cache Actions:**
- `build-jupyter-cache` - Weekly cache generation on main branch
  - Builds all formats, verifies success, saves cache
  - Creates issues on failure (duplicate prevention)
  - Uses unique keys: `build-{env-hash}-{run-id}`
- `restore-jupyter-cache` - Read-only restore for PRs
  - Never saves (prevents cache corruption)
  - Prefix matching finds latest cache
  - Optional `fail-on-miss` for strict requirements

**Combined performance:**
- Cold cache (first build): 9-11 min
- Warm cache (incremental): 3-5 min
- Perfect cache (no changes): 30-40 sec

---

## Workflow Example

### Before (Current Approach)

```yaml
# 15-18 minutes total
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # 7-8 minutes: Setup environment + LaTeX
      - uses: quantecon/actions/setup-environment@v0
        with:
          install-latex: 'true'
      
      # Manual cache management
      - uses: actions/cache@v4
        with:
          path: lectures/_build
          key: ${{ hashFiles('lectures/**') }}
      
      # 8-10 minutes: Build
      - run: jupyter-book build lectures/
      
      # Manual deployment
      - uses: quantecon/actions/preview-netlify@v0
        with:
          # ... many configuration options
```

### After (Container + Modular Actions)

```yaml
# 9-13 minutes with warm cache
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    container: ghcr.io/quantecon/quantecon:latest  # ~1-2 min pull
    steps:
      - uses: actions/checkout@v4
      
      # Install lecture-specific packages (1-2 min)
      - name: Install lecture dependencies
        run: conda env update -f environment.yml
      
      # Restore cache from main branch (if available)
      - uses: quantecon/actions/restore-jupyter-cache@v0
        with:
          cache-type: 'build'
      
      # Build (uses restored cache for incremental build)
      - uses: quantecon/actions/build-lectures@v0
        id: build
      
      # Deploy preview (PR only)
      - uses: quantecon/actions/preview-netlify@v0
        if: github.event_name == 'pull_request'
        with:
          netlify-auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          netlify-site-id: ${{ secrets.NETLIFY_SITE_ID }}
          build-dir: ${{ steps.build.outputs.build-path }}
      
      # Deploy production (main branch)
      - uses: quantecon/actions/publish-gh-pages@v0
        if: github.ref == 'refs/heads/main'
        with:
          build-dir: ${{ steps.build.outputs.build-path }}
```

**Improvements:**
- ⚡ 30-40% faster (9-13 min vs 15-18 min) - LaTeX pre-installed saves 2-3 min, base packages save 3-4 min
- 🎯 Clearer (explicit steps, obvious failures)
- 🔧 Easier to customize (add/remove deployment targets)
- 📦 Dedicated cache actions (build-jupyter-cache + restore-jupyter-cache)
- 🐛 Better debugging (know which action failed)

---

## Key Design Decisions

### Why Containers?

**Problem:** LaTeX installation is unavoidable bottleneck
- Takes 2-3 minutes with Conda, Mamba, or UV
- Can't be meaningfully cached
- Required for PDF generation and some Jupyter Book features

**Solution:** Pre-install in container
- LaTeX installed once during weekly container build
- All lecture builds reuse same pre-built environment
- Only solution that eliminates this bottleneck

### Why Global Container?

**Alternatives considered:**
1. ❌ Per-lecture containers (too complex to maintain)
2. ❌ Multi-stage containers (over-engineered)
3. ✅ Single global container with minimal base environment (optimal simplicity)

**Rationale:**
- All lectures use same Python scientific stack (Anaconda base provides common packages)
- Lecture-specific packages (quantecon, cvxpy, etc.) installed from each lecture's environment.yml
- LaTeX requirements identical across all lectures
- Disk space is cheap (~7-8 GB acceptable)
- Massive reduction in complexity
- Easy to update (one PR to container, lectures install their own dependencies)

### Why Modular Actions?

**Alternative:** Monolithic "super action" that does everything

**Decision:** Keep modular approach

**Rationale:**
- Saves only ~3-5 lines in workflow files
- Loss of clarity, flexibility, debuggability not worth it
- Modular is the GitHub Actions ecosystem standard
- Each action testable in isolation
- Clear failure messages
- Mix and match per lecture needs

### Why Two-Layer Caching?

**Why not just container?**
- Container provides environment, not build outputs
- Jupyter Book builds take 3-10 minutes
- Incremental builds much faster (~30 sec to 2 min)
- Build cache prevents unnecessary rebuilds

**Why not just GitHub Actions cache?**
- Still need to install environment every time
- LaTeX alone takes 2-3 minutes
- Cache can't eliminate environment setup time

**Together:**
- Container eliminates environment setup (~7 min)
- Build cache eliminates unnecessary rebuilds (~3-8 min)
- Combined effect: 10x faster on cached builds

**Why the build cache is keyed on the environment, not lecture content:**
- `_build` is a stable warm-start baseline from `main`; a content hash would miss the cache on every PR (each edits some `.md`) and force a cold, full re-execution.
- Freshness is handled elsewhere: jupyter-cache re-executes only changed notebooks (content-addressed per notebook), Sphinx rebuilds incrementally, and the weekly cold rebuild clears any drift.
- Trade-off: Sphinx incremental doesn't delete output for removed sources, so deleted/renamed lectures can leave *orphaned* pages — but they're unreachable in navigation (absent from `_toc.yml`) and cleared by the weekly rebuild.

---

## Performance Targets

### Current Performance (Baseline)

```
Total: 15-18 minutes
├─ Setup: 7-8 min  (Python + LaTeX + dependencies)
└─ Build: 8-10 min (Jupyter Book compilation)
```

### Target Performance (Container + Cache)

> These breakdowns assume the container image is already present locally (self-hosted or a warm/pre-cached runner, ~20 s). On GitHub-hosted runners add ~1-2 min for the per-run image pull.

**First build (cold cache):**
```
Total: 11-13 minutes
├─ Container pull: 20 sec
├─ Checkout: 10 sec
├─ Install lecture packages: 1-2 min (quantecon, cvxpy, etc.)
├─ Cache restore: 5 sec (miss)
├─ Build: 8-10 min (full build)
└─ Cache save: 30 sec
```

**Incremental build (warm cache, some changes):**
```
Total: 4-6 minutes
├─ Container pull: 20 sec (cached)
├─ Checkout: 10 sec
├─ Install lecture packages: 1-2 min (conda env update)
├─ Cache restore: 10 sec (hit)
├─ Incremental build: 2-4 min
└─ Cache save: 30 sec
```

**No-op build (perfect cache, no content changes):**
```
Total: 30-40 seconds
├─ Container pull: 20 sec (cached)
├─ Checkout: 10 sec
├─ Cache restore: 5 sec (hit)
├─ Build: 5 sec (Jupyter Book detects no changes)
└─ Cache save: 5 sec
```

**Improvement:**
- Cold: 40% faster (9-11 min vs 15-18 min)
- Warm: 70-80% faster (3-5 min vs 15-18 min)
- Perfect: 95% faster (30-40 sec vs 15-18 min)

---

## Repository Structure

### Actions Repo (`quantecon/actions`)

```
quantecon/actions/
├── containers/
│   ├── quantecon/                 # Full image (Ubuntu + LaTeX + Miniconda + Anaconda)
│   │   ├── Dockerfile
│   │   └── environment.yml
│   └── quantecon-build/           # Lean image (build toolchain only)
│       ├── Dockerfile
│       └── environment.yml
│
├── build-jupyter-cache/           # Modular action
│   ├── action.yml                 # Generate cache on main branch
│   ├── scripts/                   # External scripts
│   └── README.md
│
├── restore-jupyter-cache/         # Modular action
│   ├── action.yml                 # Restore cache for PRs
│   └── README.md
│
├── build-lectures/                # Modular action
│   ├── action.yml                 # Multi-format builds, asset assembly
│   └── README.md
│
├── preview-netlify/                # Modular action
│   ├── action.yml                 # Netlify PR preview deployment
│   └── README.md
│
├── publish-gh-pages/              # Modular action
│   ├── action.yml                 # GitHub Pages deployment
│   └── README.md
│
├── .github/workflows/
│   └── build-containers.yml       # Weekly automated builds
│
└── docs/
    ├── ARCHITECTURE.md           # This file (architecture overview)
    ├── CONTAINER-GUIDE.md         # Container build and usage guide
    ├── FUTURE-DEVELOPMENT.md      # Future enhancement plans
    ├── MIGRATION-GUIDE.md         # How to migrate lecture repos
    ├── QUICK-REFERENCE.md         # Quick reference for all actions
    └── README.md                  # Documentation index
```

### Lecture Repos (Simplified)

```
lecture-python-intro/
├── lectures/              # Content
│   ├── _config.yml
│   ├── _toc.yml
│   └── *.md
│
└── .github/workflows/
    └── ci.yml            # Minimal workflow (~20 lines)
```

**Before:** Each lecture repo had complex setup
**After:** Copy template, set variables, done

---

## User Experience

### For Researchers (Content Authors)

**No changes required:**
- ✅ Still use Anaconda for local development
- ✅ Still edit Markdown/Jupyter notebooks
- ✅ Still commit and push to GitHub
- ✅ CI runs automatically (just faster)

**Containers are invisible to users.**

### For Maintainers (DevOps)

**Simplified maintenance:**
- ✅ One centralized `environment.yml` to update
- ✅ Weekly automated container rebuilds
- ✅ Update action once, affects all lectures
- ✅ Clear logs (know which action failed)
- ✅ Easy to add new lectures (copy template)

### For Contributors

**Easier to understand:**
- ✅ Each action has clear purpose
- ✅ Can test actions independently
- ✅ Standard GitHub Actions patterns
- ✅ Good documentation for each component

---

## Migration Path

### Phase 1: Infrastructure (Week 1)
- Create container infrastructure
- Build and test images
- Create modular actions

### Phase 2: Testing (Week 2)
- Migrate test lecture
- Validate performance
- Fix any issues

### Phase 3: Documentation (Week 3)
- Write migration guides
- Create templates
- Update documentation

### Phase 4: Rollout (Week 4-5)
- Migrate remaining lectures (~10 repos)
- Monitor and adjust
- Deprecate old approach

---

## Key Benefits

### Speed ⚡
- **3-4x faster** on cold cache
- **5-10x faster** on warm cache
- **20-30x faster** on perfect cache

### Simplicity 🎯
- Cleaner workflows (remove setup steps)
- Dedicated cache actions (restore = one line, no configuration)
- Standard patterns across all lectures

### Reliability 🔒
- Pre-built environment (no installation failures)
- Deterministic builds (same container always)
- Clear error messages (know what failed)

### Maintainability 🔧
- Centralized environment management
- Update once, affects all lectures
- Independent action updates
- Easy to add new lectures

### Flexibility 🧩
- Modular composition
- GPU support via tag change
- Custom workflows possible
- Progressive adoption

---

## Open Questions (Resolved)

### ✅ UV vs Containers?
**Answer:** Containers. UV doesn't solve LaTeX bottleneck (2-3 min unavoidable).

### ✅ Per-lecture or global container?
**Answer:** Global. Lectures share ecosystem, simplicity wins.

### ✅ Monolithic or modular actions?
**Answer:** Modular. Clarity and flexibility worth ~3 extra lines.

### ✅ How to handle GPU lectures?
**Answer:** Separate `:gpu` tag, same simplicity.

### ✅ What about users?
**Answer:** Keep Anaconda. Containers only for CI.

---

## Success Criteria

### Technical Metrics
- ✅ Build time < 5 min (warm cache)
- ✅ Build time < 12 min (cold cache)
- ✅ Container pull < 30 sec
- ✅ Cache hit rate > 70%

### User Experience
- ✅ Lecture workflows < 30 lines
- ✅ Zero manual cache management
- ✅ Clear error messages
- ✅ Easy to customize

### Maintenance
- ✅ Single environment file
- ✅ Automated container builds
- ✅ No per-lecture Dockerfiles
- ✅ Centralized updates

---

## Related Documentation

- [CONTAINER-GUIDE.md](CONTAINER-GUIDE.md) - Container build and usage guide
- [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md) - How to migrate lecture repos
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Quick reference for all actions
- [FUTURE-DEVELOPMENT.md](FUTURE-DEVELOPMENT.md) - Future enhancement plans

---

**This architecture is implemented and in production. 🚀**
