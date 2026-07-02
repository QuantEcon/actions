# Project: Optimize Preview Builds

Research and design notes for making PR preview builds as fast as possible across the lecture repos, so authors see a deployed preview of their changes quickly after pushing.

**Tracking issue:** [#92](https://github.com/QuantEcon/actions/issues/92) · **Date:** July 2026 · **Method:** measured step-level timings from real workflow runs, container-registry layer analysis, and a multi-agent design pass in which every recommendation was adversarially verified against the code in this repo, the consumer workflows, and platform behavior. Rejected ideas are recorded below with their refutations so they are not re-litigated.

---

## 1. Where preview time actually goes (measured)

Step-level timings from real runs (June–July 2026):

| Scenario | Run | Total | Breakdown |
|---|---|---|---|
| `lecture-dp` PR, warm cache | 28225111740 | ~2.7 min | Initialize containers **129s**, checkout 2s, cache restore 3s, **Build HTML 22s**, artifact upload 3s |
| `lecture-dp` PR, cold cache | 27920399325 | ~40 min | Initialize containers 102s, **Build HTML 2,350s** (full notebook re-execution) |
| `lecture-python.myst` PR (RunsOn `g4dn.2xlarge`) | 28569868463 | ~17 min | checkout (fetch-depth 0) **101s**, Setup Anaconda **102s**, JAX+numpyro install **55s**, artifact download 31s, notebooks build **117s**, **PDF build 379s**, HTML build 80s, Netlify deploy **61s** |

Three observations drive the whole design:

1. **Fixed overhead dominates the common case.** On a warm `lecture-dp` PR, the container pull is 75% of the run; the actual build is 22 seconds. On `lecture-python.myst`, ~8.3 min of every PR builds PDF and notebook formats an author never looks at in a preview, and ~2.6 min rebuilds a conda environment on a machine that already boots from a custom AMI.
2. **The 40-minute case was a freshness failure, not inherent cost.** The weekly cache builder failed silently for ~2 months (#83), so every PR in that window ran cold. Making caches fresh, layered, and *loud* is a speed feature.
3. **45% of every container pull is TeX.** The lean `quantecon-build` image is 2,741 MB compressed: 28 MB base + **1,233 MB TeXLive apt layer** + 8 MB + 344 MB Miniconda + 1,112 MB conda env + 15 MB. An HTML-only preview never invokes TeX. (The full and lean images share only the 28 MB base layer — their big layers have distinct digests, so there is no cross-image pull benefit.)

Cache sizes are a non-issue: `lecture-dp` build caches are ~88 MB, jupyter-caches ~15 MB; restore is 1–3 s.

Note: `lecture-dp`'s ci.yml currently only uploads a build artifact — it does not yet deploy a preview or post a PR comment. This design doubles as the template for the preview rollout tracked in [QuantEcon/meta#327](https://github.com/QuantEcon/meta/issues/327).

## 2. Target architecture

### Container CPU repos (`lecture-dp` class)

- **A TeX-free preview image** `ghcr.io/quantecon/quantecon-preview` (~1.7 GB compressed, zstd layers): `quantecon-build` minus the TeXLive layer, with a pinned `netlify-cli` baked in and the **science stack unchanged** — execution parity between PR builds and the weekly jupyter-cache is the invariant everything relies on (see #28). Used by ci.yml, cache.yml *and* publish.yml for HTML-only repos so all builds share one environment.
- **Three cache planes:**
  1. *Weekly fresh rebuild* (`build-jupyter-cache`) — the corrective anchor;
  2. *Cache-on-merge* — an incremental save on every push to main, killing mid-week staleness and making a cold PR require multiple simultaneous failures;
  3. *PR-scoped save* (`restore-jupyter-cache` with `save-cache: 'true'` — already shipped in v0.8.0, just not enabled) — pushes 2+ to a PR never re-execute what push 1 already ran.
- **Loudness:** the #83 alerting fix plus a cache-age warning in `restore-jupyter-cache`, so staleness is detected in under a day instead of months.

### GPU repo (`lecture-python.myst`)

Stays on RunsOn GPU — migrating previews to the CPU container chain was evaluated and **rejected** (§5): 28 of 121 lectures import JAX/numpyro (absent from the container env), and a cold CPU run extrapolates to >1.5 h. Instead:

- **HTML-only PR previews**; the three-format build moves behind a `full-preview` label, and PDF/notebook coverage moves to the weekly build.
- **Bake the environment into the AMI** it already boots: miniconda + the pinned env + `jax[cuda13]`/numpyro + netlify-cli, with an `env_hash` drift guard; ci.yml flips to `setup-environment`'s ~0s container-mode path.
- **Shallow checkout** (`fetch-depth: 1`), with `--depth=1` hardening in `scripts/detect-changed-lectures.sh`.

### Both repo classes

- **Instant placeholder PR comment** (~20 s after push): a tiny first job with no container and no checkout posts "Building preview for `<sha>`…" with the *deterministic* preview URLs (`pr-N--site.netlify.app` / `pr-N.project.pages.dev`), which the deploy step later upgrades in place. The single largest author-*perceived* improvement available.
- **Concurrency cancellation** — also closes a live hazard where a superseded run finishing last overwrites the preview and comment with a stale commit's content.
- **Paths filters** so docs-only PRs skip the preview entirely.

## 3. Expected time budgets

| Scenario | Today | After Phase 1 | End state |
|---|---|---|---|
| `lecture-dp` small edit (warm) | ~2.7 min; no deploy/comment yet | ~2.2–2.5 min | **~1.5–2.5 min incl. deploy** (init ~45–70s, HTML 10–22s); links at ~20s |
| `lecture-dp` cold miss | ~40 min, silent, every push | ~10× rarer, loud, once per PR | ~18–28 min via parallel pre-execution, and rare |
| `lecture-python.myst` small edit | ~17 min | **~8–9 min** | ~3.5–5 min (~2.5–3.5 prose-only once incrementality lands); first signal ~20s |
| Second push to same PR | same as first + stale-overwrite hazard | execution skipped when code unchanged (saves 60–600s) | dp ~1.5–2 min, pymyst ~3.5–5 min |

## 4. Roadmap

### Phase 1 — days; all S-effort, independently shippable and revertible

| Item | Where | Savings | Risk notes |
|---|---|---|---|
| HTML-only PR previews: drop tojupyter (117s) + pdflatex (379s) steps from PR CI; three-format build behind a `full-preview` label (add `labeled` to `pull_request` types); PDF/notebook coverage moves to weekly cache.yml (filter raw `_build/latex`/`_build/jupyter` out of the uploaded artifact) | `lecture-python.myst` ci.yml + cache.yml | **−430–465s/PR** (17 → ~9.5 min alone) | LaTeX breakage detected weekly instead of per-PR — requires the #83 fix first; consider decoupling the html cache save from PDF builder success |
| #83 alerting fix: `curl` REST fallback (curl is already in both images — no rebuild needed) + `::error::` guard in `create-failure-issue.sh`; `upload-failure-reports: true` on the `build-lectures` calls inside `build-jupyter-cache` | this repo (PLAN.md P0 / items 1, 2, 14) | 0s direct; prevents the measured ~35-extra-min-per-PR-for-2-months regression class; **hard prerequisite** for everything that reduces build frequency | low |
| PR-scoped cache save: `save-cache: 'true'` on the restore step (mechanism shipped in v0.8.0 via #24/#41) | `lecture-dp` ci.yml (one line); later each migrated repo | 60–600s per push whose code cells are unchanged vs a prior successful push; bounds a cold disaster to once per PR; cost +5–20s post-job save | saves nothing until first green build (post-if `success()`); PR caches self-clean via 7-day eviction |
| Cache-on-merge: push-to-main job (container: checkout → restore with `save-cache:'true'` → `build-lectures` html), `paths-ignore: [environment.yml]` (avoids old-env/new-key race with the weekly rebuild), concurrency-grouped | `lecture-dp` workflows; zero actions-repo changes — the key scheme already supports it | removes the mid-week staleness tax (0–120s avg/PR, up to ~10 min busy weeks); cold builds need every merge save AND the weekly build to fail together | low, *given* #83 alerting lands first |
| Shallow checkout: `fetch-depth: 1`; `--depth=1` on the two SHA fetches in `detect-changed-lectures.sh` (verified: fetching a SHA into a shallow clone without depth pulls the full history behind it — the guard is load-bearing) | `lecture-python.myst` ci.yml; this repo's `scripts/` | **−80–95s** on pymyst (101s → ~8–20s) | base-SHA fetch failure degrades gracefully (deep links lost, deploy still succeeds) |
| zstd layers for `quantecon-build`: `outputs: type=image,push=true,compression=zstd,force-compression=true,oci-mediatypes=true`; add a tag input to `test-container.yml` (it hardcodes `:latest`) and validate a `:zstd` tag first; keep the full image gzip for local dev | `.github/workflows/build-containers.yml` | **−20–35s** off every container init (BuildKit caps ~zstd-11 and small-file untar I/O is codec-independent — not the naive 45s) | Docker ≥23 required to pull (runners are on 28); verify inline-cache reuse survives the gzip→zstd transition on the first weekly build |
| Concurrency cancellation: `group: ci-${{ github.event.pull_request.number \|\| github.run_id }}`, `cancel-in-progress: true` (the templates' verbatim block would let `workflow_dispatch` runs share an empty group and cancel each other) | both consumer ci.yml + `templates/ci.yml` | recovers ~half a superseded run; closes the stale-overwrite hazard | cancellation is safe: PR runs save no caches mid-flight yet; Netlify publishes atomically |
| Paths filters: fail-open `paths-ignore: [README.md, CONTRIBUTING.md, LICENSE, .github/dependabot.yml, …]` (allow-lists rot silently); gate CLI-install steps in both preview actions on `github.event_name == 'pull_request'` | consumer ci.yml + templates; `preview-netlify`/`preview-cloudflare` | 100% of the run on docs-only PRs; ~25–45s on pymyst `workflow_dispatch` runs | revisit if previews become required status checks; >300-file PRs can false-skip |

**Phase 1 net:** `lecture-python.myst` ~17 → ~8–9 min; `lecture-dp` warm ~2.7 → ~2.2–2.5 min; the 40-min class becomes ~10× rarer, loud, and once-per-PR. Zero paid infrastructure, no new images.

### Phase 2 — 1–2 weeks: slim image, AMI bake, instant first signal

| Item | Where | Savings | Risk notes |
|---|---|---|---|
| Ship `quantecon-preview` (~1.7 GB zstd): `quantecon-build` minus the TeX apt layer and TeX fonts (keep git/curl/graphviz/fontconfig/kaleido-chrome deps); env minus `jupyterlab`, `notebook` **and the `jupyter` metapackage** (it transitively reinstalls both — verified); keep ipykernel/ipywidgets/nodejs/**MKL** for execution parity; bake pinned netlify-cli (+66 MB, +2–3s); stack-pins-match assertion in `test-container.yml`. Switch `lecture-dp` ci/cache/publish to it | `containers/quantecon-preview/`, `build-containers.yml`, then `lecture-dp` | container init 102–129s → **~45–70s**; warm dp preview ~1.5–2.5 min total | audit each repo for `usetex`/`imgmath` before rollout (verified absent in lecture-dp); rollback is one line; three pinned images kept in sync by the CI pin check |
| GPU AMI bake: miniconda + `anaconda=<baseline>` env + pinned `jax[cuda13]`/numpyro + netlify-cli; append `env_hash` to `/etc/quantecon-container`; flip ci.yml to `setup-environment` (container-mode ~0s). Mandatory: append the env's bin dir to `$GITHUB_PATH` (internal non-login shells never source `/etc/profile.d`); keep the ~5s GPU sanity check; `env_hash` mismatch → `::warning::` + `conda env update` (~2 min, self-healing). Staged rollout: bake → `workflow_dispatch` test → flip the PR trigger. **Verify first that the deployed AMI contains the marker file** | pymyst Packer build (docs/GPU-AMI-SETUP.md) + ci.yml | **~110–145s net/PR** (157s removed minus GPU check, marker overhead, and ~10–40s EBS lazy-load of the baked env; Fast Snapshot Restore not worth ~$540/mo/AZ) + ~25–45s from baked netlify-cli; bonus: pins today's floating `pip install -U jax` | the container-mode path has never been exercised on this AMI — hence the staged rollout |
| Instant placeholder comment: first job with **no container, no checkout** (REST `pulls.listFiles` for changed files) upserts "Building preview for `<sha>`…" + deterministic deep links via a shared hidden marker; deploy step upgrades it in place; label links as serving the previous build until then (aliases persist — links go stale, not 404). Bundle with the #14 stable-alias fix and the shared comment-script extraction (PLAN items 5/6) + a `site-name` input on preview-netlify | both preview actions + a shared script; consumer ci.yml first job (`pull-requests: write`) | time-to-first-signal ~17 min → **~20s** on pymyst; ~20s on dp once meta#327 adds its deploy | fork PRs gated by the existing trust check; depends on Phase 1 concurrency to prevent stale overwrites |
| Cache freshness warning: write `_build/.cache-metadata.json` `{sha, date, run_id}` before the weekly save; age check in `restore-jupyter-cache`'s status step (`warn-stale-days`, default 8; fallback `global.db` mtime); `::warning::` + step-summary on stale/bare-prefix-fallback/total-miss; `cache-age-days` output; release + repin consumers (exact pins mean restore-side warnings deliver nothing until the repin) | `build-jupyter-cache` + `restore-jupyter-cache` | 0s on healthy runs; staleness detection months → <1 day, independent of issue creation; makes "why was my preview slow" answerable from the run page | warn threshold 8d > weekly cadence — fires only on genuine failure/eviction |

### Phase 3 — bolder: cold-case compression, incrementality, unification

| Item | Where | Savings | Risk notes |
|---|---|---|---|
| Parallel notebook pre-execution: `jcache notebook add -r myst_nb_md` + `jcache project execute --executor local-parallel` **unconditionally** before `jb build` (a cache-miss gate never fires on a stale prefix-matched hit; warm-cache cost is a ~5–10s no-op). Container repos only — never the GPU box (concurrent JAX kernels OOM a single T4). First tractable step of #2 | `build-lectures` (`pre-execute` input) or `restore-jupyter-cache`; pilot on `lecture-dp` | cold 2,350s → **~950–1,550s** (1.5–2.5× — numba/BLAS already multithread within kernels, so not the naive 4×) | OOM under concurrency (fallback: jb re-executes failed notebooks serially — correctness preserved); jupyter-cache 1.0.1 exposes no worker-count knob |
| True Sphinx incrementality: set all sources to an old mtime, touch exactly `git diff --name-only $CACHE_SHA HEAD` (stamp the cache-build SHA into cache metadata — diffing against merge-base can serve Monday-stale prose, and touching the PR diff is mandatory); deletions/renames or `_toc.yml`/`_config.yml` changes → full rebuild (short-circuit **before** the touch — `xargs touch` would create empty files for deleted paths); restored `_build/html` supplies untouched pages | `build-lectures` (`incremental` input); pilot `lecture-dp` | dp: 22s → ~10–14s (minor); pymyst post-migration: **~90–150s on prose-only edits** (121-doc read+write dominates once execution is cached) | validate once by diffing incremental vs fresh output; env-version mismatch falls back safely to full re-read |
| RunsOn Magic Cache + migrate pymyst's weekly artifact chain onto the standard cache actions: enable `extras=s3-cache` + `runs-on/action@v2` in cache.yml and ci.yml **simultaneously** (partial rollout = producer/consumer on different backends → permanent silent miss); first move jax/numpyro into `environment.yml`'s pip section (`--prune` would strip out-of-band installs). Ticks the PLAN.md actions/cache-on-RunsOn blocker | pymyst cache.yml + ci.yml + environment.yml | ~10–20s/PR; value is mostly strategic — unifies the GPU repo onto the keyed/alerted cache machinery, unblocking meta#327's endgame | eviction semantics change (90d artifact → 10d age-since-creation) — #83 alerting is a hard prerequisite |
| Cost right-sizing: `g4dn.xlarge` + spot (price-capacity-optimized) for pymyst PR previews **only**; keep `g4dn.2xlarge` on-demand for cache/publish (4 vCPUs can add minutes to full cold executions; spot interruption restarts the job — acceptable for previews only). A/B a full **cold** run in 16 GB first | pymyst ci.yml `runs-on` label | ~0s wall-clock; ~30% instance cost, 40–70% more via spot | do last |

## 5. Evaluated and rejected

Recorded with refutations so these aren't re-litigated.

| Idea | Why rejected |
|---|---|
| Plain-runner conda cache instead of containers | Hit path ~90–150s — no better than today's container init and strictly worse than the slim-image endpoint. Worse: PR-saved caches are branch-scoped and nothing on main would seed one, so the *first* run of every PR pays a ~5–6 min full solve. Also splits the PR execution env from the container the weekly jupyter-cache was executed in — jupyter-cache keys on notebook content, not environment, so this silently mixes environments (the #28 drift class). #18 documents the same conclusion from the other direction. |
| Single-page draft builds (`jb build lectures/foo.md`) | 44/52 `lecture-dp` lectures fail outright under `-W --keep-going` (cross-refs to excluded siblings); no nav/toctree/numbering; and myst-nb resolves the page build's jupyter-cache to `_build/_page/<name>/.jupyter_cache`, so the restored weekly cache is invisible and every push re-executes cold — slower than the incremental full build, while producing a broken artifact. |
| Sphinx `-j auto` | jupyter-book 1.0.4 hardcodes `parallel=1` and its CLI rejects smuggled flags. Even forked, Sphinx only parallelizes reads with >5 outdated docs (a no-op for 1–2-lecture edits), and parallel readers would race the shared jupyter-cache sqlite DB. `jcache local-parallel` captures the same parallelism through a code path designed for it. |
| Prewarmed RunsOn CPU runners / GitHub larger runners (container repos) | Gross ~35–55s saving vs the slim+zstd endpoint, but RunsOn pre-job latency (~15–40s boot, invisible in step timings) nets −5s to +40s — too small to justify an AMI-rebake pipeline and moving free public-repo CI onto paid infrastructure. Revisit only if a hard sub-60s target appears after Phase 2. |
| Migrate pymyst previews to the CPU container chain now | Warm HTML-only CPU chain is ~parity with the *optimized* GPU path; the container env has no jax/numpyro, so 28/121 lectures fail on any code edit; a cold CPU run must execute 121 lectures including numpyro MCMC on CPU — >1.5 h extrapolated. A changed-lecture router (CPU for non-JAX prose edits, GPU dispatch otherwise) is the documented fallback if GPU capacity ever forces it. |
| Revive the `feat/pr-cache-save` branch | Its single commit already landed on main via #24 and was superseded by #41's improved read-only keys; the shipped v0.8.0 mechanism is better. Delete the branch; the remaining work is one line per consumer ci.yml. |
| HTML-first deploy reordering on pymyst (deploy HTML, then build PDF/notebooks, redeploy) | Workable (~7.5–8.5 min perceived saving) but subsumed by HTML-only previews, which deliver the same perceived cut plus ~8 min of GPU runner time per PR, with one deploy and no green-comment-beside-red-check ambiguity. Documented fallback if PDFs must build on every PR. |
| Bake netlify-cli into the *current* images | Saves 0s today (no containerized repo runs preview-netlify yet) while growing the pull that is already 75% of the cached run. Folded into the `quantecon-preview` image instead, where it prevents a future ~60–120s npm install once meta#327 adds the deploy step. The AMI-side bake for the GPU repo *is* kept. |
| Sub-1.2 GB image via dropping MKL / micromamba | MKL removal changes numerics vs the pinned baseline the #28 pins protect — execution parity is the invariant. Micromamba lacks the `conda tos` mechanism the Dockerfile uses and breaks `setup-environment`'s `conda env update` delta path. The TeX + jupyter-metapackage trim gets ~95% of the bytes with none of the parity risk. |

## 6. Open questions

1. Does the deployed `quantecon_ubuntu2404` AMI actually contain the `/etc/quantecon-container` marker file? (Gate for the Phase 2 AMI bake — verify via `workflow_dispatch` before flipping ci.yml.)
2. What is `lecture-dp`'s merge rate to main? Cache-on-merge's per-PR saving and cold-frequency reduction scale with it.
3. Does 16 GB survive 4 concurrent kernels under `jcache local-parallel` on the heaviest DP lectures? (jupyter-cache 1.0.1 exposes no worker-count knob — pilot with memory instrumentation.)
4. Product call on HTML-only previews: week-old PDF/ipynb download assets with a stale note, or hidden buttons? (Newly-added lectures 404 against week-old staged notebooks either way.)
5. Team tolerance for LaTeX/tojupyter breakage surfacing weekly instead of per-PR — and should the weekly cache save be decoupled so an html-only cache still saves when the PDF builder fails?
6. Netlify vs Cloudflare for the meta#327 rollout: are any `_build/html/_pdf` files over Cloudflare's hard 25 MiB per-asset cap (or near the 20k-file cap)? With CLIs pre-baked the platforms tie on speed — this is the deciding constraint for PDF-shipping repos.
7. Does buildx inline-cache reuse survive the gzip→zstd transition with `force-compression=true`? (One-run check; a full rebuild that week is harmless but should be expected.)
8. RunsOn platform verification (PLAN.md open blockers): `actions/cache`, Magic Cache `extras=s3-cache`, and OIDC behavior on the self-hosted GPU runners — prerequisite for Phase 3's artifact→cache migration.
9. After Phase 2, is there appetite for a hard sub-60s total-preview target for container repos? That's the only trigger to revisit prewarmed CPU runners.
10. Sphinx incrementality validation: does incremental-vs-fresh output diff clean for `lecture-dp` (toctree/prev-next/numbering), and do artifact-zip mtime semantics on pymyst (no mtime preservation, unlike `actions/cache` tar) hold up once that repo migrates?

## 7. Relationship to other work

- **PLAN.md** — the repo backlog. Phase 1 here includes its P0 (#83 alerting) and items 5 (Cloudflare alias URL), 6 (shared comment script), and 14 (script hardening); the cache freshness warning extends item 2.
- **Issues:** #83 (alerting — prerequisite), #14 (stable alias URL — bundled into Phase 2), #18 (container-mode caching — the plain-runner rejection documents the same constraint), #2 (isolated execution — Phase 3's parallel pre-execution is its first tractable step).
- **[QuantEcon/meta#327](https://github.com/QuantEcon/meta/issues/327)** — preview unification: the `quantecon-preview` image + placeholder comment + deterministic URLs form the template that rollout should adopt.
