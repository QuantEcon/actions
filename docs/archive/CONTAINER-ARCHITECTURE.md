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

## Simplified Global Container Approach ⭐ **SIMPLEST**

**Goal:** One container for all lectures, centrally managed in actions repo.

### Architecture Overview

**Single Global Container - Maximum Simplicity**

```
quantecon/actions/
├── containers/
│   └── quantecon/
│       ├── Dockerfile              # Single image: LaTeX + Miniconda + all packages
│       ├── environment.yml         # Centralized environment for ALL lectures
│       └── environment-gpu.yml     # Optional: GPU variant
├── .github/workflows/
│   └── build-containers.yml        # Builds quantecon:latest and quantecon:gpu
└── setup-container-env/            # Simple composite action
    └── action.yml

lecture-python-intro/  ← NO Docker files, NO environment.yml!
├── .github/workflows/
│   └── ci.yml                      # Just uses the container
└── lectures/
```

**Key insight:** All lectures share the same environment, so one container works for everyone.

### How It Works

**Option A: Ultra-Simple with Composite Action (Recommended)**

```yaml
# lecture-python-intro/.github/workflows/ci.yml
name: Build Lectures
on: [pull_request]

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
      
      # Action handles caching + building!
      - name: Build Lectures
        uses: quantecon/actions/build-lectures@main
        with:
          lecture-dir: 'lectures'
```

**That's it!** The action handles:
- Restoring build cache
- Building with jupyter-book
- Saving build cache
- Uploading artifacts

---

**Option B: Direct Cache Management (More Control)**

```yaml
# lecture-python-intro/.github/workflows/ci.yml
name: Build Lectures
on: [pull_request]

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
      
      # Manual cache management
      - uses: actions/cache@v4
        with:
          path: lectures/_build
          key: jb-build-${{ runner.os }}-${{ hashFiles('lectures/**/*.md') }}
      
      - run: jupyter-book build lectures/
```

**Recommendation:** Use Option A (composite action) for consistency across all lecture repos.

---

**For GPU-enabled lectures:**
```yaml
    container:
      image: ghcr.io/quantecon/quantecon:gpu  # GPU variant
```

### Performance Breakdown

```
With global container + build caching:

First PR (cold cache):
  - Pull container:        ~10-20 sec (environment ready!)
  - Execute notebooks:     ~8-10 min (can't avoid)
  - Build book:            ~30 sec
  Total:                   ~9-11 min

Subsequent PRs (warm cache):
  - Pull container:        ~10-20 sec
  - Restore build cache:   ~10-20 sec
  - Incremental rebuild:   ~2-4 min (only changed files)
  Total:                   ~3-5 min ✅

vs Current:
  - Setup (Conda+LaTeX):   ~7-8 min
  - Execute notebooks:     ~8-10 min
  - Total:                 ~15-18 min
```

**Savings:** ~10-13 min on PRs with warm cache!

### Container Build (Centralized in actions repo)

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

# Copy centralized environment file
COPY environment.yml /tmp/environment.yml

# Create quantecon environment with ALL packages
RUN /opt/conda/bin/mamba env create -f /tmp/environment.yml && \
    /opt/conda/bin/mamba clean -afy && \
    rm /tmp/environment.yml

# Activate environment by default
ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
ENV CONDA_DEFAULT_ENV=quantecon

WORKDIR /workspace
```

```yaml
# containers/quantecon/environment.yml (centralized for ALL lectures)
name: quantecon
channels:
  - conda-forge
  - defaults
dependencies:
  - python=3.13
  - jupyter-book
  - jupytext
  - matplotlib
  - numpy
  - pandas
  - quantecon
  - scipy
  # ... all packages needed by ANY lecture
```

---

### Composite Action: Single Point of Control

**Design principle:** The action encapsulates ALL lecture build concerns - caching, building, artifacts, configuration.

```yaml
# build-lectures/action.yml
name: 'Build Lectures'
description: 'Complete lecture build pipeline with caching and artifact management'

