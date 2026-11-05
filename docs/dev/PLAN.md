# Plan

Current priorities for `QuantEcon/actions`, the repositories that use the actions and how far each has moved onto them, and the dependency policy. What has been done is in the [CHANGELOG](../../CHANGELOG.md), the issues and git; the work plan in progress is #246.

## Current state

- **Actions (8):** `setup-environment`, `build-lectures`, `build-jupyter-cache`, `restore-jupyter-cache`, `preview-netlify`, `preview-cloudflare`, `publish-gh-pages`, `deploy-cloudflare`. Latest release **`v0.15.0`** (2026-11-05), and `@v0` points to it.
- **Containers (2):** `quantecon` (full) and `quantecon-build` (lean), on the Anaconda 2026.07 baseline, with the Ubuntu base pinned by digest. See the Dependency policy below, and [CONTAINERS.md](CONTAINERS.md).
- **Testing:** the action harness on every pull request, the container checks, and the canary repository; see [TESTING.md](TESTING.md). A release that changes what an action does is staged by hand on the canary before `v0` moves ([CONTRIBUTING.md](../../CONTRIBUTING.md#staged-releases)).

## Consumers in production

| Repo | Actions used | Version |
|---|---|---|
| `lecture-dp` | Full chain: `restore-jupyter-cache`, `build-lectures`, `build-jupyter-cache`, `publish-gh-pages` | `@v0` |
| `lecture-python.myst` | `preview-netlify` (ci.yml), `publish-gh-pages` | `@v0` |
| `test-actions-lecture-intro` | Full chain, `preview-netlify` and `preview-cloudflare` (`qe-preview-canary`): the canary | `@v0` |
| `lecture-jax` | `preview-netlify`, `publish-gh-pages` | **`@v0.12.0`** (2 call sites) |
| `lecture-python-intro` | `publish-gh-pages` | **`@v0.12.0`** |
| `lecture-python-advanced.myst` | `publish-gh-pages` | **`@v0.12.0`** |
| `lecture-python-programming` | `publish-gh-pages` | **`@v0.12.0`** |
| `lecture-python-programming.fr` | `preview-netlify` (ci.yml), `publish-gh-pages` (with `create-release-assets`) | **`@v0.12.0`** (2 call sites) |
| `continuous_time_mcs` | `publish-gh-pages` | **`@v0.12.0`** |

Eight call sites across six repositories are exact pins, all on `@v0.12.0` (checked 2026-11-05). Each falls a release behind whenever one ships, until someone merges its Dependabot bump. Exact pins are what stranded `lecture-dp` three releases behind, with alerting that had never worked (#83), and a Dependabot bump surfaces a release without moving the pin: `lecture-python.myst#1000` sat open for 13 days before it was closed as superseded. Moving the lecture family to `@v0` (QuantEcon/workspace-lectures#33) waits on release gating, P0 below.

The canary meets a release first on one path only. Its weekly cache build runs on Sunday at 03:00 UTC, a day ahead of the consumers' Monday builds. But its `ci.yml` runs on pull requests and by hand, with no schedule and no `dispatch-alias`, and its `publish.yml` runs only on a `publish*` tag, so neither the preview path nor the publish path has an automatic lead over consumers. And its workflows name `@v0`, the tag a release moves, so they test a candidate only when someone stages one by hand.

Lecture repositories are tracked centrally in [QuantEcon/meta#321](https://github.com/QuantEcon/meta/issues/321), and the preview rollout in [QuantEcon/meta#327](https://github.com/QuantEcon/meta/issues/327).

## Priorities

The numbered items keep the numbers the July 2026 review gave them, which issues cite.

### P0: release gating (#138)

A release reaches a published lecture site before any test has met it, unless it is staged by hand. The gate is a workflow in the canary that tests a checkout of the candidate (decided on #143), not a second repository or a `v0-next` tag.

| # | Item | Refs |
|---|---|---|
| 0a | **The gate's fixture**, in its own folder in the canary. Purpose-built, about five lectures, all three builders, and a staged-failure self-test from the start. It must cover plotly/kaleido static export, which the container smoke fixture covers and the canary does not. Gate builds are frozen: the image by a committed digest, cold builds, intersphinx off, so a run reads nothing that has moved since the last one. The canary's other workflows keep `quantecon-build:latest` and `@v0` | #136, #85, #143 |
| 0b | **`gate.yml` in the canary, green before `v0` moves.** A `workflow_dispatch` workflow that takes the candidate as an input, checks it out and calls `uses: ./actions-repo/<action>`, which works in container jobs. It accepts only commits reachable from `main` or a `v*` tag, and its secrets live in a canary environment restricted to the canary's `main`. It covers `build-jupyter-cache`'s sibling chain by rewriting the four `uses: …@v0` lines to local paths before the step runs, at the cost of testing a patched `action.yml`; it does not exercise how consumers fetch the actions by tag. `publish-gh-pages` is in the gate for its deploy only: the release-asset packaging is tested in this repository's harness (`publish-release-packaging`). The preview leg deploys and asserts through `dispatch-alias` and `deployed` | #135, #143, #227 |
| 0c | **Close the ungated consumer paths regardless of 0b.** Schedule the canary's `ci.yml` and `publish.yml` ahead of the consumers' Monday builds. `publish.yml` has no `workflow_dispatch`, and its job-level `if:` accepts only tag pushes, so a scheduled or dispatched run would skip its only job and never go red. `ci.yml` should pass `dispatch-alias` and fail unless `deployed` is `'true'` | #135, #136 |
| 0d | **Prove the gate can stop a release, and that a red gate reaches a person.** Both have precedent here: container smoke tests that could not fail (#108), and a canary that failed eight weeks running and filed no issue (#83) | #135, #83, #108 |

### Backlog

| # | Item | Refs |
|---|---|---|
| 11 | **Composite action or reusable workflow.** A short decision rule, in CONTRIBUTING.md or ARCHITECTURE.md, so new CI lands at the right level | #29 |
| 12 | **Environment manifest v1.** The publish-time manifest holds name, tag, commit and size. Define a versioned schema, record the effective environment (the resolved `conda list` and `pip freeze`, the container digest), and send it to `status-lectures` by `repository_dispatch` | #30, meta#321 |
| 15 | **Small fixes.** `build-jupyter-cache`'s failure-issue repro commands omit `--path-output`, so a local repro writes to `lectures/_build` rather than `./_build` (#229). Its failure alert can land on an open pull request that carries the label, instead of an issue (#238) | #229, #238 |
| 18 | **The remaining `${{ }}` in `run:` scripts.** Five actions still expand expressions straight into `run:` text: all but `deploy-cloudflare` and the two preview actions. The ones carrying caller-supplied text are `build-lectures`' `builder`, `source-dir`, `output-dir`, `html-copy-pdf` and `html-copy-notebooks`; `publish-gh-pages`' `build-dir` and `asset-name`; `restore-jupyter-cache`'s `cache-type`, `key`, `path` and `save-cache`; and `setup-environment`'s `environment` and `environment-name`. None is exploitable today, since the text is the calling workflow's own, but it is the pattern the rest of the repository avoids. #236, input validation in `restore-jupyter-cache`, touches the same inputs | #228, #236 |

## Dependency policy

The lean image pins every package in its `environment.yml` that the `anaconda` metapackage also pins, at the metapackage's version, currently `anaconda=2026.07`. Drifting a package ahead of that baseline is what broke lecture execution in #28 and plotly export in #222. Packages the metapackage does not contain, transitive dependencies and the pip layer's `>=` floors still float.

- **The stack moves as one coordinated change:** both images together, only when the lecture repositories adopt a new Anaconda baseline, validated by the lecture matrix.
- **Dependabot handles everything else,** minors and patches grouped per ecosystem and majors grouped for review. Every baseline-pinned conda package is under `ignore` in `.github/dependabot.yml`, so it is never proposed past the baseline.
- **An urgent security fix** may move a single package, with the deviation noted in `environment.yml`.
- **No scheduled rebuilds** (#234). Both Dockerfiles pin the `ubuntu:24.04` base by digest, and Dependabot proposes each new 24.04 digest as one pull request for both images, which builds and smoke-tests them before `:latest` moves. A schedule would republish an unchanged image when the base had not moved, and re-resolve the floating packages with no pull request when it had. `validate-containers.yml` checks on every harness run that both images pin the same digest. The lecture matrix runs weekly against `:latest` on its own, so drift in the lecture repositories is still caught. What the pin does not make reproducible is #129.

## Open issues

| Area | Issues | Where it stands |
|---|---|---|
| Release gating | #138 (tracking), #135, #136 | P0, items 0a–0d |
| Testing | #100 | Stage 1, the harness, and the canary are live; the gate is split out to #138 |
| Container validation | #188 (tracking), #142, #141, #196 | #142's phase 1 builds and smoke-tests an image on its pull request; phase 2 promotes a tested digest and moves `:latest` only on green. #141 and #196 are `lecture-python.myst`'s build time against the lecture matrix's ceiling |
| Preview speed | #92 (tracking), #145, #147–#152, #154–#158, #160 | HTML-only previews are decided (#146): #148 is unblocked, and the PDF check that goes with it is in `templates/ci.yml`. #160 is stale pages republished from the build cache |
| Small fixes and hardening | #216, #217, #228, #229, #236, #238 | Backlog items 15 and 18; #216 and #217 are documented in the `preview-cloudflare` and `build-lectures` chapters |
| Environment and reproducibility | #30, #129, #18, #224, #2 | #30 is backlog item 12; #129 is parked as a discussion; #18, container-mode caching, needs measuring first; #224 caches the TeX Live install that standard-runner PDF builds download on every run, which a slow mirror can stall for hours; #2 is exploratory |
| Build strictness | #97, #98 | #97 needs an org-wide decision on HTML strictness; #98 needs a falsifiable repro |
| New actions and decisions | #27, #96, #183, #184, #185, #186, #194, #195 | #27 is decided: a `restore-gh-pages` action and template, built here. #96 waits on #195, whether the `.notebooks` repos go first. #183 tracks alternatives to the RunsOn GPU image. #184 and #185 propose shared actions for link checking and Colab checks, which #194 asks whether to build; #186 proposes build-time monitoring across the lecture repositories |
| Docs | #29, #178, #179 | #29 is backlog item 11; #179 publishes the manual |
| Work plan | #246 | The decisions of 2026-11-04 and the waves that carry them out |

## Rollout status

### Phase 1: `lecture-dp` — complete

`lecture-dp` runs the full chain in production at `@v0`.

### Phase 2: the other lecture repositories

Previews first ([meta#327](https://github.com/QuantEcon/meta/issues/327)), then CPU full chains, GPU last. `publish-gh-pages` is already at 8/8 across the publishing lecture repositories, six of them on exact pins (Consumers, above); this table is about the full chain.

| # | Repository | Runner | Status |
|---|---|---|---|
| 1 | `lecture-python.myst` (previews) | GPU | Live, on `preview-netlify@v0` |
| 2 | Remaining python repos (previews) | Container | `lecture-jax` is done (`@v0.12.0`); four repos are still on `nwtgck/actions-netlify` (meta#327, QuantEcon/workspace-lectures#2) |
| 3 | `lecture-python-intro` (full chain) | Container | Planned; blocked on #97 and #98 |
| 4 | `lecture-python-programming` (full chain) | Container | Planned; blocked on #97 and #98 |
| 5 | `lecture-python-advanced.myst` (full chain) | Container | Planned |
| 6 | `lecture-python.myst` (full chain) | RunsOn GPU | Blocked on the RunsOn checks below |

`lecture-jax` is the suggested full-chain pilot: it is the smallest of the five, and #97 and #98 bite intro and programming only (QuantEcon/meta#348).

Each repository follows the user manual's [Migrating an existing repository](../user/getting-started.md#migrating-an-existing-repository): cache first, then the pull-request workflow, then publishing. What differs by repository:

- **`lecture-python.myst`** builds on RunsOn GPU runners (`runs-on: "runs-on=${{ github.run_id }}/family=g4dn.2xlarge/image=quantecon_ubuntu2404/disk=large"`), whose machine image carries the QuantEcon marker file, so `setup-environment` runs in container mode there. Its ML libraries (JAX, PyTorch, numpyro) come from the repository's own environment files, through `environment-update`. Its `collab.yml` runs in Google Colab's container and stays a standalone workflow.
- **`lecture-python-intro`, `lecture-python-programming` and `lecture-python-advanced.myst`** build on CPU in a container, as the templates do, with LaTeX for the PDF and Netlify previews. Beyond #97 and #98 for intro and programming, they need nothing the templates lack.

Before `lecture-python.myst`'s full chain, two things are unconfirmed on RunsOn's self-hosted GPU runners:

- `actions/cache` saving and restoring;
- the OIDC token flow of `actions/deploy-pages`.

Settled: the `.notebooks` repositories give way to notebooks on gh-pages with theme-generated Colab URLs ([quantecon-book-theme#359](https://github.com/QuantEcon/quantecon-book-theme/issues/359)); the notebook zip stays an inline workflow step; `collab.yml` and `linkcheck.yml` stay standalone workflows; and the HTML recovery tool (#27) is built here as a restore action, with no off-GitHub copy of the release archives, since the sources are the backup.
