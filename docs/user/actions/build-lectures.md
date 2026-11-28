# build-lectures

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Runs `jb build`, Jupyter Book 1, on the book in `source-dir`, with one builder per step:

- **`html`**, the default: the website, in `_build/html`.
- **`pdflatex`**: the PDF, in `_build/latex`.
- **`jupyter`**: the lectures as notebooks, in `_build/jupyter`.

An `html` build can also copy in the PDF and the notebooks from earlier builds, so the site offers them for download. When a build fails, the action prints the traceback of each notebook that failed to execute, and can upload the execution reports as an artifact.

With `engine: mystmd` it runs `myst build`, [mystmd](https://mystmd.org)'s CLI, from the folder in `source-dir` that holds `myst.yml`, with the same three builders: `--html`, `--pdf` and `--ipynb`. Fewer of the action's checks apply there: see [mystmd](#mystmd).

## When to use it

Use it in any job that builds lectures, after [`setup-environment`](setup-environment.md), and after [`restore-jupyter-cache`](restore-jupyter-cache.md) in a job that starts from a cache. A preview or publish step then deploys the directory in its `build-path` output.

- **One step per format.** For a site that offers the PDF and the notebooks, build `jupyter` and `pdflatex` first, then `html` with `html-copy-pdf` and `html-copy-notebooks`, all in one job. See [Downloads on the site](#downloads-on-the-site).
- **Not in the weekly cache build.** [`build-jupyter-cache`](build-jupyter-cache.md) runs this action itself, once for each of its builders.

## Requirements

- **Runner.** Any job where a login shell finds `jb`, and the `python` it runs on, which checks the executed notebooks: a QuantEcon container, whose images carry Jupyter Book 1 and LaTeX, or a GitHub-hosted runner after `setup-environment`, whose environment file must then install `jupyter-book` 1.x and every extension the book's `_config.yml` loads. The `pdflatex` builder needs LaTeX: on a standard runner, pass `install-latex: 'true'` to `setup-environment`.
  With `engine: mystmd`, a login shell must find `myst`, which you install in an earlier step (the images do not carry it), and a `python` with `ipykernel` and `jupyter_server`, which both images have. The `jupyter` builder needs the [QuantEcon/mystmd](https://github.com/QuantEcon/mystmd) fork, whose `--ipynb` upstream mystmd lacks. See [mystmd](#mystmd).
- **Node.** None with `jb1`. With `engine: mystmd`, the Node that `myst` runs on: both QuantEcon images carry Node 24, and elsewhere `actions/setup-node` installs it.
- **Permissions.** None of its own: the action calls no GitHub API. The job needs `contents: read` for `actions/checkout`.
- **Secrets.** None.
- **Files in your repository.** A Jupyter Book 1 project in `source-dir`: its `_config.yml`, its `_toc.yml` and the pages they name. With `engine: mystmd`, a mystmd project instead: its `myst.yml`, with a `site:` for the `html` builder and `exports:` for the other two. The `html` builder dates each page from the repository's git history, so check out with `fetch-depth: 0`.
- **Setup outside GitHub.** None.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from build-lectures/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `engine` | no | `jb1` | What builds the book: `jb1`, the default, runs `jb build`, Jupyter Book 1; `mystmd` runs `myst build`, mystmd's CLI, which must be on the runner's `PATH`. Empty means `jb1`. With `mystmd` the builders are `html`, `pdflatex` and `jupyter` alone, and `nitpick`, `error-outputs`, `output-dir` and the two copy inputs do not apply: the chapter has a table of what applies on each engine. |
| `builder` | no | `html` | What to build: `html`, the default, builds the website into `<output-dir>/_build/html`; `pdflatex` builds the PDF into `<output-dir>/_build/latex`, and needs LaTeX; `jupyter` builds notebooks into `<output-dir>/_build/jupyter`. Any other value is passed to `jb build` as `--builder <value>`, which writes into a directory under `<output-dir>/_build`. With `engine: mystmd` these three run `myst build --html`, `--pdf` and `--ipynb`, which write into `<source-dir>/_build/html` and `<source-dir>/_build/exports`, and any other value is refused. `--ipynb` is the QuantEcon/mystmd fork's: upstream mystmd lacks it. |
| `source-dir` | no | `lectures` | The book to build, relative to the workspace: the directory that holds its `_config.yml` and `_toc.yml`, or with `engine: mystmd` its `myst.yml`, where `myst build` runs. |
| `output-dir` | no | `.` | The directory the build is written under, passed to `jb build` as `--path-output`, so the output lands in `<output-dir>/_build`. The cache actions read and write `_build` at the workspace root, so keep the default, `.`, in a job that uses them. With `engine: mystmd` it must be `.`: `myst build` writes `_build` beside `myst.yml`, in `source-dir`, and `build-path` gives where. |
| `extra-args` | no | `''` | Further arguments for the build command, split on whitespace, so a quoted value that contains a space cannot be passed. Empty, the default, means the engine's own: `-W --keep-going` for `jb1`, and `--strict` for `mystmd`. Setting this replaces them, so on `jb1` keep `-W` in it: without `-W`, a warning does not fail the build, and a notebook that raises an exception is only a warning. `error-outputs` still finds the traceback that the exception leaves on the page. On `mystmd`, `--strict` fails an `html` build on an error, such as a cell that raises, and `jb build`'s flags (`-W`, `--keep-going`, `-n`, `--builder`, `--path-output`, …) are refused. |
| `nitpick` | no | `true` | `'true'`, the default, passes `-n` to `jb build`, whatever the builder: Sphinx's nitpicky mode, which warns about every reference it cannot resolve, so that under `-W` one fails the build. Without it Sphinx warns only about the kinds of reference it always checks, such as `{ref}` and `{doc}`, and shows any other it cannot resolve as plain text. `'false'` leaves `-n` out. A `-n` in `extra-args` as well does no harm. Not used with `engine: mystmd`, which has no nitpicky mode. |
| `error-outputs` | no | `''` | What to do, after a build that passes, about an executed notebook that holds an error output: a traceback that the page shows. `-W` misses one whose exception was raised while IPython displayed output, such as a figure that failed to draw, because the kernel reports that cell as successful. `fail` fails the step, `warn` annotates each one and passes, and `ignore` skips the check. Empty, the default, means `fail`. Either way the log and the step summary name each notebook and cell, with its traceback. An error is allowed in a cell tagged `raises-exception`, in a notebook whose `mystnb` metadata sets `execution_allow_errors`, and anywhere in a book whose `_config.yml` sets `execute.allow_errors`. Not checked yet with `engine: mystmd` (#364). |
| `html-copy-pdf` | no | `false` | With `builder: html`: `'true'` copies each PDF under `<output-dir>/_build/latex` into `<output-dir>/_build/html/_pdf/` before the build, so the site offers it for download. The PDF comes from a `pdflatex` build earlier in the job, or from a restored build cache; if that directory does not exist, a warning says so and the site is built without it. Ignored by the other builders. Refused with `engine: mystmd`, which links downloads from `myst.yml`. |
| `html-copy-notebooks` | no | `false` | With `builder: html`: `'true'` copies each notebook under `<output-dir>/_build/jupyter` into `<output-dir>/_build/html/_notebooks/` before the build, at the same path, so the site offers them for download: `_build/jupyter/sub/page.ipynb` becomes `_build/html/_notebooks/sub/page.ipynb`. The notebooks come from a `jupyter` build earlier in the job, or from a restored build cache; if that directory does not exist, a warning says so and the site is built without them. Ignored by the other builders. Refused with `engine: mystmd`, which links downloads from `myst.yml`. |
| `upload-failure-reports` | no | `false` | `'true'` uploads an artifact when the build fails, holding the `reports` directories in `_build/html`, `_build/latex` and `_build/jupyter`, and `_build/.jupyter_cache`, all under `output-dir`, kept for 7 days. With `engine: mystmd` it holds `logs`, `temp` and `execute` from `<source-dir>/_build` instead. `'false'`, the default, uploads nothing. For the `html`, `pdflatex` and `jupyter` builders the log shows each failing notebook's traceback either way. |
| `failure-artifact-name` | no | `''` | The name of the artifact that `upload-failure-reports` uploads. Empty, the default, names it `execution-reports-<builder>`. A name can be used only once in a workflow run, so set this when more than one job in a run builds with the same builder. |

<!-- END GENERATED -->

Paths are relative to the workspace, which is the repository root after `actions/checkout`.

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from build-lectures/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `build-path` | The directory the builder wrote to: `<output-dir>/_build/html`, `_build/latex` or `_build/jupyter` for those three builders. For any other it is `<output-dir>/_build`, the directory above the one that builder wrote to. With the default `output-dir` it starts with `./`, as in `./_build/html`. With `engine: mystmd` it is `<source-dir>/_build/html`, or `<source-dir>/_build/exports` for `pdflatex` and `jupyter`, as in `lectures/_build/html`. Set whether or not the build succeeds. |
| `error-output-count` | How many error outputs the `error-outputs` check reported, not counting those it allows: `0` when it found none. Set with `warn` as well as `fail`. Empty when the check did not run: with `ignore`, with `engine: mystmd`, or after a build that failed. |

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
    ├── <directory>/<lecture>.ipynb
    └── …
```

Each notebook keeps its path under `_build/jupyter`, as the theme links a page to `/_notebooks/<page>.ipynb` with the page's directory in `<page>`. So a lecture in a subdirectory of `source-dir` gets its link, and two lectures with the same name in different directories keep a notebook each.

One limit applies to the links: **sites served under a path.** Both links start at the site's root, `/_pdf/…` and `/_notebooks/…`, so they lead nowhere on a site that is not at the root of its domain, such as a GitHub Pages project site with no custom domain. The theme's `download_nb_path` option puts a prefix in front of the notebook links; the PDF link has no such option.

After `restore-jupyter-cache`, the copies can also come from the build cache, if its cache build ran those builders: `_build/latex` and `_build/jupyter` are then already in place, as the last cache build left them.

### Other arguments for `jb build`

Keep `-W --keep-going` in any value you set, because it replaces the default:

```yaml
- uses: quantecon/actions/build-lectures@v0
  with:
    extra-args: '-W --keep-going --all'   # rebuild every page, not only the changed ones
```

`-v` makes the log more verbose, and `-q` quieter. `-n` needs no place in it: the `nitpick` input passes it, and a second `-n` does no harm.

### Unresolved references

`nitpick: 'true'`, the default, passes `-n` to `jb build` for every builder: Sphinx's nitpicky mode, which warns about every reference it cannot resolve, so that under `-W` one fails the build. Without it, Sphinx warns only about the kinds of reference it always checks, such as `{ref}` and `{doc}`; a `{py:func}` naming a function no page documents, say, shows as plain text. To build without `-n` while the references are fixed:

```yaml
- uses: quantecon/actions/build-lectures@v0
  with:
    nitpick: 'false'   # until the unresolved references are fixed
```

To keep `-n` but accept a target that no page documents, list it in `nitpick_ignore_regex`, under `sphinx:`, `config:` in `_config.yml`. Each entry is a pair of regular expressions, for the reference's type and its target, as in `[py:func, mymodule\..*]`. `nitpick_ignore` does not work there: YAML gives each entry as a list, and Sphinx looks for a tuple.

### mystmd

`engine: mystmd` builds a mystmd project: `source-dir` is the folder that holds its `myst.yml`, where `myst build` runs and writes its `_build`. The action does not install `myst`. QuantEcon builds with the [QuantEcon/mystmd](https://github.com/QuantEcon/mystmd) fork, which has no release to install from, so this job builds it from a pinned commit, as [QuantEcon/test-lecture-theme-mystmd](https://github.com/QuantEcon/test-lecture-theme-mystmd/blob/main/.github/workflows/ci.yml) does, and caches it packed, by that commit, so that later runs install it in seconds:

```yaml
name: Build lectures with mystmd
on:
  pull_request:

env:
  # The QuantEcon/mystmd commit to build with: its qe-v15 tag. Bump it deliberately.
  QE_MYSTMD_SHA: 39cda142a43f7a8a96459d8d667e7c43a1853fa5

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon-build:latest   # carries Node 24, git and LaTeX
    permissions:
      contents: read
      packages: read   # the image pull, as the templates grant it
    defaults:
      run:
        shell: bash
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0   # each page's history comes from git log
      - name: Restore mystmd
        id: mystmd
        uses: actions/cache@v6
        with:
          path: qe-mystmd.tgz
          key: qe-mystmd-${{ env.QE_MYSTMD_SHA }}
      - name: Build mystmd from the fork at its pin
        if: steps.mystmd.outputs.cache-hit != 'true'
        run: |
          src="$RUNNER_TEMP/qe-mystmd"
          git init -q "$src"
          git -C "$src" fetch -q --depth 1 https://github.com/QuantEcon/mystmd.git "$QE_MYSTMD_SHA"
          git -C "$src" checkout -q FETCH_HEAD
          cd "$src"
          # The bun version the fork declares, so it follows the pin.
          npm install -g --no-fund --no-audit "$(node -p "require('./package.json').packageManager.split('+')[0]")"
          bun install
          bun run build
          # The CLI is one bundled file with no dependencies, so its pack installs offline.
          (cd packages/mystmd && npm pack --pack-destination "$RUNNER_TEMP" > /dev/null)
          mv "$RUNNER_TEMP"/mystmd-*.tgz "$GITHUB_WORKSPACE/qe-mystmd.tgz"
      - name: Install mystmd
        run: npm install -g --no-fund --no-audit ./qe-mystmd.tgz
      - uses: quantecon/actions/setup-environment@v0
      - uses: quantecon/actions/build-lectures@v0
        id: build
        env:
          BASE_URL: /my-lectures   # a site served under a path, such as a GitHub Pages project site
        with:
          engine: mystmd
          source-dir: lectures
          upload-failure-reports: 'true'
      - uses: actions/upload-artifact@v7
        with:
          name: site
          path: ${{ steps.build.outputs.build-path }}
```

On a runner with no container, such as a GPU machine, add `actions/setup-node` with `node-version: '24'` before the build of mystmd. The site's address comes from `BASE_URL`, which `myst build` reads from the environment: leave it out for a site at the root of its domain.

**The PDF and the notebooks** come from `exports:` in `myst.yml`, or in a page's frontmatter: `--pdf` builds each export of format `pdf`, `pdf+tex` or `typst`, and `--ipynb` each of format `ipynb`, into `_build/exports` unless an export names its own `output`. A build that finds none to build fails the step. Build them before the website, and build the website in the same job:

```yaml
- uses: quantecon/actions/build-lectures@v0
  with:
    engine: mystmd
    builder: pdflatex
- uses: quantecon/actions/build-lectures@v0
  id: build
  with:
    engine: mystmd
    builder: html
```

The site links an export only if its file is there when the site is built, through `myst.yml`'s `downloads`, and only the `html` build fails on a cell that raises: `myst build` exits 0 from an export whose cell raised. mystmd caches only a page that ran without an error, so the `html` build executes that page again, and fails. `html-copy-pdf` and `html-copy-notebooks` do not apply: `myst build --html` deletes `_build/html` before it writes.

**`extra-args`** is `--strict` when you leave it empty, which makes an `html` build exit 1 on any error, such as a cell that raises or a Jupyter server that does not start, and not on a warning. `error_rules` in `myst.yml` makes a warning an error. The action passes `--execute` itself, so to build without `--strict`, as for a book with pages that raise on purpose, give `extra-args: '--execute'`, which changes nothing else. `jb build`'s flags are refused.

**What applies.** `nitpick` and `error-outputs` are not used. The error-output check has no mystmd version yet, nor does a check of a cell that raises in a `pdflatex` or `jupyter` build: both are [#364](https://github.com/QuantEcon/actions/issues/364). [Behaviour](#behaviour) has the table. [`build-jupyter-cache`](build-jupyter-cache.md) builds with Jupyter Book 1 only.

### In the templates

The [workflow templates](https://github.com/QuantEcon/actions/tree/main/templates) build the website with this action, with `upload-failure-reports: 'true'`: [`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) for a pull request's preview, and [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) before it publishes to GitHub Pages. `publish.yml` carries the `jupyter` and `pdflatex` steps, and the two copy inputs, as comments. [`cache.yml`](https://github.com/QuantEcon/actions/blob/main/templates/cache.yml) builds through `build-jupyter-cache` instead. `publish.yml` and `cache.yml` check out the full history, with `fetch-depth: 0`; `ci.yml` does not, so a preview dates every page to the pull request's commit, and its log carries the shallow-clone warning.

In `ci.yml` this action runs in the `build` job, which holds no secrets, and the preview is deployed from a separate `deploy` job that runs no notebook code. `ci.yml` also builds the PDF, in a `pdf-check` job that starts when the build job has finished. Some LaTeX errors pass the `html` build and fail only the `pdflatex` build; `pdf-check` turns the pull request's checks red on them, before they reach the publish. The build job uploads its `_build/.jupyter_cache` for it, so `pdf-check` executes no notebooks. A site that publishes no PDF switches the job off with `PDF_CHECK: 'false'` in the workflow's `env:` block, and a repository that wants a broken PDF to block merges makes `pdf-check` a required status check, with `build` required too. See [The PDF check](../getting-started.md#the-pdf-check).

## Behaviour

With `engine: jb1`, the default:

1. **Downloads.** For an `html` build with `html-copy-pdf: 'true'`, every `.pdf` anywhere under `_build/latex` is copied into `_build/html/_pdf/`. With `html-copy-notebooks: 'true'`, every `.ipynb` under `_build/jupyter` is copied into `_build/html/_notebooks/` at the same path. Only the PDF copy is flat: PDFs from subdirectories land side by side, and the theme links the book's one PDF. A missing source directory is a warning, not a failure; a copy that fails, into a destination that cannot be written, fails the step before the build.
2. **Git history.** For every builder but `pdflatex` and `jupyter`, the action checks that git can read the repository, because [quantecon-book-theme](https://github.com/QuantEcon/quantecon-book-theme) dates each page and builds its changelog from `git log`, and drops both without a word when git fails.
   - In a container whose image does not already trust every directory, git refuses the work tree, reporting "dubious ownership": the runner creates the workspace as its own user, and the container's steps run as root. Both QuantEcon images trust every directory, so there git reads the tree and nothing is added. Elsewhere the action trusts the work tree for the rest of the job, by adding `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_<n>` and `GIT_CONFIG_VALUE_<n>` to the job's environment, so later steps can run git too. No git configuration file is written, and the entries do not outlast the job.
   - A warning says when the build will lack the dates: git is missing, `source-dir` is not in a git work tree, git cannot read the work tree, or the clone is shallow. A shallow clone dates every page to the checked-out commit.
3. **The build.** The action runs, in a login shell, so that on a standard runner the Conda environment from `setup-environment` is active:

   ```text
   jb build <source-dir> --path-output <output-dir> <builder flags> [-n] <extra-args>
   ```

   | Builder | Builder flags | Output |
   |---|---|---|
   | `html` | none | `<output-dir>/_build/html` |
   | `pdflatex` | `--builder pdflatex` | `<output-dir>/_build/latex` |
   | `jupyter` | `--builder=custom --custom-builder=jupyter` | `<output-dir>/_build/jupyter` |
   | any other | `--builder <builder>` | a directory under `<output-dir>/_build`, which is what `build-path` gives |

   `-n` is there for every builder with `nitpick: 'true'`, the default, and left out with `'false'`. The log shows the full command in its "Build Command" group.

   For the `jupyter` builder, with both `-W` and `--keep-going` in `extra-args`, the step also fails when `jb build` exits 0 after logging a warning. sphinx-tojupyter, which provides the builder, ends `jb build` with status 0 before Sphinx can fail it, so the action reads the warnings from `jb build`'s stderr instead, and lists them in a log group. With `-W` alone, `jb build` fails at the first warning on its own.
4. **Error outputs.** After a build that passes, unless `error-outputs` is `ignore`, the action reads every notebook that myst-nb wrote to `<output-dir>/_build/jupyter_execute`, and checks each page's outputs as the page shows them. A notebook the build executed holds its outputs. For a page taken from the execution cache, myst-nb renders the cache's copy but writes the notebook without its outputs, so the action finds that copy in the cache, as myst-nb does, and checks it. That is wherever myst-nb looks in the cache: in a book whose `_config.yml` sets `execute_notebooks: cache` under `execute:`, for every page that no `exclude_patterns` there keeps from executing and whose own `mystnb` frontmatter sets no other `execution_mode`. It skips a notebook with no source under `source-dir`, since a restored build cache keeps the notebooks of lectures since removed. Each `error` output it finds gets an annotation on the source file, at the cell's `{code-cell}` line in a MyST Markdown source, and its traceback in a log group. The annotation says how the error got there, from the code cells after it: the cell raised if none of them ran, since execution stops at a cell that raises, and it raised while its output was displayed if one did. When no code cell after it was to run, because it is the last one or every later one is tagged `skip-execution`, there is nothing to tell by. The step summary lists them all, and `error-output-count` gives how many. With `fail` the step then fails, and with `warn` it passes. A notebook that cannot be read is reported the same way, and fails the step with `fail` too, since it went unchecked, and so is one whose execution cache cannot be read. An error output is allowed where nbclient and myst-nb allow a cell to raise:
   - in a cell tagged `raises-exception`;
   - in a notebook whose frontmatter sets `execution_allow_errors: true` under `mystnb:`;
   - anywhere in a book whose `_config.yml` sets `allow_errors: true` under `execute:`.
5. **When `jb build` fails**, the action prints a summary of the builder, source and output. For the `html`, `pdflatex` and `jupyter` builders it then prints each failed notebook's traceback, from `reports/*.err.log` in the build's output directory: the last 200 lines of each, in a log group named after the report. With `upload-failure-reports: 'true'` it uploads the reports and the execution cache as an artifact, and after a failed error-output check it uploads them too.
6. **On success**, the log ends with a "Build Summary" group and a listing of the output directory, in "Build Artifacts". Nothing is uploaded.

### With `engine: mystmd`

1. **Inputs.** Before anything runs, the first step refuses:
   - a builder other than `html`, `pdflatex` or `jupyter`;
   - `html-copy-pdf` or `html-copy-notebooks` set to `'true'`;
   - an `output-dir` other than `.`;
   - a `source-dir` with no `myst.yml`;
   - a flag of `jb build`'s in `extra-args`: `-W` or a cluster that holds it, `-n`, `--warningiserror`, `--keep-going`, `--nitpick`, `--builder`, `--custom-builder`, `--path-output`, `--config` or `--toc`.

   It says in the log that `nitpick` and `error-outputs` are not used.
2. **Git history**, as for `jb1`, for the `html` builder.
3. **`myst`.** The build step fails if a login shell finds no `myst`, and logs where it found it and `myst --version`, which names the fork's `qe-v<n>`. For the `jupyter` builder it fails if `myst build --help` lists no `--ipynb`.
4. **Two settings for a container**, for the `myst` command and the kernels it starts, logged:
   - `--dns-result-order=ipv4first` is added to `NODE_OPTIONS`. In the QuantEcon images Node resolves `localhost` to `::1` first, and without it every page of the site fails to render.
   - When the step runs as root, as a container job's steps do, Jupyter's `ServerApp.allow_root` is set from a folder in the runner's temporary directory, put first on `JUPYTER_CONFIG_PATH`. Without it `jupyter_server` does not start as root, and nothing executes. No Jupyter configuration of yours is written to.
5. **The build.** From `source-dir`, in a login shell:

   ```text
   myst build <builder flag> --execute <extra-args>
   ```

   | Builder | Builder flag | Output, which `build-path` gives |
   |---|---|---|
   | `html` | `--html` | `<source-dir>/_build/html` |
   | `pdflatex` | `--pdf` | `<source-dir>/_build/exports`, unless an export names its own `output` |
   | `jupyter` | `--ipynb`, the fork's | `<source-dir>/_build/exports`, likewise |

   `--execute` is always there: a PDF shows the cells' outputs only from an executed build, and `--ipynb`, which writes its notebooks without outputs, still fills the execution cache that a later `html` build reads. An empty `extra-args`, the default, is `--strict`. The log shows the command in its "Build Command" group.
6. **What the build wrote.** `myst build` exits 0 when it finds nothing to build, and when an export or a page fails. So after a build that exits 0 the step also fails:
   - for `html`, if this build wrote no `_build/html/index.html` (there is no `site:` in `myst.yml`), or if the log has an `Error fetching <url>` line, one for each page that failed to render, which a log group lists;
   - for `pdflatex` and `jupyter`, if `_build/logs/myst.build.json`, which `myst` writes after the exports, lists no export of the builder's formats, or lists one whose output this build did not write.
7. **When the build fails**, the summary names the engine. `myst` has printed each traceback in the build step's log. With `upload-failure-reports: 'true'` the artifact holds `logs`, `temp` (LaTeX's logs) and `execute` (the execution cache) from `<source-dir>/_build`.

**What applies on each engine.**

| | `jb1` | `mystmd` |
|---|---|---|
| A warning fails the build | with `-W`, in the default `extra-args` | no: `--strict`, the default, fails an `html` build on errors only; `error_rules` in `myst.yml` makes a warning an error |
| A cell that raises fails the build | with `-W`, for every builder | `html` alone, with `--strict`; `pdflatex` and `jupyter` exit 0 ([#364](https://github.com/QuantEcon/actions/issues/364)) |
| `nitpick` | `-n` | not used: mystmd has no nitpicky mode |
| A `jupyter` build's warnings (#300) | read from `jb build`'s stderr | not needed: `myst`'s own status |
| `error-outputs`, an error raised while a result is displayed (#247) | every builder | not yet ([#364](https://github.com/QuantEcon/actions/issues/364)): `myst` passes it, even with `--strict` |
| `html-copy-pdf`, `html-copy-notebooks` | `html` | refused: downloads come from `myst.yml` |
| `output-dir` | `--path-output` | refused unless `.`: output is in `<source-dir>/_build` |
| Git history check | every builder but `pdflatex` and `jupyter` | the same |
| What the build wrote | — | the site's `index.html` and its pages, or each export |
| Tracebacks after a failed build | from `reports/*.err.log` | in `myst`'s own log |
| `upload-failure-reports` | `reports` and `.jupyter_cache` | `logs`, `temp` and `execute` |
| `build-path` | `<output-dir>/_build/<builder's directory>` | `<source-dir>/_build/html` or `/exports` |
| `error-output-count` | set | empty |

### What fails the job

A failed build. For every builder but `jupyter`, that is `jb build` exiting with an error, and with `-W`, which the default `extra-args` passes, every warning makes it one, so a notebook cell that raises an exception fails the build. So does a reference Sphinx cannot resolve, with `nitpick: 'true'`, the default: see [Unresolved references](#unresolved-references). For the `jupyter` builder under `-W --keep-going`, `jb build` exits 0 whatever it warned about, so the action fails the step on each warning itself: see [Behaviour](#behaviour), step 3. Under `-W` alone, `jb build` fails at the first warning for the `jupyter` builder too.

After a build that passes, an executed notebook that holds an error output, with `error-outputs` at its default, `fail`. `-W` cannot see an exception raised while IPython displays output, such as a figure that fails to draw. The kernel reports that cell as successful, so myst-nb renders the traceback on the page without a warning, and `jb build` exits 0.

With `engine: mystmd`: an invalid input, before anything runs; no `myst`; `myst build` exiting with an error, which with `--strict` an `html` build does on any error, a cell that raises included; and a build that exits 0 having written nothing, or with a page that failed to render. See [With `engine: mystmd`](#with-engine-mystmd).

A build reads, and executes, only the pages that changed since Sphinx last saved its state in `_build`, and every builder shares that state. So once one build in a job has read the pages, a later one over the same `_build` reads none of them, and repeats none of the first build's warnings. After a first build that failed with `-W --keep-going`, a second one passes, and a cell that raised reaches it only through the error-output check. To see the failures again, rebuild with `--all` in `extra-args`. The exception is a `jb-book` with parts after a `pdflatex` build. `pdflatex` changes a setting the builders share (`numfig_secnum_depth`), so the next build with another builder reads every page again: it takes from the execution cache each page that executed, and executes again each one that failed.

> [!WARNING]
> Keep `-W` in any `extra-args` you set. A cell that raises is not an error to Jupyter Book: myst-nb logs it as a warning and carries on, and only `-W` turns that into a failed build. Without it `jb build` exits 0 over a broken lecture. With `error-outputs: fail`, the step still fails on the traceback that the exception leaves in the notebook, but every other warning passes unseen. `--keep-going` makes the build report every such warning before it fails, instead of stopping at the first; without `-W` it does nothing.
>
> Setting `raise_on_error: true` under `execute:` in `_config.yml` also fails the build, but at the first failing notebook, before any `reports/*.err.log` is written. Prefer `-W`.

## Troubleshooting

**`❌ BUILD FAILED - Jupyter Book build encountered errors`.** The groups below it hold each failed notebook's traceback. To reproduce the failure locally, run the command from the "Build Command" group, for example `jb build lectures --path-output . -n -W --keep-going`.

**`jb build exited 0, but the jupyter build logged <n> warning(s), and -W makes each one an error`.** The `jupyter` build warned, under `-W --keep-going`. The log group "The jupyter build's <n> warning(s)" lists each warning: fix them as for any other builder. A `tojupyter_static_file_path` entry that names a directory the book does not have warns `tojupyter_static_path entry … does not exist`: drop the entry. The same `jb build` command, run locally, exits 0 too: look for `WARNING:` in its output, or run it with `-W` and without `--keep-going`, which fails at the first warning.

**`…: <error>. The cell raised, and the notebook stopped there`.** The cell raised an exception, and the cells after it never ran. `-W` fails the build that executes the page, so this build ran without `-W` in `extra-args`, or it came after another build in the job and read no page: that build's log names the failure. Fix the cell, or tag it `raises-exception` if the error is meant to be shown.

**`…: <error>. The page shows the traceback`.** No code cell after this one was to run: it is the notebook's last, or every later one is tagged `skip-execution`. So the check cannot tell whether the cell raised or its output did. See the entry above and the one below.

**`…: <error>. The kernel reported this cell as successful, so -W did not catch it, and the page shows the traceback`.** The cell's code ran, but displaying its output raised, so the page shows a traceback where the output should be. The log group named after the cell holds the traceback. A common cause is a deprecation that expires inside a figure's drawing: under NumPy 2.4, for example, Matplotlib rejects a length-1 array passed to `ax.text` as a coordinate. Fix the cell, or tag it `raises-exception` if the error is meant to be shown. `error-outputs: 'warn'` lets the build pass while you fix it.

**The build passed, but a notebook failed.** `extra-args` is set without `-W`, and `error-outputs` is `warn` or `ignore`. Add `-W` back. Or the build came after another in the same job and read no page: see [What fails the job](#what-fails-the-job).

**`jb: command not found`.** On a standard runner, `setup-environment` has not run, or its environment file does not install `jupyter-book`. In a container, check the job's `container:` image.

**`PDF source directory not found: …` or `Notebook source directory not found: …`.** An `html` build asked for a copy that nothing produced. Run the `pdflatex` or `jupyter` build first, in the same job, or restore a build cache whose cache build ran it.

**`… is a shallow clone, so every page's 'Last changed' date will be the checked-out commit's date`.** Set `fetch-depth: 0` on `actions/checkout`.

**`git cannot find the work tree for …`.** `source-dir` is not inside a git checkout: check that `actions/checkout` runs first, and where it checks out to.

**The failure-report upload fails because `an artifact with this name already exists`.** Another job in the run, or an earlier step in the same job, uploaded reports for the same builder. Give each build its own `failure-artifact-name`.

**`WARNING: py:func reference target not found: …`, or another `reference target not found`.** With `nitpick: 'true'`, the default, every builder runs with `-n`, so every reference Sphinx cannot resolve is a warning, and `-W` makes it an error. Fix the reference, or accept its target in `nitpick_ignore_regex`, or set `nitpick: 'false'` while you fix it: see [Unresolved references](#unresolved-references).

**A rebuild passes after a failed build, with no warnings.** It read nothing: see [What fails the job](#what-fails-the-job). Rebuild with `--all`.

**`engine must be jb1 or mystmd (or empty, for jb1)`.** The value is `mystmd`, the engine, not `myst`, its command, and not `jb2`: Jupyter Book 2 is not an engine yet.

**`❌ BUILD FAILED - mystmd build encountered errors`.** `myst build` failed, or its check of what it wrote did. The tracebacks, and what `myst` reported, are in the build step's log, above the summary. To reproduce it locally, run the command from the "Build Command" group in `source-dir`.

**`myst is not on PATH, and engine: mystmd runs it`.** Install mystmd in an earlier step of the job: see [mystmd](#mystmd). A login shell runs the build, so `myst` must be on the `PATH` it sets up.

**`builder: jupyter runs myst build --ipynb, and this myst has no --ipynb`.** `--ipynb` is the QuantEcon/mystmd fork's, and this `myst` is upstream's. Install the fork, as in [mystmd](#mystmd). The log's `myst:` line says which `myst` the build found.

**`myst build --html exited 0, but wrote no …/index.html`.** `myst.yml` has no `site:`, so `myst` built no website. Add one, with its `template:`.

**`myst build --html exited 0, but <n> page(s) of the site failed to render`.** The log group "The pages that failed to render" lists each address `myst` could not fetch from its own content server. In a container the action already prefers IPv4, which is the usual cause. Otherwise the theme failed on those pages: the lines above them in the log say how.

**`myst build --pdf exited 0, but found no export of its kind to build`**, or **`--ipynb`**. List one under `exports:` in `myst.yml`, or in a page's frontmatter, with `format: pdf` (or `typst`) for the PDF and `format: ipynb` for the notebooks.

**`… export(s) wrote nothing in this build`.** An export failed, and `myst` carried on. Its log says why. A LaTeX error leaves its logs in `<source-dir>/_build/temp`, which `upload-failure-reports: 'true'` uploads.

**A `pdflatex` or `jupyter` build passed with a cell that raises.** `myst build` exits 0 from an export, whatever its flags. Build `html` in the same job, which runs that page again and fails: see [mystmd](#mystmd). A check of the export builds is [#364](https://github.com/QuantEcon/actions/issues/364).

**`Could not load Jupyter session manager to run executable nodes`.** `myst` could not start Jupyter. The `python` a login shell finds must have `jupyter_server` and `ipykernel`. As root, the action lets `jupyter_server` start: the log's "Running as root" line shows it did.

**`extra-args holds -W, a flag of jb build, which myst build does not take`.** Leave `extra-args` empty for mystmd's default, `--strict`, or give `myst build`'s own flags. A workflow that builds on both engines can leave it empty on both: on `jb1` an empty one is `-W --keep-going`.

**`engine: mystmd builds from the directory that holds myst.yml, and … has none`.** Set `source-dir` to the folder with `myst.yml` in it.

**`html-copy-pdf and html-copy-notebooks do not apply with engine: mystmd`**, or **`output-dir must be '.' with engine: mystmd`**. Drop the input: see [mystmd](#mystmd) for how a mystmd site offers its downloads, and use the `build-path` output for where the build is.

**`<input> must be a single line`.** Every input but `extra-args` is one value, and a line break would end the line that prints it, and the runner reads a next line that starts with `::` as a workflow command. So the action fails in its first step, before it has done anything. A YAML block scalar (`|`), or an expression whose value spans lines, puts one there: write the value on one line. See [Security](../security.md#what-the-actions-themselves-do). `extra-args` may span lines: it is split on whitespace, line breaks included.