inputs:
  # Build configuration
  lecture-dir:
    description: 'Directory containing lectures'
    required: false
    default: 'lectures'
  
  builder:
    description: 'Jupyter Book builder (html, pdflatex, dirhtml, etc.)'
    required: false
    default: 'html'
  
  config-file:
    description: 'Path to _config.yml (relative to lecture-dir)'
    required: false
    default: '_config.yml'
  
  toc-file:
    description: 'Path to _toc.yml (relative to lecture-dir)'
    required: false
    default: '_toc.yml'
  
  # Cache configuration
  enable-cache:
    description: 'Enable build caching (recommended: true)'
    required: false
    default: 'true'
  
  cache-key-prefix:
    description: 'Prefix for cache key'
    required: false
    default: 'jb-build'
  
  cache-paths:
    description: 'Additional paths to cache (comma-separated)'
    required: false
    default: ''
  
  # Artifact configuration
  upload-artifact:
    description: 'Upload build as artifact'
    required: false
    default: 'true'
  
  artifact-name:
    description: 'Name for uploaded artifact'
    required: false
    default: 'lectures-html'
  
  artifact-retention-days:
    description: 'Days to retain artifact'
    required: false
    default: '7'
  
  # Build options
  extra-args:
    description: 'Extra arguments to pass to jupyter-book build'
    required: false
    default: ''
  
  fail-on-warnings:
    description: 'Fail build if warnings occur'
    required: false
    default: 'false'

outputs:
  cache-hit:
    description: 'Whether build cache was restored'
    value: ${{ steps.cache.outputs.cache-hit }}
  
  build-path:
    description: 'Path to built output'
    value: ${{ steps.build.outputs.build-path }}

runs:
  using: "composite"
  steps:
    # Cache restoration
    - name: Restore Jupyter Book cache
      id: cache
      if: inputs.enable-cache == 'true'
      uses: actions/cache@v4
      with:
        path: |
          ${{ inputs.lecture-dir }}/_build
          ${{ inputs.cache-paths }}
        key: ${{ inputs.cache-key-prefix }}-${{ runner.os }}-${{ inputs.builder }}-${{ hashFiles(format('{0}/**/*.md', inputs.lecture-dir), format('{0}/**/*.py', inputs.lecture-dir), format('{0}/**/*.ipynb', inputs.lecture-dir), format('{0}/_config.yml', inputs.lecture-dir), format('{0}/_toc.yml', inputs.lecture-dir)) }}
        restore-keys: |
          ${{ inputs.cache-key-prefix }}-${{ runner.os }}-${{ inputs.builder }}-
          ${{ inputs.cache-key-prefix }}-${{ runner.os }}-
    
    # Build
    - name: Build lectures with Jupyter Book
      id: build
      shell: bash
      run: |
        set -e
        cd ${{ inputs.lecture-dir }}
        
        echo "::group::Jupyter Book Build"
        
        # Build command
        BUILD_CMD="jupyter-book build . --builder ${{ inputs.builder }}"
        
        # Add extra args if provided
        if [ -n "${{ inputs.extra-args }}" ]; then
          BUILD_CMD="$BUILD_CMD ${{ inputs.extra-args }}"
        fi
        
        # Add fail-on-warnings if enabled
        if [ "${{ inputs.fail-on-warnings }}" = "true" ]; then
          BUILD_CMD="$BUILD_CMD --warningiserror"
        fi
        
        # Execute build
        echo "Running: $BUILD_CMD"
        eval $BUILD_CMD
        
        echo "::endgroup::"
        
        # Output build path
        BUILD_PATH="${{ inputs.lecture-dir }}/_build/${{ inputs.builder }}"
        echo "build-path=$BUILD_PATH" >> $GITHUB_OUTPUT
        echo "✅ Build complete: $BUILD_PATH"
    
    # Artifact upload
    - name: Upload build artifact
      if: inputs.upload-artifact == 'true'
      uses: actions/upload-artifact@v4
      with:
        name: ${{ inputs.artifact-name }}
        path: ${{ steps.build.outputs.build-path }}
        retention-days: ${{ inputs.artifact-retention-days }}
        if-no-files-found: error
```

**Key design principles:**
1. **Sensible defaults**: Works with zero configuration
2. **Comprehensive options**: Every common customization is an input
3. **Single responsibility**: Action owns the entire build pipeline
4. **Hidden complexity**: Cache keys, paths, logic all internal
5. **Extensible**: Can add new features without changing workflows

**Usage examples:**

```yaml
# Minimal (uses all defaults)
- uses: quantecon/actions/build-lectures@main

# Custom directory and builder
- uses: quantecon/actions/build-lectures@main
  with:
    lecture-dir: 'source'
    builder: 'pdflatex'

