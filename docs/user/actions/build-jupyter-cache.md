# build-jupyter-cache

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Builds the lectures from scratch, in each format listed in `builders`, and saves the result as the cache that pull-request and publish builds restore with [`restore-jupyter-cache`](restore-jupyter-cache.md). It saves two caches:

- **The build cache**: the whole `_build` directory, with the HTML, the PDF, the notebooks and the execution cache.
- **The execution cache**: `_build/.jupyter_cache` alone, which holds each notebook's executed outputs.

Both are saved only when every build passes. A failed run saves nothing, so the builds that restore keep the last good cache, and it files an issue, so that the failure is seen.

## When to use it

Use it in a workflow of its own, on the default branch: weekly, on demand, and when the environment file changes, as [`cache.yml`](https://github.com/QuantEcon/actions/blob/main/templates/cache.yml) does.

- **On the default branch.** A cache saved there can be restored by every branch and pull request. One saved on another branch serves only that branch, and the pull requests that target it.
- **On its own.** The action runs [`setup-environment`](setup-environment.md) and [`build-lectures`](build-lectures.md) itself, so the job needs neither.
- **From scratch.** Do not restore a cache before it. Its fresh build is what clears out what incremental builds leave behind, such as the pages of a lecture that has been removed.

## Requirements

- **Runner.** A QuantEcon container, or a GitHub-hosted Ubuntu runner, where `setup-environment` builds the Conda environment and, with `pdflatex` among the builders, installs LaTeX.
- **Node.** None.
- **Permissions.** `issues: write`, to file the failure issue, unless `create-issue-on-failure` is `'false'`. The job also needs `contents: read` for `actions/checkout`, and the templates grant `packages: read` in a `container:` job, for the image pull. Saving caches and uploading artifacts need no permission.
- **Secrets.** None: the failure issue is filed with the job's own token.
- **Files in your repository.** The book in `source-dir`. In standard mode, the environment file, and with `pdflatex` the LaTeX package list; see [`setup-environment`](setup-environment.md#requirements). In container mode, the `environment-update` file if you set one. Check out with `fetch-depth: 0`, so that the cached HTML dates each page from its own history.
- **Setup outside GitHub.** None.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from build-jupyter-cache/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `builders` | no | `html` | The formats to build and cache: any of `jupyter`, `pdflatex` and `html`, separated by commas or whitespace, as in `jupyter,pdflatex,html`. They run in that order whatever order they are listed in, and the `html` build copies in the PDF and the notebooks when those are listed too. An unknown name, or none at all, fails the run before anything is built. |
| `environment` | no | `environment.yml` | Path to the Conda environment file. In standard mode `setup-environment` builds the environment from it, and fails if it does not exist. In either mode its hash is part of the build cache's key, so give `restore-jupyter-cache` the same file. |
| `environment-update` | no | `''` | Container mode: path to a Conda environment file of packages to add to the image's environment, which `setup-environment` installs. Empty, the default, adds none. In either mode its hash is part of the build cache's key, so give `restore-jupyter-cache` the same file. |
| `source-dir` | no | `lectures` | The book to build, as `build-lectures` takes it: the directory that holds its `_config.yml` and `_toc.yml`. The execution cache's key hashes every `.md` file under it. |
| `latex-requirements-file` | no | `latex-requirements.txt` | Standard mode, with `pdflatex` among the builders: path to the list of apt packages that `setup-environment` installs for LaTeX. The job fails if the file is missing or names no package. Ignored in container mode, whose images carry LaTeX. |
| `upload-artifact` | no | `true` | `'true'`, the default, uploads the whole `_build` directory as the artifact `build-cache-<run id>` when a build fails, since no cache is saved then. `'false'` uploads nothing. A run whose builds all pass uploads no artifact either way: the cache holds `_build`. |
| `artifact-retention-days` | no | `30` | How many days to keep the artifact that `upload-artifact` uploads, up to the repository's retention limit. |
| `create-issue-on-failure` | no | `true` | `'true'`, the default, files an issue when the run fails, or comments on the open one that carries the first of `issue-labels`, and fails the job if neither worked. It needs `issues: write`. `'false'` files nothing. |
| `issue-assignees` | no | `''` | Comma-separated GitHub usernames to assign a new failure issue to. Empty, the default, assigns nobody. |
| `issue-labels` | no | `build-failure,automated` | Comma-separated labels for a new failure issue, created in the repository if they do not exist. The first also finds an open failure issue: a later failure comments on it instead of filing another. Empty files a new issue for every failure. |
| `upload-failure-reports` | no | `true` | `'true'`, the default, makes each failed build upload its execution reports as `execution-reports-<builder>`, as the `build-lectures` input of the same name does, and the failure issue names them. `'false'` uploads none. The default differs from `build-lectures`' because this action runs unattended. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from build-jupyter-cache/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `cache-saved` | `'true'` when every requested build passed, which is when the build and execution caches are saved; `'false'` otherwise, including a run that stopped before any build. Always set. |
| `build-success` | The same value as `cache-saved`: `'true'` only when every requested build passed; `'false'` for anything else, including a run that stopped during setup, before any build. Always set. |
| `cache-key` | The key the build cache is saved under, `build-<hash of environment>-<hash of environment-update>-<run id>`. Set even when a build fails and nothing is saved. |
| `jupyter-status` | `success` or `failure` for a `jupyter` build that ran, `skipped` when `builders` does not list it. Empty when the run stopped before the builds. |
| `pdflatex-status` | `success` or `failure` for a `pdflatex` build that ran, `skipped` when `builders` does not list it. Empty when the run stopped before the builds. |
| `html-status` | `success` or `failure` for an `html` build that ran, `skipped` when `builders` does not list it. Empty when the run stopped before the builds. |
| `failure-issue-url` | The URL of the failure issue filed or commented on. Empty when every build passed, or with `create-issue-on-failure: 'false'`. |

<!-- END GENERATED -->

## Examples

### Minimal

A weekly cache build in a container, which can also be started by hand:

```yaml
name: Build cache
on:
  schedule:
    - cron: '0 0 * * 0'   # Sundays at 00:00 UTC
  workflow_dispatch:

jobs:
  build-cache:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    permissions:
      contents: read
      issues: write    # the failure issue
      packages: read   # the image pull, as the templates grant it
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0   # each page's "Last changed" date comes from git log
      - uses: quantecon/actions/build-jupyter-cache@v0
```

### Every format

For a site that offers the PDF and the notebooks as downloads:

```yaml
- uses: quantecon/actions/build-jupyter-cache@v0
  with:
    builders: jupyter,pdflatex,html
```

The cached `_build/html` then holds the PDF and the notebooks too, so a build that restores it can offer them without building them again: see [`build-lectures`](build-lectures.md#downloads-on-the-site).

### On a standard runner

Leave out the `container:` block. `setup-environment` then builds the Conda environment from `environment.yml`, and with `pdflatex` among the builders installs the LaTeX packages listed in `latex-requirements.txt`. Both files must be at the repository root, or named with `environment` and `latex-requirements-file`.

### In the templates

[`cache.yml`](https://github.com/QuantEcon/actions/blob/main/templates/cache.yml) runs this action weekly, on manual dispatch, and on pushes to `main` that change `environment.yml`, one run at a time. It builds `html`, lists the other formats as comments, files an issue on failure, and keeps the failed `_build` for 30 days.

## Behaviour

1. **Builders.** `builders` is split on commas and whitespace, and every name must be `jupyter`, `pdflatex` or `html`.
2. **Environment.** `setup-environment` runs with `environment`, `environment-update` and `latex-requirements-file`, and installs LaTeX only when `pdflatex` is among the builders. Its other inputs keep their defaults, so in standard mode the environment is named `quantecon`, uses Python 3.13, and is cached under `cache-version` `v1`.
3. **Builds.** `build-lectures` runs once for each requested builder, always in the order `jupyter`, `pdflatex`, `html`, with its default `extra-args`, `-W --keep-going`, and `output-dir`, `.`. The `html` build copies in the PDF when `pdflatex` ran, and the notebooks when `jupyter` ran. A failed build does not stop the later ones, so each run reports on every builder.
4. **Caches.** If every build passed, both caches are saved:

   | Cache | Path | Key |
   |---|---|---|
   | Build | `_build` | `build-<hash of environment>-<hash of environment-update>-<run id>` |
   | Execution | `_build/.jupyter_cache` | `jupyter-cache-<hash of the .md files under source-dir>-<run id>` |

   A file that does not exist hashes to an empty string, so with no `environment-update` the build cache's key is `build-<hash>--<run id>`. Every successful run saves new entries, and `restore-jupyter-cache` restores the newest through a prefix match. GitHub removes a cache that has not been restored for 7 days, and the oldest caches first when the repository's cache storage is full.
5. **Job summary.** "Jupyter Cache Build Summary" gives the outcome, the cache key, the trigger, the commit, the mode `setup-environment` ran in, each builder's result and the size of each directory in `_build`.

The action runs `setup-environment` and `build-lectures` at `@v0`, whichever version of `build-jupyter-cache` the workflow pins.

### When a build fails

1. **Nothing is saved.** The last good caches stay, and the builds that restore them carry on as before.
2. **Artifacts.** With `upload-artifact`, the whole `_build` directory as `build-cache-<run id>`. With `upload-failure-reports`, each failed build's reports as `execution-reports-<builder>`.
3. **The failure issue.** With `create-issue-on-failure`, the action files an issue titled `🔴 Cache Build Failed - <date>`, with the labels in `issue-labels` and the assignees in `issue-assignees`. If an open issue already carries the first of those labels, it adds a comment there instead. Either way the text links to the run, gives each builder's result, names the artifacts the run actually uploaded, and gives a command to reproduce each failed build locally. The action then checks that the issue was filed, and fails if it was not.
4. **The job fails**, with `One or more builds failed - see summary above`.

A run can also stop before any lecture is built: on an invalid `builders`, or when `setup-environment` fails. It then fails with `The cache build aborted during …, before any lecture was built`, and the issue says that no lecture was built, so that the failure is not mistaken for a broken lecture. Every builder then reads `not run`.

## Troubleshooting

**`Unknown builder '…' in the builders input. Valid builders: jupyter, pdflatex, html`.** Fix the name: the PDF builder is `pdflatex`, not `pdf`.

**`Could not file the failure issue: the token lacks issue permissions`.** Add `issues: write` to the job's `permissions:`, or set `create-issue-on-failure: 'false'`.

**`create-issue-on-failure is enabled but no failure issue was filed (…)`.** The step that files the issue failed, and the reason is in its log, just above. The run's own failure is in the job summary.

**`The cache build aborted during setup, before any lecture was built`.** `setup-environment` failed: its log, and the [`setup-environment` troubleshooting](setup-environment.md#troubleshooting), give the cause.

**New failures comment on an old issue.** The action comments on the open issue that carries the first label. Close the issue once the build is fixed; the next failure files a new one.

**Pull requests do not restore the new cache.** A cache saved on another branch does not reach them: run the workflow on the default branch. Check also that the runs that restore pass the same `environment` and `environment-update`, since both files' hashes are in the key.
