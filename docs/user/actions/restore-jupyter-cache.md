# restore-jupyter-cache

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Restores a cache that [`build-jupyter-cache`](build-jupyter-cache.md) saved, before a build, so the build starts from the last cache build instead of from nothing. Jupyter Book then re-executes only the notebooks whose code has changed, which is where most of a lecture build's time goes. That needs the book to execute its notebooks through that cache, with `execute_notebooks: cache` in its `_config.yml`.

It restores one of two caches, chosen with `cache-type`:

- **`build`**, the default: the whole `_build` directory, as the cache build left it. That is the HTML and the execution cache, and the PDF and notebooks if the cache build made them.
- **`execution`**: only `_build/.jupyter_cache`, which holds each notebook's executed outputs. It is much smaller, and saves the execution time, but not the rest of the build.

By default it only restores. With `save-cache: 'true'` it also saves a cache at the end of the job, which, saved from a pull request's run, only that pull request's later runs can restore.

## When to use it

Use it in a job that builds lectures, after `setup-environment` and before [`build-lectures`](build-lectures.md): in the pull-request builds of [`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml), and in the publish builds of [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml).

- **Not in the cache build itself.** `build-jupyter-cache` builds from scratch on purpose; see its chapter.
- **Once per job.** Every `build-lectures` step after it builds on the restored `_build`.

## Requirements

- **Runner.** Any runner or container with `bash`. A job on Windows never finds a cache saved on Linux, since `actions/cache` keeps the two apart.
- **Node.** None.
- **Permissions.** None: restoring and saving a cache need no `permissions:`. The job needs `contents: read` for `actions/checkout`.
- **Secrets.** None.
- **Files in your repository.** A `_config.yml` whose `execute:` section sets `execute_notebooks: cache`. With Jupyter Book's default, `auto`, notebooks are executed without jupyter-cache, so there is no execution cache to save or restore. For the build cache's key, the same `environment` file that `build-jupyter-cache` was given.
- **A cache to restore.** `build-jupyter-cache` must have succeeded on the default branch, or on the branch a pull request targets. GitHub removes a cache that goes 7 days without being restored, and the least recently used caches first when the repository's cache storage is full.
- **Setup outside GitHub.** None.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from restore-jupyter-cache/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `cache-type` | no | `build` | What to restore. `build`, the default, restores the whole `_build` directory the last cache build saved: its HTML, PDF and notebooks, and the execution cache in `_build/.jupyter_cache`. `execution` restores only `_build/.jupyter_cache`, which holds each notebook's executed outputs. |
| `path` | no | `_build` | The build directory to restore into. The path is part of what identifies a cache, so only `_build`, the default, finds the caches that `build-jupyter-cache` saves; any other path finds only what this action saved with `save-cache` and the same `path`. With `cache-type: execution` the cache goes into `<path>/.jupyter_cache`. |
| `source-dir` | no | `lectures` | With `cache-type: execution`: the book's directory. The key hashes every `.md` file under it, as `build-jupyter-cache` does with its own `source-dir`. Ignored for the build cache. |
| `environment` | no | `environment.yml` | With `cache-type: build`: the Conda environment file whose hash is part of the key. Give the same file that `build-jupyter-cache` was given, or no cache matches. Ignored for the execution cache. |
| `environment-update` | no | `''` | With `cache-type: build`: the container delta file whose hash is part of the key. Give the same file that `build-jupyter-cache` was given; with another, only the fallback matches, restoring the newest cache built from the same `environment`. Ignored for the execution cache. |
| `key` | no | `''` | A key to restore in place of the generated ones. It is matched as a prefix, so the newest cache whose key starts with it is restored. With `save-cache: 'true'` the cache is saved under exactly this key, and only once: a cache is never overwritten, and a later run that matches the key exactly saves nothing. Empty, the default, uses the generated keys. |
| `fail-on-miss` | no | `false` | `'true'` fails the job when nothing is restored. `'false'`, the default, carries on without a cache, and the build starts from scratch. |
| `save-cache` | no | `false` | `'true'` also saves the directory at the end of the job, if the job succeeds and its key did not match exactly. Saved from a pull request's run, the cache can be restored only by that pull request's later runs; saved from a run on a branch, it reaches every pull request that targets the branch. So use it in pull-request builds only. `'false'`, the default, only restores. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from restore-jupyter-cache/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `cache-hit` | `'true'` when a cache was restored, whether its key matched exactly or only as a prefix; `'false'` when nothing was restored. Always set. Unlike the `actions/cache` output of the same name, it counts a prefix match, which is how a read-only restore with the generated keys always matches. |
| `cache-key` | The key of the cache that was restored: a saved key such as `build-<hash>-<hash>-<run id>`, not the prefix that found it. Empty when nothing was restored. |

<!-- END GENERATED -->

## Examples

### Minimal

A pull-request build in a container that starts from the build cache:

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
      packages: read   # the image pull, as the templates grant it
    steps:
      - uses: actions/checkout@v7
      - uses: quantecon/actions/setup-environment@v0
      - uses: quantecon/actions/restore-jupyter-cache@v0
      - uses: quantecon/actions/build-lectures@v0
```

### Saving for later runs of a pull request

```yaml
- uses: quantecon/actions/restore-jupyter-cache@v0
  with:
    save-cache: 'true'
```

At the end of a successful job, `_build` is saved under a key that ends in the run id. The pull request's later runs restore it, so each one re-executes only what changed since its previous run, not since the last cache build.

- **Only in pull-request builds.** Saved from a pull request's run, the cache is visible only to that pull request's later runs. Saved from a run on a branch, as in `publish.yml`, it would reach every pull request that targets the branch, and as the newest match it would win over the cache build's.
- **One save per run.** A re-run of the job, or a second job in the same run, finds this run's own key as an exact match, and saves nothing.
- **Storage.** Each run saves a whole `_build`, and GitHub removes the least recently used caches when the repository's cache storage is full.

### Only the execution cache

```yaml
- uses: quantecon/actions/restore-jupyter-cache@v0
  with:
    cache-type: execution
```

### Requiring a cache

```yaml
- uses: quantecon/actions/restore-jupyter-cache@v0
  with:
    fail-on-miss: 'true'
```

The job fails when no cache is found, for a build that would take too long without one.

### In the templates

[`ci.yml`](https://github.com/QuantEcon/actions/blob/main/templates/ci.yml) restores the build cache before a pull request's build, with `save-cache` and `fail-on-miss` as comments. [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) restores it before the build it publishes. Both restore what [`cache.yml`](https://github.com/QuantEcon/actions/blob/main/templates/cache.yml) saves.

## Behaviour

### Keys

The action looks up a key, and then a fallback:

| `cache-type` | Restored to | Key | Fallback |
|---|---|---|---|
| `build` | `<path>` | `build-<hash of environment>-<hash of environment-update>-` | `build-<hash of environment>-` |
| `execution` | `<path>/.jupyter_cache` | `jupyter-cache-<hash of the .md files under source-dir>-` | `jupyter-cache-` |

`build-jupyter-cache` saves its caches under the same prefixes, followed by its run id. A file that does not exist hashes to an empty string. With `save-cache: 'true'` the key ends in this run's id instead, and is the one the cache is saved under. With `key` set, that key is both the key and the only fallback.

GitHub looks first among the caches of the branch or pull request the job runs for, trying the key and then the fallback, and then the same among the caches of the base and default branches. For each, an exact match wins, and otherwise the newest cache whose key starts with it is restored. So a pull request that has saved its own cache restores that one, even when a newer cache build has run since.

### Why the keys are what they are

- **The build cache never falls back across `environment` files.** `_build` does not record the packages that produced it. Restored after a change to the environment file, it would hand the build pages and outputs made with the old packages. An edited environment file is a miss on purpose, and the build starts from scratch. The fallback does cross `environment-update` files, and neither key records the container image, so a job on a newer image restores a `_build` made on the old one.
- **The execution cache does fall back to any execution cache.** Jupyter Book checks each cached notebook against the notebook's current code, and re-executes any that no longer match, so a cache made from other lectures is safe as far as the code goes. It does not check the packages: the key hashes only the lectures, so after a change to the environment the execution cache hands back outputs made with the old packages, until the next cache build replaces it.
- **The build cache's key does not hash the lectures.** The key is the same for every pull request, so every pull request restores the last cache build and re-executes only its own changes. A key that hashed the lectures would change with every edit, and miss on nearly every pull request. The cost is that a lecture removed since the last cache build keeps its old pages, which nothing links to, until the next cache build replaces `_build`.

### Status report

The action prints what it asked for and what it found. On a typical read-only restore of the build cache:

```text
╔════════════════════════════════════════════════════════════════╗
║                    BUILD CACHE STATUS                          ║
╚════════════════════════════════════════════════════════════════╝

  Cache Type:     build
  Requested Key:  build-<hash of environment>--
  Cache Hit:      false (exact key match)
  Matched Key:    build-<hash of environment>--<run id>
  Save Cache:     false

════════════════════════════════════════════════════════════════════
  ✅ Cache restored successfully
════════════════════════════════════════════════════════════════════
```

`Cache Hit` is `actions/cache`'s exact-match flag, which a read-only restore with the generated keys never sets; `Matched Key` shows what was restored, and the action's own `cache-hit` output is `'true'`. A collapsed "Cache Contents" group follows, with the size of the cache and of each directory in it. On a miss, the report says so, and the build carries on from nothing.

## Troubleshooting

**`No cache found`.** In order of likelihood:

- The pull request changes the environment file. That is a miss on purpose: the build runs from scratch, and the cache build after the merge saves a new cache.
- The default branch has no cache: the cache build has not succeeded yet, or GitHub has removed its cache, after 7 days without a restore or to make room. Run the cache workflow by hand, for example with `gh workflow run cache.yml`.
- `environment` differs from what `build-jupyter-cache` was given, or `path` is not `_build`.
- The cache build and this job compress differently. `actions/cache` compresses with `zstd` where it is installed and with `gzip` where it is not, and finds only caches made the same way. Run both jobs in the same image, or both on the runner.

**`Cache miss with fail-on-miss enabled`.** As above; the job failed because `fail-on-miss` is `'true'`.

**The site shows pages of a lecture that was removed.** They come from the build cache, and the next cache build clears them. To clear them now, run the cache workflow by hand.

**The restored build is broken.** Delete the repository's `build-` caches on the Caches page of its Actions tab, then run the cache workflow.