# Disable caching (for debugging)
- uses: quantecon/actions/build-lectures@main
  with:
    enable-cache: 'false'

# Custom artifact name and retention
- uses: quantecon/actions/build-lectures@main
  with:
    artifact-name: 'lecture-python-intro-html'
    artifact-retention-days: '30'

# Strict mode (fail on warnings)
- uses: quantecon/actions/build-lectures@main
  with:
    fail-on-warnings: 'true'
```

**Benefits:**
- ✅ **Zero-config by default**: Just `uses: quantecon/actions/build-lectures@main`
- ✅ **Centralized control**: All logic in one place
- ✅ **Easy updates**: Change action, all repos benefit
- ✅ **Flexible**: Options cover all use cases
- ✅ **Maintainable**: Lecture repos stay simple

---

### Automated Build Workflow

```yaml
# .github/workflows/build-containers.yml
name: Build QuantEcon Containers

on:
  push:
    branches: [main]
    paths:
      - 'containers/quantecon/**'
  schedule:
    - cron: '0 2 * * 1'  # Weekly rebuild on Monday
  workflow_dispatch:

jobs:
  build-cpu:
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
      
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build and push GPU variant
        uses: docker/build-push-action@v5
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

### GPU Support

```dockerfile
# containers/quantecon/Dockerfile.gpu
FROM nvidia/cuda:12.2.0-base-ubuntu24.04

# Install LaTeX (same as CPU version)
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

# Copy GPU environment file
COPY environment-gpu.yml /tmp/environment.yml

# Create environment with GPU packages (PyTorch, JAX, etc.)
RUN /opt/conda/bin/mamba env create -f /tmp/environment.yml && \
    /opt/conda/bin/mamba clean -afy && \
    rm /tmp/environment.yml

ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
ENV CONDA_DEFAULT_ENV=quantecon

WORKDIR /workspace
```

### Pros & Cons

**Pros:**
- ✅ **Maximum simplicity**: Lecture repos just use pre-built container
- ✅ **No Docker knowledge**: Zero Docker expertise required
- ✅ **No custom action needed**: Direct container usage in workflow
- ✅ **Instant startup**: Image always pre-built, <1 min setup
- ✅ **Centralized control**: One environment.yml for all lectures
- ✅ **Consistent everywhere**: All lectures use identical environment
- ✅ **Easy updates**: Update environment.yml → auto-rebuilds for all
- ✅ **GPU support**: Simple `:gpu` variant when needed
- ✅ **Minimal workflow**: Same 3 lines for every lecture repo

**Cons:**
- ⚠️ **Monolithic environment**: All lectures share same packages
  - Impact: Environment has union of all package requirements
  - Mitigation: Not a problem - disk is cheap, consistency is valuable
  
- ⚠️ **Less isolation**: Can't test lecture with minimal dependencies
  - Impact: Can't verify each lecture's exact requirements
  - Mitigation: Our lectures share Python scientific stack anyway
  
- ⚠️ **Central updates required**: Adding package needs PR to actions repo
  - Impact: Can't add package directly in lecture repo
  - Mitigation: Centralized testing prevents conflicts, PRs are fast

**Verdict:** Massive simplicity gain, cons are minor and acceptable

---

## Two-Layer Caching Strategy

The global container solves environment setup, but lecture builds still take time because notebooks must execute. We need **two layers of caching**:

### Layer 1: Environment Cache (Container)

**What it caches:**
- Python environment (~500 MB)
- LaTeX installation (~1.5 GB)
- System tools and dependencies

**How it works:**
- Pre-built container image in GHCR
- Pulled once, cached by Docker on runner
- ~10-20 seconds to pull on first use
- Instant on subsequent jobs (Docker cache)

**Managed by:** QuantEcon actions repo (centralized)

---

### Layer 2: Build Cache (Per-Repo)

**What it caches:**
- `lectures/_build/` directory
- Executed notebook outputs
- Built HTML/PDF files
- Jupyter Book cache

**How it works:**
- GitHub Actions cache per repository
- Key: hash of lecture source files
- Restores previous build, only rebuilds changed files
- ~10-20 seconds to restore

**Managed by:** Each lecture repo workflow

---

### Complete Caching Workflow

