# Changelog

All notable changes to the QuantEcon Actions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- ⚠️ **BREAKING** **`build-lectures`**: a new `nitpick` input, `'true'` by default, passes `-n`
  to `jb build` for every builder: Sphinx's nitpicky mode, which warns about every reference it
  cannot resolve, so that under `-W` one fails the build. The `pdflatex` and `jupyter` builders
  always passed `-n`, and now pass it through the input; `nitpick: 'false'` leaves it out. The
  `html` builder passed none, and now does: a site whose pages hold a reference that only
  nitpicky mode reports, such as a `{py:func}` naming a function no page documents, fails its
  `html` build until the reference is fixed. A `-n` that a caller also passes in `extra-args` does
  no harm: `jb build` takes it twice. #300's check of a `jupyter` build's warnings reads `-W` and
  `--keep-going` from `extra-args`, as before. **`build-jupyter-cache`** gets `nitpick` and
  `extra-args` too, with `build-lectures`' defaults, passes both to each of its builds, and
  refuses a `nitpick` other than `'true'` or `'false'` before setup. Its failure issue's commands
  to reproduce a build are built from them. It runs `build-lectures@v0`, so a caller pinned to an
  earlier `build-jupyter-cache` gets `-n` on its `html` cache build too, with no input to drop
  it, and moves to this release to set one. The new harness job `build-nitpick` shows an
  unresolved reference failing an `html` and a `jupyter` build with `nitpick` on, and passing
  both with it off; `bjc-alert` checks the commands and that each build is given both inputs. To
  migrate: fix each reference the build lists, accept its target in `nitpick_ignore_regex` in
  `_config.yml`, or set `nitpick: 'false'` on each `build-lectures` and `build-jupyter-cache` step
  while you do. (#97)

## [0.19.0] - 2026-11-11

### Added
- **`restore-gh-pages`** and **`templates/restore.yml`**: puts a GitHub Pages site back as one of
  the repository's releases holds it, without a build, from the archive, checksum and manifest
  that `publish-gh-pages` attaches on a tag. The action downloads the release's archive and
  checksum with `gh`, checks the archive's SHA-256 before anything is extracted, refuses an
  archive that holds anything but files and directories, and gives the extracted site as
  `build-dir`, with the commit it was built from as `commit`. It reads only the repository's own
  releases, needs only `contents: read`, and finds the archive by its tag unless `asset-name` is
  given. The template, run by hand on the default branch with the release's tag, hands the site
  to `publish-gh-pages` to deploy, in `publish.yml`'s `pages` concurrency group. The next publish
  replaces the restored site. (#27)

### Changed
- **Container images**: `sphinx-exercise` moves from 1.2.1 to 1.2.2 in both images, which the
  full image pins and the lean image takes as its floor. The patch release writes a captioned
  figure inside an exercise or solution as `\begin{figure}[H]`, as Sphinx does inside its own
  admonitions, so a PDF build no longer stops there with `Not in outer par mode`. HTML output is
  unchanged. Both images were smoke-tested before `:latest` moved, and the lecture matrix then
  passed on all eight legs. (#312)

### Fixed
- ⚠️ **BREAKING** **`build-lectures`**: a `jupyter` build under `-W --keep-going`, the default
  `extra-args`, now fails on a warning, as the other builders do. It used to pass every warning.
  sphinx-tojupyter's `JupyterBuilder.finish()` calls `exit()` with 0 inside Sphinx's build,
  before Sphinx turns the warnings that `--keep-going` counted into exit status 1. So `jb build`
  exited 0 whatever the build warned about, a cell that raised included. The release gate's
  staged-failure self-test showed it: only the error-output check caught the raised cell. The
  build step now keeps a copy of `jb build`'s stderr, Sphinx's warning stream. For the `jupyter`
  builder, when `jb build` exits 0 with both `-W` and `--keep-going` in `extra-args`, it fails
  the step on any warning in it, and lists each in a log group. The failure report then prints
  the failed notebooks' tracebacks, as for any failed build. `-W` alone already failed at the
  first warning, and without `-W` nothing changes. `build-jupyter-cache` gets the same through
  `build-lectures@v0`; it builds `jupyter` first, so that build is the one that reads and
  executes the pages. The error-output check now tells a cell that raised, after which no code
  cell ran, from one whose output raised while it was displayed, after which one did. It says
  which in its annotation and in a Cause column in the step summary, where it used to say "The
  kernel reported this cell as successful" of both. The new harness job
  `build-jupyter-warning-guard` shows a clean `jupyter` build passing, a cell that raises failing
  the build step, the same warnings passing without `-W`, and the check's wording. The lecture
  matrix found one warning, in three lecture repositories: a `tojupyter_static_file_path` entry
  naming a directory the book does not have, which warns `tojupyter_static_path entry … does not
  exist`. Their pull requests drop that entry, and no other QuantEcon caller's `jupyter` build
  logs a warning. To migrate: fix each warning the build step lists, such as by dropping that
  entry, or set `extra-args` without `-W` for the `jupyter` build while you do. (#300)

## [0.18.0] - 2026-11-10

### Added
- **`preview-workers`**: a new action that previews a pull request on an existing Cloudflare
  Worker, as Cloudflare moves static sites from Pages to Workers. It uploads the built site as a
  new version of the Worker with `wrangler versions upload --preview-alias pr-<number>`, which
  never changes what the Worker serves in production, at
  `https://pr-<number>-<worker-name>.<account-subdomain>.workers.dev`, and comments on the pull
  request as `preview-netlify` and `preview-cloudflare` do, with a comment of its own. It has
  their trust gate, `dispatch-alias`, `placeholder` and outputs. `deploy-url` is built from the
  inputs and checked against wrangler's record of the upload: a wrong `account-subdomain`, or a
  Worker whose preview URLs are off, fails the job rather than post a link that cannot load.
  `deployment-url` is the version's own preview URL, which keeps showing that push. The wrangler
  config is generated for each run by the writer `deploy-cloudflare` uses, now in `scripts/`,
  with no change to `deploy-cloudflare`. The token is an account-owned API token scoped to the
  one Worker, which the chapter shows how to make. (#145)

### Changed
- **Container images**: builds of `main` outside the kept window are now deleted from GHCR. A
  new monthly workflow, `prune-images.yml`, keeps `main`'s newest 10 builds and every version of
  the last 90 days, tagged or not, so every build of the last 90 days; the newest builds are the
  rollback targets. It keeps a dispatch from a branch for 14 days. It always keeps `:latest`, a
  pull request's candidates, every digest in `.github/container-pins.txt`, any version carrying a
  tag it does not own, and every manifest these list. Until now nothing was deleted: 338 versions
  of `quantecon` had built up, and 221 of `quantecon-build`. A workflow that pins an image by
  digest keeps working while that build is kept. To keep a pin for longer, add its digest to
  `.github/container-pins.txt` in a pull request, or have the version tagged with a name that
  does not end in `-<7 hex digits>`. The one pin known in QuantEcon, `quantecon-build` in the two
  theme test repositories, is in the file. A dispatch is a dry run unless told otherwise, a pull
  request that changes the pruner lists what it would delete, and a run with more than 50
  versions of an image to delete deletes none. (#277)
- **`preview-netlify`, `preview-cloudflare`, `deploy-cloudflare`**: through Dependabot's lockfile
  bump, `preview-cloudflare` and `deploy-cloudflare` pin wrangler 4.158.0, up from 4.156.1, and
  `preview-netlify` pins netlify-cli 27.16.2, up from 27.16.1. `preview-workers` ships with
  wrangler 4.158.0. The harness installs each from its lockfile and runs it. (#294)
- **`publish-gh-pages`**: `softprops/action-gh-release`, which attaches the release assets, moves
  from 3.0.3 to 3.0.4, through Dependabot's bump. The patch release classifies GitHub API errors
  more safely. (#295)
- **Container images**: `quantecon-book-theme` moves from 0.22.1 to 0.22.2 in both images,
  through Dependabot's bump. The patch release's dark-mode button is labelled "Toggle dark mode",
  and a site that sets no author no longer shows "Author name not set" in its page header. Both
  images were smoke-tested before `:latest` moved. (#293)

### Documentation
- **Releases** (CONTRIBUTING, Staged Releases): a release that changes an action passes the
  release gate before `v0` moves. The gate is `gate.yml` in the canary,
  QuantEcon/test-actions-lecture-intro, dispatched on its `main` with the candidate, which it
  refuses unless it is reachable from `main` or a `v*` tag. It checks the candidate out and runs
  the actions from that checkout on a fixture whose image is pinned by digest and whose pages
  read nothing from the network: `build-jupyter-cache` cold with all three builders, its siblings
  at the candidate too; both cache restores; both previews and a GitHub Pages deploy, each
  checked for the candidate's build. It replaces the canary pull request and `cache.yml` dispatch
  that a staged release ran by hand, which now stage only what the gate does not reach: a
  preview's pull-request half, `setup-environment` outside a container, `setup-latex`,
  `deploy-cloudflare`, `preview-workers`, and a release's own scenarios. A red gate run from
  `main` assigns a `release-gate` issue in the canary to whoever dispatched it. `TESTING.md`
  describes the gate, and `PLAN.md` drops items 0a, 0b and 0d. (#135, #136)

## [0.17.0] - 2026-11-10

### Added
- **`setup-latex`**: a new action that installs TeX Live, or any apt packages, on a standard
  Ubuntu runner, from a cache of the downloaded `.deb` archives. A plain `apt-get install`
  downloads TeX Live from the runner's Ubuntu mirror on every run, 1.1 GB for the usual lecture
  list, and a slow mirror stalls that without ever failing: since September, 12 of 220 such steps
  in the lecture repositories took over 5 minutes, and the slowest ran for nearly 6 hours. The
  cache key hashes the packages installed on the host, so an exact hit installs the archives as
  local files with no `apt-get update` and no download. A fallback restore, as after a new
  runner image, downloads only what the cache lacks. It caches archives, not installed files, so
  dpkg runs TeX Live's maintainer scripts as before. `download-timeout-minutes`, 30 by default,
  stops a download that runs longer, and `'0'` sets no limit. The cache is saved after the
  install, except on an exact hit or from a tag. The 15 lecture repositories that inline their
  own `apt-get install texlive-…` step can switch with a one-step change, which the chapter
  shows. The work is in `scripts/latex-packages.sh`, for `setup-environment`'s `install-latex` to
  share. (#224)

### Changed
- **`build-jupyter-cache`, `restore-jupyter-cache`**: the execution cache's key hashes the
  environment files too, as
  `jupyter-cache-<hash of environment>-<hash of environment-update>-<hash of the lectures>-<run id>`,
  and a restore falls back to `jupyter-cache-<env>-<update>-`, then `jupyter-cache-<env>-`: the
  build cache's fallbacks. It used to hash the lectures alone and fall back to any execution
  cache. `.jupyter_cache` checks each notebook against its code, but not against the packages
  that executed it, so a pull request that changed the environment file restored outputs made
  with the old packages, re-executed nothing, and passed. Now it misses and executes every
  lecture, as it does with the build cache. `environment` and `environment-update` apply to both
  cache types. A workflow that already restores `cache-type: execution` misses once after `v0`
  moves, until its next cache build, and one that also sets `fail-on-miss: 'true'` should run
  its cache workflow once then; no QuantEcon workflow restores `execution`. The harness's new
  `unit-exec-env-miss` restores the seed's lectures under another environment file, and must
  miss. (#270)
- **`templates/ci.yml`, `templates/publish.yml`**: both restore `cache-type: 'execution'`,
  `_build/.jupyter_cache` alone, instead of the build cache. The build cache brings back what the
  last cache build made, including what the source has deleted since. Since #160 the restore
  removes its `html`, but a build that makes the notebooks or the PDF over it can still copy a
  removed lecture's notebook, or a deleted PDF, into the site. The execution cache leaves nothing
  of the kind, and is several times smaller, so a restore downloads less, and a pull request's
  `save-cache` stores less. The rest of `_build` saves no work: a fresh checkout makes Sphinx
  rewrite every page. A repository that copied an older template sets `cache-type: 'execution'`
  on the restore step of both. `build-jupyter-cache` still saves the build cache, since
  `restore-jupyter-cache`'s default restores it; whether it stops, or becomes opt-in, goes with
  a later change of that default (review M3). (#270)
- **`setup-environment`**: `install-latex` installs the LaTeX packages as `setup-latex` does,
  through the same script: from a cache of their downloaded archives, keyed on `cache-version`,
  the list and the packages installed on the host, with no `apt-get update` and no download on
  an exact hit. It used to download them from the runner's Ubuntu mirror on every run, which a
  slow mirror can stall for hours. A new output, `latex-cache-hit`, says which way they came. On
  a run that downloads, `apt-get update` and the download together are now stopped after 30
  minutes, with no input to change it: a download that runs past 30 minutes now fails, where it
  used to finish slowly. No QuantEcon repository passes `install-latex`. `build-jupyter-cache`
  passes it for a `pdflatex` build in standard mode, and its three QuantEcon callers all run in a
  container. A repository that needs another limit can install LaTeX with `setup-latex` and its
  `download-timeout-minutes` instead. `cache-version` now keys the LaTeX cache too, so a bump also
  downloads the packages afresh. Each entry in the list must be an apt package name, so an option
  such as `--no-install-recommends`, which apt used to take from the file, now fails the job. The
  messages for a missing or empty list now name the file. (#224)
- **Container images**: `:latest` moves only once the image it will point at has passed the
  smoke test. Until now the merge's own build pushed `:latest` directly, and `test-container.yml`
  tested it afterwards. That build is not the image its pull request tested: it rebuilds the
  changed layers, whose floating packages resolve again, and a dispatch or a direct push to
  `main` was tested by nothing. `build-containers.yml` now pushes only candidates, `main-<sha>`
  and one `main-<date>-<time>-<sha>` tag for the run, and calls `test-container.yml` on them
  twice, for the smoke test and for the size report. When every smoke test passes, a new
  `promote` job points `:latest` at the digest each build pushed, all the images together, with
  `docker buildx imagetools create`, through a new `scripts/promote-image.sh`. The script first
  checks that each candidate tag still resolves to the digest pushed, then that `:latest` does
  after the move, and the job's step summary has the digests pushed, promoted and replaced, with
  the rollback command. A failed smoke test or promotion leaves `:latest` where it was and opens
  the failure tracking issue. A failed size report alerts too, but cannot hold a promotion back,
  since it fails on the measurement, not the image. A cancelled run alerts only when no newer
  run has superseded it. On any branch but `main` the promotion is a dry run, and
  `validate-containers.yml` dry-runs it on each pull request's candidates, with a self-test of
  the script on every harness run. `test-container.yml` loses its `workflow_run` trigger and its
  own alert, now the build run's, and takes a `checks` input. The lecture matrix starts only
  after a run on `main`, since a branch's run moves nothing. `:latest` moves a few minutes later
  after a merge, by the smoke test's run time. Every `main-*` tag is kept as a rollback target.
  The `sed` tag lists in `build-containers.yml` are rewritten, so `.github/actionlint.yaml` and
  its ignores for them go. (#142)

### Fixed
- **`preview-cloudflare`**: `deploy-url`, and with it the comment's preview URL and every lecture
  link, is built on the address Cloudflare serves the project at, which it keeps apart from the
  project's name and which can differ from `<project-name>.pages.dev`. The address comes from the
  deployment's own URL in wrangler's record of the deploy, the `pages-deploy-detailed` line it
  writes to `WRANGLER_OUTPUT_FILE_PATH`, so no other call is made, and the alias URL is still built,
  stable across pushes, as #14 made it. `deployment-url` is read from the same record, in place of
  the first matching URL in wrangler's log. When the record gives no URL of the form
  `https://<hash>.<name>.pages.dev`, the step warns, `deploy-url` falls back to
  `<project-name>.pages.dev` as before, and `deployment-url` is empty. When the address is not
  `<project-name>.pages.dev`, a notice says so: a comment posted with `placeholder: 'true'` still
  links there, having no deploy to ask, until the deploy's comment replaces it (#216).

## [0.16.0] - 2026-11-07

### Added
- **CI**: the harness gate lints this repository's own workflows with actionlint. Until now it
  linted only the templates and the manual's examples, so `.github/workflows/` had never been
  linted. The first run found 11 problems, all shellcheck findings at style or info level, and
  none from actionlint's own rules. Four are fixed with rewrites that print the same output. Three
  are `sed` calls that edit each line of a multi-line value, where SC2001's `${var//}` cannot
  apply, so each has a `# shellcheck disable` with that reason. The other four are in
  `build-containers.yml`, which this change leaves alone because a merge that edits it rebuilds
  both images and moves `:latest`. `.github/actionlint.yaml` ignores them for that file only,
  until #142's phase 2 changes it. actionlint skips `run:` scripts when it finds no shellcheck,
  so the gate now fails if the runner image has none, and logs its version. TESTING.md and
  AGENTS.md give the same check to run locally. (#100)
- **CI**: the harness gate shellchecks each action's `run:` scripts, and `scripts/*.sh`, through
  a new `scripts/lint-shell.py`, since actionlint never reads an `action.yml`. The script reads
  every `*/action.yml` with PyYAML, runs shellcheck at warning severity on each `run:` script
  whose shell is bash or sh, and reports each finding at its line in the `action.yml`. It also
  fails on any `${{ }}` left in a `run:` script, an action's or a workflow's. #228 moved every one
  in the actions into `env:`, and the workflows had none, so AGENTS.md's rule now holds from here
  on. At warning severity it found nothing else: the 56 `run:` scripts and the 9 `scripts/*.sh`
  pass with shellcheck 0.11.0. The two scripts under
  `containers/` are left out, since a change there rebuilds both images. (#100)

### Changed
- **`restore-jupyter-cache`**: `cache-type` accepts only `build` or `execution`, and `save-cache`
  and `fail-on-miss` only `'true'` or `'false'`; `path` must not be empty. Anything else fails the
  run in its first step, on every call, a custom `key`'s included, before anything is restored or
  registered for saving. The steps compared these values exactly, but their conditions compared
  them case-insensitively. So `save-cache: 'True'` registered the job-end save under the
  read-only key, which has no run ID: the first run saved under it, every later run matched it
  exactly and saved nothing, and the pull request's cache stopped updating without a word. A
  typo such as `cache-type: exec` restored the whole build cache, and `fail-on-miss: yes` was
  false. An empty `path` restored the execution cache into `/.jupyter_cache`, and failed inside
  `actions/cache` for the build cache. An unquoted `true` or `True` is unaffected, since YAML
  reads it as a boolean and the action receives `'true'`. No QuantEcon workflow passes a value
  outside these. Each input's description names its accepted values, and a new harness job,
  `unit-input-values`, shows each refused value failing the action where a control passes. It
  also makes #160's `cache-type: execution` safer to adopt: a mistyped value can no longer bring
  the build cache back unnoticed. (#236)
- **Every action**: an input that is one value fails the run in the action's first step if it
  holds a line break, and every input printed in an error or a warning is escaped. The runner
  reads each line a step prints that starts with `::` as a workflow command, so an input such as
  `environment` or `build-dir` whose second line began with `::` issued that command when the
  action printed it, and a value such as `50%25` printed in an annotation showed as `50%`.
  Refused now: every input but `build-lectures`' `extra-args`, which is split on whitespace and
  is now printed with its line breaks as spaces; `build-jupyter-cache`'s `builders`,
  `issue-labels` and `issue-assignees`, which are lists; and the tokens and IDs passed as
  secrets, which no action prints. `deploy-cloudflare` already refused a line break in each of
  its inputs but the secrets, and its message for `build-dir` is now the shared one. Both the
  check and the escaping are `scripts/workflow-command.sh`, which each step sources from
  `$GITHUB_ACTION_PATH/../scripts/`, in place of the copies in `build-lectures`,
  `restore-jupyter-cache`, both preview actions, `scripts/preview-decide.sh` and
  `scripts/detect-changed-lectures.sh`. Every other value behaves as before, and no QuantEcon
  workflow passes a line break in any of these inputs. New harness jobs:
  `workflow-command-helper` tests the file, and `inputs-line-break` shows each action failing in
  its first step on one. Copilot's review of #265 found the first case, in `setup-environment`.
  (#267)

### Removed
- ⚠️ **BREAKING** **`deploy-cloudflare`**: `require-access` is removed, and `visibility` is
  required, as the v0.14.0 and v0.15.0 deprecations said. Passing `require-access` now fails the
  job in its first step, with a message that says what to use instead, and so does leaving out
  `visibility`, which used to check the site as private with a warning. `require-access: 'false'`
  was the only way to turn the checks off, and that goes with it: every deploy is checked before
  the upload, after the deploy and on the alias, as private or public. The `visibility` output is
  set on every run whose inputs pass. To migrate: replace `require-access: 'true'`, or neither
  input, with `visibility: private`. For `require-access: 'false'`, use `visibility: public` and
  remove `team-domain` if the site is public, or `visibility: private` if it is behind Access.
  The chapter's "Moving from `require-access`" table gives each form. Two QuantEcon workflows
  call the action, both pinned to v0.12.0 and passing neither input, so each needs
  `visibility: private` when it moves to this release. `dc-inputs` shows both failures. (#177)

### Documentation
- **Developer docs** (#178): `docs/dev` describes the project as it is. `ARCHITECTURE.md` is the
  current design: the parts, and why the actions are composite, the environment an image, the
  caches keyed as they are, deploys kept in jobs of their own, installs pinned, inputs passed
  through `env:`, failures alerted and the manual generated. The pitch, the performance targets,
  the migration plan, the resolved questions and the success criteria are gone. `TESTING.md` is
  how testing works now: the harness's gate and summary, its fixtures, what each action's jobs
  cover, the container checks, the canary, local checks, and what nothing covers. It said the
  preview actions and `publish-gh-pages` had no tests, which the harness's `preview-*`,
  `publish-release-packaging` and `publish-modes` jobs had made untrue. `PLAN.md` keeps the
  current state, consumers, open priorities, dependency policy, open issues and rollout, and
  drops the closed items and the history. A root `AGENTS.md`, which Copilot code review and other
  agents read, replaces `.github/copilot-instructions.md`, pointing at `docs/dev` instead of
  repeating it. `CONTAINER-VALIDATION.md` describes the lecture matrix as it runs, when, what it
  builds and how to read a run, without the February 2026 results. No container size is written
  into the docs any more: like the user manual, the dev docs point at each `Test Container` run's
  size report (#201). `tests/README.md` and CONTRIBUTING's doc-update table follow. (#192)
- **Getting started**: the alert that told `@v0` workflows to copy the templates from v0.14.0 is
  gone, now that `v0` is on v0.15.0, which has the `mode` and `placeholder` inputs the templates
  use. PLAN's release line says `@v0` is on v0.15.0. (#246)

### Fixed
- **`restore-jupyter-cache`, `build-lectures`, `build-jupyter-cache`, `publish-gh-pages`,
  `setup-environment`**: no action expands `${{ }}` into a `run:` script any more. Fifty-eight
  expressions in these five actions put an input, a step's output, a `hashFiles()` result or the
  run ID straight into the script text, where bash read a value as shell. Each now reaches the
  script through `env:`, quoted, and the run ID is `$GITHUB_RUN_ID`. So `restore-jupyter-cache`
  takes a `path` holding a `$` as written: `_build/$x` used to restore into, and save from,
  `_build/`. It also refuses a `key` or `path` that holds a line break, before writing either
  as a step output, where the line break would have started another output; its `key` and
  `path` descriptions say so. `setup-environment` quotes `environment` and `environment-name`
  where it runs `conda env update`. Every other value behaves exactly as before. New harness
  jobs: `unit-custom-seed` and `unit-custom-restore` save and restore a custom `key` into a
  `path` holding a space and a `$`; `unit-line-break` shows a line break in either failing the
  action; and `build-html-copy` runs `html-copy-pdf` and `html-copy-notebooks`, which no
  harness job turned on. ARCHITECTURE's rule on inputs now has no exceptions, PLAN drops
  backlog item 18, and TESTING lists the new jobs. (#228)
- **`build-lectures`**: `html-copy-notebooks` copies each notebook under `_build/jupyter` into
  `_build/html/_notebooks/` at the same path. It copied them flat, but quantecon-book-theme links
  a page to `/_notebooks/<page>.ipynb` with the page's directory in it, so a lecture in a
  subdirectory had a download link that led nowhere, and two lectures with the same name in
  different directories left one notebook between them. A top-level notebook lands where it did,
  and no QuantEcon book that copies its notebooks has a lecture in a subdirectory. A failed copy
  now fails the step, for the PDF too: `find … -exec cp … \;` ignored a failed `cp`, so the site
  was built without the download. The PDF copy stays flat, since the theme links the book's one
  PDF. The `html-copy-notebooks` description and the chapter say so, and the chapter drops its
  caveat on lectures in subdirectories. The harness's `build-html-copy` job copies a second
  `lecture1.ipynb` from a subdirectory, and shows a read-only destination failing each copy.
  (#217)
- **`build-jupyter-cache`**: the failure issue's commands to reproduce each failed build pass
  `--path-output .`, as `build-lectures` does for the action's own builds, so a local repro run
  from the repository's root builds into `_build` there. Without it, `jb build` wrote into the
  book's own directory, `lectures/_build` by default, away from where the action, its artifact
  and its caches put the build. No harness job can file a real issue, so a new one, `bjc-alert`,
  runs the alert step's own script against a stand-in for the GitHub API, and checks the command
  it gives for each failed builder. (#229)
- **`build-jupyter-cache`**: a failure is reported on the open issue that carries the first of
  `issue-labels`, never on a pull request that carries it. The Issues API lists pull requests
  too, newest first, and the lookup took the newest item of either kind. So a newer labelled pull
  request got the report as a comment, no issue was filed, and `failure-issue-url` pointed at the
  pull request. The lookup now takes the newest open issue among the first 100 items, and with
  only pull requests labelled the action files a new issue. The step that checks the alert was
  filed now also fails unless the URL ends in `/issues/<number>`, and says so when it is a pull
  request's. No QuantEcon pull request has ever carried `build-failure`, the default first
  label, so a caller who keeps the defaults has not met this. `bjc-alert` covers a labelled pull
  request alone, a newer one beside an older issue, an issue after more than 30 newer pull
  requests, and nothing labelled. PLAN drops backlog item 15, and TESTING lists the new job.
  (#238)
- **`restore-jupyter-cache`**: a build-cache restore that matches, exactly or by prefix, removes
  the restored `<path>/html`, and logs how many files went. A build writes over `_build/html` but
  removes nothing from it, so a site built over the build cache published again every page and
  file deleted from the source since the last cache build: a removed lecture's pages, a deleted
  `_static` file, image or dataset, and the `_pdf/` and `_notebooks/` copies that the cache build
  staged there. The restored HTML saved no work, since a fresh checkout gives every source file a
  new modification time and Sphinx rewrites every page anyway. `_build/jupyter`, `_build/latex` and
  `_build/.jupyter_cache` stay, and an execution-cache restore removes nothing. There is no input:
  a build always rewrites `html`. A build that offered the PDF or the notebooks from a restored
  `_build/html/_pdf/` or `_notebooks/`, without `html-copy-pdf` or `html-copy-notebooks`, sets
  those two inputs, which copy them from the restored `_build/latex` and `_build/jupyter`; no
  QuantEcon workflow did. `lecture-dp` gets the change through `@v0` with no edit. The
  `cache-type` description, the chapter, ARCHITECTURE's "Two caches", the templates' comments and
  Getting started's migration steps say so. The harness's build-restore jobs show the removal,
  with an execution restore as the control. #270 is the second step. (#160)

## [0.15.0] - 2026-11-05

### Added
- ⚠️ **BREAKING** **`build-lectures`**: an `error-outputs` input, `fail`, `warn` or `ignore`, and an
  `error-output-count` output. After a build that passes, the action reads the notebooks myst-nb
  wrote to `_build/jupyter_execute`, outputs included, and reports every `error` output in them:
  an annotation on the source file, the traceback in a log group, and a table in the step
  summary. `fail`, the default (an empty value), then fails the step, and `warn` passes it.
  `-W` misses these tracebacks when the exception is raised while IPython displays output, such
  as a figure that fails to draw: the kernel reports the cell as successful, nbclient does not
  raise, and myst-nb renders the traceback without a warning. So `jb build` exits 0 and the page
  is published with the traceback on it, as the Black–Litterman lecture on
  python-advanced.quantecon.org was from August until its fix in November. ipykernel 7.3.0 fails
  a cell whose last value cannot be displayed, but output shown through `display()`, which is how
  a figure reaches the page, still passes. Errors are allowed where nbclient and myst-nb allow a
  cell to raise: a cell tagged `raises-exception`, a notebook whose `mystnb` metadata sets
  `execution_allow_errors`, and a book whose `_config.yml` sets `execute.allow_errors`.
  Notebooks with no source under `source-dir`, which a restored build cache can carry, are
  skipped. `build-jupyter-cache` gets the same `error-outputs` input and passes it to each build.
  The new harness job `build-display-error-guard` stages a display-time error and a
  `raises-exception` control, and builds under each value. A site whose pages carry such a
  traceback now fails its build: fix the cell, tag a deliberate one `raises-exception`, or set
  `error-outputs: 'warn'` while it does. (#247)
- **`publish-gh-pages`**: a `mode` input, so the upload, the deploy and the release assets can
  each run in a job of their own, and only the job that deploys holds the Pages permissions
  (finding M1 of the 2026-10-06 review). The action used to upload, deploy and release in one
  composite step, so a caller had to grant `pages: write` and `id-token: write` to the job that
  executed the notebooks. `all`, the default, is that behaviour, unchanged. `upload` uploads
  `build-dir` as the run's `github-pages` artifact and needs only read access. `deploy` deploys
  that artifact, from a later job of the same run, with `pages: write` and `id-token: write`, and
  takes no `build-dir` or `cname`. `release` makes the release assets from `build-dir`, in a job
  with `contents: write`, on a tag as before. `build-dir` is no longer a required input, since
  `deploy` takes none. The action checks its inputs first, and fails before anything is uploaded
  on an unknown mode, a missing `build-dir`, `build-dir` or `cname` with `deploy`,
  `create-release-assets: 'true'` with `upload` or `deploy`, or an `asset-name` with a character
  other than a letter, digit, `.`, `_` or `-`. A name with a backslash gave a checksum file that
  `sha256sum --check` rejects; the eight consumers that make release assets all use names
  inside that set. A new `mode` output gives the mode, and is empty when the inputs were
  refused. The release assets are unchanged, except that the manifest's strings are now
  escaped, so a tag with a `"`, which git allows, gives valid JSON, where it used to give a
  manifest no parser could read. Their packing moved into `scripts/package-release-assets.sh`,
  which the action runs. In CI, as decision 5 on
  #143 asks, `publish-release-packaging` runs that script with a stand-in tag and checks each
  part of the manual's contract: the file names, an archive of the whole site with `./` paths and
  hidden files, a checksum that `sha256sum --check` accepts, and a manifest with exactly the
  documented fields and types. `publish-modes` runs the action with `contents: read` alone. It
  asserts that `upload` uploads the site, that `release` skips off a tag, and that each refused
  combination fails with an empty `mode`, before anything is uploaded. A real deploy and a
  release upload are the staged canary's to prove. (#233)
- **`preview-netlify`, `preview-cloudflare`, `templates/ci.yml`**: a `placeholder` input, which
  posts the pull request's preview comment within seconds of a push, before the build has
  finished, and a `placeholder` job in `ci.yml` that runs it (#153). Until now the comment came
  only after a successful deploy, minutes later. With `placeholder: 'true'` the action decides as
  for a deploy, so a fork's or Dependabot's pull request gets nothing, then installs and deploys
  nothing. It builds the preview URL from the pull request's number, from a new
  `netlify-site-name` input on `preview-netlify` and from `project-name` on `preview-cloudflare`,
  and reads the changed lectures from the API's list of the pull request's files, by change
  detection's rules, so its job needs no checkout, no container and no secret. The comment is
  headed "⏳ … Preview Building", says that its links show the last push deployed until this one's
  deploy finishes, and carries the same hidden marker, so the deploy's comment replaces it in
  place; the placeholder never replaces the deploy's comment for its own commit. The token, the
  site or account ID and `build-dir` are now required for a deploy only: a run that would deploy
  without one fails at a new input check, before anything is installed, with an error naming it.
  A step that passes them, as every caller does, deploys as before. The `preview-comment` harness
  job now runs that check for 20 cases, and the placeholder's comment against the API stand-in,
  and `preview-wiring` runs a deploy without its token or `build-dir`, and invalid placeholder
  inputs, through each action.

### Changed
- **`preview-cloudflare`, `deploy-cloudflare`**: the pinned wrangler moves from 4.156.0 to
  4.156.1, through Dependabot's lockfile bump. The harness installs it from both lockfiles and
  runs it. (#259)
- **`templates/publish.yml`**: builds and deploys in separate jobs, as `ci.yml` does since #232.
  `build` builds in the container with `contents: read` and ends with `publish-gh-pages`
  `mode: upload`. `deploy` needs `build`, runs on `ubuntu-latest` with no checkout or container,
  holds only `pages: write` and `id-token: write`, and runs `mode: deploy` in the `github-pages`
  environment. The optional release assets move to a commented `release-assets` job with
  `contents: write`, which runs `mode: release` on a tag once the deploy has succeeded. It takes
  the site from an `html` artifact that a commented step in `build` uploads before the Pages
  upload, hidden files included, so the archive holds what it did. The template needs the release
  that adds `mode`: an earlier `@v0` ignores the input, and both jobs fail. (#233)
- **`templates/ci.yml`, `templates/cache.yml`, `templates/publish.yml`**: the pull request preview
  is deployed from a job that runs no notebook code, and no template leaves the job's token in
  git's config for later steps (finding M1 of the 2026-10-06 review). Building the lectures runs
  code the repository does not fully control, and it used to share a job with the step that hands
  the Netlify or Cloudflare token to the deploy CLI. `ci.yml` now has three jobs. `build` (renamed
  from `preview`) builds in the container with `contents: read` and no secrets, and uploads
  `_build/html` as the `html` artifact, hidden files included. `deploy` needs `build`, has no
  container, holds the provider secrets and `pull-requests: write`, sets up Node 24 and runs only
  the preview action on the downloaded site. `pdf-check` now needs `build` too, so it runs beside
  the deploy rather than after it. Every checkout in the three templates sets
  `persist-credentials: false`. Change detection in `deploy` fetches the history it needs from
  GitHub with no credentials, which a public repository allows; a private repository sets
  `fetch-depth: 0` on `deploy`'s checkout, as its comment says. A site that copies the new
  `ci.yml` and makes the old job a required status check must require `build` in place of
  `preview`: no job is called `preview` any more, so until it does its pull requests wait for a
  check that never reports. `pdf-check` and `deploy` are both skipped when `build` fails, so
  either needs `build` required beside it. Two harness jobs, `preview-site-handoff` and
  `preview-deploy-job`, run the hand-off: the site must arrive whole, hidden files included, and
  from a shallow checkout with no stored credentials, change detection must list the files GitHub
  lists for the pull request. (#232)
- **Container images**: the Ubuntu base is pinned by digest, and nothing rebuilds the images on
  a schedule any more, as decided on #234. Until now `build-containers.yml` rebuilt both images
  every Monday. When `ubuntu:24.04` had not moved, BuildKit replayed every layer from the cache
  and republished the same image (four of the seven Mondays from 2026-08-24 to 2026-10-05), while
  the READMEs, `docs/CONTAINER-GUIDE.md` and `docs/dev/ARCHITECTURE.md` promised weekly security
  updates. When it had moved, the images' floating packages re-resolved with no pull request,
  which is how plotly 7 reached the lean image (#222). Both Dockerfiles now pin
  `ubuntu:24.04@sha256:fe81560…`, the digest the current `:latest` images were built on, so the
  pin changes neither image. Dependabot proposes each new 24.04 digest as one pull request for
  both images, which builds and smoke-tests them before `:latest` moves, and ignores 26.04 and
  any other release. OS updates therefore arrive whenever Canonical republishes the base, every
  few weeks, reviewed. Those docs and `CONTRIBUTING.md` now say so, and point to #129 for what
  the pin does not make reproducible. On every harness run, `validate-containers.yml` checks that
  each image pins its base by digest and that both pin the same one
  (`scripts/check-base-pins.sh`). The lecture matrix, `test-containers-lectures.yml`, which the
  weekly build used to trigger, now runs weekly on a schedule of its own against `:latest`
  (Monday 02:00 UTC), so drift in the lecture repos against an unchanged image is still caught.
  (#235)

### Deprecated
- **`deploy-cloudflare`**: `require-access`, and leaving out both it and `visibility`, are still
  accepted in this release, with the same warning on every run. v0.14.0 said they would become
  errors in this release; that moves to v0.16.0, so that sites have a release's notice. Add
  `visibility` now. (#177)

### Documentation
- **`docs/dev/PLAN.md`**: caught up with wave 1 of #246 and the v0.13.0 and v0.14.0 releases.
  Since #240 a dispatched or scheduled run can exercise the preview deploy, so the statements
  that it could not are gone, and 0c's prerequisite is recorded as met: what remains is the
  canary's own changes (#135, #136). The release state says `v0` is on v0.14.0, and the eight
  exactly pinned call sites still read `@v0.12.0`. Backlog item 18 counts five actions with
  `${{ }}` in `run:` scripts, not seven, and item 15 lists #238 as left and #243 as done. The rows
  for #222, #227 and #230 record their closure, and #232, #233, #236, #238, #239, #243, #246 and
  #247 get rows. (#246)
- **User manual** (#178): the cross-cutting chapters, in `docs/user/`. `getting-started.md` sets
  up a lecture repository from the templates, gives what each job of `ci.yml` and `publish.yml`
  does and holds, covers the changes a site makes to them (downloads, the PDF check, release
  assets, a standard runner, a custom domain, Cloudflare Pages), and moves an existing repository
  over, cache first, with its rollback. `composition.md` follows the chain from the cache build to
  a preview or publish, what passes between the steps, and the settings that must agree.
  `containers.md` covers the two images: what each holds, which to use, how to use and pin one,
  and when they change, now that nothing rebuilds them on a schedule (#235). It does not call
  them public, since an anonymous pull is refused (#129), and points at each `Test Container`
  run's size report rather than quote sizes that drift. `versioning.md` covers `@v0` against an
  exact release, how a release reaches a repository, and that `build-jupyter-cache` runs its two
  siblings at `@v0` whatever it is pinned to. `security.md` covers fork pull requests and
  `pull_request_target`, what each template job can reach, the deploy jobs of #232 and #233, and
  what the actions themselves do. `templates/README.md` and the three container READMEs become
  signposts, and the container READMEs' build, update and test sections move to a new
  `docs/dev/CONTAINERS.md`. `docs/MIGRATION-GUIDE.md` and `docs/CONTAINER-GUIDE.md` are removed:
  their content is in these chapters, and the per-repository migration notes are in PLAN's
  rollout section. The root README points at the manual, and CONTRIBUTING's doc-update table
  names each chapter. (#191)
- **`SECURITY.md`**: how to report a vulnerability, privately through the repository's Security
  tab, and what is in scope: the actions, the templates and the container images. The harness
  gate treats a root `SECURITY.md` as documentation, as it does the README, so a change to it
  alone does not run the harness. (#191)
- **`docs/dev/PLAN.md`**: backlog item 6 is done (#253, #258), and the rows for #232, #233, #235,
  #239 and #247 record their closure. (#191)

### Fixed
- **`build-lectures`, `build-jupyter-cache`**: the failure artifacts hold the hidden directories
  they promise. `upload-artifact` leaves out every path whose name starts with a dot unless
  `include-hidden-files` is set, even a path it is given by name, and neither upload set it. So
  `build-lectures`' `upload-failure-reports` artifact held the `reports` directories without
  `_build/.jupyter_cache`, which its path list names, and `build-jupyter-cache`'s
  `build-cache-<run id>` artifact, described as the whole `_build` directory, held it without
  `.jupyter_cache` and `.doctrees`. Both uploads now set `include-hidden-files: true`. The
  harness's `build-fail-guard` and `bjc-fail-guard` jobs now download each artifact and check it
  for those directories. (#243)
- **`preview-netlify`, `preview-cloudflare`**: each action now finds its own comment on a pull
  request with more than 30 comments, and never edits anyone else's (finding M2 of the
  2026-10-06 review). Both looked for their earlier comment with one unpaginated `listComments`
  call, which returns the first 30, so on a pull request that already had 30 comments before its
  first preview, every push posted another. They also took any comment that contained the
  heading, a person's included. The two copies of the comment script are now one,
  `scripts/preview-comment.cjs`, loaded from a path resolved from `$GITHUB_ACTION_PATH`, so it
  loads in a container job too. It reads every page of comments, and updates only one by
  `github-actions[bot]` that starts with a hidden line, `<!-- quantecon-preview:netlify -->` or
  `<!-- quantecon-preview:cloudflare -->`, or with the heading, as comments posted before this
  change do, so an open pull request keeps its comment. Where several match, it
  updates the newest. The comment otherwise renders exactly as before. A new harness job,
  `preview-comment`, runs each action's own comment steps against a stand-in for the GitHub API.
  It checks each body against the one the old scripts rendered for the same inputs, and that the
  action finds its comment after 150 others and passes over a person's or another app's. (#153)

## [0.14.0] - 2026-11-05

### Added
- **`deploy-cloudflare`**: a `visibility` input, `private` or `public`, so the action publishes
  public sites as well as private ones, and checks either kind against what the workflow declares
  (#177). `private` is what the action did before: before the upload, after the deploy (production
  and the new version's preview URL) and on the alias, an anonymous request must be redirected to
  `team-domain`'s Access login. `public` inverts the same three checks: an anonymous request must
  be served the site, and a redirect to any `*.cloudflareaccess.com` fails. A Worker declared
  public but in fact gated is therefore refused before anything is uploaded, as a public Worker
  declared private already was. `team-domain` is required for `private` and an error for `public`,
  so a workflow copied from one kind of site to the other fails rather than check the wrong thing;
  it is no longer a required input. The first line of the log and the job summary's heading name
  the mode, and a new `visibility` output gives it. `scripts/check-access-gate.sh` gains
  `--public`, and `--allow-404` for the check before the deploy, when the live version need not
  hold this build's files yet. A public build with no `index.html` answers 404 at its root, so
  after the deploy it is checked on its non-HTML probe file alone; one with neither fails
  validation. In CI, `dc-gate-probe` covers every public verdict, `dc-inputs` every rejected
  combination, and `dc-refuses-ungated` the deprecated forms. A new job, `dc-refuses-mismatch`,
  runs the action against a gated and a public Worker stood in for on the runner (the access-gate
  fixture over TLS, behind `/etc/hosts`), and asserts that both mix-ups are refused before wrangler
  is installed, while matching ones reach it.
- **`preview-netlify`, `preview-cloudflare`**: a `dispatch-alias` input and a `deployed` output,
  so a scheduled or dispatched run can test the preview deploy, as decided on #143. Until now
  both actions deployed only on `pull_request`, and on any other event passed having deployed
  nothing, with nothing in the log to say so: a scheduled canary run was green while testing
  nothing. With `dispatch-alias: dispatch-canary`, a `workflow_dispatch` or `schedule` run deploys
  its build to that alias (`https://dispatch-canary--<site>.netlify.app`,
  `https://dispatch-canary.<project-name>.pages.dev`), with no comment and no changed lectures, and
  puts the URL in a notice. The value must start with the reserved `dispatch-` prefix, which no
  pull request's `pr-<number>` can, and be at most 28 characters of lowercase letters and digits
  in words joined by single dashes; anything else fails the job, on every event. The events are an
  allow-list: `pull_request` as before, and `workflow_dispatch` and `schedule` only with the
  input. No input makes `pull_request_target`, `push` or any other event deploy (#105), and fork
  and Dependabot runs are still skipped. `deployed` is always `'true'` or `'false'`, and a run
  that deploys nothing says why in a notice, or a warning on `pull_request_target`. The decision
  is one script, `scripts/preview-decide.sh`, that both actions run first. (#227)
- **CI**: two harness jobs for that decision, neither needing provider secrets. `preview-decide`
  runs `scripts/preview-decide.sh` for 35 combinations of event, actor, fork and alias, including
  `schedule` and `pull_request_target`, which the harness itself never runs on. `preview-wiring`
  runs both actions with fake credentials. It asserts that an invalid `dispatch-alias` fails each
  one before anything is installed, and that each installs its CLI exactly when the decision says
  deploy, with `deployed` always set; on this repository's own pull requests that means reaching
  the provider and failing on the credentials. A successful deploy is not covered: the staged
  canary check is its proof. (#227, #193)

### Changed
- **`templates/ci.yml`**: a new `pdf-check` job builds the PDF on every pull request and fails
  its checks when the LaTeX build fails. Malformed LaTeX can pass the HTML build and still break
  the PDF build, and with it the publish, and previews are moving to HTML only (#148). The job
  starts when the preview job has finished, so the preview link never waits for it, and builds
  from the `_build/.jupyter_cache` the preview job uploads as an artifact, so it executes no
  notebooks and needs no GPU runner. A site that publishes no PDF sets `PDF_CHECK: 'false'` in the
  workflow's `env:` block, and the job is reported as skipped. The switch is in the file, not a
  repository variable, because a run for a fork's pull request does not receive repository
  variables. Harness jobs run the hand-off on the fixture in the lean image, through the
  template's switch, and check that `PDF_CHECK: 'false'` skips both the upload and the job.
  (#230)
- **`preview-netlify`, `preview-cloudflare`**: the CLI is installed only when the run will
  deploy, on the deploy step's own condition, so the two cannot drift apart. A `push` run, or a
  `workflow_dispatch` run without `dispatch-alias`, used to spend 25-45 s on `npm ci` of the
  pinned CLI and then skip the deploy. The trusted-actor check is now part of the shared decision,
  and its skip message, which was plain log text, is a notice. (#193)
- **Container images**: a pull request that changes an image now builds and tests it before it
  merges. Until now the merge that first built a changed image was also the push that moved
  `:latest`, and the smoke test ran only after that. The action harness now calls the new
  `validate-containers.yml`, which builds each image the pull request changes (cached from
  `:latest`), pushes it as a candidate tagged `pr-<N>` and `pr-<N>-<date>-<time>-<sha>`, never
  `:latest`, and runs `test-container.yml`'s smoke test and size report on it in a real
  `container:` job. Its result is part of `Action harness: all checks`, so a pull request that
  changes only `containers/**` can no longer pass the required check without its image being built.
  A fork's pull request that changes an image fails the check, since its token cannot push a
  candidate. Candidates are deleted when the pull request closes. `test-container.yml` takes
  `images` and `tag` inputs, on dispatch as well as on a call (#150), and opens a tracking issue
  when its run after a build fails: without one, #222 went unseen for three weeks. Each
  `build-containers.yml` run writes the digest it pushed, and the one `:latest` held before it, to
  its step summary as the rollback handle, and adds a tag unique to the build,
  `main-<date>-<time>-<sha>`. Main's own builds still move `:latest` before any test; that is
  phase 2. (#142)
- **Container images**: `quantecon-book-theme` moves from 0.22.0 to 0.22.1 in both images,
  through Dependabot's bump. The patch release stops registering `sphinx-book-theme.js`, which
  every page requested and got a 404 for, and leaves out the View Source button, with its
  `href="None"`, on generated pages. Both images were built and smoke-tested as `pr-223`
  candidates before the merge, the first Dependabot bump to take that path. (#223)

### Deprecated
- **`deploy-cloudflare`**: `require-access`, and leaving out both it and `visibility`, which relied
  on its default (#177). Both still work in this release, with a warning on every run:
  `require-access: 'true'`, and neither input, check the site as `visibility: private`, as
  v0.12.0's default did, and `require-access: 'false'` still skips every check. Setting both
  inputs fails the job. In the minor release after this one, both forms become errors and
  `visibility` becomes required, so add it now. The chapter's "Moving from `require-access`" table
  gives the change for each form; note that `visibility: public` checks the site rather than skip
  the checks.

### Documentation
- **`CONTRIBUTING.md`**: Staged Releases says how to roll back a container image: retag `:latest`
  to the digest it held before, which each `build-containers.yml` run now records in its step
  summary, with `docker buildx imagetools create`. Its known limit on container images now says
  that they stage on pull requests only: the merge's own build and scheduled rebuilds still push
  `:latest` untested. (#142)

### Fixed
- **`preview-netlify`, `preview-cloudflare`**: the comment's changed lectures, and the
  `changed-files` output, are the lectures the pull request added or modified.
  `scripts/detect-changed-lectures.sh` compared the base branch's tip with the head
  (`BASE..HEAD`), so every lecture changed on the base branch after the pull request branched off
  was listed too. It now compares from the merge base (`BASE...HEAD`), which the checkout must
  have:
  - A checkout with `fetch-depth: 0` has it, and nothing is fetched. The script used to fetch the
    two commits on every run.
  - In a shallow checkout the fetch is now bounded (#147). Fetching the two commits with no depth,
    as the script did, pulled their entire history into a depth-1 checkout. It now fetches 64
    commits behind each, and deepens, doubling, until it finds the merge base. If it has not
    found it 1,024 commits behind each, it warns and compares from the base branch's tip, as
    before. `--depth` is used only for a commit the checkout lacks: on one it has, it cuts the
    history behind it to that depth. The fetches skip git's automatic maintenance, which runs in
    the background and can rewrite `.git/shallow` during the next deepen, making git abort it.
  - A git failure is a warning carrying git's own message. Every git call ended in
    `2>/dev/null || true` or `|| echo ""`, so a failure listed no lectures without a word. It
    still never fails the step: the deploy is worth more than the links.

  A second, per-file `git diff`, which repeated the first comparison, is gone. A new harness job,
  `preview-change-detection`, runs the script against a scratch repository checked out as
  `actions/checkout` checks out a pull request: in full, and 1, 2 and 50 commits deep, with a
  rename, a merge base just inside the cap and one past it, a remote that cannot be fetched from,
  and no repository at all. (#215)
- **`test-container.yml`**: the image-size job failed on every run once `ubuntu-latest` became
  ubuntu-26.04, whose Docker 29.4 uses the containerd image store: there `docker image inspect`
  reports the compressed content size, and the job's guard (#172) refuses to print that as the
  on-disk size. The job now switches the runner's daemon back to the classic store
  (`features.containerd-snapshotter=false`) before it pulls, so the on-disk figure is still the
  unpacked layers on overlay2, comparable with every earlier report. The guard stays and fails
  the job if the switch does not hold. (#142)

## [0.13.0] - 2026-11-05

### Changed
- **`preview-netlify`, `preview-cloudflare`, `deploy-cloudflare`**: the pinned deploy CLIs move
  from v0.12.0's wrangler 4.136.3 and netlify-cli 27.8.1 to wrangler 4.156.0 and netlify-cli
  27.16.1, through Dependabot's lockfile bumps. The harness installs both from their lockfiles
  and runs them. (#207, #219)
- **Containers**: both images move to the **Anaconda 2026.07** baseline, which every lecture repo
  in the validation matrix already pins (#188). The full image's metapackage goes to
  `anaconda=2026.07`. The lean image's pin set is re-derived from the 2026.07 linux-64 py313 MKL
  build, which moves three of its ten pins: scipy 1.17.1 → 1.18.0, matplotlib 3.10.9 → 3.11.0 and
  scikit-learn 1.8.0 → 1.9.0; numpy, pandas, seaborn, sympy, numba, networkx and statsmodels are
  unchanged. The lean image's `icu=73.1` hold, kept so the Node 24 move did not re-solve its native
  stack, is dropped as planned, with its Dependabot `ignore`: the lean image now resolves icu 78.3
  (as the full image does), Qt 6 in place of Qt 5 (pyqt 5.15 → 6.11), lxml 5.3 → 6.1 and libxml2
  2.13 → 2.15. The documented image sizes were measured on the 2026.06 images. (#199)
- **`test-containers-lectures.yml`**: each matrix repo can set its own `timeout-minutes`
  (default 120), and `lecture-python.myst` gets 180. Its CPU HTML build alone takes 72-118 min
  depending on the runner, so at 120 a leg's result depended on the host it landed on (#159);
  its runtime is discussed in #196. Each leg also records the runner's CPU model and core count
  in the job summary (#141).
- **`build-lectures`**: when notebooks fail to execute, the failure report now prints each one's
  traceback (the last 200 lines of `reports/<doc>.err.log`) in its own collapsible log group.
  myst-nb logs only `CellExecutionError` and the report's path, so the traceback was otherwise
  only in the 7-day reports artifact; diagnosing #159 took far longer for that reason.
  `stop-commands` wraps each traceback, so notebook output cannot act as a workflow command.
- **`build-containers.yml`**: an edit to a README under `containers/` no longer rebuilds and
  pushes both `:latest` images, or re-runs the container test workflows that follow the build.
  The Dockerfiles copy only `environment.yml`, so a README cannot change an image. Other Markdown
  under `containers/` still triggers a build: the smoke-test fixture's pages are Markdown. (#178)

### Documentation
- **`docs/dev/PLAN.md`, `CONTRIBUTING.md`**: caught up with the v0.12.0 follow-ups, which have
  landed. The canary runs `preview-cloudflare` (QuantEcon/test-actions-lecture-intro#67), so
  Staged Releases loses its known limit about it, and step 2 says the canary PR deploys to both
  preview providers. The six consumers that passed `cname` have dropped it, so PLAN's follow-up
  list is gone. PLAN also records the 2026-11-04 decisions, none of them implemented yet: the
  release gate is a `gate.yml` in the canary that tests a candidate checkout, with its fixture in
  its own folder there and no `v0-next` tag (#135, #136, #143); the preview actions are to deploy
  outside a pull request only when asked (#227); HTML-only previews keep a parallel PDF check
  (#146, #230); and scheduled image rebuilds give way to a digest-pinned base that Dependabot
  moves (#234, #235). Stale facts are corrected: every exact pin is on `v0.12.0`, branch hygiene
  (item 16) is done, the container smoke fixture does exercise plotly export, and items 6, 15
  and 18 point at #153, #229 and #228. (#202)
- **User manual** (#178): every action has its chapter. `build-lectures`, `build-jupyter-cache`,
  `restore-jupyter-cache`, `preview-netlify`, `preview-cloudflare`, `publish-gh-pages` and
  `deploy-cloudflare` get theirs in `docs/user/actions/`, and their READMEs become generated
  signposts. What only the READMEs held moves into the chapters: the Netlify and Cloudflare Pages
  setup guides; the comparison of the two, now kept to what the actions do, since provider pricing
  is not something this repository can keep current; the preview actions' note, from #143, that they
  deploy nothing on events other than `pull_request`; the `publish-gh-pages` migration notes; and
  the `deploy-cloudflare` Access checklist, with no account details. The `publish-gh-pages` chapter
  documents the release assets, the archive, its SHA-256 checksum and the manifest, as a contract
  that a release changes only with a CHANGELOG entry (#27). `docs/QUICK-REFERENCE.md` is removed:
  its action table is the manual's index, and the rest is in the chapters. The harness gate now
  fails when an action has no chapter. (#190)
- **The seven actions' `action.yml` descriptions** are rewritten for readers, since the manual
  copies them verbatim, and corrected where they, or the READMEs, were wrong:
  - `restore-jupyter-cache`'s `path` said a different path restores the cache into a directory
    the build does not read. The path is part of what identifies a cache, so any path but
    `_build` finds none of the caches `build-jupyter-cache` saves.
  - The `build-jupyter-cache` README listed a third, bare `build-` fallback key, which
    `restore-jupyter-cache` no longer uses. The chapters give the two it does.
  - The preview READMEs said change detection needs `fetch-depth: 0`. The actions fetch the pull
    request's base and head commits themselves.
  - The `preview-cloudflare` setup guide now asks for a token with Cloudflare Pages Edit alone,
    not the broader "Edit Cloudflare Workers" template.
  - `deploy-cloudflare`'s `account-subdomain` example no longer names a real account, and its
    refusal message points at the chapter's setup checklist instead of the README.
  - The caches save execution time only when the book sets `execute_notebooks: cache`, which the
    `build-jupyter-cache` and `restore-jupyter-cache` chapters now require. Sphinx re-reads every
    page of a fresh checkout, so the old claim that it rewrites only the changed pages is gone.
  - `restore-jupyter-cache`'s `save-cache` reaches every pull request when saved from a branch,
    so the chapter keeps it to pull-request builds, and a re-run, which matches its own key
    exactly, saves nothing.
  - Three limits in the code are documented, and filed: the preview actions' change detection
    lists lectures changed on the base branch after the pull request branched off (#215);
    `preview-cloudflare` builds its URLs from `project-name`, which is wrong when Cloudflare gives
    the project another `pages.dev` address (#216); and `html-copy-notebooks` copies the notebooks
    flat, so the download link of a page in a subdirectory leads nowhere (#217).
  - Both QuantEcon images trust every directory for git, so the `build-lectures` chapter's
    "dubious ownership" handling is for other images only. (#190)
- **`preview-netlify`, `preview-cloudflare` READMEs**: the Security sections said a notification
  is logged whenever the deploy is skipped. That holds only for Dependabot and fork PRs. On any
  event other than `pull_request`, both actions skip change detection, the deploy and the PR
  comment without saying so, and still succeed with an empty `deploy-url`; the sections now say
  that. (#143)
- **`docs/dev/PLAN.md`, `docs/dev/TESTING.md`**: statements the #143 spike disproved are
  corrected.
  - A gate can choose the candidate at run time: check it out, then call
    `uses: ./actions-repo/<action>`, which works in container jobs. PLAN 0b said no such design
    was possible.
  - Of the canary's gate-disqualifying properties, only Dependabot is repo-level (PLAN 0a).
  - A manual dispatch does not exercise the preview deploy.
  - `build-jupyter-cache`'s sibling chain can be covered before a release, by rewriting its
    nested `uses:` lines to local paths. TESTING.md and the harness header comment had called
    that impossible.

  PLAN 0c and the #135 and #143 rows record what the spike means for the plan; the decisions stay
  open. (#143)
- **User manual** (#178): `docs/user/` gets its index, `docs/user/README.md`, and its first
  chapter, `docs/user/actions/setup-environment.md`, which absorbs `setup-environment/README.md`;
  that README is now a signpost to it. The chapter's Inputs and Outputs tables, the index's action
  table and the signpost are generated from `action.yml` by `scripts/generate-docs.py`, between
  `BEGIN GENERATED` / `END GENERATED` markers. The harness `gate` job fails when they drift, and
  checks every example in `docs/user` and `templates/`: each `quantecon/actions` step passes only
  inputs its `action.yml` declares and every required one, each complete workflow sets
  `permissions:`, and each passes actionlint 1.7.12, a release pinned by checksum. PyYAML is pinned
  in `scripts/requirements.txt`, which a new Dependabot pip entry tracks; the generator and that
  file join the gate's ignore list, since the gate's own checks are their test. New chapters start
  from `docs/dev/CHAPTER-TEMPLATE.md`. (#189)
- **`setup-environment`**: the input and output descriptions in `action.yml`, which the manual now
  copies verbatim, are rewritten for readers and corrected in two places. `conda-cache-hit` is
  empty, not `false`, in container mode and on a cache miss. And `environment-name` overrides the
  environment file's `name:` rather than having to match it. The third error found, a
  `cache-version` bump that did not rebuild, is fixed under Fixed. (#189)
- Developer docs move to `docs/dev/`, the first step of the user manual (#178): `ARCHITECTURE.md`,
  `GPU-AMI-SETUP.md`, `PLAN.md`, `TESTING.md`, and `containers/VALIDATION.md` as
  `CONTAINER-VALIDATION.md`, with a `docs/dev/README.md` index. `docs/README.md`,
  `docs/FUTURE-DEVELOPMENT.md` and `PROJECT-OPTIMIZE-PREVIEWS.md` are removed; the preview plan
  is tracked in #92 and its sub-issues. The harness gate's ignore list follows the moves.
- **`restore-jupyter-cache` README**: the cache status sample now matches what the action prints.
  It showed an "Age Information" block the action has never produced, left out the "Directory
  Sizes" block it does produce, and showed an exact `Cache Hit` that a read-only restore with the
  generated key cannot get, since saved keys end in the saving run's id. (#187)
- **`docs/dev/PLAN.md`** refreshed after v0.12.0 delivered the rest of the July 2026 audit
  (#110): items 7 and 8 are done, item 10 is absorbed by the user manual (#178), item 15 is down
  to one cosmetic fix, a new item 18 records the `${{ }}` expressions still expanded inside `run:`
  scripts, and the consumers section lists the two follow-ups outside this repo (dropping
  `cname:` in six consumers, a permanent `preview-cloudflare` step in the canary). (#187)

### Fixed
- **`deploy-cloudflare`**: when a hostname serving the Worker is found ungated, the error said to
  turn Access on or turn off the Worker's `workers.dev` route. With the route off its preview URLs
  stay on, which wrangler itself warns may leave them public, so the message now says to turn off
  both the route and the preview URLs. (#190)
- **`setup-environment`**: bumping `cache-version` builds a fresh Conda environment, as it was
  documented to. It was in the exact cache key but in neither `restore-keys` fallback, and the
  first fallback matched the same environment file under any version, so a bump restored the
  previous version's environment and ran `conda env update` on it. `cache-version` now comes
  before the Python version and the file hash, and the key has one fallback, which includes it:
  `conda-<os>-<environment-name>-<cache-version>-py<python-version>-`. An edit to the environment
  file still restores the latest environment of the same version and updates it; a bump restores
  nothing. The key format changes, so the first standard-mode run after upgrading builds the
  environment from scratch once. Container mode has no Conda cache and is unaffected, and so is
  every current consumer: those that use `setup-environment` run it in a container. A new harness
  job, `env-version-bump`, bumps the version on a cached environment and fails unless nothing is
  restored; a second, `env-file-edit`, checks the other half, that an edited environment file
  under the same version still restores through the fallback. The step's closing summary now
  tells that case apart ("Restored from an earlier cache, then updated from the environment
  file") instead of reporting it as "Installed fresh". (#205)
- **`setup-environment`**: a restored Conda environment is an exact copy of the cache.
  `setup-miniconda` creates the environment before the restore, and the restore's `tar`
  extracted the cache on top of it, keeping every file only the fresh environment had. A cache
  whose packages differ from what a fresh `conda create` installs, as any pinned stack's do, came
  back as a mix of both. On the canary's Anaconda 2025.12 stack that put pip 26.2.1's files beside
  pip 25.3's, and pip failed to import: an exact hit left it broken, and a fallback restore failed
  the job, because `conda env update` runs pip. The environment `setup-miniconda` creates is now
  removed before the restore, and created again with `python-version` when nothing is restored.
  New harness jobs pin pip below a fresh install's, so the two environments differ, and check that
  an exact hit and a fallback restore each hold a single, working pip. (#209)
- **`test-containers-lectures.yml`**: the HTML stage is tried twice. Several lectures fetch a
  dataset from raw GitHub in a hidden cell at build time, and with the matrix building several
  repos at once from shared runner IPs that fetch is sometimes refused with HTTP 429,
  non-deterministically: the same notebook passed on the other container in the same run.
  Nothing in the stack retried it, so one 429 failed the leg and, off the weekly `workflow_run`
  trigger, filed a CI-failure issue for a flake. A first attempt that fails is now rebuilt once
  with `--all`. The repos build with `execute_notebooks: cache` and the jupyter cache survives
  between steps, so the retry executes only the notebooks that failed; `--all` is what makes it
  sound, because after a failed `-W --keep-going` build a plain rebuild reads nothing, re-emits
  no warning and exits 0 with the traceback still in the page, which would have passed every
  persistent failure. The retry uploads its execution reports as
  `reports-html-retry-<container>-<repo>`, and a retried leg says so in the job summary. A
  persistent failure still fails the leg. (#102)
- **`test-containers-lectures.yml`**: `lecture-python-programming` is back in the matrix. The
  February 2026 rewrite of the workflow (81e96ff) dropped it without a note, unlike
  `lecture-jax`, so lecture content from three repos executed on the images while the
  validation docs described four. Its notebooks fetch from raw GitHub at build time too, which
  the retry above absorbs. `docs/dev/CONTAINER-VALIDATION.md` and `docs/dev/TESTING.md` list
  the four-repo matrix under the repo's current name. (#102)
- **`scripts/check-latex-versions.sh`** runs under `set -euo pipefail` (PLAN item 15). A failed
  `apt-get update` used to be ignored, so the script went on to report versions from a stale
  package index. It now fails the run. The per-package lookup gains an explicit `|| true`: `grep`
  exits 1 for a package apt does not know, which under `pipefail` would abort the script before it
  could print `NOT FOUND`. (#187)
- **Containers**: the lean image (`quantecon-build`) exports plotly figures again. Its
  `environment.yml` pinned only ten packages to the Anaconda 2026.07 baseline, so everything else
  re-resolved whenever the image was rebuilt. The scheduled rebuild on 2026-10-19 moved plotly to
  7.x, which exports images only with kaleido 1.x, while both images ship kaleido 0.2 on purpose
  (it bundles its own chromium). Since then every `to_image` and `write_image` in the lean image
  has failed: the smoke test on `quantecon-build` has been red, with no alert, because
  `test-container.yml` files none; and so has the lecture-validation matrix's
  `lecture-python-advanced.myst` leg, whose lectures also pass `engine="kaleido"`, an argument
  plotly 7 removed. The full image takes plotly 6.7.0 from the metapackage and was unaffected.
  The lean image now pins every package in its file that the `anaconda=2026.07` metapackage
  also pins, at the metapackage's version, so its conda layer matches the full image's. Against
  a solve of the old file on 2026-11-04, eight versions move: plotly 7.1.0 → 6.7.0, ipykernel
  7.3.0 → 6.31.0, jupyterlab 4.6.4 → 4.5.9, notebook 7.6.3 → 7.5.7, ipywidgets 8.1.9 → 8.1.7,
  mkl-service 2.9.0 → 2.7.2, pip 26.2.2 → 26.1.2 and Python 3.13.18 → 3.13.14. mkl, jupyter,
  openpyxl, pytables, h5py, requests, beautifulsoup4 and pyyaml are pinned at the versions they
  already resolved to. xlrd, graphviz, python-graphviz and lxml are not in the metapackage, so
  they stay unpinned. The new pins join the conda `ignore` list in `.github/dependabot.yml`, so
  Dependabot does not propose moving them past the baseline. (#222)

## [0.12.0] - 2026-09-24

### Added
- **`deploy-cloudflare`**: a new action that publishes a built site to an existing Cloudflare
  Worker behind Cloudflare Access, for members-only sites that GitHub Pages cannot serve on the
  Team plan (Pages access control needs Enterprise Cloud). It runs on `push`, `schedule` and
  `workflow_dispatch`; `preview-cloudflare` stays PR-only. The part worth building is the gate
  check. An unauthenticated request must be answered with a redirect to **exactly** the team's
  `<team>.cloudflareaccess.com` login domain. A `2xx` fails as "the site is public", a redirect to
  another Access organisation fails, and so does anything else, including an unreachable host.
  The check runs **before** uploading, so a Worker that does not exist, is public, or is gated by
  the wrong organisation is refused with nothing uploaded. It runs again after the deploy, on
  production and on the new version's own preview URL (the config enables preview URLs, and a
  gate on the production hostname alone would leave that one public). It also runs when wrangler
  fails, because wrangler can fail after the version is live. An optional preview alias
  (`alias: report-2026-08`) is checked after its upload. Each check probes the site root and one
  real non-HTML file from the build, so a gate on the entry point alone cannot pass. The output
  URLs are constructed from inputs, never parsed from wrangler's output; only the version
  preview URL, which is probed but never output, comes from wrangler's version ID. The action does not
  create Workers or provision Access: an admin creates and gates each Worker once, and the deploy
  token is account-owned with Editor on that one Worker, so it cannot create an ungated Worker
  either. It takes the lessons of #105 for itself. wrangler is pinned exactly and installed with
  `npm ci` from a committed lockfile (Dependabot now tracks npm for this directory), and it runs
  uncaptured, so its errors reach the log. The action sets up Node 24 only when the runner has
  less than 22. The probe, `scripts/check-access-gate.sh`, is the one verified in the
  QuantEcon/status-projects#35 pilot. (#163)
- **CI**: four `deploy-cloudflare` harness jobs, none needing a Cloudflare account.
  `dc-gate-probe` runs the probe against a local stand-in (`.github/fixtures/access-gate/`) for
  every response shape. `dc-refuses-ungated` asserts that a Worker which does not exist is refused
  before wrangler is even installed, with a positive control showing the same inputs reach
  wrangler once the gate is off. `dc-inputs` asserts that every invalid input fails in
  validation, including #163's own example alias `2026-08`, which Cloudflare rejects because
  aliases must start with a letter. `dc-wrangler-config` dry-runs the generated config through the
  pinned wrangler, which is what a Dependabot bump of the lockfile is tested against. A real deploy
  is not covered; the first consumer deploy is its proof. (#163)
- **`build-jupyter-cache`**: `latex-requirements-file` input, passed through to
  `setup-environment`. A `pdflatex` builder forces `install-latex` on, and in standard
  (non-container) mode `setup-environment` then hard-fails when its requirements file is
  missing, but the path could not be set from here. The default is
  `latex-requirements.txt`, `setup-environment`'s own, and deliberately not `''`: the
  runner passes an explicit empty value through instead of applying the callee's default,
  which would have failed every standard-mode pdflatex build. Ignored in container mode,
  where the images ship LaTeX. (#109)
- **CI**: `bjc-builders-parse` harness job for the `builders` fix below. It turns the
  runner into a container-mode host with the same `/etc/quantecon-container` marker a GPU
  AMI carries, so the internal `setup-environment@v0` is a no-op and every build the
  parser enables fails in seconds on a missing source dir; the per-builder statuses then
  record exactly which builders were parsed. Two controls (`'jupyter,pdflatex,html'`, and
  a two-line block value with a trailing comma) must attempt exactly their builders;
  `'html,pdf'` and `'nojupyter'` must abort with no builder run. The old substring parser
  would have built html and jupyter respectively, and the controls prove setup really was
  a no-op, so an empty status cannot be a setup failure in disguise. `bjc-abort-guard`'s
  `'nonsense'` could not catch either shape: it names no valid builder at all. (#107)
- **CI**: `env-container-update` harness job, the first coverage anywhere of
  `setup-environment`'s `environment-update` path, and the harness's first container job.
  In `ghcr.io/quantecon/quantecon-build:latest` it applies a delta
  file that says `name: wrong-name` and asserts that the pip package it lists (checked
  absent beforehand) is importable by the `python` on `PATH`, that no `envs/wrong-name`
  appeared, and that the image's own packages survived. (#107)
- **CI**: the relevance gate now checks that every third-party `uses:` pin in
  `templates/*.yml` matches the ref `.github/workflows/` pins for the same action, with
  one `::error::` per mismatch. The templates are what consumer repositories are scaffolded
  from, and nothing kept them current: Dependabot's github-actions ecosystem scans
  `.github/workflows/` and named `action.yml` files only, so a `/templates` entry in
  `dependabot.yml` would be a no-op. It runs in the gate, which always runs, because a
  templates-only PR matches the ignore list and a gated job would skip exactly the PRs
  that can introduce drift. Consequence: a Dependabot major bump of such an action (today
  only `actions/checkout`) now goes red until the templates move in the same PR. (#109)
- **CI**: `preview-cli-install` harness job — `npm ci` from each preview action's lockfile on
  Node 24, after which the CLI must start and report the pinned version. The preview actions
  themselves cannot run in the harness (a deploy needs the provider's token, and they skip
  Dependabot's PRs outright), so without this job the Dependabot CLI bumps added below would
  merge with no CI signal at all. It does not exercise a deploy: a new CLI still needs a real PR
  against each provider. The gate's self-test now also treats the two lockfiles as must-run
  paths. (#105)

### Changed
- **`preview-cloudflare`, `preview-netlify`**: the CLI is no longer installed globally. Each
  job runs `npm ci` into a fresh directory under `RUNNER_TEMP` — not `$GITHUB_ACTION_PATH`, which in a
  container job is the `_actions` directory mounted from the host — and the deploy step calls
  the binary by the absolute path the install step now outputs as `bin`. The
  CLI's own executables (`wrangler`, `wrangler2`, `cf-wrangler`; `netlify`, `ntl`) are linked
  into a `bin` directory added to `GITHUB_PATH`, so they stay on `PATH` for later steps in the
  caller's job, as the global install left them, without the dependency bins in
  `node_modules/.bin` shadowing the caller's tools. (#105)
- **Container images**: Node.js moves from 20 (end-of-life 2026-04-30) to 24 LTS. The
  lean image carried 20.17.0 and the full image 20.20.2. It no longer comes from conda,
  which cannot supply 24 here: every `jupyterlab` below 4.6 on the defaults channel,
  including the 4.5.7 that `anaconda=2026.06` pins, constrains `nodejs` to 20.x. Both
  images now install Node from nodejs.org, pinned by version and SHA256 like Miniconda,
  after the conda layer. Dropping the conda `nodejs` leaves the full image's solve
  unchanged; the lean image holds `icu=73.1`, the version the old `nodejs` pinned, so its
  native stack does not re-solve. `netlify-cli` (27.x, which needs node >=22.13) and
  `wrangler` (which refuses to run below node 22), which `preview-netlify` and
  `preview-cloudflare` install per job, are now inside their supported range.
- **Templates**: `actions/checkout` moves from `@v4` to `@v7` in `ci.yml`, `cache.yml` and
  `publish.yml`, matching this repo's own workflows and the consumer repositories in
  `PLAN.md`'s table. `@v4` runs on node20, so every repository scaffolded from the templates brought
  Node 20 back; `@v7` runs on node24. The `fetch-depth: 0` on the `cache.yml` and
  `publish.yml` checkouts is kept. Templates reach a repository only when it is scaffolded,
  so existing consumers and the `v0` tag are unaffected.
- **`publish-gh-pages`**: `cname` still writes the `CNAME` file (it also lands in the
  release archive) but now warns that it has no effect on the deploy. The GitHub Actions
  Pages path this action uses (`configure-pages` → `upload-pages-artifact` →
  `deploy-pages`) ignores `CNAME` files; the custom domain is set only in Settings → Pages,
  which the input description and README now say. The value reaches the shell through
  `env:` rather than `${{ }}` interpolation. (#109)
- **Container tests**: the smoke fixture now builds with `quantecon_book_theme`, the theme both
  images ship and every lecture site uses, instead of `sphinx_book_theme`, and no longer sets
  `latex_elements.fontpkg: ""`. That override sent the PDF build down the TeX-defaults path,
  so it never loaded the FreeFont `.otf` names that Sphinx's default xelatex `fontpkg` asks for
  and both Dockerfiles symlink into place; a regression there could not fail the test. The
  unused `containers/quantecon/tests/test-container.sh` (full image only, `set -e` only, in
  no workflow) is deleted and the image README points at `smoke-test.sh` and the Test
  Container workflow instead. `run-local-tests.sh` now passes `-W --keep-going` like the CI
  script, so a warning that fails CI also fails locally. (#108)

### Removed
- **`publish-gh-pages`**: the `asset-url` output. It was bound to
  `steps.upload-release.outputs.asset-url`, which `softprops/action-gh-release` never sets
  (it exposes `url`, `id`, `upload_url` and `assets`), so it was always empty while the
  README advertised it. Not repointed at `fromJSON(…assets)[0].browser_download_url`:
  unguarded, that errors whenever the release step is skipped, which is the default. A
  caller still reading it gets the same empty string as before. (#107)

### Fixed
- **Container images, `build-lectures`**: every page built in a container job lost its
  "Last changed" header and changelog, with nothing in the log. The runner owns the
  bind-mounted workspace (uid 1001) while container steps run as root, so git refuses the
  work tree ("detected dubious ownership", exit 128) after `actions/checkout`, whose own
  `safe.directory` entry lives only in a temporary HOME. quantecon-book-theme drops the
  header when git fails, and `detect-changed-lectures.sh` hides the same failure behind
  `|| true`, so in a container job it can report no changed lectures. Both images now set `safe.directory '*'` at system scope. `build-lectures`
  trusts the source work tree when git cannot read it, and warns when it still cannot, or
  when the checkout is shallow (which dates every page to the checkout commit). The
  `publish.yml` and `cache.yml` templates now check out with `fetch-depth: 0`.
- **`setup-environment`**: in container mode the delta update could land in the wrong
  environment. `conda env update -f` took its target from the file's own `name:`, so a
  delta saying `name: lecture-python` went to a new `envs/lecture-python`, not on `PATH`:
  the step printed "✅ Environment updated successfully" and the build then failed with
  `ModuleNotFoundError`. It now updates the environment that is actually active, the
  prefix of the `python` on `PATH` (`conda env update -p`), and fails with diagnostics if
  that is not a conda env. Not `-n <environment-name>` as #107 proposed: on a
  container-mode host whose stack lives in `base` (the GPU AMI of `docs/GPU-AMI-SETUP.md`)
  that would silently create a fresh `envs/quantecon`, because `conda env update` creates
  a missing prefix without a word. A `::warning::` names any disagreement between the
  file's `name:` or `environment-name` and the active env (a host whose stack is in `base`
  silences the second with `environment-name: base`). Still no `--prune`, which would
  strip the image's env down to the delta. The file path is quoted now and reaches the
  shell through `env:`. (#107)
- **`setup-environment`**: the LaTeX requirements file is parsed properly. `grep -v '^#'`
  stripped only whole-line comments, so `texlive-xetex   # for unicode math` reached apt
  verbatim, and a file of nothing but comments failed the `PACKAGES=$(…)` pipeline under
  `pipefail`, killing the step with no output. `#` now starts a comment anywhere on a
  line, CRLF and several packages per line work, and each name reaches `apt-get` as its
  own quoted argument. A file with no package names is an explicit `::error::`, not the
  warn-and-skip #107 proposed, deliberately: `install-latex: true` with nothing to install
  is a misconfiguration, and skipping would only defer the failure to a harder-to-diagnose
  missing-TeX error in the pdflatex build. (#107)
- **`setup-environment`**: the environment summary listed the wrong Python in standard
  mode. The step runs plain `bash` (deliberately, for containers), which has not run
  `setup-miniconda`'s login-shell activation, so `pip list` showed the runner's default
  Python right under "Conda: Restored from cache ✅". Standard mode now lists
  `$CONDA/envs/<environment-name>` explicitly (`python -m pip list`, falling back to
  `conda list -n`) without the `2>/dev/null` that hid errors, and never fails the step.
  Container mode is unchanged. (#107)
- **`build-lectures`**: the failure banner named an artifact that did not exist and the
  wrong reports directory. It hardcoded `execution-reports-<builder>` although the upload
  honours `failure-artifact-name`, which `test-containers-lectures.yml` always sets, so
  every failing container-validation run printed a wrong download line; and it sent
  pdflatex users to `_build/pdflatex/reports/`, where Sphinx's outdir is `_build/latex`.
  The banner now takes the artifact name from the upload step's own expression and the
  reports path from the upload step's path list. (#107)
- **`build-jupyter-cache`**: `builders` was validated and parsed by substring, so
  `'html,pdf'` passed and built html alone with no warning, `'nojupyter'` switched the
  jupyter build on, and `install-latex`, derived from the same test, followed. The input
  is now split on commas and any whitespace (newlines included, so a YAML block value
  works), empty tokens are skipped, and each token must be exactly `jupyter`, `pdflatex`
  or `html`; every unknown one gets its own `::error::` naming the valid set, before
  setup starts. `'html, pdflatex'`, `'html pdflatex'` and `'html,'` still work, and
  matching stays case-sensitive (`'HTML'` was already rejected). Validation and parsing
  are one step now, and the input reaches the shell through `env:`. (#107)
- **`build-jupyter-cache` README**: the `upload-artifact` row and the build-flow diagram
  still put the `_build` artifact on the success path; since v0.8.0 it uploads only when a
  build fails (the step's gate is `upload-artifact == 'true' && all-passed != 'true'`).
  (#109)
- **`scripts/detect-changed-lectures.sh`**: a renamed lecture never got a preview deep
  link. `git diff --name-status` reported it as `R<score>` with two paths, which the
  added/modified filter dropped, so neither preview action linked it. `--no-renames`
  decomposes a rename into `D` + `A`, and the `A` half is kept like any added lecture.
  (#107)
- **`preview-cloudflare`**: a failed deploy printed no diagnostic at all. Under
  `bash -eo pipefail`, `DEPLOY_OUTPUT=$(wrangler pages deploy … 2>&1)` aborted the step on
  wrangler's non-zero exit with wrangler's stderr captured into the variable, so the log ended
  at `🔍 Deploying preview…` and the output dump and error branch after it were unreachable
  (`DEPLOY_EXIT_CODE=$?` could only ever read 0). wrangler's output now streams into the
  `Deployment Output` group through `tee`, the exit code is read from `PIPESTATUS` with `set -e`
  suspended around the call, and a failure ends with an `::error::` annotation and wrangler's
  own exit code. Neither preview action had any `::error::` annotation before. (#105)
- **`preview-netlify`**: the same abort-before-dump shape threw away the captured `--json`
  error payload of a failed deploy; netlify's readable error on stderr did reach the log.
  stdout now goes through `tee` to a file, with the same `PIPESTATUS` capture and `::error::`.
  It is stdout only: merging stderr would corrupt the JSON whenever a successful deploy prints
  an npm or Node notice. Separately, the "Raw output was:" guard could not fire in the case it
  was written for. `python3 -c "…json.load…"` exits non-zero on non-JSON stdout, and `set -e`
  aborted the step at the assignment with a bare traceback, so the guard only ever fired on
  valid JSON lacking `deploy_url`/`url`. The parse is now `|| true`, and the guard prints the
  raw output and fails with an `::error::`. (#105)
- **CI**: the image-size job in `test-container.yml` has never reported a size, so the
  v0.11.0 entry saying image size "is now reported from the manifest" (#108) did not hold.
  `docker/build-push-action` attaches a provenance attestation by default, which makes each
  `:latest` an OCI image index (the amd64 image plus an attestation manifest) with no
  top-level `layers`. jq failed with "Cannot iterate over null" on every run, and without
  `pipefail` the step took `tee`'s exit status and stayed green. The job now reads the
  `linux/amd64` manifest out of the index and reports two labelled figures: **compressed**,
  the sum of its layer sizes (what a cold pull downloads), and **on disk**, the unpacked
  layers after a `docker pull` as `docker image inspect` reports them on the overlay2 graph
  driver. It runs under `pipefail`, requires each figure to be a positive integer, and fails
  under the containerd image store, where that inspect field is the compressed content size
  instead. (#106, #108)

### Documentation
- Swept the docs against the shipped code (#106, #109, #99): the Anaconda 2026.06 baseline (the
  full image's metapackage, the lean image's pin set); image sizes measured on 2026-09-23 and
  labelled by metric (full 3.33 GB compressed / 8.60 GB on disk, lean 2.93 / 7.32 GB), replacing
  "~8GB / ~3GB" and "~60% smaller"; the lean image's TeX Live is the full image's minus
  `texlive-luatex`, not "minimal". Examples that call a preview action grant
  `pull-requests: write`, and `actions/checkout` examples move to `@v7`.
  Nonexistent inputs (`preview-netlify`'s `alias`, `build-lectures`' `build-html` and
  `cache-workflow`), an invented LaTeX-cache log line, a Pages-404 fix that dropped `pages` and
  `id-token`, and stale cache keys are corrected; custom domains point at Settings → Pages, since
  the Actions Pages deploy ignores a CNAME file. New `templates/latex-requirements.txt` for
  standard-runner PDF builds; CONTRIBUTING.md documents staged releases and the `v0` rollback.

### Security
- **`preview-netlify`, `preview-cloudflare` READMEs**: the Security section suggested
  `pull_request_target` for fork PRs. Following it builds and runs a fork's notebooks with the
  deploy token and a write-scoped `GITHUB_TOKEN` in reach, the "pwn request" pattern, and it
  would not have produced a preview anyway: both actions deploy only when
  `github.event_name == 'pull_request'`, so under `pull_request_target` the fork check never
  fires and the deploy step is skipped. Both READMEs now say fork previews are unsupported and
  warn against `pull_request_target`. (#105)
- **`preview-cloudflare`, `preview-netlify`**: `wrangler@latest` and `netlify-cli@latest` were
  installed on every run and then handed the deploy credentials — two unpinned npm packages
  with large dependency trees, in a repo that SHA-pins every third-party Action against tag
  hijacking. Each CLI is now pinned to an exact version (wrangler 4.136.3, netlify-cli 27.8.1)
  by a `package.json` and `package-lock.json` beside its `action.yml`, and `npm ci` installs
  exactly that lockfile, integrity hashes included. The Dependabot `npm` entry that
  `deploy-cloudflare` introduced now covers both preview directories as well, grouped like the
  other ecosystems: minor/patch bumps of the three CLI pins in one PR, majors in another. (#105)
- **`preview-netlify`**: the auth token is off the command line and out of the generated step
  script. `--auth="${{ inputs.netlify-auth-token }}"` wrote the token into the script file the
  runner puts on disk and into the argv of the netlify process. The step now passes it as
  `NETLIFY_AUTH_TOKEN` and the site as `NETLIFY_SITE_ID`, both read natively by netlify-cli
  (checked against 27.8.1's source), and drops `--auth` and `--site`. The PR number, head SHA
  and `build-dir`, also interpolated into the script before, move into `env:` in the same
  edit, as v0.11.1 did for `preview-cloudflare`. The deploy also passes `--no-build`: the site
  is prebuilt, and netlify-cli 27 would otherwise run any configured build command first, in a
  process that inherits the token. Closes `PLAN.md` backlog item 8. (#105)

## [0.11.1] - 2026-08-07

### Fixed
- **`preview-cloudflare`**: PR comments linked the per-deployment hash URL
  (`https://b3a5c314.{project}.pages.dev`) instead of the stable branch alias
  (`https://pr-{number}.{project}.pages.dev`), so every push to a PR produced a
  fresh set of links and reviewers had to scroll for the newest comment. The cost was larger
  than the headline URL: **every per-lecture deep link** in the comment carried the same hash,
  so a reviewer could not keep a tab open across a review. The alias is now **constructed**
  rather than parsed — `pr-N` is already alias-safe, so the URL is fully determined by inputs
  the action already holds, and no output parsing can go wrong. Note the README already
  documented the alias as the behaviour, so this brings the code in line with its own docs.
  A latent bug went with it: the old `grep … | head -1` took whichever `pages.dev` URL came
  first, and wrangler prints the alias *before* the hash URL in some versions — so
  `deploy-url` silently returned the alias on one wrangler release and the hash on another.
  The per-deployment URL is still worth having, so it is now a separate `deployment-url`
  output (extracted by excluding the alias, not by position) and named in the comment's
  Build Info block for anyone who needs to look at one specific revision. Inputs in the
  deploy step also move from `${{ }}` interpolation into `env:`, matching the discipline the
  comment step in the same file already followed. (#14)

## [0.11.0] - 2026-08-07

### Added
- **build-jupyter-cache**: `upload-failure-reports` input, default `true`, passed through to the
  inner `build-lectures` calls so a failed cache build uploads its `reports/*.err.log` tracebacks.
  Previously the failure issue told maintainers to "download the build artifact for detailed
  execution reports" while those reports were only reachable buried inside the full `_build`
  artifact — hundreds of MB including `.jupyter_cache` — and not at all when `upload-artifact` was
  off. The issue body now names the artifacts that were actually produced and gives per-builder
  reproduce commands matching `build-lectures`' real flags. The default deliberately differs from
  `build-lectures`' own `false`: that action is driven by a human watching a PR, this one runs
  unattended. (#83)
- **CI**: `bjc-fail-guard` harness job — a failing cache build must fail the step, report
  `html-status=failure`, and save **no** cache over the last good one. The failure path had no
  coverage at all, which is how three bugs accumulated on it. Issue filing itself stays out of the
  PR harness (it needs `issues: write` and would file real issues on every run); that belongs to
  the canary. (#83)

### Changed
- **CI**: the action harness no longer uses `paths:` filters. A path filter suppresses creation of
  the workflow *run*, not just its jobs, so no check run is ever published for that commit and a
  required `Action harness: all checks` would sit "waiting for status to be reported" forever —
  GitHub's own guidance is to avoid requiring workflows that can be skipped. Demonstrated live:
  release PR #119 touched only `CHANGELOG.md` and GitHub reported "no checks reported on the
  branch". The workflow now always runs, and a new `gate` job decides relevance per-job (a job
  skipped by a conditional reports success to a required check). This is the prerequisite for
  making the harness a required check on `main` — issue #116 item 5, whose suggested
  `paths-ignore` companion workflow would not have worked, since `paths-ignore` is not the
  complement of `paths` and a mixed PR would fire both, producing two same-named check runs.
  The gate's decision rule is an **ignore** list rather than a cover list, deliberately: for a
  required check the expensive mistake is a green earned by running nothing, so anything
  unrecognised runs the whole harness. It also self-tests — the must-always-run set is derived
  from the `uses: ./<action>` lines in the workflow itself, so widening the ignore list to swallow
  a real action path fails the gate closed instead of silently skipping the suite. `harness-summary`
  now certifies both shapes (all-ran and all-skipped), rejects a vacuous empty job set, and fails
  if the gate and the fan-out disagree. (#116)
- **CI**: the container smoke tests could not fail. `containers/quantecon/tests/minimal-jupyter-book/`
  was inert for three independent reasons — `execute_notebooks: "off"`, its one code block was a
  plain ` ```python ` fence rather than a `{code-cell}`, and it had no jupytext front matter — so an
  image whose numpy, matplotlib or kaleido was completely broken still produced a green test. It now
  executes real cells that **assert** on results (a stack that imports but computes wrong answers is
  exactly what a smoke test should catch), covering numpy/scipy, pandas, a real matplotlib PNG
  render, and a plotly static export through kaleido — the #85 path. `execute_notebooks: force` plus
  `raise_on_error: true`, and the build passes `-W`, because a raising cell is otherwise only a
  warning.
  `test-container.yml` now runs both images as real `container:` jobs rather than `docker run`. That
  is not cosmetic: a container job forces `HOME=/github/home` while `docker run` leaves `HOME=/root`,
  and that difference is precisely why #85 passed these tests while failing the lecture matrix, which
  does use a container job. The job asserts `HOME` explicitly so a silent revert is caught. A new
  `--self-test` mode stages a deliberate exception and fails if the build does *not* go red,
  attributing on captured output rather than `reports/*.err.log` (with `raise_on_error` myst-nb
  raises before Sphinx writes the report). The lean image also gains pdflatex coverage it never had,
  and image size is now reported from the manifest — **compressed** layer bytes, a different and
  smaller number than the previous `docker images` figure, so the two series are not comparable.
  (#108)

### Fixed
- **build-jupyter-cache**: failure alerting **never worked in container mode**, which is the
  documented default. Three independent bugs sat on the same 14-line path, and because that path
  only runs once something else has already broken, none were caught. (1) The step invoked its
  script through `${{ github.action_path }}`, which expands to the *runner's* path
  (`/home/runner/work/_actions/...`); inside a job `container:` the action is mounted at
  `/__w/_actions/...`, so bash got a nonexistent path — `No such file or directory`, exit 127,
  before the script ran (actions/runner#2185). (2) Neither container image installs `gh`, so
  fixing (1) alone would have died one line later on `gh issue list`. (3) `gh issue create
  --label` validates labels client-side and fails when they don't exist — no consumer has
  `build-failure` or `automated`, so even a hosted runner with `gh` would have failed. The step is
  now `actions/github-script` against the REST API: no CLI, no `action_path`, and missing labels
  are created implicitly. Observed impact: `lecture-dp` ran ~2 months un-alerted (#28), and the
  canary repo failed eight consecutive weeks (2026-02-22 → 2026-04-12) filing zero issues while a
  sibling workflow using a REST-API action filed every week. (#83)
- **build-jupyter-cache**: a failed build could be reported as the *wrong* failure. Composite
  steps carry an implicit `success()` in a plain `if:`, so once any earlier step failed —
  including the alerting step itself — `Fail if builds failed` silently skipped, and the job's
  only error was whatever incidental step happened to break. In `lecture-dp` run 26381283100 the
  visible red was an exit-127 from "Create failure issue" while the actual build failure never
  surfaced. Both that step and the alert step are now `always() && …`. (#83)
- **build-jupyter-cache**: alerting can no longer silently no-op. A new step asserts an issue was
  actually filed and fails the job with an explicit error otherwise; the URL is exposed as the new
  `failure-issue-url` output. **Consumers must have `issues: write`** while
  `create-issue-on-failure` is `true` (the shipped `templates/cache.yml` already does) — a missing
  permission is now a loud failure with a message naming the fix, rather than silence. (#83)
- **`build-jupyter-cache`**: a failure *before* the builds — most plausibly an `environment-update` that no
  longer solves, a container tag that stops resolving, or a registry outage on pull — alerted nobody. The
  `Setup environment` step has no `continue-on-error`, so the composite aborted there and `verify-builds`
  never ran; its `all-passed` output was therefore `''` rather than `'false'`, and all three downstream
  guards tested `== 'false'`. The alert step, the "verify the alert was filed" assert added in #122, and
  the fail step all skipped, so an unattended weekly build could go red with nothing reaching the tracker —
  the same silence #83 was about, on the one path #122 did not cover. The action now resolves its overall
  status in a single `always()` step that maps "verify-builds never ran" to `false`, and every guard tests
  `!= 'true'` rather than `== 'false'`, so the failure path fails **safe**: it alerts on any abort, not only
  on anticipated ones. This also covers aborts in the input-validation steps above `Setup environment`,
  which had the identical hole. `build-success`/`cache-saved` consequently report `false` where they used to
  report `''` — a value no caller could distinguish from success. The `continue-on-error: true` on `Setup
  environment` sketched in the issue was deliberately not taken: it would have let all three builds run
  against a broken environment, burning the full build timeout to produce an issue whose table blames the
  lectures for an environment failure. Two follow-on defects on the same path are fixed with it — the issue
  body listed a `build-cache-<run-id>` artifact whenever `upload-artifact` was on, but that upload is
  correctly skipped when nothing was built (it now keys off the upload step's `artifact-id` output, which is
  empty both when that step is skipped and when `if-no-files-found: warn` lets it succeed having uploaded
  nothing — the step's outcome alone would not have caught the second case), and its "no artifacts" fallback
  asserted both upload inputs were off when the real reason was that no build ran. The
  issue body and job summary now name the phase that failed and distinguish a builder that was *considered
  and skipped* from one that was *never run*. Covered by a new `bjc-abort-guard` harness job asserting both
  abort shapes; note that whether an issue is actually *filed* remains canary-only, since it needs
  `issues: write`. (#123, #127)

## [0.10.0] - 2026-08-05

### Added
- **CI**: Action-level PR harness (`.github/workflows/test-actions.yml`) — the first automated
  tests for the action logic itself, run against the PR's code via `./` local paths. Covers
  `restore-jupyter-cache` (both cache types × both modes, `fail-on-miss` both ways — the #104
  defect class), the standard-mode conda cache in `setup-environment` (two-run miss→hit chain,
  the #33/#78 path CI had never confirmed), a real executed `build-lectures` HTML build in both
  directions (a good build passes; a build whose code cell raises must fail the step), and a
  `build-jupyter-cache` → `restore-jupyter-cache` round-trip. Ships a committed
  `.github/fixtures/mini-lectures/` fixture that, unlike the container test book, executes a
  real code cell so `_build/.jupyter_cache` is genuinely populated. First stage of #100;
  publish/preview coverage and the `@v0` sibling-pin chain remain with the post-release canary
  proposed there. (#100)

### Changed
- **build-lectures**: documented that `-W` is load-bearing for build failure. A code cell that
  raises is only a *warning* to Jupyter Book, so `-W` in the `extra-args` default is the sole
  reason a broken lecture fails the build — and `extra-args` replaces the default rather than
  extending it. Overriding it without `-W` yields a published site, an error-report page, and
  exit 0. The README now says so next to the default, and the Troubleshooting entry that
  suggested bare `--keep-going` is corrected (it does nothing without `-W`). (#116)
- **CI**: `build-fail-guard` now attributes its expected failure instead of accepting any red.
  Asserting only `outcome == failure` would also have been satisfied by a build that died on an
  unrelated `-W` warning; the job now requires the staged `CellExecutionError` traceback in
  `harness/_build/html/reports/broken.err.log`. Also recorded in the workflow header that
  "Re-run failed jobs" can never go green on this harness — it bumps `run_attempt`, and so the
  cache salt, without re-running the seed jobs that saved under the old salt. (#116)
- **publish-gh-pages**: `softprops/action-gh-release` moved to v3.0.2, SHA-pinned as
  `3d0d9888cb7fd7b750713d6e236d1fcb99157228`. Recorded retrospectively — it shipped in v0.10.0
  with no entry at the time, which left the v0.9.0 note about v3.0.1 (#94) as the file's last word
  on the pin while the code had moved past it. (#101)

### Fixed
- **build-lectures**: on hosted (non-container) runners, a **successful build failed the step
  anyway**. The build step runs in a login shell (`bash -l`, required for conda activation) and
  ended with `exit $BUILD_EXIT_CODE`; the exit builtin triggers `~/.bash_logout` processing,
  where Ubuntu's `clear_console` fails on a headless runner at `SHLVL=1` and its status
  overrides the one passed to `exit` — so `jb build` printed its success banner and the step
  still returned 1. The step now returns its status by ending the script instead of calling
  `exit`. Container builds were never affected (root has no `~/.bash_logout`), which is why
  production lecture builds never surfaced this. Caught by the new action harness. (#100)
- **setup-environment**: the standard-mode Conda environment cache could be saved but **never
  restored** on hosted runners. The cache was rooted at `${CONDA}/envs`, whose parent directory
  is root-owned on the runner image, so every restore died in tar (`Cannot utime` / `Cannot
  change mode: Operation not permitted`) and `actions/cache` reported a miss — every run paid
  the full environment solve, and a partial extraction could leave a mangled env behind for
  `conda env update` to patch. The cache is now rooted at the runner-owned
  `${CONDA}/envs/<environment-name>` directory, which round-trips cleanly. Existing caches under
  the old path become unreachable (the `path` input is part of the cache version); the first run
  after upgrading re-saves under the new path. Caught by the new action harness on its first run
  — this is the #33/#78 path that PLAN item 9 noted had never been confirmed by CI. (#100)

## [0.9.0] - 2026-07-23

### Added
- **CI**: `test-containers-lectures.yml` and `build-containers.yml` now open (or comment on) a
  deduplicated tracking issue when they fail, via the new
  `scripts/create-ci-failure-issue.sh`. Both run unattended — off a weekly schedule and off
  `workflow_run` — and had no alert path: container validation was red for nine consecutive weeks
  in Feb–Apr 2026 with nothing surfacing it. One open issue is kept per workflow; repeat failures
  are appended as comments. Manual `workflow_dispatch` runs are excluded, since those have someone
  watching. (#103)

### Changed
- **Containers**: Migrated both images to the **Anaconda 2026.06** baseline (`anaconda=2026.06` in
  `containers/quantecon/environment.yml`, and the matching linux-64 py313 MKL pin set in the lean
  image's explicit stack). This is the baseline the lecture repos build against. The images have
  shipped this since 2026-07-08 — it is live in `:latest` and reaches consumers through the image
  tag rather than through this release. (#95)
- **build-jupyter-cache, restore-jupyter-cache, setup-environment**: `actions/cache`,
  `actions/cache/restore` and `actions/cache/save` moved from `@v5` to `@v6`. (#90)
- **publish-gh-pages**: `softprops/action-gh-release` moved to v3.0.1. (#94)

### Fixed
- **restore-jupyter-cache**: Every output, and the `fail-on-miss` guard, now work with
  `save-cache: 'true'`. The save-mode step used the top-level `actions/cache@v6`, which declares
  `cache-hit` alone — `cache-matched-key` exists only on `actions/cache/restore` — so the outputs
  bound to it always came back empty: `cache-hit` was `false` on a perfect restore, `cache-key` was
  blank, the status report announced "⚠️ No cache found" immediately after logging a successful
  restore, and `fail-on-miss: 'true'` failed the job unconditionally. The restore now always runs
  through `actions/cache/restore@v6`, and save mode adds an `actions/cache@v6` step with
  `lookup-only: true` whose only job is to register the job-end save `post:` hook. ⚠️ This is the
  mode the preview-optimisation work rolls out (#92). (#104)
- ⚠️ **BREAKING** **restore-jupyter-cache**: Dropped the bare `build-` restore-key fallback, which
  made the build cache impossible to miss — an `environment.yml` change silently restored a `_build`
  produced by the old environment instead of missing and rebuilding, contradicting the action's own
  documented behaviour. The `build-{env-hash}-{update-hash}-` and `build-{env-hash}-` fallbacks
  remain, so a warm start is still found within the same environment. The execution cache keeps its
  bare `jupyter-cache-` fallback: `.jupyter_cache` is content-addressed per notebook and revalidates
  itself, whereas `_build` carries no record of what produced it. (#104)

  **Migration:** no config change is needed, but the first build after an `environment.yml` change
  is now a genuine cache miss and therefore cold. That is the intended behaviour — the warm start it
  replaces was reusing build output generated by the superseded environment.
- **CI**: The buildx registry layer cache in `build-containers.yml` now resolves. Both `cache-from`
  refs interpolated `github.repository_owner`, which preserves the `QuantEcon` casing; buildx
  rejects `ghcr.io/QuantEcon/...` as "repository name must be lowercase" and treats a failed cache
  import as non-fatal, so every container build since the cache was added has been cold — and green.
  The namespace is now a lowercase `IMAGE_NAMESPACE` env var used by both jobs. (#103)
- **CI**: Added a workflow-level `concurrency` group to `build-containers.yml`. Both jobs push
  `:latest` and every consumer pins `:latest`, but nothing serialised the workflow — on 2026-07-08
  two overlapping runs meant the *older* commit's build finished last and won the tag. (#103)
- **CI**: `test-containers-lectures.yml` no longer silently cancels most of its matrix. The
  job-level group `test-build-${{ matrix.repo.repo }}` was shared across runs, and a concurrency
  group holds only one running plus one pending job, so a later run evicted the earlier run's queued
  legs — all three runs on 2026-07-08 concluded `cancelled`, which does not read as a regression.
  The group is now scoped by run id, with superseding handled explicitly by a workflow-level group.
  This is the only workflow that exercises `setup-environment` and `build-lectures` against real
  lecture content. (#103)
- **CI**: Added `permissions:` and `timeout-minutes` to the workflows that declared neither
  (`test-container.yml`, `check-latex-versions.yml`), `permissions:` to
  `test-containers-lectures.yml`, and `timeout-minutes` to the `build-containers.yml` build jobs.
  (#103)
- **Containers (quantecon-build)**: Pinned the lean image's core scientific stack (numpy, scipy,
  pandas, matplotlib, seaborn, sympy, numba, networkx, statsmodels, scikit-learn) to the Anaconda
  2025.12 baseline the lecture repos built against at the time (via `anaconda=2025.12`), instead of
  resolving to "latest at build time". The unpinned stack drifted ahead of that baseline, yielding
  non-reproducible images that diverged from what the lectures are tested against; downstream this
  surfaced as a `CellExecutionError` in `un_insure.md` on repos building on the lean image (the
  likely trigger being numpy 2.4.0's stricter array-to-scalar conversion, though the exact breaking
  combination is no longer reproducible on current packages). The full `quantecon` image already
  pinned `anaconda=2025.12` and was unaffected. (#28) — both images have since moved to the 2026.06
  baseline within this same release; see **Changed** above (#95).
- **Containers**: Pinned `kaleido<1.0` in both images and dropped the build-time
  `kaleido.get_chrome_sync()` step. Unpinned, `kaleido` resolved to v1.x, which dropped the bundled
  chromium and requires a separately provisioned Chrome; the build-time download landed in `/root`
  but CI container jobs run with `HOME=/github/home`, so Plotly static-image export failed at runtime
  with `ChromeNotFoundError` (e.g. `BCG_complete_mkts.md`, `BCG_incomplete_mkts.md`,
  `knowing_forecasts_of_others.md`). kaleido 0.2.x bundles its own chromium (location-independent)
  and still exports PNGs on the current plotly. (Migrating to kaleido v1 with system-provisioned
  Chrome is a future follow-up.)

## [0.8.0] - 2026-06-16

### Fixed
- **restore-jupyter-cache**: Read-only restore no longer uses a fake `-00000000` primary key that
  could never match; it now uses the content/env prefix directly, so the logged "Requested Key" is
  honest (behaviour unchanged — restore still falls through to prefix matching). (#34, H4)
- **CI**: Container test workflows (`test-container.yml`, `test-containers-lectures.yml`) now check
  out the commit that built the image (`workflow_run.head_sha`, falling back to `github.sha`)
  instead of the default branch, so tests run against the matching commit. (#37, M11/M12)
- **build-jupyter-cache**: Internal sibling action calls are pinned from `@main` to `@v0`, so a
  pinned `build-jupyter-cache` no longer transitively executes unreleased `main` code. (Relative
  `./` paths can't be used — in a composite action they resolve against the consumer's workspace,
  not this repo.) (#38, H8)
- **publish-gh-pages**: Release tarball is written to `$RUNNER_TEMP` (outside `build-dir`) so the
  archive can't recurse into itself (#38, M15); `create-release-assets` now skips off-tag and fails
  fast when `github-token` is missing, instead of erroring mid-upload (#38, M16).
- **build-lectures**: The build command no longer uses `eval`; it invokes `jb build` directly with
  the source/output directories passed via `env` and quoted, so paths with spaces/metacharacters are
  handled safely. The `output-dir` default changed from `./` to `.` (drops the `.//_build`
  double-slash). `extra-args` is still word-split (documented in the step). (#36, M10/L17/L22)
- **setup-environment**: Fixed standard-mode (non-container) Conda caching — the env was restored
  from cache and then **recreated unconditionally** by `setup-miniconda`, so the cache saved
  nothing. It now restores the cached env (`${CONDA}/envs`, keyed by env name + Python version +
  `environment.yml` hash) and runs `conda env update --prune` only when there's no exact cache hit
  (a miss or a `restore-keys` partial match); dropped the deprecated `use-only-tar-bz2`. The
  `environment.yml` is validated up front, missing LaTeX requirements now error instead of silently
  skipping (broken env later), and the `cache-version` input documents that it is standard-mode only
  (no effect in container mode). (#33, C3/L19/L23)

### Changed
- **restore-jupyter-cache**: Documented the optional `save-cache` input (PR-scoped saving) and
  clarified the `path` constraint (must match where `build-lectures` reads, `_build`) across the
  README and `docs/QUICK-REFERENCE.md`; the docs no longer claim the action is strictly read-only.
  (#34, H5/L21)
- **Docs**: Documented that the build-cache key is intentionally environment-only (warm-start
  baseline; freshness handled by jupyter-cache + Sphinx incremental + the weekly cold rebuild) in
  the cache action READMEs and `docs/ARCHITECTURE.md`. (#34, H6)
- **build-jupyter-cache**: The `_build` artifact is now uploaded only when a build fails (for
  debugging), instead of duplicating the cached `_build` into a 30-day artifact on every successful
  run. (#38, M14)
- **Containers**: Pinned Miniconda in the full `quantecon` image to a specific version + SHA256
  (matching the lean `quantecon-build` image) for supply-chain security and reproducibility, and
  added `apt-get clean` for image-size parity. (#32, C2/L20)
- **Containers**: Capped `nodejs` at the current LTS (`>=20,<25`, i.e. ≤ node 24) in both container
  environments, and added a matching Dependabot `ignore` (node ≥ 25), excluding the non-LTS node 25
  line that Dependabot's `<26` proposal would have allowed.
- **preview-netlify / preview-cloudflare**: De-duplicated the change-detection logic into a shared
  `scripts/detect-changed-lectures.sh`, and made it treat `lectures-dir` as a literal path instead
  of a regex (a dir name with `.`/`+` etc. no longer misbehaves). The per-file "has changes" test
  now uses `git diff --quiet` rather than parsing diff text, fixing a pre-existing edge case where a
  file whose only changes were `---`/`+++`-style lines (e.g. front-matter delimiters) was wrongly
  excluded. (#35, M9/H7)

### Security
- **preview-netlify / preview-cloudflare**: PR-controlled values (changed file paths, deploy URL)
  are now passed to the `github-script` PR-comment step via `env` and read from `process.env`
  instead of being interpolated into the script body, closing a script-injection vector. (#35, N2)
- **CI**: SHA-pinned the third-party GitHub Actions (`docker/*`, `softprops/action-gh-release`,
  `conda-incubator/setup-miniconda`) to full commit SHAs (with a `# vN` comment), so a hijacked
  upstream tag can't inject code into our workflows. First-party `actions/*` stay on major tags
  (GitHub-maintained, per GitHub's guidance), and Dependabot keeps the SHA pins current. (#39, L18)

### Documentation
- Swept the docs for stale references and inconsistencies (#40, D24–D34): replaced dead workflow /
  template / file references (`containers/VALIDATION.md`'s fictional builder pipeline → the real
  `test-containers-lectures.yml`; `cache-standard.yml`; `Dockerfile.gpu` / `environment-gpu.yml`);
  corrected the container sizes from measured values (lean ~7.1 GB / full ~8.3 GB on disk, ~2.9 /
  ~3.2 GB compressed pull — the old docs mixed compressed and on-disk metrics) across README /
  ARCHITECTURE / CONTAINER-GUIDE and documented the lean image in the Container Guide; refreshed the
  README status line and switched its usage examples from `@main` to `@v0`; documented
  `failure-artifact-name` in QUICK-REFERENCE; clarified in MIGRATION-GUIDE that the container
  workflow is the recommended path; replaced the README "Usage by Repository" list with a pointer to
  [QuantEcon/meta#321](https://github.com/QuantEcon/meta/issues/321); and fixed a mangled code fence
  in TESTING.md.

## [0.7.0] - 2026-06-16

### Added
- **Templates**: Comprehensive workflow templates (`ci.yml`, `cache.yml`, `publish.yml`) for
  lecture repositories, with inline setup guidance.
- **build-lectures**: `failure-artifact-name` input to give failure-report artifacts a custom
  name, avoiding name collisions when several builders run in one job.

### Changed
- **Containers**: Upgraded `quantecon-book-theme` from 0.10.1 to 0.18.0.
- **Containers**: Updated Sphinx extensions to match the lecture-python-intro versions.
- **Docs**: Standardised all template and documentation action references on the floating `@v0`
  tag (was `@v1`, which never existed and broke any copied template). Documented the `@v0`
  convention in `README.md` and added a step to move the floating `v0` tag on each release in
  `CONTRIBUTING.md`.
- **CI**: Reworked the container test workflows into a unified, sequential per-repo pipeline with
  concurrency control; temporarily disabled lecture-jax until JAX install commands are added
  ([lecture-jax#284](https://github.com/QuantEcon/lecture-jax/issues/284)).

## [0.6.0] - 2026-02-09

### Changed
- **Architecture**: Simplified notebook deployment - notebooks now served from gh-pages
  instead of separate `.notebooks` repos
  - Eliminates 4 separate `.notebooks` repositories (one per lecture series)
  - Removes sync workflows from publish pipelines
  - Google Colab integration via direct gh-pages URLs
  - Requires `quantecon-book-theme` update (tracked in quantecon-book-theme#359)
  - Single source of truth for notebooks alongside HTML content

### Removed
- **`setup-environment`**: Remove `install-ml-libs` and `ml-libs-version` inputs ⚠️ **BREAKING**
  - ML/GPU libraries (JAX, PyTorch, numpyro) should be specified in each repo's
    `environment.yml` or `environment-update.yml` instead of being hardcoded in the action
  - JAX now bundles its own CUDA toolkit via pip (`jax[cuda13]`), so system-level
    CUDA installation is unnecessary — GPU drivers on the AMI are sufficient
  - Removes pip cache step and hardcoded install step for ML libraries
  - **Migration:** Repos using `install-ml-libs: 'true'` should move ML packages to
    their `environment-update.yml` and remove the `install-ml-libs` input

### Added
- **Documentation**: New GPU-AMI-SETUP.md guide for building RunsOn GPU AMI
  - Driver requirements (NVIDIA >= 580 for CUDA 13)
  - Packer template for automated AMI builds
  - Marker file setup for container detection
  - Architecture notes on JAX bundled CUDA

## [0.5.2] - 2026-02-06

### Added
- **`restore-jupyter-cache`**: New `save-cache` input for PR-scoped build caching (#24)
  - When `true`, saves build cache at job end using `actions/cache`
  - Subsequent pushes to the same PR restore the prior build, only re-executing changed notebooks
  - Cache is scoped to the PR branch (cannot affect other PRs or main)
  - Default `false` preserves existing read-only behavior

## [0.5.1] - 2026-02-06

### Fixed
- **`build-lectures`**: Stage PDF and notebooks *before* HTML build so Jupyter Book
  theme can detect them and activate download features (#23)
- **`preview-netlify`**: Replace `jq` with `python3` for JSON parsing (lean container
  does not include `jq`)
- **`quantecon-build` container**: Add `texlive-fonts-extra` (provides `bbm.sty`) and
  `xindy` for PDF builds

### Changed
- **`test-containers-lectures`**: Add `builder` dimension to test matrix
  (container × repo × builder) for parallel validation of all build types
- **`test-containers-lectures`**: Add `builder` input to `workflow_dispatch` for
  targeted manual testing

## [0.5.0] - 2026-02-06

### Changed
- Renamed `environment-file` input to `environment` across all actions
  - `setup-environment`: `environment-file` → `environment`
  - `build-jupyter-cache`: `environment-file` → `environment`
  - `restore-jupyter-cache`: `environment-file` → `environment`

### Added
- **`environment-update`** input for container-optimized builds
  - `setup-environment`: New `environment-update` input for delta package installs
  - `build-jupyter-cache`: New `environment-update` input (passed through to setup-environment)
  - `restore-jupyter-cache`: New `environment-update` input (for cache key computation)
  - Default `''` skips conda update entirely in container mode (fastest path)
  - When specified, installs only delta packages from a minimal environment file
- Cache key computation now includes both `environment` and `environment-update` file hashes
- Documentation for RunsOn + custom AMI setup for GPU builds
  - AMI requirements for container mode detection (marker file)
  - Workflow examples and comparison tables

## [0.4.0] - 2026-02-05

### Added
- **`build-jupyter-cache`** - Dedicated action for building and caching notebook execution
  - Runs on `main` branch (scheduled weekly or on push)
  - Full notebook execution with Jupyter Book
  - Saves execution cache with unique key (`build-{env-hash}-{run-id}`)
  - Verification step ensures cache validity before saving
  - Creates GitHub issue on build failure with duplicate prevention
  - Uploads execution reports as artifacts on failure

- **`restore-jupyter-cache`** - Dedicated action for restoring notebook execution cache
  - Runs on PR branches (read-only restore, never saves)
  - Prefix-based matching finds most recent cache
  - Detailed cache status output (hit/miss, matched key)
  - ~80% build time reduction when cache available (tested: 16m53s → 3m28s)

- **Workflow Templates** (`templates/`)
  - `cache.yml` - Container-based cache workflow for lecture repos
  - `cache-standard.yml` - Standard runner workflow (with LaTeX install)
  - `README.md` - Template documentation and usage instructions

### Changed
- **BREAKING**: Removed caching inputs from `build-lectures`
  - Removed `cache-notebook-execution` input
  - Removed `use-build-cache` input
  - Removed `build-cache-hit` output
  - **Migration**: Use dedicated `build-jupyter-cache` and `restore-jupyter-cache` actions

### Documentation
- Updated ARCHITECTURE.md with Layer 2 caching strategy
- Updated MIGRATION-GUIDE.md with cache workflow examples
- Updated QUICK-REFERENCE.md with cache action reference
- Added comprehensive README for both cache actions

## [0.3.0] - 2026-02-05

### Added
- **Lean Container** (`ghcr.io/quantecon/quantecon-build:latest`)
  - Optimized for CI builds (~3GB vs ~8GB full container)
  - Miniconda + Python 3.13 + Jupyter Book tooling
  - XeLaTeX with essential packages (no full TexLive)
  - Weekly automated builds alongside full container

- **Container Test Workflow** (`.github/workflows/test-container.yml`)
  - Automated validation of both containers after builds
  - XeLaTeX compilation tests
  - Jupyter Book HTML/PDF build tests

- **Lecture Validation Tests** (`.github/workflows/test-containers-lectures.yml`)
  - Full lecture builds against all 4 QuantEcon lecture repositories
  - Tests container's built-in environment (ignores lecture repo's environment.yml)
  - Matrix-based parallel testing across all containers × all repos (2×4 = 8 jobs)
  - Triggered automatically after container builds, or manually via workflow_dispatch
  - 120-minute timeout per build, artifacts retained for debugging
  - Validated: All 4 lecture repos build successfully on both containers

### Changed
- **`setup-environment`** - Now container-aware
  - Auto-detects QuantEcon containers via `/etc/quantecon-container` marker
  - Skips redundant LaTeX installation when running in container
  - Activates pre-installed `quantecon` conda environment in containers
  - Falls back to full setup on `ubuntu-latest` or other runners
  - Added `skip-latex` input for manual control

- **Container Infrastructure**
  - Added Chrome + kaleido for Plotly static image export (`fig.to_image()`)
  - Added Intel MKL for optimized linear algebra (2-3x faster for numerical computations)
  - Added scikit-learn for ML lectures
  - Added DejaVu fonts to both containers for XeLaTeX compatibility
  - Updated lean container to Miniconda py313_25.11.1-1
  - Uses `defaults` channel only (matches Anaconda metapackage behavior)

### Documentation
- Added container marker documentation
- Updated setup-environment README with container detection details

## [0.2.0] - 2026-02-03

### Added
- `preview-cloudflare` - Cloudflare Pages deployment for PR previews
  - Works with public and private repositories (free tier supports both)
  - Predictable preview URLs (`pr-{number}.{project}.pages.dev`)
  - Changed lecture detection with direct links in PR comments
  - Smart PR comments (updates existing instead of duplicates)
  - Security-aware (skips forks and dependabot)

### Changed
- **BREAKING**: Renamed `deploy-netlify` → `preview-netlify` to better reflect its purpose as a PR preview action (not production deployment)

## [0.1.1] - 2026-01-16

### Changed
- Improved failure logging with clear summary
  - Add prominent error message on build failure
  - Display build configuration summary
  - Provide instructions for downloading execution reports

### Documentation
- Add comprehensive Netlify setup guide
  - CLI-only site creation instructions
  - How to disable duplicate PR comments
  - Decision table for different scenarios

## [0.1.0] - 2026-01-16

### Added
- **Core Actions:**
  - `setup-environment` - Conda/LaTeX/ML environment setup with caching
  - `build-lectures` - Jupyter Book builds with execution caching
  - `deploy-netlify` - PR preview deployment with smart comments
  - `publish-gh-pages` - Native GitHub Pages deployment (OIDC-based)

- **Container Infrastructure** (`ghcr.io/quantecon/quantecon:latest`)
  - Ubuntu 24.04 LTS + TexLive (latest) + Miniconda + Python 3.13
  - Anaconda 2025.12 metapackage (numpy, scipy, pandas, matplotlib, jupyter)
  - Jupyter Book 1.0.4post1 + sphinx extensions
  - Weekly automated builds (Monday 2am UTC)

- **Build Features:**
  - Asset assembly (`html-copy-pdf`, `html-copy-notebooks`)
  - Execution reports on failure
  - GitHub native build cache for fast PR builds
  - Multi-format support (HTML, PDF, Jupyter notebooks)

### Performance
- Container setup: ~2-3 min (vs ~7-8 min ubuntu-latest)
- Conda environment caching (~5-6 min savings)
- Overall: 60-70% faster environment setup

---

## Version History

- **v0**: Tracks the latest release — the topmost dated section above. [docs/user/versioning.md](docs/user/versioning.md) says which reference to pin and how a release reaches a repository.

## Migrating an existing repository

See [docs/user/getting-started.md](docs/user/getting-started.md#migrating-an-existing-repository).

## Testing

See [docs/dev/TESTING.md](docs/dev/TESTING.md) for how a change to the actions is tested.
