# Testing

How a change to this repository is tested: the action harness on every pull request, the container checks, the canary lecture repository, and what you can run locally. The last section says what none of them covers.

| Where | What it tests | When it runs |
|---|---|---|
| [`test-actions.yml`](../../.github/workflows/test-actions.yml), the action harness | Each action at the pull request's commit, the templates' hand-offs between jobs, and the user manual | Every pull request, every push to `main`, and by hand |
| [`validate-containers.yml`](../../.github/workflows/validate-containers.yml), called by the harness | Each image a pull request changes, built as a `pr-<N>` candidate and smoke-tested | Within the harness, on a pull request that changes an image |
| [`test-container.yml`](../../.github/workflows/test-container.yml) | The smoke test and size report, on an image's candidates before they can reach `:latest` | Called by `validate-containers.yml` on a pull request's candidates and by `build-containers.yml` on main's, before it promotes them; and by hand for any tag |
| [`test-containers-lectures.yml`](../../.github/workflows/test-containers-lectures.yml) | Four lecture repositories built in both images | After each promotion to `:latest`, weekly on Monday at 02:00 UTC, and by hand |
| [QuantEcon/test-actions-lecture-intro](https://github.com/QuantEcon/test-actions-lecture-intro), the canary | A release, in a real lecture repository, with real deploys | On its own pull requests and weekly cache build, and for what the release gate does not reach |
| [`gate.yml`](https://github.com/QuantEcon/test-actions-lecture-intro/blob/main/.github/workflows/gate.yml) in the canary, the release gate | A release candidate, checked out and run on a frozen fixture: the cache build, both restores, both previews and a GitHub Pages deploy | By hand, on the canary's `main`, before `v0` moves |

## The action harness

`test-actions.yml` calls each action as `uses: ./<action>`, so it tests the code on the pull request, not a released tag. Its required check is `Action harness: all checks`.

### The gate

The workflow has no `paths:` filter: a filtered-out workflow publishes no check run, and a required check would then wait forever. Instead its first job, `gate`, decides whether the change can affect the actions:

- **`IGNORED`** is a list of paths that cannot, such as the root docs, `docs/`, `tests/` and `templates/`. It is an ignore list, not a cover list, so a path it does not recognise runs the whole harness: forgetting to extend it costs CI minutes, never a green check earned by running nothing.
- **A self-test** fails the gate if `IGNORED` would match any file the harness must run for: each action's `action.yml`, which it reads from the workflow's own `uses: ./<action>` lines, the shared scripts and lockfiles, and the container files. It also checks that `IGNORED` still matches the paths it is meant to.
- **The checks a docs-only change still needs** run in the gate itself, because such a change skips every other job: the templates pin the same third-party actions as `.github/workflows/`, and `scripts/generate-docs.py --check --check-examples --actionlint` finds the manual's generated tables current, a chapter for every action, and every example valid. [CHAPTER-TEMPLATE.md](CHAPTER-TEMPLATE.md) lists those checks.
- **actionlint over `.github/workflows/`** runs in the gate too, on every event, so a problem in any workflow fails the required check. actionlint lints each `run:` script with shellcheck, and silently skips them when it finds none, so the gate fails when the runner image has no shellcheck, and logs both tools' versions. An ignore goes in `.github/actionlint.yaml`, which actionlint reads by default, limited to one file and saying why.
- **shellcheck over the actions' `run:` scripts and `scripts/*.sh`** runs in the gate as well, through [`scripts/lint-shell.py`](../../scripts/lint-shell.py), because actionlint never reads an `action.yml`. It fails on any `${{ }}` in a `run:` script, an action's or a workflow's, since a value belongs in the step's `env:`, and on any shellcheck finding of warning severity or above, reported at its line in `action.yml`. The container scripts under `containers/` are left out, since a change there rebuilds both images.

`harness-summary`, the job behind `Action harness: all checks`, passes only if the gate succeeded and either every job succeeded, when the gate found the change relevant, or every job was skipped, when it did not. Any other mix fails it.

### Fixtures

- **`.github/fixtures/mini-lectures/`**: a two-page book with a code cell that really executes, so a build writes a genuine `_build/.jupyter_cache`. Cache keys are salted with the run's id and attempt, so one run's caches cannot satisfy another's miss assertions.
- **`.github/fixtures/access-gate/server.py`**: a local stand-in for a Cloudflare Access gate, which answers in every shape the `deploy-cloudflare` gate probe has to tell apart, over TLS when a job needs it.
- **`.github/fixtures/preview-comment/`**: the comment bodies the preview actions must render for given inputs, and a stand-in for GitHub's API that the comment script runs against.
- **`.github/fixtures/release-stub/gh`**: a stand-in for the `gh release view` and `gh release download` calls `restore-gh-pages` makes, serving releases from a directory, and recording any call it does not expect.

The container smoke fixture in `containers/quantecon/tests/` is separate: it tests an image, not the actions. See [CONTAINERS.md](CONTAINERS.md#the-smoke-test).

### What each action's jobs cover

| Action | Jobs | What they assert |
|---|---|---|
| Every action | `workflow-command-helper`, `inputs-line-break` | `scripts/workflow-command.sh`, which every action sources, escapes a workflow command's data and names each input that holds a line break, and a step that cannot find it fails; each action refuses a line break in an input that is one value in its first step, before anything prints it (#267) |
| `restore-jupyter-cache` | `unit-build-*`, `unit-exec-*`, `unit-custom-*`, `unit-line-break`, `unit-input-values` | For both cache types: a genuine miss, a read-only restore that stays quiet, a restore in save mode (#104), and `fail-on-miss` firing on a miss; an execution restore missing after a change to the environment file alone, and falling back to the cache build's after a lecture edit (#270); a build restore removing the restored `html` and keeping `.jupyter_cache`, `jupyter` and `latex`, where an execution restore leaves an `html` alone (#160); a custom `key` saved and restored exactly, into a `path` holding a space and a `$`, taken as written; a line break in `key` or `path` failing the action before anything is restored (#228); and a `cache-type`, `save-cache` or `fail-on-miss` outside its accepted values, or an empty `path`, failing it too (#236) |
| `setup-environment` | `env-*` | In standard mode, a cold Conda cache and then a warm one with a build on the restored environment; a `cache-version` bump that restores nothing, and an edited environment file that restores through the fallback (#205); for a pinned stack, an exact hit and a fallback restore that each hold one working pip (#209). With `install-latex: 'true'`, a LaTeX cache miss that installs a working `pdflatex`, then an exact hit that installs it with no request to any mirror (#224). In container mode, that the delta lands in the environment on `PATH` |
| `setup-latex` | `latex-*`, and a case in `inputs-line-break` | A miss that downloads, installs a working `pdflatex` and saves the cache; an exact hit on another runner of the same image that installs it with no request to any mirror, through apt's proxy pointed at a stand-in that records every request, and with the maintainer scripts run (#224); a changed list that restores through the fallback, downloads the rest and keeps only the archives it needed; `download-timeout-minutes` stopping a mirror that trickles forever; every bad list or input failing before anything is prepared, and the script's `prepare` failing, and saying why, with a `sudo` that asks for a password; and, on a container-mode host, nothing installed |
| `build-lectures` | `env-hit-build`, `build-fail-guard`, `build-display-error-guard`, `build-jupyter-warning-guard`, `build-html-copy` | A real build of the fixture, with its executed output; that a cell that raises fails the step; that an error raised while IPython displays a result fails it too (#247); that a `jupyter` build under `-W --keep-going` fails the step on its warnings, where `jb build` exits 0, passes with none, and passes them without `-W`, and that the error-output check reports a cell that raised as one (#300); and that `html-copy-pdf` and `html-copy-notebooks` copy a PDF and two notebooks into the site, a nested one at its own path (#217), and that a failed copy fails the step |
| `build-jupyter-cache` | `bjc-*` | A build that saves both caches, which the round-trip jobs then restore; a failing build that saves nothing; an abort before the builds that still reports failure; `builders` parsed by exact token; the failure alert's script, run against a stand-in for the GitHub API: a repro command for each failed build that builds where the action does, a comment on the open labelled issue and never on a labelled pull request, and a verification step that fails on a pull request's URL |
| `preview-netlify`, `preview-cloudflare`, `preview-workers` | `preview-*` | The pinned CLIs install from their lockfiles and run; the deploy decision for each combination of event, actor, fork and `dispatch-alias`; change detection against a scratch repository, shallow and full; the comment, rendered against the API stand-in, finding only its own; `preview-cloudflare`'s preview URL, built on the address in wrangler's record of the deploy, against a stub wrangler; `preview-workers`' Worker name, subdomain and alias rules, its preview URL set only when wrangler's record of the upload names it, against a stub wrangler, and the pinned wrangler accepting its generated configuration and writing that record, in a dry run (#145); and each action installing its CLI only for a deploy, refusing a bad input first |
| `publish-gh-pages` | `publish-release-packaging`, `publish-modes` | The release assets' names, layout, checksum and manifest; `mode: upload` working with read access alone, and a mode the inputs cannot carry out failing before anything is uploaded |
| `restore-gh-pages` | `restore-round-trip`, `restore-refuses`, and a case in `inputs-line-break` | Against releases packed by `publish-gh-pages`' own packing script and served by a stand-in `gh`: each restored exactly, hidden files included, whether the archive is found by its tag or named by `asset-name`, with `commit` from the manifest or empty without one (#27); a bad tag or `asset-name` failing before `gh` is called; and no release, no archive, two archives, no checksum, a checksum naming another file, an archive changed after its checksum, and an archive holding a symlink or a path through `..`, each failing with no site left behind. The real releases API, and the hand-off to `publish-gh-pages`, are the canary's |
| `deploy-cloudflare` | `dc-*` | The Access gate probe telling every response apart, gated and public; the action refusing an ungated Worker, or one that contradicts `visibility`, before it installs anything; every invalid input failing in validation, a missing `visibility` and any `require-access` among them; and the pinned wrangler accepting the generated configuration |

The templates have jobs of their own: `pdf-check-*` runs `ci.yml`'s PDF check hand-off and its `PDF_CHECK: 'false'` switch, and `preview-site-handoff` and `preview-deploy-job` its build-to-deploy hand-off, with change detection fetching no stored credentials. `container-images` is the call to `validate-containers.yml`.

`build-jupyter-cache` runs `setup-environment` and `build-lectures` at `@v0`, because GitHub does not allow an expression in `uses:`. So in the harness, as for consumers, those two run as the latest release, not as the pull request has them.

### Adding a job

- Put it beside the related jobs, and add it to `harness-summary`'s `needs:`. A job that must be skipped stays out of `needs:`, since the summary fails a skipped job; check its skip from another job, as the `pdf-check-switch-*` jobs do.
- Show that it can fail: run it once against the bug it guards, or with the assertion inverted, and say so in the pull request.
- If the job needs a file the gate would ignore, check the gate's self-test still passes.

## Containers

A pull request that changes an image builds and smoke-tests it before it can merge. The merge rebuilds the images, smoke-tests them again, and moves `:latest` only if every smoke test passes; the lecture matrix then runs against the promoted images. [CONTAINERS.md](CONTAINERS.md) describes that path and the smoke test, and [CONTAINER-VALIDATION.md](CONTAINER-VALIDATION.md) the lecture matrix and its results.

## The canary

[QuantEcon/test-actions-lecture-intro](https://github.com/QuantEcon/test-actions-lecture-intro) is a lecture repository kept for testing the actions. It pins `@v0` and runs the full chain:

- `ci.yml`, on its pull requests and by hand: `restore-jupyter-cache`, `build-lectures`, and real deploys with both `preview-netlify` and `preview-cloudflare`;
- `cache.yml`, weekly on Sunday at 03:00 UTC and by hand: `build-jupyter-cache`;
- `publish.yml`, on a `publish*` tag: `publish-gh-pages`.

In a staged release, a branch of the canary points these at the candidate tag only for what the release gate does not reach: see [Staged Releases](../../CONTRIBUTING.md#staged-releases).

### The release gate

`gate.yml` in the canary tests a candidate before `v0` moves. It is dispatched on the canary's `main` with `candidate`, a commit SHA or a `v*` tag of this repository, and refuses one that is reachable from neither `main` nor a `v*` tag, before any job that holds a secret. It checks that commit out and runs every action from it, as `uses: ./actions-repo/<action>`, on the fixture in the canary's `gate/`. The fixture's image is pinned by digest, its pages read nothing from the network, and Dependabot updates nothing in it, so a red gate means the candidate.

- **The cache build:** `build-jupyter-cache` with all three builders and nothing restored, after its four nested `uses: quantecon/actions/…@v0` lines are rewritten to the checkout, so its siblings run at the candidate. A nested call left over fails the job. It checks that every page executed, from a line each page prints, in the HTML and the PDF's LaTeX.
- **Two site builds** restore that run's caches, the execution cache as `templates/ci.yml` does and the build cache as the canary's `ci.yml` does, and must restore that run's key.
- **The deploys** run in jobs of their own that execute no notebook, under environments that allow `main` only: `preview-netlify` and `preview-cloudflare` with `dispatch-alias: dispatch-release-gate`, which must report `deployed`, and `publish-gh-pages` in its `upload` and `deploy` modes. Each deployed URL must serve a marker file holding the candidate's SHA, compared by content.
- **The verdict** passes only if every job did. A red run from `main` opens or comments on a `release-gate` issue in the canary, assigned to whoever dispatched it.

`self-test: build-fails` appends a raising cell to the fixture, and `self-test: nothing-deployed` runs the previews without their alias. Each must turn the gate red. On any branch but `main` the deploy jobs are refused, so such a run is always red, and the jobs before the deploys show whether the build works.

## Locally

- **The manual's checks**: `python3 scripts/generate-docs.py --check --check-examples --actionlint "$(command -v actionlint)"`, with the actionlint release the gate pins.
- **The workflows**: `actionlint` from the repository's root, with no arguments. Both actionlint commands lint `run:` scripts only when a `shellcheck` is on your `PATH`, and `pip install shellcheck-py` into a virtual environment provides one. A shellcheck version other than the one the gate logs can report differently.
- **The actions' shell**: `python3 scripts/lint-shell.py`, with that shellcheck, or another given as `--shellcheck PATH`. It prints the version it ran.
- **A larger book**: clone a real lecture repository into `tests/local/`, which git ignores; see [tests/README.md](../../tests/README.md).
- **The images**: build them as [CONTAINERS.md](CONTAINERS.md#building-locally) shows, and run the smoke test on macOS with `containers/quantecon/tests/run-local-tests.sh`.
- **An action from a branch**: in a lecture repository, point a step at `quantecon/actions/<action>@<branch>`.

## What is not covered

- **Real deploys.** No harness job deploys anywhere: that needs real sites and secrets. The release gate deploys both previews and GitHub Pages for each candidate, and the canary's pull requests and tag runs deploy them too; a `deploy-cloudflare` deploy is proven only by the first consumer run after a release.
- **A filed failure issue.** The harness checks the issue's text and the guards that lead to it, but filing one needs `issues: write` and would open real issues on every run, so only an unattended consumer or canary run files one.
- **`build-jupyter-cache` exactly as shipped, at the candidate.** In the harness its siblings run at `@v0`. The release gate runs them at the candidate, but in a copy of the action with its nested calls rewritten.
- **How consumers fetch a release.** The release gate runs the actions from a checkout, so the download a consumer's `uses: …@v0` makes is first exercised after `v0` moves. And the gate runs when a releaser dispatches it, not on a schedule.
- **`setup-environment` outside a container, `setup-latex`, `deploy-cloudflare` and `preview-workers` at the candidate.** The gate builds in a container and deploys to no Worker; a release that changes them stages them by hand.
- **The lecture repositories' own content**, beyond the four the lecture matrix builds.