```yaml
# lecture-python-intro/.github/workflows/ci.yml
name: Build Lectures
on: [pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    
    # Layer 1: Environment cache (container)
    container:
      image: ghcr.io/quantecon/quantecon:latest
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    steps:
      - uses: actions/checkout@v4
      
      # Layer 2: Build cache (per-repo)
      - name: Cache Jupyter Book Build
        uses: actions/cache@v4
        with:
          path: lectures/_build
          key: jb-build-${{ runner.os }}-${{ hashFiles('lectures/**/*.md', 'lectures/**/*.py', 'lectures/**/*.ipynb') }}
          restore-keys: |
            jb-build-${{ runner.os }}-
      
      - name: Build Lectures
        run: |
          cd lectures
          jupyter-book build .
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: lectures-html
          path: lectures/_build/html
```

---

### Cache Performance Analysis

**Cold cache (first build or environment changed):**
```
Pull container:           ~10-20 sec  (Layer 1)
No build cache:           N/A
Execute all notebooks:    ~8-10 min   (unavoidable)
Build book:               ~30 sec
Total:                    ~9-11 min
```

**Warm cache (only lecture content changed):**
```
Pull container (cached):  ~5 sec      (Layer 1: Docker cache hit)
Restore build cache:      ~10-20 sec  (Layer 2)
Execute changed only:     ~2-4 min    (incremental)
Build book:               ~30 sec
Total:                    ~3-5 min ✅
```

**Warm cache (no changes, cache hit):**
```
Pull container (cached):  ~5 sec
Restore build cache:      ~10-20 sec
No execution needed:      ~0 sec      (Jupyter Book skips)
Build book:               ~10 sec     (fast relink)
Total:                    ~30-40 sec ✅✅
```

---

### Cache Key Strategy

**For Jupyter Book builds:**
```yaml
key: jb-build-${{ runner.os }}-${{ hashFiles('lectures/**/*.md', 'lectures/**/*.py', 'lectures/**/*.ipynb') }}
```

**Behavior:**
- Hash includes all lecture source files
- Changes to any lecture file → new cache key → rebuild
- Changes to only one file → Jupyter Book rebuilds only that file
- No changes → perfect cache hit → instant build

**Fallback:**
```yaml
restore-keys: |
  jb-build-${{ runner.os }}-
```
- If exact match fails, restore most recent cache
- Jupyter Book determines what needs rebuilding
- Still faster than rebuilding everything

---

### Cache Size Estimates

**Container (Layer 1):**
- Size: ~2 GB uncompressed, ~700 MB compressed
- Stored: GHCR (free, unlimited)
- Shared: Across all lecture repos

**Build cache (Layer 2):**
- Size: ~100-500 MB per lecture repo
- Stored: GitHub Actions cache (10 GB limit per repo)
- Individual: Each lecture repo has its own

**Total cache usage:**
- Actions repo: ~700 MB (container)
- Per lecture repo: ~100-500 MB (builds)
- Well within free tier limits

---

### Alternative: Pre-Built Images (Optional Enhancement)

For even faster CI, the action could be enhanced with scheduled pre-builds:

```yaml
# quantecon/actions/.github/workflows/prebuild-lecture-images.yml
name: Pre-build Lecture Images
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday at 2 AM
  workflow_dispatch:

jobs:
  prebuild:
    strategy:
      matrix:
        lecture:
          - python-intro
          - python-programming
          - python-advanced
    runs-on: ubuntu-latest
    steps:
      - name: Fetch environment.yml
        run: |
          curl -o environment.yml \
            https://raw.githubusercontent.com/QuantEcon/lecture-${{ matrix.lecture }}/main/environment.yml
      
      - name: Build and push
        uses: quantecon/actions/setup-container-env@main
        with:
          environment-file: 'environment.yml'
          image-name: 'lecture-${{ matrix.lecture }}'
          force-rebuild: 'true'
```

**Benefits:**
- Images always fresh and cached
- PR builds use pre-built images (~10-20 sec setup)
- No first-build delay in CI

**Tradeoff:** Weekly scheduled builds vs on-demand builds

---

## Setup Process

### One-Time: Build Base Image

```bash
# In quantecon/actions repo
cd containers/base

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM ubuntu:24.04

# Install LaTeX
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        texlive-full \
        texlive-xetex \
        latexmk && \
    rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniconda3-latest-Linux-x86_64.sh && \
    /opt/conda/bin/conda install -y mamba -c conda-forge && \
    /opt/conda/bin/conda clean -afy

ENV PATH=/opt/conda/bin:$PATH

WORKDIR /workspace
EOF

# Build and push
docker build -t ghcr.io/quantecon/lecture-base:latest .
docker push ghcr.io/quantecon/lecture-base:latest
```

