# Migration Plan

Plan for migrating the 4 QuantEcon lecture repositories to use centralized composite actions.

**Last Updated:** February 2026

---

## Current State

The core infrastructure is complete and validated:

- **Container images** — `quantecon` (full, ~8GB) and `quantecon-build` (lean, ~3GB), validated against all 4 lecture repos
- **Composite actions** — `setup-environment`, `build-lectures`, `build-jupyter-cache`, `restore-jupyter-cache`, `preview-netlify`, `preview-cloudflare`, `publish-gh-pages`
- **Container-aware setup** — Auto-detects QuantEcon containers and RunsOn custom AMIs via `/etc/quantecon-container` marker
- **Two-layer caching** — Container image (Layer 1) + dedicated cache actions for `_build/` directory (Layer 2), including PR-scoped caching
- **Asset assembly** — PDF and notebook staging for HTML download features
- **Execution reports** — Failure artifacts with reports and cache for debugging
- **Multi-format builds** — HTML, pdflatex, and jupyter builders
- **PR previews** — Netlify and Cloudflare Pages with smart PR comments
- **GitHub Pages publishing** — Native OIDC-based deployment

---

## Rollout Strategy

### Phase 1: Production Test with `lecture-dp` (new repo)

Before migrating any existing repositories, we'll validate the full workflow on a **new** lecture series `lecture-dp`. This gives us a fresh canvas — no legacy workflows to work around, no risk to existing production sites, and a clean baseline for performance measurement.

| Step | Task | Status |
|------|------|--------|
| 1 | Create `lecture-dp` repo with standard lecture structure | ⏳ |
| 2 | Set up container-based CI with `setup-environment` + `build-lectures` | ⏳ |
| 3 | Add `build-jupyter-cache` / `restore-jupyter-cache` for caching | ⏳ |
| 4 | Configure PR previews (`preview-netlify` or `preview-cloudflare`) | ⏳ |
| 5 | Configure production deployment (`publish-gh-pages`) | ⏳ |
| 6 | Run in production for a period, measure performance, gather feedback | ⏳ |

### Phase 2: Migrate Existing Repos

Once `lecture-dp` is running smoothly, migrate existing repos — CPU-only first, GPU last:

| # | Repository | Runner | Deployment | Complexity | Status |
|---|-----------|--------|------------|------------|--------|
| 1 | `lecture-python-intro` | Container | Netlify | Standard | ⏳ Planned |
| 2 | `lecture-python-programming.myst` | Container | GitHub Pages | Standard | ⏳ Planned |
| 3 | `lecture-python-advanced.myst` | Container | GitHub Pages | Standard | ⏳ Planned |
| 4 | `lecture-python.myst` | RunsOn GPU | GitHub Pages | GPU + ML libs | ⏳ Planned |

### Per-repo Migration Checklist

- [ ] Create migration branch
- [ ] Replace environment setup with `setup-environment`
- [ ] Replace build steps with `build-lectures`
- [ ] Add `build-jupyter-cache` / `restore-jupyter-cache` for build caching
- [ ] Configure PR preview deployment (`preview-netlify` or `preview-cloudflare`)
- [ ] Configure production deployment (`publish-gh-pages` or Netlify production)
- [ ] Validate build output matches current production
- [ ] Measure performance improvement
- [ ] Merge and monitor

---

## lecture-python.myst Gap Analysis

`lecture-python.myst` is the most complex repo — GPU builds, ML libraries, 3 build formats, release assets, and notebook sync. This section tracks what our actions already support and what needs work before we can migrate it.

### Current Workflows (5)

| Workflow | Trigger | Runner | Purpose |
|----------|---------|--------|---------|
| `cache.yml` | Weekly + manual | RunsOn `g4dn.2xlarge` GPU | Full HTML build, upload `_build` as artifact |
| `ci.yml` | PR + manual | RunsOn `g4dn.2xlarge` GPU | Notebooks + PDF + HTML → Netlify preview |
| `publish.yml` | Tag `publish*` | RunsOn `g4dn.2xlarge` GPU | PDF + notebooks + HTML → GH Pages + release + notebook sync |
| `collab.yml` | Weekly + manual | RunsOn GPU + Colab container | Colab compatibility testing → issue on failure |
| `linkcheck.yml` | Weekly + manual | `ubuntu-latest` | Link checker → issue on failure |

### Key Architecture Patterns

