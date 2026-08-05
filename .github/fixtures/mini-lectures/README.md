# mini-lectures fixture

A deliberately tiny lecture repository consumed by the action-level PR harness
([`.github/workflows/test-actions.yml`](../../workflows/test-actions.yml), issue #100).

Both this and `containers/quantecon/tests/minimal-jupyter-book` execute real
code cells, but they test different things and should stay separate:

| | this fixture | the container fixture |
|---|---|---|
| Tests | **action logic** on hosted runners | **image contents** in a container job |
| Environment | minimal — Python + `jupyter-book` | whatever the image ships |
| Execution mode | `cache`, so `_build/.jupyter_cache` is genuinely populated | `force` + `raise_on_error` |
| Optimised for | a fast conda solve | exercising numpy/scipy/pandas/matplotlib and the kaleido→chromium path |

Merging them would make this one slow (a full science stack to solve on every
harness job) and that one blind to the cache artifact.

The harness copies this directory into the workspace at run time and appends a
per-run salt (run id + attempt) to `environment.yml` and `lectures/`, so every
run derives unique cache keys and a "cache miss" assertion can never be
polluted by a previous run's caches.

The environment is intentionally minimal — Python plus `jupyter-book` — because
the harness tests **action logic**, not the science stack. The full-stack
fixture (plotly, matplotlib, `quantecon_book_theme`, xelatex) belongs to the
post-release canary repo proposed in #100, which runs on the real containers.
