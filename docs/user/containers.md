# Containers

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Two container images carry everything a lecture build needs before the job starts: Python and the scientific stack, Jupyter Book, LaTeX, and Node for the deploy tools. A job that runs in one spends its first minutes pulling the image instead of installing a toolchain, and [`setup-environment`](actions/setup-environment.md) adds only the packages the lectures need beyond it.

| Image | Python packages |
|---|---|
| `ghcr.io/quantecon/quantecon` (full) | The `anaconda=2026.07` metapackage, several hundred packages |
| `ghcr.io/quantecon/quantecon-build` (lean) | An explicit list, each pinned to its version in that same Anaconda 2026.07 release: numpy, scipy, pandas, matplotlib, seaborn, plotly, sympy, numba, networkx, statsmodels, scikit-learn, the Jupyter stack and a few file-format packages |

Both run on x86-64 and have no GPU support: GPU builds run on a self-hosted machine image instead, as [On a GPU](#on-a-gpu) describes.

## Which image to use

The templates use the full image. It runs any lecture written against the Anaconda baseline, so most lecture repositories need few or no extra packages on top.

The lean image is a little smaller to pull, because TeX Live is most of the size of both. Use it when the lectures need only its pinned list, plus the packages they add themselves. A package the full image has and the lean one lacks fails the build at the import, so a repository moving to the lean image adds such packages to its `environment-update` file.

Each [`Build QuantEcon Containers`](https://github.com/QuantEcon/actions/actions/workflows/build-containers.yml) run reports the size of the images it built, compressed and on disk, in the summaries of its `Image size` jobs.

## What is in them

Both images hold:

- **Ubuntu 24.04**, the base, pinned by digest.
- **TeX Live** from Ubuntu's packages: `texlive-latex-recommended`, `texlive-latex-extra`, `texlive-fonts-recommended`, `texlive-fonts-extra` and `texlive-xetex`, with `latexmk`, `xindy`, `dvipng`, `ghostscript` and `cm-super`, and the FreeFont and DejaVu fonts set up for XeLaTeX. The full image adds `texlive-luatex`, and the lean image adds `graphviz`.
- **Miniconda**, and a Conda environment named `quantecon`, with Python 3.13, first on `PATH`. A step's `python` is that environment's.
- **Jupyter Book 1** with the extensions the lectures use: `quantecon-book-theme`, `sphinx-tojupyter`, `sphinxext-rediraffe`, `sphinx-exercise`, `sphinx-proof`, `sphinxcontrib-youtube`, `sphinx-togglebutton` and `sphinx-reredirects`, with `quantecon-book-networks`, and `kaleido` below 1.0 for plotly's static image export.
- **Node 24**, outside Conda and ahead of it on `PATH`, for the deploy tools the preview actions install.
- **A git setting that trusts every work tree.** In a container job the checkout belongs to the runner's user while the steps run as root, and without it git would refuse the repository, so each page would lose its "Last changed" date.
- **The marker file** `/etc/quantecon-container`, which tells `setup-environment` it is in a QuantEcon image.

They do not hold the packages only some lectures use, such as `quantecon`, `cvxpy`, `jax` or the data-download packages. A repository lists those in an `environment-update` file; see [Using an image](#using-an-image).

The exact contents are each image's `Dockerfile` and `environment.yml`, in [`containers/`](https://github.com/QuantEcon/actions/tree/main/containers).

## Using an image

```yaml
name: Build lectures
on:
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    permissions:
      contents: read
      packages: read
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: quantecon/actions/setup-environment@v0
        with:
          environment-update: environment-update.yml
      - uses: quantecon/actions/build-lectures@v0
```

- **Access.** The images are not public: an anonymous pull is refused ([#129](https://github.com/QuantEcon/actions/issues/129)). A container job in a QuantEcon repository pulls them with `packages: read`, as the templates do.
- **Extra packages.** `environment-update` names a Conda environment file of the packages the image lacks, which `setup-environment` installs into the image's environment on every run. Leave it out if the image has everything. [Adding packages in a container](actions/setup-environment.md#adding-packages-in-a-container) shows the file.
- **Full history.** `fetch-depth: 0` lets the theme date each page from its own history.

On your own machine, log in to `ghcr.io` first, with a token that can read QuantEcon's packages, then run the image over the repository:

```bash
docker run --rm -v "$(pwd)":/workspace -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  jb build lectures --path-output ./
```

A local `docker run` keeps `HOME=/root`, while a container job sets `HOME=/github/home`, so a failure that depends on the home directory may show in only one of the two.

## When the images change

Nothing rebuilds the images on a schedule. An image changes when a pull request that changes it merges:

- **A change to an image's recipe,** its `Dockerfile` or `environment.yml`. The science stack moves as one coordinated change, to the next Anaconda baseline the lecture repositories pin, in both images together.
- **Dependabot's pull requests,** for the packages outside the Anaconda baseline, such as `quantecon-book-theme`, and for the Ubuntu base. The base is pinned by digest, so Ubuntu's security updates arrive when Dependabot proposes a new `ubuntu:24.04` digest, which happens whenever Canonical republishes the image, every few weeks.

Each such pull request builds its images as candidates tagged `pr-<number>`, and smoke-tests them, before it can merge. The merge rebuilds the images and smoke-tests them again, and only if every test passes moves `:latest`, which every workflow that names `:latest` uses from its next run. If a test fails, `:latest` stays on the images it had.

The Ubuntu packages, TeX Live among them, are the versions in Ubuntu's archive when an image's apt layer was last built. That layer is rebuilt when the pinned base moves or the apt step changes, and not otherwise.

After each change reaches `:latest`, and weekly on Monday at 02:00 UTC, a test run builds four lecture repositories in both `:latest` images. The weekly run catches a lecture repository, or the actions, drifting against images that have not changed. It changes no image itself.

## Pinning an image

`:latest` moves with every merged change. To keep a workflow on one image, name it by digest:

```yaml
container:
  image: ghcr.io/quantecon/quantecon@sha256:<digest>
```

Each build is also tagged `main-<YYYYMMDD>-<HHMMSS>-<commit>`, which finds an image by date, and the step summary of each [`Build QuantEcon Containers`](https://github.com/QuantEcon/actions/actions/workflows/build-containers.yml) run records the digest it pushed. A digest always names the same image. Rebuilding an image exactly from its recipe is another matter, which [#129](https://github.com/QuantEcon/actions/issues/129) covers.

Old images are deleted. The newest 10 builds, and every build of the last 90 days, are kept. To keep a pinned digest for longer, add it to [`.github/container-pins.txt`](https://github.com/QuantEcon/actions/blob/main/.github/container-pins.txt) in a pull request to this repository, and say which workflows pin it. Otherwise the pin stops working once its build is deleted.

## On a GPU

The images have no GPU support. GPU builds run on RunsOn self-hosted runners, from a machine image that carries the same marker file and a Conda environment, so `setup-environment` treats it like a container. See [Running on your own host](actions/setup-environment.md#running-on-your-own-host), and [GPU-AMI-SETUP.md](../dev/GPU-AMI-SETUP.md) for how that machine image is built.

## Troubleshooting

**A step cannot import a package.** The image lacks it. Add it to the `environment-update` file. To see what an image holds, run `conda list` in it.

**The image pull fails with `unauthorized` or `denied`.** The job lacks `packages: read`, or the repository is outside QuantEcon and cannot read the images.

**A build that passed before fails after `:latest` moved.** Find the image the last good run used: its log names the digest in "Initialize containers". Pin that digest while you fix the build, and see the CHANGELOG for what changed in the image.