1. **Cache-first** — `cache.yml` runs weekly, uploads `_build` as artifact. CI/publish download it via `dawidd6/action-download-artifact@v12`
2. **RunsOn GPU** — 4 of 5 workflows use `g4dn.2xlarge` with custom `quantecon_ubuntu2404` AMI
3. **No conda caching** — Fresh `conda-incubator/setup-miniconda@v3` each run; build cache is the primary time saver
4. **JAX CUDA** — Installed separately via `pip install -U "jax[cuda13]"` + `numpyro`, validated with `scripts/test-jax-install.py` and `nvidia-smi`
5. **3 build passes** — `ci.yml` and `publish.yml` run: (1) jupyter notebooks, (2) pdflatex, (3) HTML
6. **GH Pages via branch push** — `publish.yml` uses `peaceiris/actions-gh-pages@v4` (pushes to gh-pages branch)

### Feature Support Matrix

| Feature | lecture-python.myst does | Our action | Status |
|---------|-------------------------|------------|--------|
| Environment setup on RunsOn AMI | `conda-incubator/setup-miniconda@v3` | `setup-environment` (marker detection) | ✅ Supported |
| ML libs (JAX CUDA 13, numpyro) | `pip install -U "jax[cuda13]"` + numpyro | `setup-environment` (`install-ml-libs`) | ✅ Supported — verify CUDA 13 |
| HTML build | `jb build lectures -W --keep-going` | `build-lectures` (builder: html) | ✅ Supported |
| PDF build | `jb build --builder pdflatex` | `build-lectures` (builder: pdflatex) | ✅ Supported |
| Jupyter notebook build | `jb build --builder=custom --custom-builder=jupyter` | `build-lectures` (builder: jupyter) | ✅ Supported |
| Asset staging (PDF → html/_pdf) | Manual `mkdir -p` + `cp` | `build-lectures` (`html-copy-pdf`) | ✅ Supported |
| Asset staging (notebooks → html/_notebooks) | Manual `mkdir -p` + `cp` | `build-lectures` (`html-copy-notebooks`) | ✅ Supported |
| Execution reports on failure | `actions/upload-artifact@v6` per builder | `build-lectures` (`upload-failure-reports`) | ✅ Supported |
| Build cache (weekly generation) | Artifact upload via `actions/upload-artifact@v6` | `build-jupyter-cache` (uses `actions/cache`) | ✅ Supported — different mechanism |
| Build cache (PR restore) | `dawidd6/action-download-artifact@v12` | `restore-jupyter-cache` (uses `actions/cache`) | ✅ Supported — different mechanism |
| Netlify PR preview | Manual `netlify-cli` install + deploy | `preview-netlify` | ✅ Supported |
| Changed file detection in PR | Custom bash git diff script | `preview-netlify` / `preview-cloudflare` | ✅ Supported |
| GitHub Pages publish | `peaceiris/actions-gh-pages@v4` | `publish-gh-pages` (native OIDC) | ✅ Supported — different mechanism |
| CNAME for custom domain | `cname: python.quantecon.org` | `publish-gh-pages` (`cname` input) | ✅ Supported |
| Release assets (tar.gz + checksum + manifest) | `softprops/action-gh-release@v2` | `publish-gh-pages` (release asset inputs) | ✅ Supported |
| Issue creation on failure | `peter-evans/create-issue-from-file@v6` | `build-jupyter-cache` (`create-issue-on-failure`) | ✅ Supported |
| Download notebooks zip | `zip -r download-notebooks.zip _build/jupyter` | — | 🔴 Not yet supported |
| Notebook repo sync | Clone + push to `lecture-python.notebooks` | — | 🔴 Not yet supported |
| Colab compatibility testing | Separate workflow with Colab container | — | ⚪ Out of scope (standalone) |
| Link checking | `lycheeverse/lychee-action@v2` | — | ⚪ Out of scope (standalone) |
| GPU validation (`nvidia-smi`) | Inline step | — | ⚪ Inline step (no action needed) |

### Items to Resolve

#### 1. Verify `actions/cache` on RunsOn AMI

**Priority:** High — blocking

Our cache actions (`build-jupyter-cache`, `restore-jupyter-cache`) use `actions/cache`. The current `lecture-python.myst` uses artifact-based caching (`actions/upload-artifact` + `dawidd6/action-download-artifact`). We need to confirm `actions/cache` works correctly on RunsOn self-hosted runners.

