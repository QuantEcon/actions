# quantecon

The full QuantEcon container image, `ghcr.io/quantecon/quantecon`: Ubuntu 24.04, TeX Live, and a Conda environment built from the `anaconda` metapackage, with Jupyter Book and the extensions the lectures use. Its recipe is this directory's [`Dockerfile`](Dockerfile) and [`environment.yml`](environment.yml), and [`tests/`](tests/) holds the smoke test that runs in both images.

- Using it: [Containers](../../docs/user/containers.md), in the user manual.
- Building, testing and updating it: [CONTAINERS.md](../../docs/dev/CONTAINERS.md), in the developer docs.
