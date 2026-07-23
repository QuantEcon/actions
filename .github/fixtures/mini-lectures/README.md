# mini-lectures fixture

A deliberately tiny lecture repository consumed by the action-level PR harness
([`.github/workflows/test-actions.yml`](../../workflows/test-actions.yml), issue #100).

It differs from `containers/quantecon/tests/minimal-jupyter-book` in one
important way: **it executes a real code cell** (`execute_notebooks: cache`), so
building it produces a genuine `_build/.jupyter_cache` — the artifact the cache
actions exist to save and restore. The container fixture builds with execution
off and cannot exercise that path.

The harness copies this directory into the workspace at run time and appends a
per-run salt (run id + attempt) to `environment.yml` and `lectures/`, so every
run derives unique cache keys and a "cache miss" assertion can never be
polluted by a previous run's caches.

The environment is intentionally minimal — Python plus `jupyter-book` — because
the harness tests **action logic**, not the science stack. The full-stack
fixture (plotly, matplotlib, `quantecon_book_theme`, xelatex) belongs to the
post-release canary repo proposed in #100, which runs on the real containers.