**Expected:** Should work — RunsOn runners are standard GitHub Actions runners with full API access. The `setup-environment` README already documents RunsOn + `actions/cache` compatibility.

**Action:** Test with a simple workflow on a RunsOn runner.

#### 2. Verify OIDC GitHub Pages deployment from RunsOn

**Priority:** High — blocking

Our `publish-gh-pages` uses native OIDC-based deployment (`actions/deploy-pages`). The current repo uses `peaceiris/actions-gh-pages@v4` which pushes to a gh-pages branch. OIDC deployment requires the runner to request an OIDC token from GitHub.

**Expected:** Should work — RunsOn runners support OIDC tokens. But needs verification.

**Action:** Test a Pages deployment from a RunsOn runner.

#### 3. Verify JAX CUDA 13 compatibility

**Priority:** Medium

Our `setup-environment` has `install-ml-libs: 'true'` which installs JAX and PyTorch. Need to verify the installed JAX version supports CUDA 13 and matches what the lectures expect.

**Action:** Check `setup-environment` ML libs install commands against `jax[cuda13]` + numpyro.

#### 4. Download Notebooks Zip

**Priority:** Medium — needed for `publish.yml` parity

`publish.yml` creates `download-notebooks.zip` from `_build/jupyter` and uploads it as an artifact. We don't have this as a built-in feature.

**Options:**
- Add `create-notebooks-zip: 'true'` input to `build-lectures`
- Add it as an inline workflow step in the migration (simpler)
- Add it as a feature of `publish-gh-pages`

**Recommendation:** Inline workflow step initially. Consider action feature if other repos need it.

#### 5. Notebook Repository Sync

**Priority:** Low — `lecture-python.myst` specific

`publish.yml` pushes generated `.ipynb` files to `quantecon/lecture-python.notebooks` using a PAT (`QUANTECON_SERVICES_PAT`). This is highly repo-specific.

**Recommendation:** Keep as inline workflow steps in the migrated `publish.yml`. Document the pattern in the migration guide.

---

## Standalone Workflows (Not Migrated)

These workflows are independent of the build chain and can remain as-is:

### Colab Compatibility Testing (`collab.yml`)

Runs weekly inside a Google Colab container (`us-docker.pkg.dev/colab-images/public/runtime:latest` with `--gpus all`) to verify notebooks execute in the Colab environment. Creates a GitHub issue on failure.

**Decision:** Keep as standalone workflow. Not part of the build/deploy chain.

### Link Checking (`linkcheck.yml`)

Runs weekly against the `gh-pages` branch using `lycheeverse/lychee-action@v2`. Creates a GitHub issue on broken links.

**Decision:** Keep as standalone workflow. Could become a reusable action later if other repos want it.

---

## Feature Parity Checklist

All features needed to fully replace current lecture-repo workflows:

### Remaining

- [ ] **Download Notebooks Zip** — Create zip of built notebooks for artifact/release upload
- [ ] **Notebook Repository Sync** — Document as inline workflow steps (too repo-specific for an action)
- [ ] **Verify `actions/cache` on RunsOn** — Test cache save/restore on self-hosted GPU runners
- [ ] **Verify OIDC Pages deployment from RunsOn** — Test native GH Pages deploy from self-hosted runners
- [ ] **Verify JAX CUDA 13 install** — Confirm `install-ml-libs` matches `jax[cuda13]` + numpyro

### Completed ✅

- [x] Execution reports on failure (`build-lectures` — `upload-failure-reports`)
- [x] Asset assembly (`build-lectures` — `html-copy-pdf`, `html-copy-notebooks`)
- [x] Dedicated cache actions (`build-jupyter-cache`, `restore-jupyter-cache`)
- [x] PR-scoped build caching (`restore-jupyter-cache` — `save-cache`)
- [x] Native GitHub Pages deployment (OIDC, no gh-pages branch)
- [x] Release assets with tarball, checksum, manifest (`publish-gh-pages`)
- [x] Netlify PR preview deployment (`preview-netlify`)
- [x] Cloudflare Pages PR preview deployment (`preview-cloudflare`)
- [x] Changed file detection for PR comments
- [x] Conda environment caching (standard mode)
- [x] LaTeX installation with requirements file
- [x] JAX/PyTorch ML libs installation
- [x] Multi-builder support (html, pdflatex, jupyter)
- [x] Container-aware environment setup (marker file detection)
- [x] Delta package installs (`environment-update` input)
- [x] Issue creation on build failure (`build-jupyter-cache`)