### Per Lecture Repo: Use the Action

**That's it! Just use the action in your workflow:**

```yaml
# lecture-python-intro/.github/workflows/ci.yml
name: Build Lectures
on: [pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Container Environment
        uses: quantecon/actions/setup-container-env@main
        with:
          environment-file: 'environment.yml'
          image-name: 'lecture-python-intro'
      
      - name: Build Lectures
        run: jupyter-book build lectures/
```

**No other setup needed!** The action handles:
- Dockerfile generation
- Image building
- GHCR push
- Caching
- Environment setup

---

## Migration Path

### Phase 1: Build Base Image (Actions Repo)
1. Create `containers/base/Dockerfile`
2. Setup automated builds (GitHub Actions)
3. Push to GHCR

### Phase 2: Implement Composite Action (Actions Repo)
1. Create `setup-container-env/action.yml`
2. Implement hash-based caching logic
3. Add Dockerfile template
4. Test with one lecture repo

### Phase 3: Migrate Lecture Repos (One at a Time)
```diff
# lecture-python-intro/.github/workflows/ci.yml
name: Build Lectures
on: [pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
-     - name: Setup Lecture Environment
-       uses: quantecon/actions/setup-lecture-env-full@main
-       with:
-         environment-file: 'environment.yml'
-         environment-name: 'quantecon'
      
+     - name: Setup Container Environment  
+       uses: quantecon/actions/setup-container-env@main
+       with:
+         environment-file: 'environment.yml'
+         image-name: 'lecture-python-intro'
      
      - name: Build Lectures
        run: jupyter-book build lectures/
```

**Result:** ~7 min faster setup per PR (40% total time savings)

---

## Comparison: Global Container vs Alternatives

| Aspect | Global Container ⭐ | Per-Lecture Containers | Conda (Current) |
|--------|---------------------|----------------------|-----------------|
| **Lecture repo complexity** | Minimal (3 lines) | Medium (Dockerfile) | Medium (env file) |
| **Docker knowledge needed** | None | Required | None |
| **Setup time** | <1 min | <1 min (cached) | 7-8 min |
| **Maintenance** | Single environment.yml | Per-repo Dockerfiles | Per-repo env files |
| **Build caching** | Automatic (via action) | Manual | None |
| **Consistency** | Perfect (same for all) | Medium (can diverge) | Medium (can diverge) |
| **GPU support** | Simple (`:gpu` tag) | Per-repo builds | Manual setup |
| **Adding packages** | PR to actions repo | PR to lecture repo | PR to lecture repo |
| **Isolation** | Shared environment | Per-lecture isolation | Per-lecture isolation |
| **Recommended for** | Our use case ✅ | Complex projects | Legacy approach |

---

## Implementation Roadmap (Simplified Global Container)

### Phase 1: Create Global Container & Action (Week 1)
**Goal:** Build container and composite action

Tasks:
1. Create `containers/quantecon/` directory
2. Create centralized `environment.yml` (union of all lecture requirements)
3. Create `Dockerfile` (Ubuntu + LaTeX + Miniconda + environment)
4. Create `Dockerfile.gpu` (CUDA base + same setup)
5. Create `.github/workflows/build-containers.yml`
6. Create `build-lectures/action.yml` (composite action)
7. Build and push containers to GHCR manually first time

**Deliverables:**
- `ghcr.io/quantecon/quantecon:latest` (CPU version)
- `ghcr.io/quantecon/quantecon:gpu` (GPU version)
- `quantecon/actions/build-lectures@main` (composite action)

---

### Phase 2: Test with One Lecture (Week 2)
**Goal:** Validate with `test-lecture-python-intro`

Tasks:
1. Update workflow to use container directly (no action needed!)
2. Add Jupyter Book build cache (lectures take time to execute)
3. Test cold and warm cache performance
4. Verify output matches current builds
5. Fix any issues discovered

**Success criteria:**
- ✅ Setup completes in <1 min
- ✅ Builds work correctly with cached outputs
- ✅ No breaking changes to output
- ✅ Incremental builds are fast (~3-5 min)

