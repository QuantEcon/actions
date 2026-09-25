# Plan

Working plan for `QuantEcon/actions`: current state, prioritized backlog, dependency policy, and rollout status.

**Last updated:** 2026-09-24 — after **v0.12.0**, which delivered the rest of the July 2026 audit (#105–#109, #99; the #110 tracker is closed): items 7 and 8 are done, item 10 is absorbed by the user manual (#178), item 15 is down to one cosmetic fix, the closed issues' dispositions say so, and two consumer follow-ups are recorded under Consumers in production. Before that, 2026-09-23 — the #106/#109 docs sweep: the consumers table is current again (all eight exact pins, across six repos, are on `v0.11.1`), the issues opened since the July review have refreshed dispositions (#135 added), and item 10's size-figure half is done. Before that, 2026-08-11 — release gating added as P0 (#135, #136) and the consumers table corrected: five lecture repos are still on exact pins, which this document previously said did not exist. Before that, 2026-08-07 — after the **v0.11.0** and **v0.11.1** releases and the move of `lecture-dp` and `lecture-python.myst` to `@v0`, which is the first to carry both alerting fixes (#122, #127) to consumers: `build-jupyter-cache` reaches its siblings through the pinned `@v0` ref, so neither fix existed for any consumer until `v0` moved to this release. The backlog below is still the July 2026 review; individual items carry their own closure notes.

---

## Current state

The core infrastructure is complete, hardened, and in production:

- **Actions (8)** — `setup-environment`, `build-lectures`, `build-jupyter-cache`, `restore-jupyter-cache`, `preview-netlify`, `preview-cloudflare`, `publish-gh-pages`, `deploy-cloudflare` (#163); latest release **`v0.12.0`** (2026-09-24), and `@v0` points to it (both resolve to `a53dbe4`)
- **Containers (2)** — `quantecon` (full) and `quantecon-build` (lean); science stack pinned as a set to the Anaconda 2026.07 baseline (#28, #84, #95; moved to 2026.07 in #199), `kaleido<1.0` (#85), Miniconda SHA-pinned (#32)
- **June 2026 hardening pass** — third-party actions SHA-pinned (#39, #79), shell safety in `build-lectures` (#36), preview actions de-duplicated and injection-hardened (#35), standard-mode conda caching fixed (#33, #78), docs sweep (#40, #66)
- **August 2026 alerting pass** — unattended cache-build failures now reach the tracker on every failure path: during the builds (#83, #122) and before them (#123, #127). Shipped in v0.11.0. The half neither fix can prove in-repo is whether an issue is *actually filed* — that needs `issues: write` and would open real issues on every PR run — so the canary is now the only place it is exercised, and it only started exercising it when `v0` moved to v0.11.0.
- **September 2026 audit close-out** — v0.12.0 delivered the rest of the July 2026 audit (#110): preview deploy errors surfaced and both CLIs pinned by lockfile (#105), the #107 correctness batch with new harness coverage, a smoke fixture that exercises the real theme and FreeFont path (#108), and the docs reconciled with the code and the 2026.06 baseline (#106, #109, #99). It was the first release staged by hand (CONTRIBUTING.md, Staged Releases): `v0` moved only after the canary ran real `preview-netlify` and `preview-cloudflare` deploys and a `cache.yml` dispatch at the candidate tag.

### Consumers in production

| Repo | Actions used | Version |
|---|---|---|
| `lecture-dp` | Full chain: `restore-jupyter-cache`, `build-lectures`, `build-jupyter-cache`, `publish-gh-pages` | `@v0` ([lecture-dp#52](https://github.com/QuantEcon/lecture-dp/pull/52)) |
| `lecture-python.myst` | `preview-netlify` (ci.yml), `publish-gh-pages` | `@v0` ([lecture-python.myst#1029](https://github.com/QuantEcon/lecture-python.myst/pull/1029)) |
| `test-actions-lecture-intro` | Full chain + `preview-netlify` (sandbox and post-release canary — #100 stage 2, role documented in its README) | `@v0` |
| `lecture-jax` | `preview-netlify`, `publish-gh-pages` | **`@v0.11.1`** (2 call sites) |
| `lecture-python-intro` | `publish-gh-pages` | **`@v0.11.1`** |
| `lecture-python-advanced.myst` | `publish-gh-pages` | **`@v0.11.1`** |
| `lecture-python-programming` | `publish-gh-pages` | **`@v0.11.1`** |
| `lecture-python-programming.fr` | `preview-netlify` (ci.yml), `publish-gh-pages` (with `create-release-assets`) | **`@v0.11.1`** (2 call sites) |
| `continuous_time_mcs` | `publish-gh-pages` | **`@v0.11.1`** |

**Corrected 2026-08-11.** This section previously listed only the first three rows and stated "every consumer now tracks the floating `@v0` — 11 call sites, no exact pins left". That was wrong: **six exactly-pinned call sites exist across five lecture repos**, then two to three releases behind current. The audit is QuantEcon/workspace-lectures#31. Dependabot has since bumped all six to `@v0.11.1` (2026-08-12 to 2026-08-24); they remain exact pins, so since v0.12.0 (2026-09-24) every one is a release behind until its bump is merged. The omission matters because the argument below was reasoned partly from the incomplete table — `publish-gh-pages` is in fact at **7/7** adoption across the publishing lecture repos, and it is also the action every remaining pin sits on. **Added 2026-09-23:** `lecture-python-programming.fr`, which that audit did not cover, pins the same two actions exactly; Dependabot moved both call sites from `@v0.8.0` to `@v0.11.1` on 2026-09-23 (QuantEcon/lecture-python-programming.fr#76), so the exact pins now number eight call sites across six repos.

**Follow-ups from v0.12.0**, both outside this repo:

- Since v0.12.0, `publish-gh-pages` warns that `cname` has no effect on the deploy (the Actions Pages deploy ignores a `CNAME` file; the custom domain lives in Settings → Pages). Six consumers still pass it: `lecture-python.myst`, `lecture-jax`, `lecture-python-intro`, `lecture-python-advanced.myst`, `lecture-python-programming` and `continuous_time_mcs`. Only `lecture-python.myst`, on `@v0`, sees the warning today; the other five get it with their v0.12.0 bump. Each should drop the input.
- The canary's `ci.yml` should gain a permanent `preview-cloudflare@v0` step with `project-name: qe-preview-canary`, the Pages project the v0.12.0 staging deployed to (QuantEcon/test-actions-lecture-intro#66). Then CONTRIBUTING's Staged Releases known limit for it goes.

The case against exact pins still stands on its own evidence. Pins are what stranded `lecture-dp` three releases behind, which is why its weekly cache build ran for ~2 months with alerting that had never worked (#83). Pinning plus Dependabot was tried and is not sufficient: it surfaces the bump but currency still depends on someone merging it, and `lecture-python.myst#1000` sat open for 13 days before being closed as superseded.

**What does not stand is the claim that the canary "meets a bad release first".** That holds on exactly one consumer path. The canary's weekly cache build runs Sunday 03:00 UTC against consumers' Monday 02:00/03:00 UTC, a real 23–24 hour lead. Its `ci.yml` has `pull_request` and manual `workflow_dispatch` triggers but **no schedule**, and its `publish.yml` fires only on a `publish*` tag push in the canary — so **neither the preview nor the publish path has any automatic lead** over consumers, and publish is where output reaches readers. A manual dispatch can exercise preview on demand, but a gate cannot rest on someone remembering. More fundamentally, the canary pins `@v0`, the tag a release *moves*, so it only ever exercises a published release and cannot test a candidate unless someone stages one by hand (CONTRIBUTING.md, Staged Releases). Gating is #135; the fixture it needs is #136.

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
| 5 | ~~**`preview-cloudflare`: use the stable `pr-N` alias URL.**~~ Done (#131, v0.11.1) — `deploy-url` is now constructed from the branch alias rather than grepped from wrangler output, and the surviving `deployment-url` extraction ends `\|\| true` so the fallback is reachable. The capture itself stayed fatal under `pipefail` until #174 (v0.12.0) streamed it through `tee` (#105). | #14, #131 |

### P2 — surplus removal and quality

| # | Item | Refs |
|---|---|---|
| 6 | **Extract the shared PR-comment script.** The 87-line `github-script` comment renderer is near-identical (only 2 lines differ) across `preview-netlify` and `preview-cloudflare`; move it to a shared script parameterized by title/emoji, as `detect-changed-lectures.sh` already is. | — |
| 7 | ~~**Delete the dead `asset-url` output** in `publish-gh-pages`.~~ Done (#173, v0.12.0) — deleted with its README row, not repointed at `fromJSON(…assets)[0].browser_download_url`, which errors whenever the release step is skipped, the default. | #107, #173 |
| 8 | ~~**`preview-netlify`: move the auth token into `env:`.**~~ Done (#174, v0.12.0) — with the step's four other interpolated values. `--auth` and `--site` are gone: netlify-cli reads `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID` from the environment. | #105, #174 |
| 9 | ~~**CI coverage for standard-mode conda caching.**~~ Done — `test-actions.yml` (the #100 stage-1 harness) runs the two-run miss→hit chain on every PR touching `setup-environment`, plus a build on the restored env. | #29, #33, #100 |
| 10 | **Docs surplus trim.** ~4,900 doc lines for ~1,600 lines of action code, with four overlapping indexes. Absorbed by the user manual (#178, decision 4). Its PR 1 (#182) moved the developer docs to `docs/dev/` and deleted `docs/README.md`; the rest of this item (`QUICK-REFERENCE.md`, MIGRATION-GUIDE's per-repo notes, the copilot-instructions boilerplate, ARCHITECTURE's stale blocks) is its PRs 2–5. The corrected container-size figures were propagated in the #106 sweep (#175). | #40, #178 |
| 11 | **Document composite action vs reusable workflow.** Add the short decision rule to CONTRIBUTING.md or ARCHITECTURE.md so new CI lands at the right altitude. | #29 |
| 12 | **Environment manifest v1.** The publish-time manifest is a stub (name/tag/commit/size). Define a versioned schema, capture the effective environment (resolved `conda list`/`pip freeze`, container digest, build metadata), and `repository_dispatch` to `status-lectures`. | #30, meta#321 |

### P3 — housekeeping

| # | Item | Refs |
|---|---|---|
| 13 | ~~Merge safe Dependabot PRs.~~ Resolved — #90 (checkout v7, cache v6) merged; #88 (`action-gh-release` 3.0.1) closed. | PRs #90/#88 |
| 14 | ~~Harden `create-failure-issue.sh`.~~ Moot (#122) — the script was deleted, not hardened. Every concern it listed is structurally gone: `actions/github-script` has no `/tmp` body file, a failed API call throws rather than being swallowed by `2>/dev/null \|\| echo ""`, and a new step asserts an issue was actually filed. | #83, #122 |
| 15 | Small fixes. Done: `concurrency` + `timeout-minutes` in `build-containers.yml` (#111); the `build-lectures` pdflatex debug hint path (#173); the `setup-environment` README cache key and path (#175); `set -euo pipefail` in `check-latex-versions.sh` and the `restore-jupyter-cache` README's phantom "Age Information" block (#187). Left: `build-jupyter-cache`'s failure-issue repro commands omit `--path-output`, so a local repro writes to `lectures/_build` rather than `./_build` (#107's cosmetic residual). | #107, #111, #173, #175, #187 |
| 16 | Branch hygiene: delete the merged `fix-conda-activation` branch and prune the five stale (~5 months old) feature branches after confirming nothing is stranded. | — |
| 17 | Refresh TESTING.md dated status. | — |
| 18 | **Move the remaining `run:` interpolations into `env:`.** #105, #107 and #109 moved the values they touched, but `${{ }}` expressions still expand straight into `run:` scripts in seven of the eight actions (all but `deploy-cloudflare`). Most are step outputs, hashes or run ids; the ones carrying caller-supplied text are `build-lectures`' `builder`, `source-dir`, `output-dir`, `html-copy-pdf` and `html-copy-notebooks`, `publish-gh-pages`' `build-dir` and `asset-name`, `restore-jupyter-cache`'s `cache-type`, `key`, `path` and `save-cache` (the `key` and `path` step outputs carry the caller's text into later steps too), `setup-environment`'s `environment` and `environment-name`, and both preview actions' trusted-actor check (`github.actor`, the head repo name). None is exploitable today (the text is the calling workflow's own input or a GitHub-restricted name), but it is the pattern the repo otherwise avoids. | #35, #105 |

---

## Dependency policy

The lean image's science stack (`numpy`, `scipy`, `pandas`, …) is **pinned as a set** to the Anaconda baseline the lecture repos pin (currently `anaconda=2026.07`, moved in #199; 2026.06 came in #95). Drifting individual packages ahead of that baseline is what broke lecture execution in #28.

- Stack bumps happen as **one coordinated move** — both containers together, only when the lecture repos adopt a new anaconda baseline, validated by a container lecture-build run (and, once built, the #29 env-test harness).
- Dependabot handles everything else: minors/patches grouped per ecosystem, majors grouped for individual review (#67, #76). The conda stack should be excluded via `ignore` (backlog item 3).
- Urgent security fixes may cherry-pick a single package, with the deviation documented in `environment.yml`.

---

## Open issues disposition

| Issue | Status (July 2026 review) | Disposition |
|---|---|---|
| #83 cache failures silent | Addressed in #122. Note the earlier reading of this issue was wrong: the script-not-found 127 was *not* already fixed — it was the primary bug, caused by `${{ github.action_path }}` resolving to the runner's path inside a container. Missing `gh` was real but never reached, and a third bug (client-side label validation in `gh issue create`) broke alerting on hosted runners too. All three are gone with the move to `actions/github-script`; failure reports now upload via `upload-failure-reports`. The remaining variant (#123) is closed too, in #127 | Backlog items 2a, 14 (moot) |
| #123 setup failure alerts nobody | Fixed. The gap was one of guard *polarity*, not of the alerting mechanism: every downstream step tested `all-passed == 'false'`, and a composite that aborts before `verify-builds` leaves that output `''`. Found by reading rather than from a live incident — the canary's silent weeks were build failures, not setup failures. One residual is deliberately out of scope: if the job itself never starts, or is cancelled, timed out, or loses its runner, no step runs at all — `always()` included — so nothing can be filed from inside the action. Covering that needs a workflow-level `if: failure()` notify job in the consumer repo, or a scheduled sweeper | Backlog item 2a |
| #14 Cloudflare alias URL | Closed — shipped in #131 (v0.11.1) | Backlog item 5, done |
| #29 composite-vs-workflow docs + env harness | Docs half still valid; the env-harness half is overtaken by the live canary | Backlog item 11 (item 9 done) |
| #30 env/config manifest | Partially addressed — v0 stub exists | Backlog item 12 |
| #18 container-mode caching | Re-scoped — pre-baking covers the common stack; only the per-lecture delta install is uncached. Quantify before investing | Keep open, low priority |
| #27 HTML recovery tool | Still valid — producer half exists (release assets + checksums); consumer unbuilt. Likely belongs in `workflow-backups`, not here | Decide home, then build |
| #2 isolated lecture execution | Exploratory — most tractable first step is an execution check of the *built* notebooks, which nothing in the repo executes today | Keep open, low priority |

Issues opened after the July review, dispositioned in the August 2026 triage and refreshed 2026-09-23; the rows v0.12.0 closed are updated to 2026-09-24:

| Issue | Status | Disposition |
|---|---|---|
| #105 preview error surfacing, CLI pinning, fork guidance | Closed — v0.12.0: the `pull_request_target` README warning in #170; deploy-error surfacing, lockfile-pinned CLIs (decision 2 on #110) and the Netlify `env:` move in #174 | Closed backlog item 8 |
| #107 correctness batch across the actions | Closed — v0.12.0 (#173), carrying #109's three code items | Closed backlog item 7; its cosmetic `--path-output` residual moved to item 15 |
| #106 docs sweep to the 2026.06 baseline | Closed — v0.12.0: the size job fixed in #172, the sweep in #175 (baseline, both measured image sizes, the TeX Live wording, this table and CONTRIBUTING's `PLAN.md` row) | — |
| #109 reconcile READMEs and templates with the code | Closed — v0.12.0: docs in #175, code items in #173, template checkouts in #168 | Backlog item 10 continues in #178 |
| #99 QUICK-REFERENCE Pages-404 permissions | Fixed in #175 (v0.12.0), with the two stale `build-jupyter-cache` key lines | Closed as a duplicate of #109 |
| #100 publish/preview/cache logic untested | Re-scoped — stage 1 shipped in v0.10.0 and the canary is live; stages 2–3 and the coverage gaps remain | Release gating split out to #135/#136/#138 |
| #92 optimize preview builds (tracking) | Sub-issue parent since 2026-08-13: every open phase item is filed (#146–#158). Decision 2 settled (Cloudflare Workers static assets, #145) | Decision 1 (#146) gates the largest Phase 1 win (#148); decision 3 rides the #152/#155 pilots |
| #108 unify container smoke tests | Closed — majority in v0.11.0 (#125), the residuals (fixture theme and fonts, dead `test-container.sh`, `run-local-tests.sh` flags) in #171 (v0.12.0) | — |
| #102 raw-GitHub 429 flake | Body superseded — the fix is CI-side retry, not the lecture-side change. #144 is open (retry, plus `lecture-python-programming` back in the matrix) | Rebase and review #144; validate by a maintainer dispatch after merge, since the workflow has no PR trigger |
| #97 `-n` nitpick default + extra-args passthrough | Live | Needs an org HTML-strictness decision first |
| #96 sync-notebooks action | Live, but unacknowledged tension with the v0.6.0 gh-pages-notebooks architecture | Sequencing decision required |
| #98 `_build/.doctrees` clear | Live — the mechanism is intra-job doctree reuse across builders, not cache staleness | Needs a falsifiable repro |
| #110 July 2026 audit tracking | Closed — all seven sub-issues delivered (#103 and #104 in v0.9.0, #105–#109 completed in v0.12.0). Its four decisions stand: the docs trim (now #178), CLI pinning by lockfile, both image sizes published, and staged releases (CONTRIBUTING.md) | Two consumer follow-ups under Consumers in production |
| #115 external actions worth studying | Reading list, no completion condition | Keep parked |
| #129 reproducibility of published lectures | Accurate and deliberately parked | Discussion; relates to #30 |
| #135 release gating via a `v0-next` staging tag | Unbuilt; parent #138, fixture #136. Until it lands, releases that change action behaviour are staged by hand (CONTRIBUTING.md, Staged Releases; first used for v0.12.0) | Backlog items 0b–0d |

---

## Rollout status

### Phase 1: `lecture-dp` — ✅ complete

`lecture-dp` runs the full chain (`restore-jupyter-cache` → `build-lectures` → `build-jupyter-cache` → `publish-gh-pages`) in production at `@v0` (moved in lecture-dp#52). Production use surfaced the #83 alerting gaps — a weekly cache build failed for roughly two months with no alert issue and no downloadable traceback, which is what motivated the (now closed) P0 item above.

### Phase 2: migrate existing repos

Incremental migration, previews first (see [meta#327](https://github.com/QuantEcon/meta/issues/327)), CPU-only full chains next, GPU last:

**`publish-gh-pages` is separately at 8/8** across the publishing lecture repos and is not tracked by this table — the table is about the *full chain*. Six of those eight are on exact pins; see Consumers in production above.

| # | Repository | Runner | Status |
|---|---|---|---|
| 1 | `lecture-python.myst` (previews) | GPU | ✅ live, now on `preview-netlify@v0` (was `@v0.8.0`) |
| 2 | Remaining python repos (previews) | Container | ⏳ `lecture-jax` done (`@v0.11.1`); four still on `nwtgck/actions-netlify` — meta#327, QuantEcon/workspace-lectures#2 |
| 3 | `lecture-python-intro` (full chain) | Container | ⏳ Planned — blocked on #97 and #98 |
| 4 | `lecture-python-programming` (full chain) | Container | ⏳ Planned — blocked on #97 and #98 |
| 5 | `lecture-python-advanced.myst` (full chain) | Container | ⏳ Planned |
| 6 | `lecture-python.myst` (full chain) | RunsOn GPU | ⏳ Blocked on RunsOn verification (below) |

`lecture-jax` is the suggested full-chain pilot: it is the smallest of the native five and is **not** blocked by #97/#98, which bite intro and programming specifically. See QuantEcon/meta#348.

Per-repo checklist: create migration branch → `setup-environment` → `build-lectures` → cache actions → preview action → `publish-gh-pages` → validate output against production → measure → merge and monitor.

### Remaining blockers for the GPU repo

The February 2026 gap analysis concluded every `lecture-python.myst` build feature is supported (full matrix in git history). Two verification items remain before its full-chain migration:

- [ ] **`actions/cache` on RunsOn** — confirm cache save/restore works on the self-hosted GPU runners
- [ ] **OIDC Pages deployment from RunsOn** — confirm `actions/deploy-pages` token flow works from self-hosted runners

Settled architectural decisions: eliminate the `.notebooks` repos in favour of gh-pages notebooks + theme-generated Colab URLs ([quantecon-book-theme#359](https://github.com/QuantEcon/quantecon-book-theme/issues/359)); notebook-zip stays an inline workflow step; `collab.yml` and `linkcheck.yml` remain standalone workflows.
