# Architecture

How QuantEcon Actions is built, and why. Using the actions is the [user manual](../user/README.md); how they are tested is [TESTING.md](TESTING.md); priorities and rollout are [PLAN.md](PLAN.md).

## The parts

| Part | Where | What it is |
|---|---|---|
| Eight composite actions | `<action>/action.yml` | The steps a lecture repository runs: `setup-environment`, `build-lectures`, `build-jupyter-cache`, `restore-jupyter-cache`, `preview-netlify`, `preview-cloudflare`, `publish-gh-pages` and `deploy-cloudflare`. A workflow calls one as `quantecon/actions/<action>@v0`. An action that installs a CLI keeps its `package.json` and `package-lock.json` beside its `action.yml` |
| Shared scripts | `scripts/` | What more than one action, or an action and its tests, run: change detection, the preview deploy decision and comment, the Access gate probe, release-asset packaging. Also the repository's own tooling: the manual's generator, and the container checks |
| Two container images | `containers/` | `quantecon` (full) and `quantecon-build` (lean), the environment most lecture builds run in. See [CONTAINERS.md](CONTAINERS.md) |
| Workflow templates | `templates/` | `cache.yml`, `ci.yml` and `publish.yml`, which each lecture repository copies |
| The user manual | `docs/user/` | A chapter per action, with input and output tables generated from each `action.yml`, and the guides |
| This repository's workflows | `.github/workflows/` | The action harness, and the container builds and tests. See [TESTING.md](TESTING.md) |

## How a lecture build fits together

A weekly cache build on the default branch executes every lecture from scratch and saves the result. Every pull-request and publish build restores it, so Jupyter Book re-executes only the notebooks whose code changed, and then a separate job deploys the site. The user manual's [How the actions compose](../user/composition.md) follows that chain action by action, and [Getting started](../user/getting-started.md) shows the templates' jobs.

## Design decisions

### Composite actions, one job each

Each action is a composite action that does one thing: set up the environment, build, cache, restore, or deliver. Composite steps run inside the caller's job, so a lecture repository keeps its own runner (a container, a GPU machine), its permissions and its job layout, and the templates hold the layout the lecture repositories share. Separate actions keep each one testable on its own, and a failed step names the action that failed. They compose through files and outputs: the `_build` directory, a cache key, `build-path`.

One consequence: `build-jupyter-cache` runs `setup-environment` and `build-lectures` as steps of its own, at `@v0`, because GitHub does not allow an expression in `uses:`. Those two therefore run as the latest release inside it, whatever version a workflow names for `build-jupyter-cache` and however the harness calls it.

### The environment is an image

LaTeX and the scientific stack take minutes to install, and installing them on every run is also where a build meets a package that moved. So most builds run in a container image that already holds Python, the Anaconda baseline, Jupyter Book with its extensions, TeX Live and Node, and `setup-environment` adds only each repository's extra packages, from its `environment-update` file.

