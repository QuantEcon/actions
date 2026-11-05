# Testing

How a change to this repository is tested: the action harness on every pull request, the container checks, the canary lecture repository, and what you can run locally. The last section says what none of them covers.

| Where | What it tests | When it runs |
|---|---|---|
| [`test-actions.yml`](../../.github/workflows/test-actions.yml), the action harness | Each action at the pull request's commit, the templates' hand-offs between jobs, and the user manual | Every pull request, every push to `main`, and by hand |
| [`validate-containers.yml`](../../.github/workflows/validate-containers.yml), called by the harness | Each image a pull request changes, built as a `pr-<N>` candidate and smoke-tested | Within the harness, on a pull request that changes an image |
| [`test-container.yml`](../../.github/workflows/test-container.yml) | The smoke test and size report, on both `:latest` images | After each image build, and by hand for any tag |
| [`test-containers-lectures.yml`](../../.github/workflows/test-containers-lectures.yml) | Four lecture repositories built in both images | After each image build, weekly on Monday at 02:00 UTC, and by hand |
| [QuantEcon/test-actions-lecture-intro](https://github.com/QuantEcon/test-actions-lecture-intro), the canary | A release, in a real lecture repository, with real deploys | On its own pull requests and weekly cache build, and in every staged release |

## The action harness

`test-actions.yml` calls each action as `uses: ./<action>`, so it tests the code on the pull request, not a released tag. Its required check is `Action harness: all checks`.

### The gate

The workflow has no `paths:` filter: a filtered-out workflow publishes no check run, and a required check would then wait forever. Instead its first job, `gate`, decides whether the change can affect the actions:

- **`IGNORED`** is a list of paths that cannot, such as the root docs, `docs/`, `tests/` and `templates/`. It is an ignore list, not a cover list, so a path it does not recognise runs the whole harness: forgetting to extend it costs CI minutes, never a green check earned by running nothing.
- **A self-test** fails the gate if `IGNORED` would match any file the harness must run for: each action's `action.yml`, which it reads from the workflow's own `uses: ./<action>` lines, the shared scripts and lockfiles, and the container files. It also checks that `IGNORED` still matches the paths it is meant to.
- **The checks a docs-only change still needs** run in the gate itself, because such a change skips every other job: the templates pin the same third-party actions as `.github/workflows/`, and `scripts/generate-docs.py --check --check-examples --actionlint` finds the manual's generated tables current, a chapter for every action, and every example valid. [CHAPTER-TEMPLATE.md](CHAPTER-TEMPLATE.md) lists those checks.

`harness-summary`, the job behind `Action harness: all checks`, passes only if the gate succeeded and either every job succeeded, when the gate found the change relevant, or every job was skipped, when it did not. Any other mix fails it.

### Fixtures

- **`.github/fixtures/mini-lectures/`**: a two-page book with a code cell that really executes, so a build writes a genuine `_build/.jupyter_cache`. Cache keys are salted with the run's id and attempt, so one run's caches cannot satisfy another's miss assertions.
- **`.github/fixtures/access-gate/server.py`**: a local stand-in for a Cloudflare Access gate, which answers in every shape the `deploy-cloudflare` gate probe has to tell apart, over TLS when a job needs it.
- **`.github/fixtures/preview-comment/`**: the comment bodies the preview actions must render for given inputs, and a stand-in for GitHub's API that the comment script runs against.

The container smoke fixture in `containers/quantecon/tests/` is separate: it tests an image, not the actions. See [CONTAINERS.md](CONTAINERS.md#the-smoke-test).

### What each action's jobs cover

| Action | Jobs | What they assert |
|---|---|---|
| `restore-jupyter-cache` | `unit-build-*`, `unit-exec-*` | For both cache types: a genuine miss, a read-only restore that stays quiet, a restore in save mode (#104), and `fail-on-miss` firing on a miss |
| `setup-environment` | `env-*` | In standard mode, a cold Conda cache and then a warm one with a build on the restored environment; a `cache-version` bump that restores nothing, and an edited environment file that restores through the fallback (#205); for a pinned stack, an exact hit and a fallback restore that each hold one working pip (#209). In container mode, that the delta lands in the environment on `PATH` |
| `build-lectures` | `env-hit-build`, `build-fail-guard`, `build-display-error-guard` | A real build of the fixture, with its executed output; that a cell that raises fails the step; and that an error raised while IPython displays a result fails it too (#247) |
| `build-jupyter-cache` | `bjc-*` | A build that saves both caches, which the round-trip jobs then restore; a failing build that saves nothing; an abort before the builds that still reports failure; `builders` parsed by exact token |
| `preview-netlify`, `preview-cloudflare` | `preview-*` | The pinned CLIs install from their lockfiles and run; the deploy decision for each combination of event, actor, fork and `dispatch-alias`; change detection against a scratch repository, shallow and full; the comment, rendered against the API stand-in, finding only its own; and each action installing its CLI only for a deploy, refusing a bad input first |
| `publish-gh-pages` | `publish-release-packaging`, `publish-modes` | The release assets' names, layout, checksum and manifest; `mode: upload` working with read access alone, and a mode the inputs cannot carry out failing before anything is uploaded |
| `deploy-cloudflare` | `dc-*` | The Access gate probe telling every response apart, gated and public; the action refusing an ungated Worker, or one that contradicts `visibility`, before it installs anything; every invalid input failing in validation; and the pinned wrangler accepting the generated configuration |

The templates have jobs of their own: `pdf-check-*` runs `ci.yml`'s PDF check hand-off and its `PDF_CHECK: 'false'` switch, and `preview-site-handoff` and `preview-deploy-job` its build-to-deploy hand-off, with change detection fetching no stored credentials. `container-images` is the call to `validate-containers.yml`.

`build-jupyter-cache` runs `setup-environment` and `build-lectures` at `@v0`, because GitHub does not allow an expression in `uses:`. So in the harness, as for consumers, those two run as the latest release, not as the pull request has them.

### Adding a job

- Put it beside the related jobs, and add it to `harness-summary`'s `needs:`. A job that must be skipped stays out of `needs:`, since the summary fails a skipped job; check its skip from another job, as the `pdf-check-switch-*` jobs do.
- Show that it can fail: run it once against the bug it guards, or with the assertion inverted, and say so in the pull request.
- If the job needs a file the gate would ignore, check the gate's self-test still passes.

## Containers

A pull request that changes an image builds and smoke-tests it before it can merge; the merge then rebuilds the images, moves `:latest`, and runs `test-container.yml` and the lecture matrix against them. [CONTAINERS.md](CONTAINERS.md) describes that path and the smoke test, and [CONTAINER-VALIDATION.md](CONTAINER-VALIDATION.md) the lecture matrix and its results.

## The canary

[QuantEcon/test-actions-lecture-intro](https://github.com/QuantEcon/test-actions-lecture-intro) is a lecture repository kept for testing the actions. It pins `@v0` and runs the full chain:

- `ci.yml`, on its pull requests and by hand: `restore-jupyter-cache`, `build-lectures`, and real deploys with both `preview-netlify` and `preview-cloudflare`;
- `cache.yml`, weekly on Sunday at 03:00 UTC and by hand: `build-jupyter-cache`;
- `publish.yml`, on a `publish*` tag: `publish-gh-pages`.

In a staged release, a branch of the canary points these at the candidate tag before `v0` moves: see [Staged Releases](../../CONTRIBUTING.md#staged-releases).

## Locally

- **The manual's checks**: `python3 scripts/generate-docs.py --check --check-examples --actionlint "$(command -v actionlint)"`, with the actionlint release the gate pins.
- **A larger book**: clone a real lecture repository into `tests/local/`, which git ignores; see [tests/README.md](../../tests/README.md).
- **The images**: build them as [CONTAINERS.md](CONTAINERS.md#building-locally) shows, and run the smoke test on macOS with `containers/quantecon/tests/run-local-tests.sh`.
- **An action from a branch**: in a lecture repository, point a step at `quantecon/actions/<action>@<branch>`.

## What is not covered

- **Real deploys.** No harness job deploys anywhere: that needs real sites and secrets. The canary's pull requests deploy real previews, and its tag runs publish to GitHub Pages; a `deploy-cloudflare` deploy is proven only by the first consumer run after a release.
- **A filed failure issue.** The harness checks the issue's text and the guards that lead to it, but filing one needs `issues: write` and would open real issues on every run, so only an unattended consumer or canary run files one.
- **`build-jupyter-cache`'s siblings at the candidate.** They run at `@v0`, here and in a staged release, so a change to either reaches that chain untested until `v0` moves.
- **A release before `v0` moves, automatically.** Staged releases are run by hand. A `gate.yml` in the canary that tests a candidate is #135, with its fixture #136.
- **The lecture repositories' own content**, beyond the four the lecture matrix builds.
