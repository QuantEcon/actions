# Container images

How the two images in [`containers/`](../../containers) are built, tested and updated. Which image to use, and what is in each, is in the user manual's [Containers](../user/containers.md) chapter.

## Layout

| Path | What it is |
|---|---|
| `containers/quantecon/Dockerfile`, `environment.yml` | The full image, `ghcr.io/quantecon/quantecon`: the `anaconda` metapackage |
| `containers/quantecon-build/Dockerfile`, `environment.yml` | The lean image, `ghcr.io/quantecon/quantecon-build`: an explicit package list pinned to the same Anaconda baseline |
| `containers/quantecon/tests/` | The smoke test and its fixture, which run in both images |

The two Dockerfiles have the same steps. They differ in the apt set (the lean image drops `texlive-luatex` and adds `graphviz`), in the lean image's clean-up of Conda's package cache and bytecode after the install, and in the marker file, which names the image and, in the lean one, adds `variant=build`. A change to one usually belongs in the other. Each copies only its `environment.yml` into the build, so a README edit cannot change an image.

## Building locally

From the repository root:

```bash
docker build -t ghcr.io/quantecon/quantecon:local containers/quantecon
docker build -t ghcr.io/quantecon/quantecon-build:local containers/quantecon-build
```

## How a change reaches `:latest`

1. **The pull request.** A pull request that changes `containers/**` gets [`validate-containers.yml`](../../.github/workflows/validate-containers.yml), which the action harness calls, so its result is part of `Action harness: all checks`. It checks that each Dockerfile pins its base by digest and that both pin the same one, builds each image the pull request changes, cached from `:latest`, and pushes it as a candidate tagged `pr-<N>` and `pr-<N>-<YYYYMMDD>-<HHMMSS>-<sha>`, never `:latest`. It then runs `test-container.yml`'s smoke test and size report on each candidate, in a real `container:` job. A fork's pull request that changes an image fails the check, since its token cannot push a candidate. The candidates are deleted when the pull request closes.
2. **The merge.** [`build-containers.yml`](../../.github/workflows/build-containers.yml) runs on a push to `main` that changes `containers/**`, other than a README, or the workflow itself, and on a manual dispatch (`gh workflow run build-containers.yml`). It builds the images and pushes `:latest`, `main-<sha>` and `main-<YYYYMMDD>-<HHMMSS>-<sha>`. Its step summary records the digest it pushed and the one `:latest` held before, which is the rollback target: see [Rolling back a container image](../../CONTRIBUTING.md#staged-releases). It has no schedule.
3. **After the push.** [`test-container.yml`](../../.github/workflows/test-container.yml) runs the smoke test and size report on both `:latest` images, and opens a tracking issue when it fails. [`test-containers-lectures.yml`](../../.github/workflows/test-containers-lectures.yml) builds the lecture repositories in both images: see [CONTAINER-VALIDATION.md](CONTAINER-VALIDATION.md). It also runs weekly, on Monday at 02:00 UTC, against unchanged images.

The merge's own build still moves `:latest` before any test of that exact build runs; promoting a tested digest instead is #142's phase 2.

## Updating dependencies

- **The science stack** moves as one coordinated change, to the Anaconda baseline the lecture repositories adopt, in both images together: see the Dependency policy in [PLAN.md](PLAN.md#dependency-policy).
- **Everything else** comes from Dependabot (`.github/dependabot.yml`): the conda ecosystem for both `environment.yml` files, with every baseline-pinned package under `ignore`, and the docker ecosystem for the `ubuntu:24.04` digest, as one pull request for both images.
- **Miniconda and Node** are pinned by version and SHA-256 in the Dockerfiles, and no ecosystem tracks them: bump each version and its checksum together, by hand.

## The smoke test

`containers/quantecon/tests/smoke-test.sh` runs inside an image and:

1. checks the marker file, `/etc/quantecon-container`;
2. compiles `test-xelatex.tex` with XeLaTeX, for fontspec and Unicode;
3. builds the fixture book, `minimal-jupyter-book/`, as HTML with `quantecon_book_theme`, executing every cell, under `-W --keep-going`;
4. builds it as a PDF with the `pdflatex` builder, using XeLaTeX and Sphinx's default FreeFont `fontpkg`.

The fixture's cells execute, so a broken science stack fails the build, and they export a plotly figure, which covers kaleido. `smoke-test.sh --self-test` stages a raising cell and fails unless the build goes red. Run the smoke test in a `container:` job, not with `docker run`: `docker run` keeps `HOME=/root`, so it cannot reproduce failures that depend on a container job's `HOME=/github/home`, such as #85.

To test a branch's fixture against the published images, or a pull request's candidates:

```bash
gh workflow run test-container.yml --ref <branch>
gh workflow run test-container.yml --ref <branch> -f tag=pr-<N> -f images='["quantecon-build"]'
```

`containers/quantecon/tests/run-local-tests.sh` runs the same steps on macOS without Docker. It needs MacTeX, the DejaVu fonts (`brew install --cask font-dejavu`), and a Python environment with `jupyter-book`, `quantecon-book-theme`, numpy, scipy, pandas, matplotlib, and plotly with a working `kaleido<1.0`.
