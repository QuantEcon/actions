# Plan

Working plan for `QuantEcon/actions`: current state, prioritized backlog, dependency policy, and rollout status.

**Last updated:** July 2026 — after the v0.8.0 release and a deep technical review of all actions, containers, workflows, docs, and open issues/PRs.

---

## Current state

The core infrastructure is complete, hardened, and in production:

- **Actions (7)** — `setup-environment`, `build-lectures`, `build-jupyter-cache`, `restore-jupyter-cache`, `preview-netlify`, `preview-cloudflare`, `publish-gh-pages`; released at `v0.8.0`
- **Containers (2)** — `quantecon` (full) and `quantecon-build` (lean); science stack pinned as a set to the Anaconda 2025.12 baseline (#28, #84), `kaleido<1.0` (#85), Miniconda SHA-pinned (#32)
- **June 2026 hardening pass** — third-party actions SHA-pinned (#39, #79), shell safety in `build-lectures` (#36), preview actions de-duplicated and injection-hardened (#35), standard-mode conda caching fixed (#33, #78), docs sweep (#40, #66)

**Known gap:** container-mode cache-build failure alerting is broken in the default configuration (#83) — this is the P0 item below.

### Consumers in production

| Repo | Actions used | Version |
|---|---|---|
| `lecture-dp` | Full chain: `restore-jupyter-cache`, `build-lectures`, `build-jupyter-cache`, `publish-gh-pages` | `@v0.8.0` |
| `lecture-python.myst` | `preview-netlify` (ci.yml) | `@v0.8.0` |
| `test-lecture-python-intro` | Full chain (test harness) | `@v0.6.0` |

Consumer/migration tracking lives in [QuantEcon/meta#321](https://github.com/QuantEcon/meta/issues/321); the preview-unification rollout is planned in [QuantEcon/meta#327](https://github.com/QuantEcon/meta/issues/327).

---

## Backlog (July 2026 review)

### P0 — broken safety net

| # | Item | Refs |
|---|---|---|
| 1 | **Fix container-mode failure alerting.** Neither container image installs the `gh` CLI, so `create-failure-issue.sh` exits 127 when the cache build runs inside a container (the documented default) — every failure goes un-alerted. Install `gh` in both images, or fall back to the REST API via `curl`, and guard the script so a missing CLI is a loud `::error::`. Add a container test asserting `gh` is on PATH. | #83 |

### P1 — correctness and drift prevention

| # | Item | Refs |
|---|---|---|
| 2 | **Targeted execution reports on cache failure.** The build steps inside `build-jupyter-cache` don't pass `upload-failure-reports` (defaults `false`), so a failed cache build uploads no `reports/*.err.log` artifact while the auto-issue body tells maintainers to download one. Pass it through (default `true`) and align the issue-body text with the artifact actually produced. | #83 |
| 3 | **Fix Dependabot conda grouping.** The conda groups match `*` with no `ignore` for the pinned science stack or `anaconda`, so Dependabot proposes exactly the drift the #28 pins exist to prevent (live proof: PRs #86, #87). Add `ignore` entries so the stack moves manually as a set, and correct the stale header comment. | #28, PRs #86/#87 |
| 4 | **Hold PRs #86 and #87.** Both drift the container science stack off the 2025.12 baseline; #87 additionally pulls in pandas 3.0 (major, copy-on-write default). Handle container-stack bumps as one coordinated, validated move when the lecture repos adopt a new anaconda baseline (see Dependency policy). | #28 |
| 5 | **`preview-cloudflare`: use the stable `pr-N` alias URL.** The PR comment currently shows the per-deployment hash URL grepped from wrangler output; construct `https://{branch-alias}.{project}.pages.dev` directly (the alias is already computed). | #14 |

### P2 — surplus removal and quality

| # | Item | Refs |
|---|---|---|
| 6 | **Extract the shared PR-comment script.** The 87-line `github-script` comment renderer is near-identical (only 2 lines differ) across `preview-netlify` and `preview-cloudflare`; move it to a shared script parameterized by title/emoji, as `detect-changed-lectures.sh` already is. | — |
| 7 | **Delete the dead `asset-url` output** in `publish-gh-pages` — it is wired to an output `action-gh-release` doesn't expose, is always empty, and has no consumers. Remove the README row too. | — |
| 8 | **`preview-netlify`: move the auth token into `env:`.** `--auth="…"` puts the secret on the process command line; the Cloudflare action already does this correctly. | — |
| 9 | **CI coverage for standard-mode conda caching.** The only workflow exercising `setup-environment` runs in a container, so the #33/#78 cache fix has never been confirmed by CI. Add a two-run smoke test asserting a cache hit on the second run — this doubles as the seed of the #29 env-test harness. | #29, #33 |
| 10 | **Docs surplus trim.** ~4,900 doc lines for ~1,600 lines of action code, with four overlapping indexes. Delete `docs/README.md`; shrink `QUICK-REFERENCE.md` to a one-screen link table; keep per-repo notes in one place (MIGRATION-GUIDE); drop the copilot-instructions "GitHub CLI Tool Constraints" section (boilerplate imported from another environment); strip the stale schedule/perf blocks from ARCHITECTURE.md; relocate `GPU-AMI-SETUP.md` to the infra/meta repo or trim it to the essentials (it documents AMI infrastructure — no workflow in this repo runs on GPU). Propagate corrected container-size figures everywhere. | #40 |
| 11 | **Document composite action vs reusable workflow.** Add the short decision rule to CONTRIBUTING.md or ARCHITECTURE.md so new CI lands at the right altitude. | #29 |
| 12 | **Environment manifest v1.** The publish-time manifest is a stub (name/tag/commit/size). Define a versioned schema, capture the effective environment (resolved `conda list`/`pip freeze`, container digest, build metadata), and `repository_dispatch` to `status-lectures`. | #30, meta#321 |

### P3 — housekeeping

| # | Item | Refs |
|---|---|---|
| 13 | Merge safe Dependabot PRs: #90 (checkout v7, cache v6 — first-party runtime bumps) and #88 (`action-gh-release` 3.0.1 patch, SHA-pinned). | PRs #90/#88 |
| 14 | Harden `create-failure-issue.sh`: distinguish "no existing issue" from "list failed", surface `::error::` when creation fails, use `mktemp` instead of a fixed `/tmp` path. | #83 |
| 15 | Small fixes: `set -euo pipefail` in `check-latex-versions.sh`; `concurrency` + `timeout-minutes` in `build-containers.yml`; fix the `build-lectures` pdflatex debug hint path (`_build/latex/reports`); refresh stale README blocks in `setup-environment` (cache strategy) and `restore-jupyter-cache` (phantom "Age Information"). | — |
| 16 | Branch hygiene: delete the merged `fix-conda-activation` branch and prune the five stale (~5 months old) feature branches after confirming nothing is stranded. | — |
| 17 | Refresh TESTING.md dated status. | — |

---

## Dependency policy

The lean image's science stack (`numpy`, `scipy`, `pandas`, …) is **pinned as a set** to the Anaconda baseline the lecture repos pin (currently `anaconda=2025.12`). Drifting individual packages ahead of that baseline is what broke lecture execution in #28.

- Stack bumps happen as **one coordinated move** — both containers together, only when the lecture repos adopt a new anaconda baseline, validated by a container lecture-build run (and, once built, the #29 env-test harness).
- Dependabot handles everything else: minors/patches grouped per ecosystem, majors grouped for individual review (#67, #76). The conda stack should be excluded via `ignore` (backlog item 3).
- Urgent security fixes may cherry-pick a single package, with the deviation documented in `environment.yml`.

---

## Open issues disposition

| Issue | Status (July 2026 review) | Disposition |
|---|---|---|
| #83 cache failures silent | Partially addressed — `@main` sub-action pins and the literal script-not-found 127 are fixed; the container `gh` gap and missing failure reports remain | Backlog items 1, 2, 14 |
| #14 Cloudflare alias URL | Still valid | Backlog item 5 |
| #29 composite-vs-workflow docs + env harness | Still valid | Backlog items 9, 11 |
| #30 env/config manifest | Partially addressed — v0 stub exists | Backlog item 12 |
| #18 container-mode caching | Re-scoped — pre-baking covers the common stack; only the per-lecture delta install is uncached. Quantify before investing | Keep open, low priority |
| #27 HTML recovery tool | Still valid — producer half exists (release assets + checksums); consumer unbuilt. Likely belongs in `workflow-backups`, not here | Decide home, then build |
| #2 isolated lecture execution | Exploratory — most tractable first step is an execution check of the built notebooks | Keep open, low priority |

---

## Rollout status

### Phase 1: `lecture-dp` — ✅ complete

`lecture-dp` runs the full chain (`restore-jupyter-cache` → `build-lectures` → `build-jupyter-cache` → `publish-gh-pages`) in production at `@v0.8.0`. Production use surfaced the #83 alerting gaps — the motivation for the P0 item above.

### Phase 2: migrate existing repos

Incremental migration, previews first (see [meta#327](https://github.com/QuantEcon/meta/issues/327)), CPU-only full chains next, GPU last:

| # | Repository | Runner | Status |
|---|---|---|---|
| 1 | `lecture-python.myst` (previews) | GPU | ✅ `preview-netlify@v0.8.0` live |
| 2 | Remaining python repos (previews) | Container | ⏳ meta#327 pilots |
| 3 | `lecture-python-intro` (full chain) | Container | ⏳ Planned |
| 4 | `lecture-python-programming.myst` (full chain) | Container | ⏳ Planned |
| 5 | `lecture-python-advanced.myst` (full chain) | Container | ⏳ Planned |
| 6 | `lecture-python.myst` (full chain) | RunsOn GPU | ⏳ Blocked on RunsOn verification (below) |

Per-repo checklist: create migration branch → `setup-environment` → `build-lectures` → cache actions → preview action → `publish-gh-pages` → validate output against production → measure → merge and monitor.

### Remaining blockers for the GPU repo

The February 2026 gap analysis concluded every `lecture-python.myst` build feature is supported (full matrix in git history). Two verification items remain before its full-chain migration:

- [ ] **`actions/cache` on RunsOn** — confirm cache save/restore works on the self-hosted GPU runners
- [ ] **OIDC Pages deployment from RunsOn** — confirm `actions/deploy-pages` token flow works from self-hosted runners

Settled architectural decisions: eliminate the `.notebooks` repos in favour of gh-pages notebooks + theme-generated Colab URLs ([quantecon-book-theme#359](https://github.com/QuantEcon/quantecon-book-theme/issues/359)); notebook-zip stays an inline workflow step; `collab.yml` and `linkcheck.yml` remain standalone workflows.