**Complete workflow change:**
```yaml
# Before (7-8 min setup, manual cache management)
steps:
  - uses: quantecon/actions/setup-lecture-env-full@main
    with:
      environment-file: 'environment.yml'
  - run: jupyter-book build lectures/

# After (<1 min setup, automatic caching)
jobs:
  build:
    container: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/build-lectures@main
```

**That's the entire workflow!** The action handles caching automatically.

---

### Phase 3: Documentation (Week 3)
**Goal:** Document new approach

Tasks:
1. Write `CONTAINER-SETUP-GUIDE.md`
2. Update `MIGRATION-GUIDE.md`
3. Document GPU variant usage
4. Document how to add packages (PR to environment.yml)
5. Create troubleshooting guide
6. Update CHANGELOG.md

**Deliverable:** Complete documentation

---

### Phase 4: Rollout to All Lectures (Week 4-5)
**Goal:** Migrate all lecture repos

Tasks per repo (5 minutes each!):
1. Update workflow to use container
2. Remove old `setup-lecture-env-full` usage
3. Test PR build
4. Merge to main

**Order:**
1. lecture-python-intro (already tested)
2. lecture-python-programming
3. lecture-python.myst
4. lecture-python-advanced.myst
5. lecture-datascience.myst
6. lecture-jax
7. Other repos as needed

**Migration is trivial** - just change container line in workflow!

---

## Decision Summary

**Chosen Architecture:** Single Global Container

**Why this is the simplest possible approach:**
- ✅ **One container for everything**: `ghcr.io/quantecon/quantecon:latest`
- ✅ **No custom action needed**: Direct container usage
- ✅ **Centralized environment**: One `environment.yml` in actions repo
- ✅ **Always pre-built**: Weekly automated builds
- ✅ **GPU variant**: Simple `:gpu` tag when needed
- ✅ **3-line workflow change**: Same for all repos

**What lecture repos don't need:**
- ❌ No Dockerfiles
- ❌ No environment.yml (uses centralized one)
- ❌ No image build workflows  
- ❌ No Docker knowledge
- ❌ No custom actions
- ❌ No GHCR credentials

**What lecture repos gain:**
- ✅ **<1 min setup** (vs 7-8 min currently)
- ✅ **45% faster total builds**
- ✅ **LaTeX pre-installed** (the key win!)
- ✅ **Consistent everywhere**
- ✅ **GPU support available**

**Trade-off:**
- Monolithic environment (all packages) vs per-lecture isolation
- **Accepted**: Simplicity > granular control

**Two-layer caching strategy:**
1. **Environment caching**: Container (global, ~2 GB, pre-built)
2. **Build caching**: Handled by composite action (automatic)

---

## The Complete Minimal Workflow

With the global container + composite action, lecture repos are trivial:

### Standard Workflow (Zero Configuration)

```yaml
# lecture-python-intro/.github/workflows/ci.yml
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

**That's it!** Works out of the box with sensible defaults.

---

### What the Action Does (Automatically)

1. **Cache Management**
   - Generates cache key from source files
   - Restores previous build if available
   - Saves build cache for next run

2. **Building**
   - Changes to lecture directory
   - Runs `jupyter-book build`
   - Handles errors and warnings

3. **Artifacts**
   - Uploads build output
   - Sets retention policy
   - Makes available for download

**All configurable through inputs, no workflow changes needed.**

---

### Configuration Through Action Inputs

**Common customizations:**

```yaml
# PDF builds
- uses: quantecon/actions/build-lectures@main
  with:
    builder: 'pdflatex'

# Custom directory structure
- uses: quantecon/actions/build-lectures@main
  with:
    lecture-dir: 'source/lectures'

# Strict mode for production
- uses: quantecon/actions/build-lectures@main
  with:
    fail-on-warnings: 'true'

# Long-term artifact retention
- uses: quantecon/actions/build-lectures@main
  with:
    artifact-retention-days: '90'

# Disable caching (debugging)
- uses: quantecon/actions/build-lectures@main
  with:
    enable-cache: 'false'
```

**All configuration through the action, not the workflow.**

---

### Multi-Builder Workflow (Advanced)

```yaml
# Build both HTML and PDF
jobs:
  build-html:
    runs-on: ubuntu-latest
    container: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/build-lectures@main
        with:
          builder: 'html'
          artifact-name: 'lectures-html'
  
  build-pdf:
    runs-on: ubuntu-latest
    container: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/build-lectures@main
        with:
          builder: 'pdflatex'
          artifact-name: 'lectures-pdf'
