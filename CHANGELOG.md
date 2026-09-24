# Changelog

All notable changes to the QuantEcon Actions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **`build-containers.yml`**: an edit to a README under `containers/` no longer rebuilds and
  pushes both `:latest` images, or re-runs the container test workflows that follow the build.
  The Dockerfiles copy only `environment.yml`, so a README cannot change an image. Other Markdown
  under `containers/` still triggers a build: the smoke-test fixture's pages are Markdown. (#178)

### Documentation
- Developer docs move to `docs/dev/`, the first step of the user manual (#178): `ARCHITECTURE.md`,
  `GPU-AMI-SETUP.md`, `PLAN.md`, `TESTING.md`, and `containers/VALIDATION.md` as
  `CONTAINER-VALIDATION.md`, with a `docs/dev/README.md` index. `docs/README.md`,
  `docs/FUTURE-DEVELOPMENT.md` and `PROJECT-OPTIMIZE-PREVIEWS.md` are removed; the preview plan
  is tracked in #92 and its sub-issues. The harness gate's ignore list follows the moves.
- **`restore-jupyter-cache` README**: the cache status sample now matches what the action prints.
  It showed an "Age Information" block the action has never produced, left out the "Directory
  Sizes" block it does produce, and showed an exact `Cache Hit` that a read-only restore cannot
  get, since saved keys end in the saving run's id.
- **`docs/dev/PLAN.md`** refreshed after v0.12.0 closed the July 2026 audit (#110): items 7 and 8
  are done, item 10 is absorbed by the user manual (#178), item 15 is down to one cosmetic fix, a
  new item 18 records the `${{ }}` expressions still expanded inside `run:` scripts, and the
  consumers section lists the two follow-ups outside this repo (dropping `cname:` in six
  consumers, a permanent `preview-cloudflare` step in the canary).

### Fixed
- **`scripts/check-latex-versions.sh`** runs under `set -euo pipefail` (PLAN item 15). A failed
  `apt-get update` used to be ignored, so the script went on to report versions from a stale
  package index. It now fails the run. The per-package lookup keeps an explicit `|| true`: `grep`
  exits 1 for a package apt does not know, which under `pipefail` would abort the script before it
  could print `NOT FOUND`.

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

- **v0**: Tracks the latest stable release — the topmost dated section above
- **v0.x.x**: Development/testing releases

## Migration from Legacy Workflows

See [docs/MIGRATION-GUIDE.md](docs/MIGRATION-GUIDE.md) for step-by-step instructions on migrating from repository-specific workflows to these centralized actions.

## Testing

See [TESTING.md](docs/dev/TESTING.md) for comprehensive testing strategy and validation procedures.
