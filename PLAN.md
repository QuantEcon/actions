# Plan

Working plan for `QuantEcon/actions`: current state, prioritized backlog, dependency policy, and rollout status.

**Last updated:** 2026-08-11 — release gating added as P0 (#135, #136) and the consumers table corrected: five lecture repos are still on exact pins, which this document previously said did not exist. Before that, 2026-08-07 — after the **v0.11.0** and **v0.11.1** releases and the move of `lecture-dp` and `lecture-python.myst` to `@v0`, which is the first to carry both alerting fixes (#122, #127) to consumers: `build-jupyter-cache` reaches its siblings through the pinned `@v0` ref, so neither fix existed for any consumer until `v0` moved to this release. The backlog below is still the July 2026 review; individual items carry their own closure notes.

---

## Current state

The core infrastructure is complete, hardened, and in production:

- **Actions (7)** — `setup-environment`, `build-lectures`, `build-jupyter-cache`, `restore-jupyter-cache`, `preview-netlify`, `preview-cloudflare`, `publish-gh-pages`; latest release **`v0.11.0`** (2026-08-07), and `@v0` points to it
- **Containers (2)** — `quantecon` (full) and `quantecon-build` (lean); science stack pinned as a set to the Anaconda 2026.06 baseline (#28, #84, migrated in #95), `kaleido<1.0` (#85), Miniconda SHA-pinned (#32)
- **June 2026 hardening pass** — third-party actions SHA-pinned (#39, #79), shell safety in `build-lectures` (#36), preview actions de-duplicated and injection-hardened (#35), standard-mode conda caching fixed (#33, #78), docs sweep (#40, #66)
- **August 2026 alerting pass** — unattended cache-build failures now reach the tracker on every failure path: during the builds (#83, #122) and before them (#123, #127). Shipped in v0.11.0. The half neither fix can prove in-repo is whether an issue is *actually filed* — that needs `issues: write` and would open real issues on every PR run — so the canary is now the only place it is exercised, and it only started exercising it when `v0` moved to v0.11.0.

### Consumers in production

| Repo | Actions used | Version |
|---|---|---|
| `lecture-dp` | Full chain: `restore-jupyter-cache`, `build-lectures`, `build-jupyter-cache`, `publish-gh-pages` | `@v0` ([lecture-dp#52](https://github.com/QuantEcon/lecture-dp/pull/52)) |
| `lecture-python.myst` | `preview-netlify` (ci.yml), `publish-gh-pages` | `@v0` ([lecture-python.myst#1029](https://github.com/QuantEcon/lecture-python.myst/pull/1029)) |
| `test-actions-lecture-intro` | Full chain + `preview-netlify` (sandbox and post-release canary — #100 stage 2, role documented in its README) | `@v0` |
| `lecture-jax` | `preview-netlify`, `publish-gh-pages` | **`@v0.8.0`** (2 call sites) |
| `lecture-python-intro` | `publish-gh-pages` | **`@v0.8.0`** |
| `lecture-python-advanced.myst` | `publish-gh-pages` | **`@v0.8.0`** |
| `lecture-python-programming` | `publish-gh-pages` | **`@v0.9.0`** |
| `continuous_time_mcs` | `publish-gh-pages` | **`@v0.9.0`** |

**Corrected 2026-08-11.** This section previously listed only the first three rows and stated "every consumer now tracks the floating `@v0` — 11 call sites, no exact pins left". That was wrong: **six exactly-pinned call sites exist across five lecture repos**, two to three releases behind current. The audit is QuantEcon/workspace-lectures#31. The omission matters because the argument below was reasoned partly from the incomplete table — `publish-gh-pages` is in fact at **7/7** adoption across the publishing lecture repos, and it is also the action every remaining pin sits on.

The case against exact pins still stands on its own evidence. Pins are what stranded `lecture-dp` three releases behind, which is why its weekly cache build ran for ~2 months with alerting that had never worked (#83). Pinning plus Dependabot was tried and is not sufficient: it surfaces the bump but currency still depends on someone merging it, and `lecture-python.myst#1000` sat open for 13 days before being closed as superseded.

**What does not stand is the claim that the canary "meets a bad release first".** That holds on exactly one consumer path. The canary's weekly cache build runs Sunday 03:00 UTC against consumers' Monday 02:00/03:00 UTC, a real 23–24 hour lead. Its `ci.yml` fires only on a `pull_request` in the canary, and its `publish.yml` only on a tag push there — so the **preview and publish paths have no lead at all**, and publish is where output reaches readers. More fundamentally, the canary pins `@v0`, the tag a release *moves*, so it only ever exercises a published release and cannot test a candidate. Gating is #135; the fixture it needs is #136.

Consumer/migration tracking lives in [QuantEcon/meta#321](https://github.com/QuantEcon/meta/issues/321); the preview-unification rollout is planned in [QuantEcon/meta#327](https://github.com/QuantEcon/meta/issues/327).

---

## Backlog (July 2026 review)

### P0 — broken safety net

**Release gating (#135, #136) — added 2026-08-11.** A release currently reaches a published lecture site before any test has met it. This is P0 for the same reason the alerting item below was: the safety net does not do the thing it is assumed to do. It also blocks the lecture family's move to floating `@v0` (QuantEcon/workspace-lectures#33), which is otherwise ready.

| # | Item | Refs |
|---|---|---|
| 0a | **Build `test-actions-release`** — a frozen gate fixture. The existing canary cannot be the gate: it runs `quantecon-build:latest`, has Dependabot enabled, and pins `@v0`. The first two are the *right* properties for a sandbox and disqualifying for a gate, and both are repo-level, so one repo cannot hold both roles. Purpose-built (not trimmed from intro), container pinned by digest, no network reads, ~5 lectures, all three builders, staged-failure self-test from day one. Must cover **plotly/kaleido static export** — the #85 path is uncovered by any current fixture | #136, #85, #108 |
| 0b | **Add a `v0-next` staging tag and gate on it.** Move `v0-next` to the candidate, dispatch the gate fixture, require green, then move `v0`. Works because `@v0-next` is as static as `@v0` — GitHub forbids expressions in `uses:`, so no parameterised-ref design is possible. Does **not** cover `build-jupyter-cache`'s sibling chain, which reaches `setup-environment@v0` and `build-lectures@v0` hardcoded, so "verified green" will mean "everything except that chain" | #135, #100 |
| 0c | **Close the ungated consumer paths regardless of 0b.** Schedule the canary's `ci.yml` and `publish.yml` ahead of consumers' Monday cache builds; `publish.yml` has no `workflow_dispatch` at all today, so it cannot even be run by hand | #135 |
| 0d | **Prove the gate can stop a release, and that a red gate reaches a human.** Two separate things, both with precedent here: the container smoke tests could not fail and still reported green (#108), and the canary failed eight consecutive weeks filing zero issues (#83) | #135, #83, #108 |

**The previous P0 is closed** — the one item closed in #122 (2026-08-05).

One correction to how that closure was written up: "cannot silently no-op" was too strong. #122 fixed alerting for failures *during* the builds, but a failure *before* them still skipped every guard, because they all tested `all-passed == 'false'` and an aborted run leaves that output empty rather than `'false'` (#123, fixed below). The general lesson is worth keeping: a guard written around the failure mode someone had in mind fails open on the one they did not, so guards on an alerting path should test `!= 'true'`, never `== 'false'`.

| # | Item | Refs |
|---|---|---|
| 1 | ~~**Fix container-mode failure alerting.**~~ Done (#122) — but the diagnosis above was wrong, which is worth recording. `gh` absence was real and would have bitten, but it was never reached: the step invoked its script through `${{ github.action_path }}`, which expands to the *runner's* path, and inside a `container:` job the action is mounted at `/__w/_actions/...` — so bash got a nonexistent path and exited 127 *before* the script ran. A third, unnoticed bug made alerting fail on hosted runners too: `gh issue create --label` validates labels client-side, and no consumer has `build-failure` or `automated`. Fixed by moving to `actions/github-script` (REST), which removes all three at once. The suggested remedies here would each have fixed only one: installing `gh` in both images fixes neither the path nor the labels, and a container test asserting `gh` is on PATH is now moot. | #83, #122 |

### P1 — correctness and drift prevention

| # | Item | Refs |
|---|---|---|
| 2 | ~~**Targeted execution reports on cache failure.**~~ Done (#122) — `upload-failure-reports` is now an input defaulting `true` and passed to all three inner `build-lectures` calls, and the issue body names the artifacts actually produced with per-builder reproduce commands. One correction: the reports were not entirely absent before, they were reachable only buried inside the full `_build` artifact (hundreds of MB, including `.jupyter_cache`) — and genuinely absent only when `upload-artifact` was off. It was mostly a discoverability failure. | #83, #122 |
| 2a | ~~**Alert when the cache build aborts before the builds.**~~ Done (#127) — `build-jupyter-cache` now resolves the overall status in a single `always()` step that maps "verify-builds never ran" to `false` instead of `''`, and every guard reads it as `!= 'true'`. The `continue-on-error` on `Setup environment` that the issue sketched was rejected: it would have let all three builds run against a broken environment and filed an issue blaming the lectures. Two follow-on defects on the same path were fixed with it — the issue body named a `build-cache-*` artifact that is never uploaded when nothing was built, and reported "both upload inputs are false" as the reason. Covered by a new `bjc-abort-guard` harness job. | #83, #122, #123, #127 |
| 3 | ~~**Fix Dependabot conda grouping.**~~ Done (#95) — verified in `.github/dependabot.yml`: all eleven stack packages plus `anaconda` are listed under `ignore` with **no** `update-types`, so every update type is blocked rather than just majors, and the header comment was corrected in the same change. The old comment asserted that a date-pin (`=2025.12`) meant the metapackage "stays put", which is exactly the misconception that let #86/#87 be proposed — a date-pin does not stop Dependabot offering the next release. | #28, #95 |
| 4 | ~~**Hold PRs #86 and #87.**~~ Resolved — both are closed, and the stack has since moved as one coordinated set to the anaconda 2026.06 baseline (#95). The standing policy they were held under is unchanged and now lives in Dependency policy below; item 3 is what stops Dependabot re-proposing the same drift. | #28, #95 |
| 5 | **`preview-cloudflare`: use the stable `pr-N` alias URL.** The PR comment currently shows the per-deployment hash URL grepped from wrangler output; construct `https://{branch-alias}.{project}.pages.dev` directly (the alias is already computed). | #14 |

### P2 — surplus removal and quality

| # | Item | Refs |
|---|---|---|
| 6 | **Extract the shared PR-comment script.** The 87-line `github-script` comment renderer is near-identical (only 2 lines differ) across `preview-netlify` and `preview-cloudflare`; move it to a shared script parameterized by title/emoji, as `detect-changed-lectures.sh` already is. | — |
| 7 | **Delete the dead `asset-url` output** in `publish-gh-pages` — it is wired to an output `action-gh-release` doesn't expose, is always empty, and has no consumers. Remove the README row too. | — |
| 8 | **`preview-netlify`: move the auth token into `env:`.** `--auth="…"` puts the secret on the process command line; the Cloudflare action already does this correctly. | — |
| 9 | ~~**CI coverage for standard-mode conda caching.**~~ Done — `test-actions.yml` (the #100 stage-1 harness) runs the two-run miss→hit chain on every PR touching `setup-environment`, plus a build on the restored env. | #29, #33, #100 |
| 10 | **Docs surplus trim.** ~4,900 doc lines for ~1,600 lines of action code, with four overlapping indexes. Delete `docs/README.md`; shrink `QUICK-REFERENCE.md` to a one-screen link table; keep per-repo notes in one place (MIGRATION-GUIDE); drop the copilot-instructions "GitHub CLI Tool Constraints" section (boilerplate imported from another environment); strip the stale schedule/perf blocks from ARCHITECTURE.md; relocate `GPU-AMI-SETUP.md` to the infra/meta repo or trim it to the essentials (it documents AMI infrastructure — no workflow in this repo runs on GPU). Propagate corrected container-size figures everywhere. | #40 |
| 11 | **Document composite action vs reusable workflow.** Add the short decision rule to CONTRIBUTING.md or ARCHITECTURE.md so new CI lands at the right altitude. | #29 |
| 12 | **Environment manifest v1.** The publish-time manifest is a stub (name/tag/commit/size). Define a versioned schema, capture the effective environment (resolved `conda list`/`pip freeze`, container digest, build metadata), and `repository_dispatch` to `status-lectures`. | #30, meta#321 |

### P3 — housekeeping

| # | Item | Refs |
|---|---|---|
| 13 | ~~Merge safe Dependabot PRs.~~ Resolved — #90 (checkout v7, cache v6) merged; #88 (`action-gh-release` 3.0.1) closed. There are currently **no open PRs** in this repo. | PRs #90/#88 |
| 14 | ~~Harden `create-failure-issue.sh`.~~ Moot (#122) — the script was deleted, not hardened. Every concern it listed is structurally gone: `actions/github-script` has no `/tmp` body file, a failed API call throws rather than being swallowed by `2>/dev/null || echo ""`, and a new step asserts an issue was actually filed. | #83, #122 |
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
| #83 cache failures silent | Addressed in #122. Note the earlier reading of this issue was wrong: the script-not-found 127 was *not* already fixed — it was the primary bug, caused by `${{ github.action_path }}` resolving to the runner's path inside a container. Missing `gh` was real but never reached, and a third bug (client-side label validation in `gh issue create`) broke alerting on hosted runners too. All three are gone with the move to `actions/github-script`; failure reports now upload via `upload-failure-reports`. The remaining variant (#123) is closed too, in #127 | Backlog items 2a, 14 (moot) |
| #123 setup failure alerts nobody | Fixed. The gap was one of guard *polarity*, not of the alerting mechanism: every downstream step tested `all-passed == 'false'`, and a composite that aborts before `verify-builds` leaves that output `''`. Found by reading rather than from a live incident — the canary's silent weeks were build failures, not setup failures. One residual is deliberately out of scope: if the job itself never starts, or is cancelled, timed out, or loses its runner, no step runs at all — `always()` included — so nothing can be filed from inside the action. Covering that needs a workflow-level `if: failure()` notify job in the consumer repo, or a scheduled sweeper | Backlog item 2a |
| #14 Cloudflare alias URL | Still valid | Backlog item 5 |
| #29 composite-vs-workflow docs + env harness | Still valid | Backlog items 9, 11 |
| #30 env/config manifest | Partially addressed — v0 stub exists | Backlog item 12 |
| #18 container-mode caching | Re-scoped — pre-baking covers the common stack; only the per-lecture delta install is uncached. Quantify before investing | Keep open, low priority |
| #27 HTML recovery tool | Still valid — producer half exists (release assets + checksums); consumer unbuilt. Likely belongs in `workflow-backups`, not here | Decide home, then build |
| #2 isolated lecture execution | Exploratory — most tractable first step is an execution check of the built notebooks | Keep open, low priority |

---

## Rollout status

### Phase 1: `lecture-dp` — ✅ complete

`lecture-dp` runs the full chain (`restore-jupyter-cache` → `build-lectures` → `build-jupyter-cache` → `publish-gh-pages`) in production at `@v0.8.0`. Production use surfaced the #83 alerting gaps — a weekly cache build failed for roughly two months with no alert issue and no downloadable traceback, which is what motivated the (now closed) P0 item above.

### Phase 2: migrate existing repos

Incremental migration, previews first (see [meta#327](https://github.com/QuantEcon/meta/issues/327)), CPU-only full chains next, GPU last:

**`publish-gh-pages` is separately at 7/7** across the publishing lecture repos and is not tracked by this table — the table is about the *full chain*. Five of those seven are on exact pins; see Consumers in production above.

| # | Repository | Runner | Status |
|---|---|---|---|
| 1 | `lecture-python.myst` (previews) | GPU | ✅ live, now on `preview-netlify@v0` (was `@v0.8.0`) |
| 2 | Remaining python repos (previews) | Container | ⏳ `lecture-jax` done (`@v0.8.0`); four still on `nwtgck/actions-netlify` — meta#327, QuantEcon/workspace-lectures#2 |
| 3 | `lecture-python-intro` (full chain) | Container | ⏳ Planned — blocked on #97 and #98 |
| 4 | `lecture-python-programming.myst` (full chain) | Container | ⏳ Planned — blocked on #97 and #98 |
| 5 | `lecture-python-advanced.myst` (full chain) | Container | ⏳ Planned |
| 6 | `lecture-python.myst` (full chain) | RunsOn GPU | ⏳ Blocked on RunsOn verification (below) |

`lecture-jax` is the suggested full-chain pilot: it is the smallest of the native five and is **not** blocked by #97/#98, which bite intro and programming specifically. See QuantEcon/meta#348.

Per-repo checklist: create migration branch → `setup-environment` → `build-lectures` → cache actions → preview action → `publish-gh-pages` → validate output against production → measure → merge and monitor.

### Remaining blockers for the GPU repo

The February 2026 gap analysis concluded every `lecture-python.myst` build feature is supported (full matrix in git history). Two verification items remain before its full-chain migration:

- [ ] **`actions/cache` on RunsOn** — confirm cache save/restore works on the self-hosted GPU runners
- [ ] **OIDC Pages deployment from RunsOn** — confirm `actions/deploy-pages` token flow works from self-hosted runners

Settled architectural decisions: eliminate the `.notebooks` repos in favour of gh-pages notebooks + theme-generated Colab URLs ([quantecon-book-theme#359](https://github.com/QuantEcon/quantecon-book-theme/issues/359)); notebook-zip stays an inline workflow step; `collab.yml` and `linkcheck.yml` remain standalone workflows.
