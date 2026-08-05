# Tests

Home for this repo's test infrastructure. Today it holds the local scratch area; it exists as a named place so future test tooling has somewhere obvious to land instead of accumulating at the repo root.

See [TESTING.md](../TESTING.md) for the strategy and how to run things.

## What lives where

Test assets are currently spread across the repo, each next to what it tests. This table is the map — nothing has been moved.

| Location | What | Committed? |
|---|---|---|
| `.github/workflows/test-actions.yml` | The PR harness — 14 jobs exercising the cache, environment and build actions via `uses: ./` local paths (#100 stage 1) | yes |
| `.github/fixtures/mini-lectures/` | Fixture for the harness: a two-page book with a real executed code cell, so builds populate a genuine `_build/.jupyter_cache` | yes |
| `containers/quantecon/tests/` | Container smoke tests and their minimal book | yes |
| `tests/local/` | Throwaway clones of real lecture repos, for manual testing | **no** — git-ignored |
| [`QuantEcon/test-actions-lecture-intro`](https://github.com/QuantEcon/test-actions-lecture-intro) | The canary repo (#100 stage 2). Pinned `@v0`, so it exercises `publish-gh-pages` and `preview-netlify` — neither is testable in this repo | separate repo |

## `tests/local/`

Git-ignored. Clone real lecture repos here when you want to test against something larger than the committed fixture:

```bash
# from the repo root
git clone https://github.com/QuantEcon/lecture-python-intro.git tests/local/lecture-python-intro
```

Nothing in CI reads this directory — it exists only in your working tree.

Put local clones **here** rather than at the repo root. A root-level `test-lecture-python-intro/` shadowed the canary repo's old name closely enough that the two were repeatedly confused, including in the PR that wrote this file. A path under `tests/local/` cannot collide with a repo name.

## Adding test infrastructure

Fixtures that a workflow consumes should stay next to that workflow (`.github/fixtures/`, `containers/*/tests/`) so the `paths:` filters keep working. Use `tests/` for tooling that spans more than one of them — a shared harness runner, cross-action integration scripts, or fixture-generation tooling.
