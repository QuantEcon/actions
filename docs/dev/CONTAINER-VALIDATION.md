# Container validation: the lecture matrix

[`test-containers-lectures.yml`](../../.github/workflows/test-containers-lectures.yml) builds real lecture repositories in both container images, so a change to an image, or a change in a lecture repository against an unchanged image, is caught before a lecture build meets it. How the images are built, and the smoke test each change gets first, are in [CONTAINERS.md](CONTAINERS.md).

## When it runs

- **After each `Build QuantEcon Containers` run** on `main` that succeeds, against the `:latest` it promoted, with the actions checked out at the commit that built it.
- **Weekly, on Monday at 02:00 UTC**, against `:latest`, since the images are no longer rebuilt on a schedule (#235). This run is what catches a lecture repository, or the actions, drifting against images that have not changed.
- **By hand:** `gh workflow run test-containers-lectures.yml`.

It runs after `:latest` has moved, not on a pull request's candidate images: at up to three hours a leg, it is a check after the push, not a gate.

## What it builds

The matrix is both images, `quantecon` and `quantecon-build`, times four lecture repositories:

| Repository | Notes |
|---|---|
| `lecture-python-intro` | |
| `lecture-python-programming` | |
| `lecture-python-advanced.myst` | |
| `lecture-python.myst` | The largest; its leg may run 240 minutes, the others 120 |

`lecture-jax` is left out until [lecture-jax#284](https://github.com/QuantEcon/lecture-jax/issues/284) adds its JAX install to the lectures.

Each leg clones the repository and builds it with this repository's actions, through all three builders in turn, HTML, then `pdflatex`, then `jupyter`, in one job, so the later builders reuse the notebooks the HTML build executed. A repository's two legs run one after the other, so that two builds of it do not fetch its datasets at once; different repositories run side by side.

The HTML stage is tried twice. Several lectures fetch a dataset from raw GitHub at build time, and from shared runner addresses that fetch is sometimes refused with HTTP 429. A first attempt that fails is rebuilt once with `--all`, which re-executes only the notebooks that did not reach the execution cache and re-checks every warning, so a passing flake does not fail the leg and a persistent failure still does (#102).

## Reading a run

- **Each leg is named `<repository> · <image>`.** Its job summary records the runner's CPU model and core count, since a slow leg can be the host's doing.
- **The run's summary has a table of its legs,** from the `Leg durations` job, on every run: each leg's result, its minutes and its HTML build's, its ceiling and its share of it, and the median of its last five green runs on `main`, with the change against it. A green leg over 80% of its ceiling gets a warning, since the next slow runner or added lecture would have it cancelled; so does one more than 50% and 15 minutes over its median, a jump. The median, not the previous run, because two legs of one run on identical inputs have taken 130 and 79 minutes. A warning fails nothing and files nothing. `scripts/leg-durations.sh` reads the ceilings from the matrix, and `validate-containers.yml` self-tests it on every harness run.
- **A retried leg** says so in the job summary. The first attempt's execution reports are the `reports-html-<image>-<repository>` artifact, and the retry's, if it failed too, `reports-html-retry-<image>-<repository>`.
- **A failed or cancelled run** that nobody started by hand opens a tracking issue, or comments on the open one, through `scripts/create-ci-failure-issue.sh`. A leg that hits its time limit concludes cancelled, not failed, so cancelled alerts too, which also files an issue for a run superseded by a newer image build.