```

---

### Maintenance Model

**Centralized in actions repo:**
- ✅ Environment packages (`containers/quantecon/environment.yml`)
- ✅ Build logic (`build-lectures/action.yml`)
- ✅ Cache strategy (internal to action)
- ✅ Default configurations (action defaults)

**Decentralized in lecture repos:**
- ⚙️ Which builder to use (`builder: 'html'`)
- ⚙️ Custom build options (via `extra-args`)
- ⚙️ Artifact settings (optional)

**Update scenarios:**

| Change | Where | Impact |
|--------|-------|--------|
| Add Python package | `environment.yml` in actions | Rebuild container, all repos benefit |
| Improve cache strategy | `build-lectures/action.yml` | All repos benefit automatically |
| Change default builder | `build-lectures/action.yml` | All repos using default affected |
| Lecture-specific option | Lecture repo workflow | Only that lecture affected |

**Philosophy:** Common logic centralized, customization through configuration.

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

### Week 1: Build Base Image
- [ ] Create `containers/base/Dockerfile`
- [ ] Create `.github/workflows/build-base-image.yml`
- [ ] Build and push `ghcr.io/quantecon/lecture-base:latest`
- [ ] Test base image locally

### Week 2: Implement Composite Action
- [ ] Create `setup-container-env/action.yml`
- [ ] Implement hash-based cache key generation
- [ ] Implement dynamic Dockerfile generation
- [ ] Add image existence checking
- [ ] Add comprehensive logging
- [ ] Write action README

### Week 3: Test with One Lecture
- [ ] Update `test-lecture-python-intro` to use action
- [ ] Test with unchanged environment.yml (cache hit)
- [ ] Test with changed environment.yml (rebuild)
- [ ] Measure performance vs current approach
- [ ] Fix any issues discovered

### Week 4: Documentation
- [ ] Create `CONTAINER-SETUP-GUIDE.md`
- [ ] Update `MIGRATION-GUIDE.md` with container option
- [ ] Create troubleshooting guide
- [ ] Document local debugging
- [ ] Update `CHANGELOG.md`

### Week 5-6: Rollout to All Lectures
- [ ] Migrate lecture-python-intro
- [ ] Migrate lecture-python-programming
- [ ] Migrate lecture-python.myst
- [ ] Migrate lecture-python-advanced.myst
- [ ] Monitor performance and fix issues

---

## References

- [GitHub Actions Container Jobs](https://docs.github.com/en/actions/using-jobs/running-jobs-in-a-container)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker Layer Caching](https://docs.docker.com/build/cache/)
- [Best Practices for Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

---

## Appendix: Why Action-Managed?

### Alternative A: Centralized (Dockerfiles in actions repo)
**Rejected because:**
- Tight coupling between repos
- Can't auto-rebuild when lecture environment.yml changes
- Requires PR to actions repo for every environment change
- Slower iteration cycle

### Alternative B: Decentralized (Dockerfiles in lecture repos)
**Rejected because:**
- Requires Docker knowledge from lecture maintainers
- More setup overhead per repo
- Dockerfile patterns might diverge
- Higher maintenance burden

### Alternative C: Conda Constructor
**Rejected because:**
- Still requires 2-3 min installation time
- Doesn't solve LaTeX installation problem
- Less flexible than containers
- Not widely used

### Alternative D: Self-Hosted Runners
**Rejected because:**
- Infrastructure costs and maintenance
- Security concerns with untrusted PR code
- Overkill for our needs
- Complexity doesn't justify benefits

### Alternative E: Cloud CI Services (AWS CodeBuild, etc.)
**Rejected because:**
- Monthly costs
- Requires full migration from GitHub Actions
- Less integrated with GitHub PRs
- Not free like GitHub Actions + GHCR

---

## Decision

**✅ Proceed with Action-Managed Container Approach**

**Why this is the right choice:**
1. **Simplest for users**: Lecture repos only provide `environment.yml`
2. **Zero Docker knowledge**: Maintainers don't need to learn Docker
3. **Automatic caching**: Smart hash-based, no manual management
4. **Centralized control**: All Docker logic in the action
5. **Free**: GitHub Actions + GHCR = $0/month
6. **Secure**: Uses GitHub tokens automatically
7. **Fast**: <1 min setup (cached) vs 7-8 min currently

**Trade-off accepted:** More complex action code in exchange for maximum simplicity in lecture repos.
