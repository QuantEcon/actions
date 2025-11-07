# Next Steps: QuantEcon Actions Cache Optimization

**Date**: 2025-11-07  
**Status**: Testing Phase - Fixes Applied, Awaiting Validation

---

## Current Situation

We've migrated to a unified `setup-lecture-env-full` composite action that combines Conda and LaTeX setup. Two critical bugs were discovered and fixed:

### Fixed Issues ✅
1. **Conda activation bug** (commit db876cc): `setup-miniconda` now always runs to activate environment, even on cache hits
2. **Apt cache permissions** (commit 209387f): Removed apt caching due to root permission restrictions on `/var/cache/apt/archives`

### Current Architecture
- **Conda**: Cached successfully (~5-6 min savings)
- **LaTeX**: Installed fresh each run (~2-3 min unavoidable)
- **Total time**: ~7-8 min with cache hit vs ~12 min fresh

---

## Testing Status

### Completed ✅
- Created unified `setup-lecture-env-full` action
- Deprecated old `setup-lecture-env` and `setup-latex` actions (PR #1 merged)
- Updated `cache.yml` in test repo (PR #6 merged)
- Updated `ci.yml` on PR #4 (ci-migration branch)
- Fixed conda activation bug
- Fixed apt cache permissions issue

### In Progress ⏳
- **PR #4 (ci-migration)**: Needs re-run to validate fixes
- **cache.yml on main**: Needs manual trigger to rebuild global caches with fixed action

### Not Yet Tested ❌
- Complete workflow with both fixes applied
- Global cache inheritance from main → PR branches
- Jupyter cache migration (still using artifacts)
- publish.yml workflow migration

---

## TODO List

### Immediate (Before Next Session)
1. ✅ Fix conda activation bug - **DONE**
2. ✅ Fix apt cache permissions - **DONE**
3. ⏸️ Trigger cache.yml manual run on main - **PENDING**
4. ⏸️ Re-run PR #4 to validate fixes - **PENDING**
5. ⏸️ Verify cache inheritance works (PR → main) - **PENDING**

### Short Term
6. ⏸️ Merge PR #4 (ci-migration) to main once validated
7. ⏸️ Close/archive PR #5 (test-global-cache) - superseded by PR #4
8. ⏸️ Migrate publish.yml workflow to composite actions
9. ⏸️ Convert Jupyter cache from artifacts to cache mechanism
10. ⏸️ Tag v1.0.0 release of composite actions

### Documentation
11. ⏸️ Update main README with final performance numbers
12. ⏸️ Create migration guide for other QuantEcon repos
13. ⏸️ Document cache key strategies and invalidation

---

## Future Architecture: Docker-Based Approach 🐳

### Concept
Instead of caching individual components, use a **custom Docker container** with pre-built environments:

```
quantecon/lecture-builder:latest
├── Conda environment (fully installed)
├── LaTeX packages (system-level)
├── Jupyter Book + dependencies
└── All tools ready to use
```

### Advantages
- ✅ **Complete environment caching**: Everything pre-installed
- ✅ **Sub-1 minute setup**: Just pull the image
- ✅ **No permission issues**: Container has full control
- ✅ **Version locking**: Reproducible environments
- ✅ **Faster CI**: Image pull >> package installation
- ✅ **Cross-platform**: Same environment everywhere

### Architecture
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/lecture-builder:latest
    steps:
      - uses: actions/checkout@v5
      - name: Build Lectures
        run: jupyter-book build lectures/
```

### Implementation Plan

#### Phase 1: Create Base Image
1. Create `Dockerfile` in actions repo
2. Install Conda + Python 3.13
3. Copy `environment.yml` and install packages
4. Install LaTeX system packages
5. Build and push to GitHub Container Registry (GHCR)

#### Phase 2: Workflow Integration
1. Create `setup-docker-env` composite action
2. Pull image from GHCR (cached by Docker layer caching)
3. Update workflows to use container-based jobs
4. Migrate existing cache.yml → image-builder.yml

#### Phase 3: Maintenance Strategy
1. Weekly image rebuilds (schedule)
2. Image versioning: `latest`, `v1.0`, `2025-11-07`
3. Multi-architecture support (amd64, arm64)
4. Separate images for different lecture series if needed

### Docker Image Caching
- **GitHub Actions**: Automatically caches pulled images
- **Layer caching**: Incremental updates only rebuild changed layers
- **Multi-stage builds**: Optimize for size
- **GHCR**: Free for public repos, integrated with GitHub

### Comparison: Current vs Docker

| Aspect | Current (Composite Actions) | Docker Container |
|--------|----------------------------|------------------|
| Setup time (cache hit) | ~7-8 min | ~30-60 sec |
| Setup time (cache miss) | ~12 min | ~2-3 min (pull) |
| Conda caching | ✅ Works | ✅ In image |
| LaTeX caching | ❌ Permission issues | ✅ In image |
| Reproducibility | Good | Excellent |
| Maintenance | Low | Medium |
| Flexibility | High (change env easily) | Medium (rebuild image) |

### Risks & Considerations
- ⚠️ **Image size**: Could be large (~2-3 GB with LaTeX)
- ⚠️ **Build time**: Initial image build takes time
- ⚠️ **Version updates**: Need to rebuild image for package updates
- ⚠️ **Learning curve**: Team needs Docker knowledge
- ⚠️ **Storage**: GHCR has limits (free tier: 500 MB packages, unlimited bandwidth)

### Recommendation
**Start with Docker-based approach for next iteration**. The current composite action approach works but hits fundamental GitHub Actions limitations with system package caching. Docker solves these issues elegantly.

---

## File Locations

### Actions Repository (`quantecon/actions`)
- `setup-lecture-env-full/action.yml` - Unified action (current)
- `build-lectures/action.yml` - Build composite action
- `deploy-netlify/action.yml` - Netlify deployment
- `publish-gh-pages/action.yml` - GitHub Pages publishing

### Test Repository (`test-lecture-python-intro`)
- `.github/workflows/cache.yml` - Global cache builder (main branch)
- `.github/workflows/ci.yml` - PR validation (ci-migration branch)
- `environment.yml` - Conda dependencies
- `latex-requirements.txt` - LaTeX packages

### Branches
- **actions repo**: `main` (latest fixes), `fix-conda-activation` (merged), `fix-apt-cache-permissions` (merged)
- **test repo**: `main`, `ci-migration` (PR #4 - needs testing), `unified-cache-action` (PR #6 - merged)

---

## Key Learnings

### What Worked ✅
1. Conda environment caching (~5-6 min savings)
2. Composite actions architecture (reusable, maintainable)
3. `@main` references auto-update (no version bumps needed)
4. Global cache inheritance (main → PR branches)

### What Didn't Work ❌
1. LaTeX installed file caching (`/usr/share/texlive`) - permission errors
2. Apt package caching (`/var/cache/apt/archives`) - root-owned lock files
3. System directory caching in general - GitHub Actions limitations

### Insights
- **GitHub Actions caching**: Designed for user-space files, not system packages
- **Permission model**: Cache restore runs as non-root, can't write to system paths
- **Tar limitations**: Can't handle permission mismatches during extraction
- **Docker advantage**: Containers have full control over their filesystem

---

## Performance Metrics

### Current Implementation
| Metric | Value |
|--------|-------|
| Fresh install | ~12 min |
| Conda cache hit | ~7-8 min |
| LaTeX install | ~2-3 min (always) |
| **Total savings** | **~5-6 min** |

### Docker Target (Estimated)
| Metric | Value |
|--------|-------|
| Image pull (cached) | ~30-60 sec |
| Image pull (fresh) | ~2-3 min |
| Build execution | ~8-10 min |
| **Total setup** | **<1 min** |
| **Total savings** | **~6-7 min** |

---

## Questions for Next Session

1. Should we proceed with Docker-based architecture?
2. Do we want to maintain the composite action approach as fallback?
3. Should we version the Docker images (v1.0, v1.1) or use date tags?
4. Do we need separate images per lecture series (intro, advanced, etc.)?
5. Should we explore GitHub Actions self-hosted runners as alternative?

---

## References

### GitHub Actions
- Cache documentation: https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows
- Container jobs: https://docs.github.com/en/actions/using-jobs/running-jobs-in-a-container
- GHCR: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry

### Docker
- Multi-stage builds: https://docs.docker.com/build/building/multi-stage/
- Layer caching: https://docs.docker.com/build/cache/
- Best practices: https://docs.docker.com/develop/dev-best-practices/

### Related Issues
- PR #1: Remove old actions (merged)
- PR #4: CI migration (awaiting validation)
- PR #6: Unified cache action (merged)

---

## Session Summary (2025-11-07)

### Accomplishments
1. ✅ Created unified `setup-lecture-env-full` action
2. ✅ Deprecated old separate actions
3. ✅ Fixed conda activation bug
4. ✅ Fixed apt cache permissions issue
5. ✅ Updated documentation

### Blockers Resolved
- Conda environment not activating on cache hit
- Apt cache save failing due to permission errors

### Next Validation
- Run cache.yml on main to rebuild global caches
- Re-run PR #4 to test complete workflow with fixes

**Status**: Ready for validation testing. Docker migration is recommended future direction.
