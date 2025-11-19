# Container Architecture for QuantEcon Lectures

**Date**: 2025-11-19  
**Status**: Technical Exploration  
**Goal**: Fast preview builds with pre-configured environments

---

## Executive Summary

Moving to a container-based architecture can reduce setup time from ~7-8 minutes to **under 1 minute**, providing a much better developer experience for preview builds.

**Key Benefits:**
- ⚡ Setup time: ~30-60 seconds (vs 7-8 minutes currently)
- 🔒 Reproducible environments (exact versions locked)
- 🐛 Easier debugging (test locally with same environment)
- 📦 Complete environment pre-built (no installation failures)
- 🚀 Parallel builds across repos with shared base images

---

## Current State Analysis

### Current Composite Action Approach

```yaml
# Current setup time breakdown
Conda environment restore: ~30-60 sec (cached) or ~5-6 min (fresh)
LaTeX installation:        ~2-3 min (always fresh, no cache)
Environment activation:    ~5-10 sec
Total:                     ~7-8 min (best case with cache)
```

**Limitations:**
- ❌ LaTeX cannot be cached (permission issues)
- ❌ System packages reinstalled every run
- ❌ Cache invalidation on any `environment.yml` change
- ❌ No local reproducibility (can't test exact CI environment)
- ⚠️ Dependent on external package repositories (conda-forge, Ubuntu mirrors)

---

## Container Architecture Options

### Option 1: Single Monolithic Image (Simplest)

**Concept:** One Docker image with everything pre-installed.

```dockerfile
# Dockerfile
FROM ubuntu:24.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    texlive-latex-recommended \
    texlive-fonts-recommended \
    texlive-latex-extra \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda \
    && rm Miniconda3-latest-Linux-x86_64.sh

# Copy and install conda environment
COPY environment.yml /tmp/
RUN /opt/conda/bin/conda env create -f /tmp/environment.yml \
    && /opt/conda/bin/conda clean -afy

ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
WORKDIR /workspace
```

**Pros:**
- ✅ Simplest to implement and maintain
- ✅ Single image to manage
- ✅ Fast pull (once cached)

**Cons:**
- ❌ Large image size (~3-4 GB)
- ❌ Rebuild everything on any change
- ❌ Slow initial build (~15-20 min)
- ❌ Different repos need different images

**Best for:** Single repository or very similar environments

---

### Option 2: Multi-Stage Build (Optimized)

**Concept:** Layer the build to optimize caching and size.

```dockerfile
# Stage 1: Base with system packages
FROM ubuntu:24.04 AS base
RUN apt-get update && apt-get install -y \
    wget curl git \
    texlive-latex-recommended \
    texlive-fonts-recommended \
    texlive-latex-extra \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Add Conda
FROM base AS conda-base
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda \
    && rm Miniconda3-latest-Linux-x86_64.sh
ENV PATH=/opt/conda/bin:$PATH

# Stage 3: Environment-specific
FROM conda-base AS lecture-env
COPY environment.yml /tmp/
RUN conda env create -f /tmp/environment.yml \
    && conda clean -afy
ENV PATH=/opt/conda/envs/quantecon/bin:$PATH

# Stage 4: Runtime (minimal)
FROM base
COPY --from=lecture-env /opt/conda /opt/conda
ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
WORKDIR /workspace
```

**Pros:**
- ✅ Better layer caching (only rebuild changed layers)
- ✅ Smaller final image (no build tools)
- ✅ Faster rebuilds on environment changes

**Cons:**
- ❌ More complex Dockerfile
- ❌ Still needs full rebuild for base changes
- ❌ Intermediate images consume space

**Best for:** Production use with optimization needs

---

### Option 3: Hierarchical Images (Recommended)

**Concept:** Base image + lecture-specific images.

```
quantecon/lecture-base:latest          (~2 GB)
├── System packages (LaTeX, Git, etc.)
├── Miniconda installation
└── Common dependencies

quantecon/lecture-python:latest        (~500 MB delta)
├── FROM quantecon/lecture-base
└── lecture-python.myst environment.yml

quantecon/lecture-python-intro:latest  (~200 MB delta)
├── FROM quantecon/lecture-base
└── lecture-python-intro environment.yml
```

**Implementation:**

```dockerfile
# base/Dockerfile
FROM ubuntu:24.04
LABEL org.opencontainers.image.source=https://github.com/quantecon/actions

# System dependencies
RUN apt-get update && apt-get install -y \
    git curl wget \
    texlive-latex-recommended=2023.20240207-1 \
    texlive-latex-extra=2023.20240207-1 \
    texlive-fonts-recommended=2023.20240207-1 \
    texlive-fonts-extra=2023.20240207-1 \
    texlive-xetex=2023.20240207-1 \
    latexmk xindy dvipng ghostscript cm-super \
    && rm -rf /var/lib/apt/lists/*

# Miniconda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda \
    && rm Miniconda3-latest-Linux-x86_64.sh \
    && /opt/conda/bin/conda install -n base -c conda-forge mamba \
    && /opt/conda/bin/conda clean -afy

ENV PATH=/opt/conda/bin:$PATH
WORKDIR /workspace
```

```dockerfile
# lecture-python-intro/Dockerfile
FROM ghcr.io/quantecon/lecture-base:latest

COPY environment.yml /tmp/
RUN mamba env create -f /tmp/environment.yml \
    && mamba clean -afy \
    && rm /tmp/environment.yml

ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
ENV CONDA_DEFAULT_ENV=quantecon
```

**Pros:**
- ✅ Shared base layer (pull once, use everywhere)
- ✅ Small incremental images
- ✅ Fast rebuilds (only changed lectures)
- ✅ Easy to add new lecture series
- ✅ Consistent base across all repos

**Cons:**
- ❌ More images to manage
- ❌ Need to rebuild children when base updates
- ❌ Coordination between base and lecture images

**Best for:** Multiple lecture repositories (our use case)

---

## Technology Stack Comparison

### Container Runtimes

#### 1. Docker (Standard)
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/lecture-python-intro:latest
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - uses: actions/checkout@v4
      - run: jupyter-book build lectures/
```

**Pros:**
- ✅ Native GitHub Actions support
- ✅ Excellent caching (Docker layer cache)
- ✅ Industry standard, great tooling
- ✅ Easy local testing

**Cons:**
- ❌ Requires Docker daemon (not available in some environments)
- ❌ Images can be large

**Verdict:** Best choice for GitHub Actions

---

#### 2. Podman (Daemonless)
```yaml
steps:
  - name: Setup Podman
    run: |
      sudo apt-get update
      sudo apt-get install -y podman
  - name: Run build
    run: podman run --rm -v $PWD:/workspace ghcr.io/quantecon/lecture-python-intro
```

**Pros:**
- ✅ Daemonless (better security)
- ✅ Docker-compatible
- ✅ Rootless containers

**Cons:**
- ❌ Not pre-installed in GitHub Actions
- ❌ Extra setup time
- ❌ Less mature ecosystem

**Verdict:** Overkill for CI/CD use case

---

#### 3. apptainer/Singularity (HPC-focused)
**Pros:**
- ✅ Great for HPC environments
- ✅ Single-file images

**Cons:**
- ❌ Not standard in web development
- ❌ Not ideal for GitHub Actions

**Verdict:** Not suitable for our use case

---

### Container Registries

#### 1. GitHub Container Registry (GHCR) - Recommended
```bash
# Login
echo $GITHUB_TOKEN | docker login ghcr.io -u $USERNAME --password-stdin

# Build and push
docker build -t ghcr.io/quantecon/lecture-base:latest .
docker push ghcr.io/quantecon/lecture-base:latest
```

**Pros:**
- ✅ Free for public repositories
- ✅ Integrated with GitHub (same authentication)
- ✅ Automatic cleanup policies
- ✅ Good documentation and UI
- ✅ Unlimited bandwidth

**Cons:**
- ❌ Storage limits (500MB packages free tier, but images don't count against this)
- ❌ Tied to GitHub ecosystem

**Pricing:** Free for public repos, no bandwidth charges

**Verdict:** Perfect fit for QuantEcon

---

#### 2. Docker Hub
**Pros:**
- ✅ Most popular registry
- ✅ Good free tier (1 private repo)

**Cons:**
- ❌ Rate limits (100 pulls/6hrs unauthenticated, 200/6hrs free account)
- ❌ Requires separate authentication
- ❌ Pull limits can block CI

**Verdict:** Avoid due to rate limits

---

#### 3. AWS ECR / Google GCR / Azure ACR
**Pros:**
- ✅ Enterprise-grade
- ✅ Unlimited storage (pay-as-you-go)

**Cons:**
- ❌ Costs money
- ❌ Complex setup
- ❌ Overkill for open source

**Verdict:** Not needed

---

## Implementation Strategies

### Strategy A: GitHub Actions as Build Service

**Concept:** Use GitHub Actions to build and push images automatically.

```yaml
# .github/workflows/build-images.yml in quantecon/actions repo
name: Build Container Images

on:
  push:
    branches: [main]
    paths:
      - 'containers/**'
  schedule:
    - cron: '0 0 * * 0'  # Weekly rebuilds
  workflow_dispatch:

jobs:
  build-base:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build and push base image
        uses: docker/build-push-action@v5
        with:
          context: containers/base
          push: true
          tags: |
            ghcr.io/quantecon/lecture-base:latest
            ghcr.io/quantecon/lecture-base:${{ github.sha }}
          cache-from: type=registry,ref=ghcr.io/quantecon/lecture-base:latest
          cache-to: type=inline

  build-lecture-images:
    needs: build-base
    runs-on: ubuntu-latest
    strategy:
      matrix:
        lecture: [python-intro, python-programming, python, python-advanced]
    steps:
      - uses: actions/checkout@v4
      - name: Build lecture image
        uses: docker/build-push-action@v5
        with:
          context: containers/${{ matrix.lecture }}
          push: true
          tags: ghcr.io/quantecon/lecture-${{ matrix.lecture }}:latest
```

**Pros:**
- ✅ Automated builds on changes
- ✅ Free GitHub Actions minutes for public repos
- ✅ Version tracking via git
- ✅ CI/CD integration

**Cons:**
- ❌ Build time counts against Actions minutes (unlimited for public repos, but still takes time)
- ❌ Complex workflows

**Verdict:** Good for automatic updates

---

### Strategy B: Manual Local Builds

```bash
# Build and push manually
cd containers/base
docker build -t ghcr.io/quantecon/lecture-base:latest .
docker push ghcr.io/quantecon/lecture-base:latest

cd ../lecture-python-intro
docker build -t ghcr.io/quantecon/lecture-python-intro:latest .
docker push ghcr.io/quantecon/lecture-python-intro:latest
```

**Pros:**
- ✅ Simple and direct
- ✅ No CI/CD complexity
- ✅ Full control

**Cons:**
- ❌ Manual process
- ❌ Can forget to rebuild
- ❌ No automation

**Verdict:** Good for initial testing

---

### Strategy C: Hybrid Approach (Recommended)

1. **Base image**: Auto-build weekly via GitHub Actions
2. **Lecture images**: Auto-build on `environment.yml` changes
3. **Manual override**: Can trigger builds via `workflow_dispatch`

**Benefits:**
- ✅ Automated but controllable
- ✅ Weekly freshness
- ✅ Fast iteration on environment changes

---

## Performance Comparison

### Current Approach (Composite Actions)
```
┌─────────────────────────────────────────────┐
│ Setup (7-8 min with cache)                  │
├─────────────────────────────────────────────┤
│ - Checkout: 5 sec                           │
│ - Restore Conda cache: 30 sec              │
│ - Setup Miniconda: 30 sec                  │
│ - LaTeX install: 2-3 min                   │
│ - Environment activation: 10 sec            │
└─────────────────────────────────────────────┘
│ Build lectures: 8-10 min                    │
└─────────────────────────────────────────────┘
Total: ~15-18 min per PR
```

### Container Approach
```
┌─────────────────────────────────────────────┐
│ Setup (30-60 sec)                           │
├─────────────────────────────────────────────┤
│ - Checkout: 5 sec                           │
│ - Pull image: 20-40 sec (cached layers)    │
│ - Container start: 5 sec                    │
└─────────────────────────────────────────────┘
│ Build lectures: 8-10 min                    │
└─────────────────────────────────────────────┘
Total: ~9-11 min per PR

Time saved: ~6-7 min per PR (40% faster)
```

### Image Size Estimates
```
Base image (quantecon/lecture-base):
- Ubuntu 24.04: ~80 MB
- LaTeX full:   ~1.5 GB
- Miniconda:    ~400 MB
- Total:        ~2 GB (compressed: ~700 MB)

Lecture image delta (per repo):
- Conda env:    ~300-500 MB
- Total:        ~2.3-2.5 GB (compressed: ~900 MB-1 GB)
```

### Pull Times (First Time)
```
Base image: ~2-3 min (one-time, shared across repos)
Lecture image: ~30-60 sec (incremental)
```

### Pull Times (Cached)
```
Base image: ~5-10 sec (already cached)
Lecture image: ~10-20 sec (layer verification)
```

---

## Migration Path

### Phase 1: Proof of Concept (Week 1)
1. ✅ Create base Dockerfile
2. ✅ Create lecture-python-intro Dockerfile
3. ✅ Build images locally
4. ✅ Test with test-lecture-python-intro repo
5. ✅ Measure performance improvements

**Deliverable:** Working prototype with one repository

---

### Phase 2: Infrastructure Setup (Week 2)
1. ✅ Setup GHCR organization/permissions
2. ✅ Create automated build workflow
3. ✅ Setup image versioning strategy
4. ✅ Document image usage in README
5. ✅ Test image pulls in GitHub Actions

**Deliverable:** Automated image building pipeline

---

### Phase 3: Gradual Migration (Weeks 3-4)
1. ✅ Migrate test-lecture-python-intro (already testing)
2. ✅ Migrate lecture-python-intro
3. ✅ Migrate lecture-python-programming
4. ✅ Migrate lecture-python.myst
5. ✅ Migrate lecture-python-advanced.myst

**Deliverable:** All repos using containers

---

### Phase 4: Optimization (Week 5)
1. ✅ Implement multi-arch builds (amd64, arm64)
2. ✅ Optimize image size (multi-stage builds)
3. ✅ Setup image cleanup policies
4. ✅ Add health checks
5. ✅ Performance monitoring

**Deliverable:** Production-ready container system

---

## Recommended Approach

### **Option: Hierarchical Images + GitHub Actions + GHCR**

**Why this combination:**
1. **Hierarchical images** provide the best balance of size, speed, and maintainability
2. **GitHub Actions** for automated builds integrates perfectly with our workflow
3. **GHCR** is free, fast, and integrated with GitHub

## Lecture-Specific Container Location: Two Options

This is a critical architectural decision with trade-offs.

### Option A: Centralized in actions repo (Simpler)

```
quantecon/actions/
├── containers/
│   ├── base/
│   │   ├── Dockerfile
│   │   └── latex-requirements.txt
│   ├── lecture-python-intro/
│   │   ├── Dockerfile
│   │   └── .dockerignore
│   ├── lecture-python-programming/
│   │   ├── Dockerfile
│   │   └── .dockerignore
│   └── README.md
├── .github/workflows/
│   └── build-containers.yml (builds all images)
```

**How it works:**
```dockerfile
# containers/lecture-python-intro/Dockerfile
FROM ghcr.io/quantecon/lecture-base:latest

# Fetch environment.yml from lecture repo at build time
ADD https://raw.githubusercontent.com/QuantEcon/lecture-python-intro/main/environment.yml /tmp/environment.yml
RUN mamba env create -f /tmp/environment.yml && \
    mamba clean -afy && \
    rm /tmp/environment.yml

ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
```

**Pros:**
- ✅ **Centralized management**: All container configs in one place
- ✅ **Unified versioning**: Tag all images together (v1.0, v1.1)
- ✅ **Atomic updates**: Update base and all lecture images in one PR
- ✅ **Simpler CI**: One workflow builds all images
- ✅ **Consistent tooling**: Same Dockerfile patterns across all lectures
- ✅ **Easier discovery**: See all available images in one repo

**Cons:**
- ❌ **Tight coupling**: Changes require PR to actions repo
- ❌ **Cross-repo coordination**: Lecture repo changes → must update actions repo
- ❌ **Delayed updates**: Can't auto-rebuild when lecture environment.yml changes
- ❌ **Permission model**: Need actions repo write access to update images
- ❌ **Build triggers**: Can't trigger build from lecture repo changes directly

**Best for:** Stable environments that change infrequently

---

### Option B: Decentralized in lecture repos (Flexible) ⭐ **RECOMMENDED**

```
quantecon/actions/
├── containers/
│   └── base/
│       ├── Dockerfile
│       └── latex-requirements.txt
└── .github/workflows/
    └── build-base-image.yml (builds base only)

lecture-python-intro/
├── .devcontainer/
│   └── Dockerfile
├── .github/workflows/
│   ├── build-image.yml (builds lecture image)
│   └── ci.yml (uses the image)
├── environment.yml
└── lectures/
```

**How it works:**
```dockerfile
# lecture-python-intro/.devcontainer/Dockerfile
FROM ghcr.io/quantecon/lecture-base:latest

# Copy local environment.yml
COPY environment.yml /tmp/
RUN mamba env create -f /tmp/environment.yml && \
    mamba clean -afy && \
    rm /tmp/environment.yml

ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
ENV CONDA_DEFAULT_ENV=quantecon
```

```yaml
# lecture-python-intro/.github/workflows/build-image.yml
name: Build Container Image
on:
  push:
    branches: [main]
    paths:
      - 'environment.yml'
      - '.devcontainer/Dockerfile'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: .devcontainer/Dockerfile
          push: true
          tags: |
            ghcr.io/quantecon/lecture-python-intro:latest
            ghcr.io/quantecon/lecture-python-intro:${{ github.sha }}
          cache-from: type=registry,ref=ghcr.io/quantecon/lecture-python-intro:latest
          cache-to: type=inline
```

**Pros:**
- ✅ **Automatic updates**: Environment changes auto-trigger image rebuild
- ✅ **Loose coupling**: Lecture repos independent of actions repo
- ✅ **Fast iteration**: Change environment.yml → new image in minutes
- ✅ **Local development**: Developers can build/test images in their repo
- ✅ **Clear ownership**: Each team owns their image
- ✅ **VSCode integration**: `.devcontainer/` is standard for VSCode dev containers
- ✅ **Parallel development**: Multiple lectures can update independently

**Cons:**
- ❌ **Distributed config**: Dockerfile patterns might diverge across repos
- ❌ **More workflows**: Each repo needs build workflow
- ❌ **Discovery**: Need to check each repo to see what images exist
- ❌ **Initial setup**: Each repo needs Dockerfile + workflow

**Best for:** Active development with frequent environment changes (our case)

---

### Option C: Hybrid Approach (Advanced)

Base image in actions repo + lecture images in lecture repos, with **template generation**.

```
quantecon/actions/
├── containers/
│   ├── base/
│   │   ├── Dockerfile
│   │   └── latex-requirements.txt
│   └── templates/
│       ├── lecture.Dockerfile.template
│       └── build-image.yml.template
├── scripts/
│   └── generate-container-files.sh
└── docs/
    └── CONTAINER-SETUP-GUIDE.md
```

**How it works:**
```bash
# In lecture repo, run once to set up container files
curl -sSL https://raw.githubusercontent.com/QuantEcon/actions/main/scripts/generate-container-files.sh | bash
```

This generates:
- `.devcontainer/Dockerfile` (from template)
- `.github/workflows/build-image.yml` (from template)
- `.dockerignore`

**Pros:**
- ✅ **Consistent patterns**: Generated from templates
- ✅ **Easy setup**: One command to configure
- ✅ **Flexible**: Each repo can customize after generation
- ✅ **Best of both worlds**: Centralized patterns + decentralized images

**Cons:**
- ❌ **Template drift**: Repos might not update templates
- ❌ **Extra complexity**: Need to maintain generation scripts
- ❌ **Initial overhead**: More setup required

**Best for:** Large-scale deployments with many repos

---

## Recommended Architecture: **Option B (Decentralized)**

### Repository Structure
```
quantecon/actions/
├── containers/
│   └── base/
│       ├── Dockerfile
│       ├── .dockerignore
│       └── README.md
├── .github/workflows/
│   └── build-base-image.yml
└── docs/
    ├── CONTAINER-ARCHITECTURE.md
    └── CONTAINER-SETUP-GUIDE.md

lecture-python-intro/  (example lecture repo)
├── .devcontainer/
│   ├── Dockerfile
│   ├── .dockerignore
│   └── devcontainer.json (optional: VSCode dev container config)
├── .github/workflows/
│   ├── build-image.yml
│   └── ci.yml
├── environment.yml
└── lectures/
```

### Rationale for Decentralization

1. **Environment ownership**: Lecture maintainers control their environment
2. **Fast iteration**: Change `environment.yml` → automatic image rebuild → ready in <5 min
3. **Independence**: Actions repo updates don't block lecture development
4. **Local testing**: Developers can `docker build` in their repo
5. **Clear boundaries**: Base image (shared infra) vs lecture image (repo-specific)

### Workflow Integration

```yaml
# lecture-python-intro/.github/workflows/ci.yml
name: Build Lectures
on: [pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/lecture-python-intro:latest
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    steps:
      - uses: actions/checkout@v4
      
      # Environment already set up, just build!
      - name: Build PDF
        run: jupyter-book build lectures/ --builder pdflatex
      
      - name: Build HTML
        run: jupyter-book build lectures/ --builder html
```

**Key insight:** The container image name matches the repo name pattern, making it intuitive and scalable.

---

## Setup Process for New Lecture Repos

### One-time Actions Repo Setup
```bash
# In quantecon/actions repo
cd containers/base
docker build -t ghcr.io/quantecon/lecture-base:latest .
docker push ghcr.io/quantecon/lecture-base:latest
```

### One-time Lecture Repo Setup
```bash
# In lecture-python-intro repo
mkdir -p .devcontainer .github/workflows

# Create .devcontainer/Dockerfile
cat > .devcontainer/Dockerfile << 'EOF'
FROM ghcr.io/quantecon/lecture-base:latest
COPY environment.yml /tmp/
RUN mamba env create -f /tmp/environment.yml && \
    mamba clean -afy && \
    rm /tmp/environment.yml
ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
EOF

# Create build workflow (see template above)
# Commit and push
git add .devcontainer .github/workflows
git commit -m "Add container image build"
git push
```

The workflow automatically builds the image on push.

---

## Comparison Summary

| Aspect | Centralized (A) | Decentralized (B) ⭐ | Hybrid (C) |
|--------|----------------|---------------------|------------|
| Setup complexity | Low | Medium | High |
| Maintenance | Centralized | Distributed | Mixed |
| Update speed | Slow (PR required) | Fast (auto-build) | Fast |
| Coupling | Tight | Loose | Loose |
| Consistency | High | Medium | High |
| Scalability | Medium | High | High |
| Local testing | Harder | Easier | Easier |
| Discovery | Easy | Manual | Manual |
| **Recommended** | Small scale | Active development ✅ | Many repos |

---

## Migration Path Updated

### Phase 1: Proof of Concept (Week 1) - actions repo only
1. ✅ Create base Dockerfile in `quantecon/actions/containers/base/`
2. ✅ Build and push base image to GHCR
3. ✅ Document base image in README
4. ✅ Create setup guide for lecture repos

### Phase 2: First Lecture Repo (Week 2) - test in one repo
5. ✅ Add `.devcontainer/Dockerfile` to lecture-python-intro
6. ✅ Add `build-image.yml` workflow
7. ✅ Update `ci.yml` to use container
8. ✅ Test full workflow
9. ✅ Measure performance improvements

### Phase 3: Documentation & Templates (Week 3)
10. ✅ Create setup script/template (optional)
11. ✅ Write migration guide for other repos
12. ✅ Document debugging process
13. ✅ Create troubleshooting guide

### Phase 4: Rollout (Week 4-5)
14. ✅ Migrate lecture-python-programming
15. ✅ Migrate lecture-python.myst
16. ✅ Migrate lecture-python-advanced.myst
17. ✅ Monitor and optimize

---

**Decision Point:** Proceed with **Option B (Decentralized)** where:
- Base image lives in `quantecon/actions`
- Lecture-specific images live in each lecture repo
- Each repo owns and controls its container build
```

### Workflow Changes
```yaml
# Before (composite actions)
- uses: quantecon/actions/setup-lecture-env-full@main

# After (containers)
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/quantecon/lecture-python-intro:latest
    steps:
      - uses: actions/checkout@v4
      - run: jupyter-book build lectures/
```

**Changes needed in lecture repos:** Minimal - just update workflow files

---

## Cost Analysis

### Current Approach
- GitHub Actions minutes: Free (public repos, unlimited)
- Cache storage: Free (10 GB limit, well under)
- Total: **$0/month**

### Container Approach
- GitHub Actions minutes: Free (public repos, unlimited)
- GHCR storage: Free (public images, unlimited)
- GHCR bandwidth: Free (unlimited)
- Total: **$0/month**

**Financial impact: None** ✅

---

## Risk Assessment

### Technical Risks

**High Risk:**
- ⚠️ **Image size**: Images could exceed practical limits (>5 GB)
  - *Mitigation*: Use multi-stage builds, cleanup layers, monitor size
  
**Medium Risk:**
- ⚠️ **Build time**: Initial image builds take 15-20 minutes
  - *Mitigation*: Use layer caching, build on schedule not every change
  
- ⚠️ **Maintenance overhead**: More images to keep updated
  - *Mitigation*: Automated weekly rebuilds, clear versioning strategy

**Low Risk:**
- ⚠️ **GitHub Actions compatibility**: Container jobs might have quirks
  - *Mitigation*: Well-documented feature, many users
  
- ⚠️ **Pull rate limits**: GHCR could introduce limits
  - *Mitigation*: Authenticated pulls (no limits), can switch registries

### Operational Risks

**High Risk:**
- ⚠️ **Breaking changes**: Image updates could break builds
  - *Mitigation*: Version tags (`:latest`, `:v1.0`, `:2025-11-19`), test before rollout

**Medium Risk:**
- ⚠️ **Debugging complexity**: Container issues harder to debug
  - *Mitigation*: Good logging, ability to run locally, fallback to composite actions

**Low Risk:**
- ⚠️ **Team knowledge**: Need Docker expertise
  - *Mitigation*: Comprehensive documentation, standard practices

---

## Success Metrics

### Performance Goals
- ✅ Setup time: <1 minute (vs 7-8 min currently)
- ✅ Total PR time: <11 minutes (vs 15-18 min currently)
- ✅ Cache hit rate: >90%

### Operational Goals
- ✅ Image build time: <20 minutes
- ✅ Image size: <3 GB (compressed <1 GB)
- ✅ Weekly automated rebuilds: 100% success rate
- ✅ Zero-downtime updates

### Quality Goals
- ✅ Build reproducibility: 100% (same env every time)
- ✅ Local testing: Easy `docker run` for developers
- ✅ Debugging: Clear error messages, accessible logs

---

## Next Steps

### Immediate Actions (This Week)
1. [ ] Review and approve this architecture document
2. [ ] Create `containers/` directory structure
3. [ ] Write base Dockerfile
4. [ ] Build and test base image locally
5. [ ] Create lecture-python-intro Dockerfile

### Short-term (Next 2 Weeks)
6. [ ] Setup GHCR repository and permissions
7. [ ] Create GitHub Actions workflow for image builds
8. [ ] Test container workflow in test-lecture-python-intro
9. [ ] Document container usage for developers
10. [ ] Measure and validate performance improvements

### Medium-term (Next Month)
11. [ ] Migrate remaining lecture repositories
12. [ ] Deprecate composite actions (or keep as fallback)
13. [ ] Setup automated image rebuilds
14. [ ] Create versioning and rollback strategy
15. [ ] Monitor and optimize

---

## References

- [GitHub Actions Container Jobs](https://docs.github.com/en/actions/using-jobs/running-jobs-in-a-container)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker Layer Caching](https://docs.docker.com/build/cache/)
- [Best Practices for Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

---

## Appendix: Alternative Approaches Considered

### A. Conda Constructor
Build custom Conda installers with all packages pre-installed.

**Rejected because:**
- Still requires installation time (~2-3 min)
- Doesn't solve LaTeX problem
- Less flexible than containers

### B. GitHub Actions Self-Hosted Runners
Run our own runners with pre-installed environments.

**Rejected because:**
- Infrastructure costs (servers, maintenance)
- Security concerns (running untrusted PR code)
- Overkill for our needs

### C. Cloud Build Services (AWS CodeBuild, etc.)
Use cloud CI/CD services instead of GitHub Actions.

**Rejected because:**
- Costs money
- Requires migration from GitHub Actions
- Not integrated with GitHub PRs

---

**Decision Required:** Approve proceeding with Hierarchical Images + GHCR + GitHub Actions?
