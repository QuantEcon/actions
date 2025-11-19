# Next Steps: Container-Based CI Implementation

**Date:** 19 November 2025  
**Status:** Ready for Implementation

---

## Architecture Summary

**The finalized approach combines three key elements:**

1. **Containerized Environment** - Pre-built Docker images with Python + LaTeX + all dependencies
2. **Modular Actions** - Separate, focused actions that compose together (build, deploy-netlify, publish-gh-pages)
3. **Two-Layer Caching** - Environment cache (container) + build cache (GitHub Actions cache)

**Design Rationale:** We chose modular actions over a monolithic "super action" for clarity, flexibility, and maintainability. See `archive/ACTION-DESIGN-PHILOSOPHY.md` for detailed analysis.

---

## Summary of Decisions

### Architecture: Global Container + Composite Action

**Key decisions made:**
1. ✅ **Single global container** for all lectures (`ghcr.io/quantecon/quantecon:latest`)
2. ✅ **Centralized environment.yml** in actions repo (union of all requirements)
3. ✅ **Composite action** handles all build concerns (caching, building, artifacts)
4. ✅ **GPU variant** available via `:gpu` tag
5. ✅ **Configuration through inputs**, not workflow changes

### Why This Approach

**Compared to UV:**
- UV optimizes Python packages (~5 min savings)
- But LaTeX still takes 2-3 min every time (can't cache)
- **Containers pre-install LaTeX** → only solution to the LaTeX bottleneck
- Containers save ~7 min vs UV's ~5 min

**Compared to per-lecture containers:**
- Global container is much simpler
- Monolithic environment acceptable (lectures share ecosystem)
- Updates are centralized (one PR affects all)
- No per-lecture Dockerfiles to maintain

**User experience:**
- Keep Anaconda for end users (simple installation)
- Containers only for CI/CD (users never see it)
- No breaking changes for researchers

---

## File Structure (Final)

```
quantecon/actions/
├── containers/quantecon/
│   ├── Dockerfile              # CPU version (Ubuntu + LaTeX + Miniconda)
│   ├── Dockerfile.gpu          # GPU version (CUDA base)
│   ├── environment.yml         # Centralized environment for all lectures
│   └── environment-gpu.yml     # Optional GPU-specific packages
│
├── build-lectures/             # Modular action: Build + cache
│   ├── action.yml
│   └── README.md
│
├── deploy-netlify/             # Modular action: Netlify deployment
│   ├── action.yml
│   └── README.md
│
├── publish-gh-pages/           # Modular action: GitHub Pages
│   ├── action.yml
│   └── README.md
│
├── setup-latex/                # Legacy (deprecated by containers)
│   └── ...
│
├── .github/workflows/
│   └── build-containers.yml    # Automated container builds
│
└── docs/
    ├── CONTAINER-ARCHITECTURE.md      # Complete design spec
    ├── UV-VS-CONDA-ANALYSIS.md        # Why containers over UV
    ├── ACTION-DESIGN-PHILOSOPHY.md    # Why modular over monolithic
    ├── NEXT-STEPS-CONTAINERS.md       # This file
    └── workflows/
        └── standard-ci.yml            # Template workflow
```

---

## Implementation Plan

### Week 1: Container Infrastructure

**In `quantecon/actions` repo:**

1. **Create container directory structure**
   ```bash
   mkdir -p containers/quantecon
   ```

2. **Create centralized environment.yml**
   ```yaml
   # containers/quantecon/environment.yml
   name: quantecon
   channels:
     - conda-forge
   dependencies:
     - python=3.13
     - jupyter-book
     - matplotlib
     - numpy
     - pandas
     - quantecon
     # ... union of all lecture requirements
   ```

3. **Create Dockerfile (CPU version)**
   ```dockerfile
   # containers/quantecon/Dockerfile
   FROM ubuntu:24.04
   
   # Install LaTeX
   RUN apt-get update && \
       apt-get install -y --no-install-recommends \
           texlive-full \
           texlive-xetex \
           latexmk \
           git \
           curl && \
       rm -rf /var/lib/apt/lists/*
   
   # Install Miniconda
   RUN curl -L https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda.sh && \
       bash /tmp/miniconda.sh -b -p /opt/conda && \
       rm /tmp/miniconda.sh && \
       /opt/conda/bin/conda install -y mamba -c conda-forge && \
       /opt/conda/bin/conda clean -afy
   
   # Copy and install environment
   COPY environment.yml /tmp/environment.yml
   RUN /opt/conda/bin/mamba env create -f /tmp/environment.yml && \
       /opt/conda/bin/mamba clean -afy && \
       rm /tmp/environment.yml
   
   ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
   ENV CONDA_DEFAULT_ENV=quantecon
   
   WORKDIR /workspace
   ```

4. **Create Dockerfile.gpu (GPU variant)**
   ```dockerfile
   # containers/quantecon/Dockerfile.gpu
   FROM nvidia/cuda:12.2.0-base-ubuntu24.04
   
   # Same as CPU version but with CUDA base
   # Use environment-gpu.yml if GPU packages differ
   ```

5. **Create automated build workflow**
   ```yaml
   # .github/workflows/build-containers.yml
   name: Build QuantEcon Containers
   
   on:
     push:
       branches: [main]
       paths:
         - 'containers/quantecon/**'
     schedule:
       - cron: '0 2 * * 1'  # Weekly Monday 2am
     workflow_dispatch:
   
   jobs:
     build-cpu:
       runs-on: ubuntu-latest
       permissions:
         contents: read
         packages: write
       steps:
         - uses: actions/checkout@v4
         - uses: docker/login-action@v3
           with:
             registry: ghcr.io
             username: ${{ github.actor }}
             password: ${{ secrets.GITHUB_TOKEN }}
         - uses: docker/build-push-action@v5
           with:
             context: containers/quantecon
             file: containers/quantecon/Dockerfile
             push: true
             tags: |
               ghcr.io/quantecon/quantecon:latest
               ghcr.io/quantecon/quantecon:${{ github.sha }}
             cache-from: type=registry,ref=ghcr.io/quantecon/quantecon:latest
             cache-to: type=inline
     
     build-gpu:
       runs-on: ubuntu-latest
       permissions:
         contents: read
         packages: write
       steps:
         - uses: actions/checkout@v4
         - uses: docker/login-action@v3
           with:
             registry: ghcr.io
             username: ${{ github.actor }}
             password: ${{ secrets.GITHUB_TOKEN }}
         - uses: docker/build-push-action@v5
           with:
             context: containers/quantecon
             file: containers/quantecon/Dockerfile.gpu
             push: true
             tags: |
               ghcr.io/quantecon/quantecon:gpu
               ghcr.io/quantecon/quantecon:gpu-${{ github.sha }}
             cache-from: type=registry,ref=ghcr.io/quantecon/quantecon:gpu
             cache-to: type=inline
   ```

6. **Build and push containers manually first time**
   ```bash
   cd containers/quantecon
   docker build -t ghcr.io/quantecon/quantecon:latest .
   docker push ghcr.io/quantecon/quantecon:latest
   ```

7. **Create composite action**
   ```bash
   mkdir -p build-lectures
   ```
   
   Create `build-lectures/action.yml` (see CONTAINER-ARCHITECTURE.md for full spec)

**Deliverables:**
- Container images in GHCR
- Automated build workflow
- Composite action ready

---

### Week 2: Test with One Lecture

**In `test-lecture-python-intro` repo:**

1. **Update workflow**
   ```yaml
   # .github/workflows/ci.yml
   name: Build Lectures
   on: [pull_request, push]
   
   jobs:
     build:
       runs-on: ubuntu-latest
       container:
         image: ghcr.io/quantecon/quantecon:latest
         credentials:
           username: ${{ github.actor }}
           password: ${{ secrets.GITHUB_TOKEN }}
       
       steps:
         - uses: actions/checkout@v4
         - uses: quantecon/actions/build-lectures@main
   ```

2. **Test scenarios**
   - Cold cache (first build)
   - Warm cache (rebuild without changes)
   - Incremental (change one lecture)
   - Measure all timings

3. **Validate**
   - Build output matches current approach
   - All notebooks execute correctly
   - Artifacts are correct
   - Cache works as expected

**Success criteria:**
- Setup < 1 min
- Total time < 10 min (cold), < 5 min (warm)
- Identical output to current builds

---

### Week 3: Documentation

**Create/update documentation:**

1. **CONTAINER-SETUP-GUIDE.md**
   - How to use the container in lecture repos
   - Configuration options
   - Troubleshooting

2. **Update MIGRATION-GUIDE.md**
   - Step-by-step migration from current approach
   - Before/after workflow comparison
   - What to expect

3. **Update README.md**
   - New performance metrics
   - Container approach overview

4. **Update CHANGELOG.md**
   - New container images
   - New build-lectures action
   - Deprecation notice for old actions

---

### Week 4-5: Rollout

**Migrate lecture repos one by one:**

For each repo (5 minutes per repo):
1. Update workflow file (3-line change)
2. Create PR
3. Test build
4. Merge
5. Monitor

**Migration order:**
1. test-lecture-python-intro (already tested)
2. lecture-python-intro
3. lecture-python-programming
4. lecture-python.myst
5. lecture-python-advanced.myst
6. lecture-datascience.myst
7. lecture-jax
8. Other repos

**Workflow change:**
```yaml
# Before
- uses: quantecon/actions/setup-lecture-env-full@main
  with:
    environment-file: 'environment.yml'
- run: jupyter-book build lectures/

# After
jobs:
  build:
    container: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/build-lectures@main
```

---

## File Structure (Final)

```
quantecon/actions/
├── containers/
│   └── quantecon/
│       ├── Dockerfile              # CPU version
│       ├── Dockerfile.gpu          # GPU version
│       ├── environment.yml         # Centralized environment
│       └── environment-gpu.yml     # GPU-specific packages (if needed)
├── build-lectures/
│   └── action.yml                  # Composite action
├── .github/workflows/
│   └── build-containers.yml        # Weekly container builds
└── docs/
    ├── CONTAINER-ARCHITECTURE.md   # Design document (this file)
    ├── CONTAINER-SETUP-GUIDE.md    # User guide
    ├── MIGRATION-GUIDE.md          # Migration instructions
    └── UV-VS-CONDA-ANALYSIS.md     # Why containers over UV

lecture-python-intro/  (example)
├── .github/workflows/
│   └── ci.yml                      # Simple workflow using container
└── lectures/                       # No environment.yml needed!
```

---

## Performance Targets

### Current State (Conda + LaTeX)
```
Setup:  7-8 min (cached) / 12 min (fresh)
Build:  8-10 min
Total:  15-18 min
```

### With Containers
```
Cold cache (first build):
  Setup:  10-20 sec (pull container)
  Build:  8-10 min (execute notebooks)
  Total:  9-11 min
  Savings: ~5-7 min (35-40%)

Warm cache (content changed):
  Setup:  5 sec (Docker cached)
  Cache:  10-20 sec (restore)
  Build:  2-4 min (incremental)
  Total:  3-5 min
  Savings: ~10-13 min (65-70%)

Perfect cache (no changes):
  Setup:  5 sec
  Cache:  10-20 sec
  Build:  10 sec (skip execution)
  Total:  30-40 sec
  Savings: ~14-17 min (95%)
```

---

## Key Benefits

1. **Speed**: ~40% faster on average, up to 95% with perfect cache
2. **Simplicity**: 2-line workflow, zero configuration
3. **Consistency**: All lectures use identical environment
4. **Maintainability**: Centralized updates, minimal per-repo changes
5. **LaTeX solved**: Pre-installed, no more 2-3 min wait
6. **GPU support**: Simple `:gpu` tag when needed
7. **Caching**: Two-layer (environment + build), fully automatic

---

## Optional Enhancements (Future)

1. **UV inside container**: Use UV to speed up environment creation during image build
2. **Multiple base images**: Separate images for Python vs Julia lectures
3. **Scheduled pre-builds**: Pre-build images nightly for even faster pulls
4. **Local development**: `.devcontainer` support for VSCode
5. **Image versioning**: Tagged releases (v1.0, v1.1) alongside :latest

---

## Questions Resolved

✅ **UV vs Containers?** → Containers (only way to cache LaTeX)  
✅ **Per-lecture vs global?** → Global (simpler, acceptable trade-off)  
✅ **Who manages cache?** → Composite action (single point of control)  
✅ **User installation?** → Keep Anaconda (containers only for CI)  
✅ **GPU support?** → Separate `:gpu` image variant  
✅ **Configuration?** → Through action inputs, not workflow changes  

---

## Next Actions (Tomorrow)

1. Review this plan
2. Collect all current lecture requirements for environment.yml
3. Start Week 1: Create container infrastructure
4. Build and test first container image
5. Create composite action

**Estimated timeline:** 4-5 weeks from start to full rollout

**Risk:** Low - can rollback to current approach if issues found

**Decision:** Proceed with implementation ✅
