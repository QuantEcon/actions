# build-lectures

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Runs `jb build`, Jupyter Book 1, on the book in `source-dir`, with one builder per step:

- **`html`**, the default: the website, in `_build/html`.
- **`pdflatex`**: the PDF, in `_build/latex`.
- **`jupyter`**: the lectures as notebooks, in `_build/jupyter`.

An `html` build can also copy in the PDF and the notebooks from earlier builds, so the site offers them for download. When a build fails, the action prints the traceback of each notebook that failed to execute, and can upload the execution reports as an artifact.

## When to use it

Use it in any job that builds lectures, after [`setup-environment`](setup-environment.md), and after [`restore-jupyter-cache`](restore-jupyter-cache.md) in a job that starts from the build cache. A preview or publish step then deploys the directory in its `build-path` output.

- **One step per format.** For a site that offers the PDF and the notebooks, build `jupyter` and `pdflatex` first, then `html` with `html-copy-pdf` and `html-copy-notebooks`, all in one job. See [Downloads on the site](#downloads-on-the-site).
- **Not in the weekly cache build.** [`build-jupyter-cache`](build-jupyter-cache.md) runs this action itself, once for each of its builders.

## Requirements

- **Runner.** Any job where a login shell finds `jb`: a QuantEcon container, whose images carry Jupyter Book 1 and LaTeX, or a GitHub-hosted runner after `setup-environment`, whose environment file must then install `jupyter-book` 1.x and every extension the book's `_config.yml` loads. The `pdflatex` builder needs LaTeX: on a standard runner, pass `install-latex: 'true'` to `setup-environment`.
- **Node.** None.
- **Permissions.** None of its own: the action calls no GitHub API. The job needs `contents: read` for `actions/checkout`.
- **Secrets.** None.
- **Files in your repository.** A Jupyter Book 1 project in `source-dir`: its `_config.yml`, its `_toc.yml` and the pages they name. The `html` builder dates each page from the repository's git history, so check out with `fetch-depth: 0`.
- **Setup outside GitHub.** None.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from build-lectures/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `builder` | no | `html` | What to build: `html`, the default, builds the website into `<output-dir>/_build/html`; `pdflatex` builds the PDF into `<output-dir>/_build/latex`, and needs LaTeX; `jupyter` builds notebooks into `<output-dir>/_build/jupyter`. Any other value is passed to `jb build` as `--builder <value>`, which writes into a directory under `<output-dir>/_build`. |
| `source-dir` | no | `lectures` | The book to build: the directory that holds its `_config.yml` and `_toc.yml`, relative to the workspace. |
| `output-dir` | no | `.` | The directory the build is written under, passed to `jb build` as `--path-output`, so the output lands in `<output-dir>/_build`. The cache actions read and write `_build` at the workspace root, so keep the default, `.`, in a job that uses them. |
| `extra-args` | no | `-W --keep-going` | Further arguments for `jb build`. They are split on whitespace, so a quoted value that contains a space cannot be passed. Setting this replaces the default, so keep `-W` in it: without `-W`, a notebook that raises an exception is only a warning, and the build succeeds. |
| `html-copy-pdf` | no | `false` | With `builder: html`: `'true'` copies each PDF under `<output-dir>/_build/latex` into `<output-dir>/_build/html/_pdf/` before the build, so the site offers it for download. The PDF comes from a `pdflatex` build earlier in the job, or from a restored build cache; if that directory does not exist, a warning says so and the site is built without it. Ignored by the other builders. |
| `html-copy-notebooks` | no | `false` | With `builder: html`: `'true'` copies each notebook under `<output-dir>/_build/jupyter` into `<output-dir>/_build/html/_notebooks/` before the build, so the site offers them for download. The notebooks come from a `jupyter` build earlier in the job, or from a restored build cache; if that directory does not exist, a warning says so and the site is built without them. Ignored by the other builders. |
| `upload-failure-reports` | no | `false` | `'true'` uploads an artifact when the build fails, holding the `reports` directories in `_build/html`, `_build/latex` and `_build/jupyter`, and `_build/.jupyter_cache`, all under `output-dir`, kept for 7 days. `'false'`, the default, uploads nothing. For the `html`, `pdflatex` and `jupyter` builders the log shows each failing notebook's traceback either way. |
| `failure-artifact-name` | no | `''` | The name of the artifact that `upload-failure-reports` uploads. Empty, the default, names it `execution-reports-<builder>`. A name can be used only once in a workflow run, so set this when more than one job in a run builds with the same builder. |

<!-- END GENERATED -->

Paths are relative to the workspace, which is the repository root after `actions/checkout`.

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from build-lectures/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `build-path` | The directory the builder wrote to: `<output-dir>/_build/html`, `_build/latex` or `_build/jupyter` for those three builders. For any other it is `<output-dir>/_build`, the directory above the one that builder wrote to. With the default `output-dir` it starts with `./`, as in `./_build/html`. Set whether or not the build succeeds. |

<!-- END GENERATED -->

## Examples

### Minimal

Builds the website in a container, and keeps it as an artifact of the run:

```yaml
name: Build lectures
on:
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon-build:latest
    permissions:
      contents: read
      packages: read   # the image pull, as the templates grant it
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0   # each page's "Last changed" date comes from git log
      - uses: quantecon/actions/setup-environment@v0
      - uses: quantecon/actions/build-lectures@v0
        id: build
        with:
          upload-failure-reports: 'true'
      - uses: actions/upload-artifact@v7
        with:
          name: site
          path: ${{ steps.build.outputs.build-path }}
```

### Downloads on the site

Build the notebooks and the PDF first, in the same job, then the website with both copied in:

```yaml
- uses: quantecon/actions/build-lectures@v0
  with:
    builder: jupyter
- uses: quantecon/actions/build-lectures@v0
  with:
    builder: pdflatex
- uses: quantecon/actions/build-lectures@v0
  id: build
  with:
    builder: html
    html-copy-pdf: 'true'
    html-copy-notebooks: 'true'
```

The website then holds both, and quantecon-book-theme links every page to them:

```text
_build/html/
├── index.html
├── _pdf/
│   └── <the book's PDF>
└── _notebooks/
    ├── <lecture>.ipynb
    └── …
```

Two limits apply to the links:

- **Lectures in subdirectories.** The theme links a page to `/_notebooks/<page>.ipynb`, with the page's directory in `<page>`, but the notebooks are copied into `_notebooks/` side by side. So the notebook link of a page in a subdirectory leads nowhere, and two notebooks with the same name overwrite each other ([#217](https://github.com/QuantEcon/actions/issues/217)). A book whose lectures all sit at the top of `source-dir` is not affected.
- **Sites served under a path.** Both links start at the site's root, `/_pdf/…` and `/_notebooks/…`, so they lead nowhere on a site that is not at the root of its domain, such as a GitHub Pages project site with no custom domain. The theme's `download_nb_path` option puts a prefix in front of the notebook links; the PDF link has no such option.

After `restore-jupyter-cache`, the copies can also come from the build cache, if its cache build ran those builders: `_build/latex` and `_build/jupyter` are then already in place, as the last cache build left them.

### Other arguments for `jb build`

Keep `-W --keep-going` in any value you set, because it replaces the default:

```yaml
- uses: quantecon/actions/build-lectures@v0
  with:
    extra-args: '-W --keep-going --all'   # rebuild every page, not only the changed ones
```

`-v` makes the log more verbose, `-q` quieter, and `-n` turns on Sphinx's nitpicky mode, which warns about every reference it cannot resolve. The `pdflatex` and `jupyter` builders already pass `-n`, so with `-W` every reference they cannot resolve fails the build, even where the `html` build passes.

### In the templates

The [workflow templates](https://github.com/QuantEcon/actions/tree/main/templates) build the website with this action, with `upload-failure-reports: 'true'`: [`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) for a pull request's preview, and [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) before it publishes to GitHub Pages. `publish.yml` carries the `jupyter` and `pdflatex` steps, and the two copy inputs, as comments. [`cache.yml`](https://github.com/QuantEcon/actions/blob/main/templates/cache.yml) builds through `build-jupyter-cache` instead. `publish.yml` and `cache.yml` check out the full history, with `fetch-depth: 0`; `ci.yml` does not, so a preview dates every page to the pull request's commit, and its log carries the shallow-clone warning.

## Behaviour

1. **Downloads.** For an `html` build with `html-copy-pdf: 'true'`, every `.pdf` anywhere under `_build/latex` is copied into `_build/html/_pdf/`. With `html-copy-notebooks: 'true'`, every `.ipynb` under `_build/jupyter` is copied into `_build/html/_notebooks/`. Both copies are flat: files from subdirectories land side by side, which the notebook links do not expect (see [Downloads on the site](#downloads-on-the-site)). A missing source directory is a warning, not a failure.
2. **Git history.** For every builder but `pdflatex` and `jupyter`, the action checks that git can read the repository, because [quantecon-book-theme](https://github.com/QuantEcon/quantecon-book-theme) dates each page and builds its changelog from `git log`, and drops both without a word when git fails.
   - In a container whose image does not already trust every directory, git refuses the work tree, reporting "dubious ownership": the runner creates the workspace as its own user, and the container's steps run as root. Both QuantEcon images trust every directory, so there git reads the tree and nothing is added. Elsewhere the action trusts the work tree for the rest of the job, by adding `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_<n>` and `GIT_CONFIG_VALUE_<n>` to the job's environment, so later steps can run git too. No git configuration file is written, and the entries do not outlast the job.
   - A warning says when the build will lack the dates: git is missing, `source-dir` is not in a git work tree, git cannot read the work tree, or the clone is shallow. A shallow clone dates every page to the checked-out commit.
3. **The build.** The action runs, in a login shell, so that on a standard runner the Conda environment from `setup-environment` is active:

   ```text
   jb build <source-dir> --path-output <output-dir> <builder flags> <extra-args>
   ```

   | Builder | Builder flags | Output |
   |---|---|---|
   | `html` | none | `<output-dir>/_build/html` |
   | `pdflatex` | `--builder pdflatex -n` | `<output-dir>/_build/latex` |
   | `jupyter` | `--builder=custom --custom-builder=jupyter -n` | `<output-dir>/_build/jupyter` |
   | any other | `--builder <builder>` | a directory under `<output-dir>/_build`, which is what `build-path` gives |

   The log shows the full command in its "Build Command" group.
4. **On failure**, the action prints a summary of the builder, source and output. For the `html`, `pdflatex` and `jupyter` builders it then prints each failed notebook's traceback, from `reports/*.err.log` in the build's output directory: the last 200 lines of each, in a log group named after the report. With `upload-failure-reports: 'true'` it uploads the reports and the execution cache as an artifact.
5. **On success**, the log ends with a "Build Summary" group and a listing of the output directory, in "Build Artifacts". Nothing is uploaded.

### What fails the job

`jb build` exiting with an error. With `-W`, which the default `extra-args` passes, that includes every warning, so a notebook cell that raises an exception fails the build.

A second build over the same `_build`, after one that failed with `-W --keep-going`, reads nothing, warns about nothing and passes: Sphinx's saved state counts every page as up to date. To see the failures again, rebuild with `--all` in `extra-args`.

> [!WARNING]
> Keep `-W` in any `extra-args` you set. A cell that raises is not an error to Jupyter Book: myst-nb logs it as a warning and carries on, and only `-W` turns that into a failed build. Without it the build exits 0 over a broken lecture, and the job goes on to deploy it. `--keep-going` makes the build report every such warning before it fails, instead of stopping at the first; without `-W` it does nothing.
>
> Setting `raise_on_error: true` under `execute:` in `_config.yml` also fails the build, but at the first failing notebook, before any `reports/*.err.log` is written. Prefer `-W`.

## Troubleshooting

**`❌ BUILD FAILED - Jupyter Book build encountered errors`.** The groups below it hold each failed notebook's traceback. To reproduce the failure locally, run the command from the "Build Command" group, for example `jb build lectures -W --keep-going`.

**The build passed, but a notebook failed.** `extra-args` is set without `-W`. Add it back.

**`jb: command not found`.** On a standard runner, `setup-environment` has not run, or its environment file does not install `jupyter-book`. In a container, check the job's `container:` image.

**`PDF source directory not found: …` or `Notebook source directory not found: …`.** An `html` build asked for a copy that nothing produced. Run the `pdflatex` or `jupyter` build first, in the same job, or restore a build cache whose cache build ran it.

**`… is a shallow clone, so every page's 'Last changed' date will be the checked-out commit's date`.** Set `fetch-depth: 0` on `actions/checkout`.

**`git cannot find the work tree for …`.** `source-dir` is not inside a git checkout: check that `actions/checkout` runs first, and where it checks out to.

**The failure-report upload fails because `an artifact with this name already exists`.** Another job in the run, or an earlier step in the same job, uploaded reports for the same builder. Give each build its own `failure-artifact-name`.

**A `pdflatex` or `jupyter` build fails on a reference the `html` build accepts.** Those two builders run with `-n`, so every reference they cannot resolve is a warning, and `-W` makes it an error. Fix the reference.

**A rebuild passes after a failed build, with no warnings.** It read nothing: see [What fails the job](#what-fails-the-job). Rebuild with `--all`.