- **One shared image, in two variants,** not one per lecture series. The lectures share their stack, and their LaTeX needs are the same. The full image carries the `anaconda` metapackage; the lean one an explicit list pinned to the same baseline.
- **Container mode is detected, not configured.** `setup-environment` looks for the marker file `/etc/quantecon-container`, so a self-hosted machine image that carries it, such as the RunsOn GPU image ([GPU-AMI-SETUP.md](GPU-AMI-SETUP.md)), works the same way.
- **Standard mode remains** for a repository that builds on a plain runner: `setup-environment` builds and caches a Conda environment, and installs LaTeX.
- **The images change only through reviewed pull requests**, which build and smoke-test them before `:latest` moves. The base is pinned by digest, and there is no scheduled rebuild: see the Dependency policy in [PLAN.md](PLAN.md#dependency-policy).

### Two caches: the image and the build

The image caches the environment; GitHub Actions' cache holds the build. `build-jupyter-cache` saves two caches, from scratch and only when every format built:

- **The build cache**, the whole `_build` directory, keyed on the environment files' hashes and the run id. It is keyed on the environment, not the lectures: every pull request edits some lecture, so a key that hashed them would miss on nearly every one. Jupyter Book's own execution cache decides per notebook what to re-execute, and Sphinx rebuilds incrementally. The cost is that a removed lecture keeps its old pages, unreachable from the table of contents, until the next cache build, whose fresh build clears them.
- **The execution cache**, `_build/.jupyter_cache` alone, keyed on a hash of the lectures, with a fallback to any execution cache, since Jupyter Book checks each cached notebook against its code anyway.

`restore-jupyter-cache` restores the newest by prefix, and is read-only by default, so a pull request cannot overwrite what `main` saved. The keys and their reasoning are in the [`restore-jupyter-cache` chapter](../user/actions/restore-jupyter-cache.md#why-the-keys-are-what-they-are).

### Credentials stay out of the jobs that run notebooks

Building the lectures runs code the repository does not fully control, and code that runs earlier in a job can reach what the job's later steps hold. So the templates build in one job and deploy from another: the build job has read access and no secrets, and only the deploy job holds the provider's token, or the Pages permissions. Every checkout sets `persist-credentials: false`. The preview actions deploy only on the events they allow, never on `pull_request_target`, and skip forks and Dependabot, whose runs get no secrets. The manual's [Security](../user/security.md) chapter has the details.

### What a run installs is pinned

- Third-party actions are pinned by commit SHA; GitHub's own `actions/*` by major version.
- The deploy CLIs, `netlify-cli` and `wrangler`, are installed with `npm ci` from each action's lockfile, so a Dependabot bump of a lockfile is the only way a new version arrives, and the harness runs it first.
- In the images, Miniconda and Node are checked against a SHA-256, the Ubuntu base is pinned by digest, and the science stack is pinned to the Anaconda baseline.

### Inputs reach scripts through the environment

A step passes its inputs and outputs to a script through `env:`, not by expanding `${{ }}` into the `run:` text, where a value would be read as shell. An input that is one value is refused in the action's first step if it holds a line break, since the runner reads a printed line that starts with `::` as a workflow command, and a value printed in an annotation is escaped. Both are done by `scripts/workflow-command.sh`, which each step sources. A step finds a script relative to `$GITHUB_ACTION_PATH`, never `${{ github.action_path }}`: in a container job the latter is the runner's path, which does not exist inside the container.

### Failures reach a person

An unattended cache build that fails files an issue, or comments on the open one, with `actions/github-script`, and then checks that it did. Every guard on that path tests a status for `!= 'true'`, never `== 'false'`: a run that stops before the builds leaves the status empty, and a guard written for the failure someone had in mind fails open on the one they did not. `build-lectures` prints failed notebooks' tracebacks, and fails a build whose executed notebooks hold an error output, which `-W` misses when the error is raised while a result is displayed.

### The manual is generated where it can drift

Each input's and output's description lives in its `action.yml`, which is what the action itself reports. `scripts/generate-docs.py` copies them into the manual's tables, the manual's action index and each action's README, and the harness gate fails a pull request whose committed copies differ, whose examples pass an input an action does not declare, or whose action has no chapter. See [CHAPTER-TEMPLATE.md](CHAPTER-TEMPLATE.md).

### Releases

A release is a `vX.Y.Z` tag with a CHANGELOG section; `v0` is moved to each release, and lecture repositories that name `@v0` get it on their next run. A release that changes what an action does is staged first, on the canary repository, before `v0` moves: see [CONTRIBUTING.md](../../CONTRIBUTING.md#staged-releases).

## Repository layout

```text
quantecon/actions/
├── <action>/                  # One per action: action.yml, its README signpost, and any lockfile or helper
├── scripts/                   # Shared scripts, and the repository's tooling
├── templates/                 # cache.yml, ci.yml, publish.yml, latex-requirements.txt
├── containers/
│   ├── quantecon/             # Full image: Dockerfile, environment.yml, tests/ (the smoke test)
│   └── quantecon-build/       # Lean image: Dockerfile, environment.yml
├── docs/
│   ├── user/                  # The user manual: the guides, and actions/<action>.md
│   └── dev/                   # This file, testing, containers, the plan, the GPU image
├── tests/                     # Local scratch space; see tests/README.md
└── .github/
    ├── workflows/             # The action harness and the container workflows
    └── fixtures/              # The harness's fixtures
```
