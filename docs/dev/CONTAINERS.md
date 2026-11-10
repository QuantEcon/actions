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

1. **The pull request.** A pull request that changes `containers/**` gets [`validate-containers.yml`](../../.github/workflows/validate-containers.yml), which the action harness calls, so its result is part of `Action harness: all checks`. It checks that each Dockerfile pins its base by digest and that both pin the same one, builds each image the pull request changes, cached from `:latest`, and pushes it as a candidate tagged `pr-<N>` and `pr-<N>-<YYYYMMDD>-<HHMMSS>-<sha>`, never `:latest`. It dry-runs the promotion in step 3 on each candidate, then runs `test-container.yml`'s smoke test and size report on them, in a real `container:` job. A fork's pull request that changes an image fails the check, since its token cannot push a candidate. The candidates are deleted when the pull request closes.
2. **The merge.** [`build-containers.yml`](../../.github/workflows/build-containers.yml) runs on a push to `main` that changes `containers/**`, other than a README, or the workflow itself, and on a manual dispatch (`gh workflow run build-containers.yml`). It has no schedule. It builds the images, cached from `:latest`, and pushes each as a candidate tagged `main-<sha>` and `main-<YYYYMMDD>-<HHMMSS>-<sha>`, never `:latest`. It then calls `test-container.yml` on the dated tag twice, once for the smoke test and once for the size report.
3. **The promotion.** When every smoke test has passed, the run's `promote` job points `:latest` at the digest each build pushed, all the images together, through `scripts/promote-image.sh`. The script first checks that each candidate tag still resolves to the digest pushed, and records the digest `:latest` held. Then `docker buildx imagetools create` moves the tag without rebuilding, and the script checks that `:latest` now resolves to the tested digest. The job's step summary has each digest pushed, promoted and replaced, and the command that puts back the one replaced: see [Rolling back a container image](../../CONTRIBUTING.md#staged-releases). A failed smoke test or promotion leaves `:latest` where it was. The size report does not hold the promotion back, since it fails when it cannot compute a figure, a fault in the measurement rather than the image. On any branch but `main` the promotion is a dry run, so a dispatch from a branch tests the whole run without moving `:latest`.
4. **After the promotion.** [`test-containers-lectures.yml`](../../.github/workflows/test-containers-lectures.yml) builds the lecture repositories in both images: see [CONTAINER-VALIDATION.md](CONTAINER-VALIDATION.md). It also runs weekly, on Monday at 02:00 UTC, against unchanged images.

A push run that fails opens or updates a tracking issue, so a `:latest` that stops moving is reported. So does one that is cancelled, as a timeout is, unless a newer run of the workflow has superseded it. `scripts/newer-runs.sh` counts the newer runs on the run's branch, and when it cannot list them the cancellation is reported; `validate-containers.yml` self-tests it on every harness run. A dispatch reports nothing: someone is watching it.

The image that reaches `:latest` is the one the merge built and tested, not the pull request's candidate: the merge rebuilds the changed layers, and their floating packages resolve again. Every `main-*` tag is kept, as a rollback target.

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
