# setup-environment

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Sets up the Python environment the rest of a lecture build runs in. It has two modes, and chooses one by itself:

- **Container mode**, when the file `/etc/quantecon-container` exists. The QuantEcon images, `ghcr.io/quantecon/quantecon` and `ghcr.io/quantecon/quantecon-build`, carry it, and so can a machine of your own (see [Running on your own host](#running-on-your-own-host)). The environment is already installed there, so the action adds only the packages you list in `environment-update`, or installs nothing.
- **Standard mode**, everywhere else, such as a plain `ubuntu-latest` job. The action builds a Conda environment from your `environment.yml`, caches it between runs, and can install LaTeX with apt.

The same step works in both modes, so a job can move between a container and a standard runner without changing it.

## When to use it

Use it in any job that builds lectures, after `actions/checkout` and before [`build-lectures`](https://github.com/QuantEcon/actions/tree/main/build-lectures).

- **Prefer a container.** The images already hold the scientific stack, Jupyter Book and LaTeX, which standard mode has to install or restore from its cache. The [containers README](https://github.com/QuantEcon/actions/tree/main/containers) compares the two images.
- **Keep the step in a container job even with nothing to add.** It then installs nothing, but it records the mode in the log, and it is what lets the job run on a standard runner too.
- **Do not add it before [`build-jupyter-cache`](https://github.com/QuantEcon/actions/tree/main/build-jupyter-cache).** That action runs `setup-environment` itself, and asks it for LaTeX when `pdflatex` is among its builders.

## Requirements

- **Runner.** In container mode, a job whose `container:` is a QuantEcon image, or a host with the marker file. In standard mode, a GitHub-hosted Ubuntu runner: the action uses the runner's own Conda, at `$CONDA`, and installs LaTeX with `sudo apt-get`.
- **Node.** None.
- **Permissions.** None of its own: the action calls no GitHub API. The job needs `contents: read` for `actions/checkout`. In a `container:` job the templates also grant `packages: read`, for the image pull.
- **Secrets.** None.
- **Files in your repository.** Standard mode needs the Conda environment file, `environment.yml` unless you set `environment`, and with `install-latex: 'true'` a list of LaTeX packages. The [example list](https://github.com/QuantEcon/actions/blob/main/templates/latex-requirements.txt) in `templates/` names the TeX packages the two images have in common, and is the place to start. Container mode needs a file only if you set `environment-update`.
- **Setup outside GitHub.** None.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from setup-environment/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `python-version` | no | `3.13` | Standard mode: the Python version the Conda environment is created with. It is part of the Conda cache key, so changing it starts a separate cache. Keep it in step with any `python` pin in `environment`. Ignored in container mode, which uses the Python already on `PATH`. |
| `environment` | no | `environment.yml` | Standard mode: path to the Conda environment file the environment is built from. The job fails if the file does not exist. Its hash is part of the Conda cache key, so editing the file makes the next run update the environment and save it under a new key. Ignored in container mode: use `environment-update` there. |
| `environment-update` | no | `''` | Container mode: path to a Conda environment file listing only the packages to add to the image's environment. It is applied with `conda env update`, without `--prune`, to the environment whose `python` is on `PATH`; the file's `name:` is ignored. The job fails if the file does not exist. Empty, the default, uses the image's packages as they are. Ignored in standard mode. |
| `environment-name` | no | `quantecon` | Standard mode: the name of the Conda environment to create and activate, at `$CONDA/envs/<name>`. It takes precedence over any `name:` in `environment`, and is part of the Conda cache key. In container mode it selects nothing: the update goes to the environment on `PATH`, with a warning if that environment has a different name. |
| `cache-version` | no | `v1` | Standard mode: part of the Conda cache key and of its `restore-keys` fallback, so a cache is only ever restored within one version. Changing it (say `v1` to `v2`) makes the next run build the environment from scratch. No effect in container mode, which has no Conda cache. |
| `install-latex` | no | `false` | Standard mode: `'true'` installs the apt packages listed in `latex-requirements-file`, which a `pdflatex` build needs; `'false'`, the default, installs none. Ignored in container mode, which expects LaTeX to be installed already, as it is in the images. |
| `latex-requirements-file` | no | `latex-requirements.txt` | Standard mode, with `install-latex: 'true'`: path to the list of apt packages to install, separated by spaces or newlines, where `#` starts a comment anywhere on a line. The job fails if the file is missing or names no package. |

<!-- END GENERATED -->

Paths are relative to the workspace, which is the repository root after `actions/checkout`.

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from setup-environment/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `container-mode` | `'true'` when `/etc/quantecon-container` exists, as it does in the QuantEcon images and on hosts that carry the same marker file; `'false'` otherwise. Always set. |
| `conda-cache-hit` | Standard mode: `'true'` when the Conda environment was restored from an exact cache-key match; `'false'` when only the `restore-keys` fallback matched, after which the environment is updated from `environment`; empty on a cache miss. Always empty in container mode, which has no Conda cache. Test it with `== 'true'`. |

<!-- END GENERATED -->

## Examples

### Minimal: in a container

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
      - uses: quantecon/actions/setup-environment@v0
      - uses: quantecon/actions/build-lectures@v0
```

### On a standard runner

This job builds the PDF, so it asks for LaTeX; it needs `environment.yml` and `latex-requirements.txt` at the repository root.

```yaml
name: Build PDF
on:
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v7
      - uses: quantecon/actions/setup-environment@v0
        with:
          install-latex: 'true'
      - name: Show the environment's Python
        shell: bash -l {0}   # the login shell is what activates the environment
        run: python --version
      - uses: quantecon/actions/build-lectures@v0
        with:
          builder: pdflatex
```

### Adding packages in a container

List only what the image lacks, and point `environment-update` at the file:

```yaml
- uses: quantecon/actions/setup-environment@v0
  with:
    environment-update: environment-update.yml
```

```yaml
# environment-update.yml. A name: line can be left out: it is ignored.
channels:
  - conda-forge
dependencies:
  - wbgapi
  - pip:
      - pandas-datareader
```

Keep the full `environment.yml` too if the repository also builds on a standard runner: standard mode reads that file, and ignores this one.

### In the templates

The [workflow templates](https://github.com/QuantEcon/actions/tree/main/templates) use this action in a complete setup: [`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) for pull-request previews and [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) for GitHub Pages. Both run in a container, with the standard-runner inputs as comments.

## Behaviour

### Container mode

1. With `environment-update` empty, nothing is installed.
2. Otherwise the file must exist, and the `python` on `PATH` must belong to a Conda environment: its `sys.prefix` must hold `conda-meta`. The action runs `conda env update -p <that prefix> -f <file>`.
   - The environment is chosen by its path, so neither the file's `name:` nor `environment-name` selects it. A warning says so when either names a different environment.
   - There is no `--prune`: the file lists only the extras, and pruning would remove everything else.
3. `environment`, `python-version`, `cache-version`, `install-latex` and `latex-requirements-file` are ignored, and nothing is cached: a delta is installed afresh on every run. Caching it is [#18](https://github.com/QuantEcon/actions/issues/18).

### Standard mode

1. The environment file must exist.
2. [setup-miniconda](https://github.com/conda-incubator/setup-miniconda) prepares the runner's Conda and creates the environment `environment-name` with `python-version`.
3. [actions/cache](https://github.com/actions/cache) restores `$CONDA/envs/<environment-name>`:

   | Match | Cache key |
   |---|---|
   | Exact | `conda-<os>-<environment-name>-<cache-version>-py<python-version>-<hash of environment>` |
   | Fallback | `conda-<os>-<environment-name>-<cache-version>-py<python-version>-` |

   The fallback restores the most recent cache whose key starts with it: the latest environment with the same name, `cache-version` and Python version, whatever environment file it was built from. It never crosses a `cache-version`, so changing that builds the environment from scratch.
4. Unless the key matched exactly, `conda env update -n <environment-name> -f <environment> --prune` brings the environment in line with the file, removing packages it no longer lists.
5. With `install-latex: 'true'`, the packages in `latex-requirements-file` are installed with `sudo apt-get install`.
6. At the end of the job, if the job succeeded and the key did not match exactly, the environment is saved under the key. A failed job saves nothing.

**Your own steps.** setup-miniconda activates the environment for login shells only. A `run:` step that needs it sets `shell: bash -l {0}`; under the default shell, `python` is the runner's own. `build-lectures` already does this. In container mode the environment is on `PATH` from the start.

### What fails the job

- A missing file: the environment file in standard mode, a non-empty `environment-update` in container mode, or the LaTeX list in standard mode with `install-latex: 'true'`.
- A LaTeX list that names no package.
- In container mode, a `python` on `PATH` that is not in a Conda environment.
- A failing `conda env update` or `apt-get install`.

### Log and artifacts

The action ends with three collapsed log groups: a summary of the mode and what it did, the environment's Python packages, and the `pdflatex` version. It uploads no artifacts.

## Running on your own host

Container mode keys only on the marker file, so a self-hosted runner or a custom machine image can use it. The RunsOn GPU image in [GPU-AMI-SETUP.md](../../dev/GPU-AMI-SETUP.md) is built this way. Such a host needs:

1. **The marker file**, `/etc/quantecon-container`: a first line `quantecon-container`, then `key=value` lines. The action prints the file, and names its `image=` value in the summary. For example:

   ```text
   quantecon-container
   image=quantecon_ubuntu2404
   variant=gpu
   build_date=2026-09-01T00:00:00+00:00
   ```

2. **Conda**, with `conda` on `PATH`.
3. **A Conda environment whose `python` comes first on `PATH`**, holding the scientific stack, Jupyter Book and LaTeX. It may be `base`.

The lecture-specific packages then come from `environment-update`, as in a container:

```yaml
name: Build lectures (GPU)
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: "runs-on=${{ github.run_id }}/family=g4dn.2xlarge/image=quantecon_ubuntu2404/disk=large"
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v7
      - uses: quantecon/actions/setup-environment@v0
        with:
          environment-update: environment-update.yml
      - uses: quantecon/actions/build-lectures@v0
```

## Troubleshooting

**`Environment file not found: environment.yml (required in standard / non-container mode)`.** The job ran in standard mode. If it was meant to run in a container, check its `container:` block. Otherwise add the file, or point `environment` at it, and check that `actions/checkout` runs first.

**`Environment update file not found: …`.** The path is relative to the repository root, and `actions/checkout` must run first.

**`Cannot apply …: the python on PATH is not in a conda environment`.** Container mode, on a host whose `python` is not from Conda. The message lists the `python`, `sys.prefix`, `conda` and `CONDA_DEFAULT_ENV` it found. Put the environment's `bin` directory first on `PATH`.

**A warning that the file `says name: …, but the environment on PATH is …`.** Harmless: the packages went to the environment on `PATH`. Remove the `name:` line, or make it match, to silence it.

**A warning that `environment-name is '…', but the environment on PATH is …`.** Harmless. `environment-name` does nothing in container mode, so drop it from container jobs.

**`install-latex is true but no LaTeX requirements file was found at …`, or `… contains no package names`.** Add the list, starting from the [example](https://github.com/QuantEcon/actions/blob/main/templates/latex-requirements.txt), or point `latex-requirements-file` at yours.

**`ModuleNotFoundError` in one of your own steps on a standard runner.** The step runs under the default shell, which has not activated the environment. Add `shell: bash -l {0}`.

**`conda-cache-hit` is never `'true'`.** The environment is saved only at the end of a job that succeeds, and the key changes with the environment file, `environment-name`, `python-version` and `cache-version`. The cache's post step, near the end of the job log, says whether it saved.

**The restored environment is broken.** Change `cache-version`, say from `v1` to `v2`. No cache from another version is restored, so the next run builds the environment from scratch. Deleting the repository's `conda-` caches, on the Caches page of its Actions tab, does the same.
