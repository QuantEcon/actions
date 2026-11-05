# quantecon-build

The lean QuantEcon container image, `ghcr.io/quantecon/quantecon-build`: Ubuntu 24.04, TeX Live, and a Conda environment of an explicit package list pinned to the same Anaconda baseline as the full image, with Jupyter Book and the extensions the lectures use. Its recipe is this directory's [`Dockerfile`](Dockerfile) and [`environment.yml`](environment.yml).

- Using it: [Containers](../../docs/user/containers.md), in the user manual.
- Building, testing and updating it: [CONTAINERS.md](../../docs/dev/CONTAINERS.md), in the developer docs.
