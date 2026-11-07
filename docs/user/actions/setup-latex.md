# setup-latex

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Installs TeX Live, or any apt packages you list, on a standard Ubuntu runner, and keeps the downloaded packages in the repository's Actions cache. A plain `apt-get install` downloads TeX Live from the Ubuntu mirror the runner is given on every run, a gigabyte or more, and a slow mirror can stall that for hours without ever failing. With the cache, a run on the same runner image installs from the cache and contacts no mirror at all.

It caches the downloaded `.deb` archives, not the installed files, so dpkg still runs every package's maintainer scripts and triggers, TeX Live's `mktexlsr`, `updmap-sys` and `fmtutil` among them: what it installs is what `apt-get install` of the same list installs. Each run ends in one of three ways, which the `cache-hit` output reports:

- **An exact hit:** the cache holds the archives of every package the list needs on this host. They are installed with no `apt-get update` and no download.
- **A fallback restore:** the cache holds archives for this list, or another, from a host with different packages installed, such as an older runner image. apt downloads only the packages they lack.
- **A miss:** nothing in the cache, so every package is downloaded, as without the action.

## When to use it

Use it in a job on a standard runner that needs LaTeX, in place of an inline `sudo apt-get install texlive-…` step. It is one step, and takes the same list.

- **Not needed in a QuantEcon container.** The images carry TeX Live, and the action installs nothing when it finds the container marker file, `/etc/quantecon-container`. So the same step works in a job that moves between a container and a standard runner.
- **With `setup-environment`.** Its [`install-latex`](setup-environment.md) input installs a list from a file the same way, through the same script and cache, with the download limit fixed at 30 minutes. A job needs one or the other, not both.
- **Prefer a container** where you can: the [`setup-environment` chapter](setup-environment.md#when-to-use-it) says why.

## Requirements

- **Runner.** A GitHub-hosted Ubuntu runner, or any apt-based Linux host where the job runs as root or has passwordless `sudo`. In a QuantEcon container, or on a host with the marker file, the action installs nothing.
- **Node.** None.
- **Permissions.** None: `actions/cache` uses the runner's own cache token, not `GITHUB_TOKEN`.
- **Secrets.** None.
- **Files in your repository.** None if you list the packages in `packages`. With `requirements-file`, that file: the [example list](https://github.com/QuantEcon/actions/blob/main/templates/latex-requirements.txt) in `templates/` names the TeX packages the two images have in common, and is the place to start.
- **Setup outside GitHub.** None. The cache counts against the repository's Actions cache storage, 10 GB by default: about 1.1 GB for the standard list below, and 1.4 GB with `latex-cjk-all`.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from setup-latex/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `packages` | no | `''` | The apt packages to install, separated by spaces or newlines, where `#` starts a comment anywhere on a line. Each is a package name, optionally followed by `:<arch>`, and by `=<version>` or `/<release>`. Set this or `requirements-file`, not both. |
| `requirements-file` | no | `''` | Path to a file listing the apt packages to install, in the format `packages` takes, such as the `latex-requirements.txt` that `setup-environment` reads. Set this or `packages`, not both. The job fails if the file is missing or names no package. |
| `cache-version` | no | `v1` | Part of the cache key and of its `restore-keys` fallback, so a cache is only ever restored within one version. Changing it (say `v1` to `v2`) makes the next run download every package afresh. Letters, digits, `.` and `_` only, so that no version's key starts with another's. |
| `download-timeout-minutes` | no | `30` | On a run that downloads packages, the most minutes `apt-get update` and the download may take together before the job fails. `'0'` sets no limit. The install that follows is never limited, since stopping dpkg part-way would leave the runner's packages broken. Ignored on an exact cache hit, which downloads nothing. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from setup-latex/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `cache-hit` | `'true'` when the downloaded packages were restored from an exact cache-key match, and so installed with no `apt-get update` and no download; `'false'` when only the `restore-keys` fallback matched, after which the packages the cache lacked were downloaded; empty on a cache miss, and in a QuantEcon container, where the action installs nothing. Test it with `== 'true'`. |

<!-- END GENERATED -->

## Examples

### Minimal

```yaml
name: Build PDF
on:
  pull_request:

jobs:
  pdf:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v7
      - uses: quantecon/actions/setup-latex@v0
        with:
          packages: texlive-latex-recommended texlive-latex-extra latexmk
      - name: Check pdflatex
        run: pdflatex --version
```

### Moving from an inline `apt-get` step

Most lecture repositories install TeX Live with a step like this:

```yaml
- name: Install latex dependencies
  run: |
    sudo apt-get -qq update
    sudo apt-get install -y     \
      texlive-latex-recommended \
      texlive-latex-extra       \
      texlive-fonts-recommended \
      texlive-fonts-extra       \
      texlive-xetex             \
      latexmk                   \
      xindy                     \
      dvipng                    \
      cm-super
```

The same list, as one step. The packages may be on one line or several, and `#` starts a comment:

```yaml
- name: Install latex dependencies
  uses: quantecon/actions/setup-latex@v0
  with:
    packages: |
      texlive-latex-recommended texlive-latex-extra
      texlive-fonts-recommended texlive-fonts-extra
      texlive-xetex latexmk xindy dvipng cm-super
      latex-cjk-all   # the Chinese editions' CJK support
```

Repeat it in each workflow that builds the PDF (often `ci.yml`, `cache.yml` and `publish.yml`). They share one cache, since the key depends on the list and the runner, not the workflow.

### From a file

To keep one list for every workflow, put it in a file, in the format of the [example list](https://github.com/QuantEcon/actions/blob/main/templates/latex-requirements.txt):

```yaml
- uses: actions/checkout@v7
- uses: quantecon/actions/setup-latex@v0
  with:
    requirements-file: latex-requirements.txt
```

### In the templates

The [workflow templates](https://github.com/QuantEcon/actions/tree/main/templates) build in a container, which has TeX Live, so they do not use this action.

## Behaviour

1. **The inputs are checked first.** Exactly one of `packages` and `requirements-file` must be set, the list must name at least one package, and every entry must be an apt package name. Anything else fails the job before anything is installed. In a QuantEcon container the action stops after this check.
2. **The cache is restored** with [actions/cache](https://github.com/actions/cache), from `/var/cache/quantecon-actions/latex-apt`:

   | Match | Cache key |
   |---|---|
   | Exact | `latex-apt-<os>-<arch>-<cache-version>-<hash of the list>-<hash of the installed packages>` |
   | Fallback, the same list | `latex-apt-<os>-<arch>-<cache-version>-<hash of the list>-` |
   | Fallback, any list | `latex-apt-<os>-<arch>-<cache-version>-` |

   `<os>` is the release, such as `ubuntu-26.04`, and `<arch>` the dpkg architecture, so a cache never crosses either. The list is hashed sorted, so its order does not matter. The last part hashes every package installed on the host, at its version. The archives a run downloads are the packages its host lacked, so a host with the same packages installed needs exactly those archives. That makes an exact hit complete: a new runner image, or an earlier step in the job that installed something, changes the key.
3. **On an exact hit,** the restored archives are installed as local files: no `apt-get update`, and no download. If apt would still need a package they lack, which the key should rule out, a warning says so and the run continues as on a miss.
4. **On a fallback restore or a miss,** `apt-get update` runs, then the list is downloaded into the cache directory, where apt reuses every restored archive whose version still matches and downloads the rest. The list is then installed from there. The archives of packages that are not now installed at their version, or that the host already had, are removed, so the cache holds exactly what this host needed.
5. **The cache is saved** straight after the install, under the exact key, so a later step's failure still keeps it. Nothing is saved after an exact hit, when the host already had every package (no archive was needed), or on a run for a tag: a tag's cache could only be restored by a run of the same tag.
6. **The log** ends with the installed `pdflatex` version, when there is one.

**Where caches are shared.** A run can restore caches saved on its own branch and on the default branch, so caches reach other branches through the default branch. A pull request saves into its own scope, so its later pushes reuse it, and its first run on a new runner image falls back to the default branch's cache, downloading only what changed. A repository that builds the PDF only on pull requests and tags has no cache on its default branch, so each new pull request starts cold. A scheduled or dispatched run on the default branch, such as a weekly `cache.yml`, gives every pull request a cache to fall back on.

**Versions.** A miss installs what `apt-get install` installs today. An exact hit installs the versions of the run that made the cache. The key changes with the runner image, so those are never older than the image's own packages.

**Trust.** On a hit, the archives come from the repository's own Actions cache and are installed as root, without the signature check apt makes when it downloads them. That is the trust `setup-environment`'s Conda cache already has. A pull request from a fork cannot write to the default branch's cache, and on a GitHub-hosted runner the job can already run anything as root through `sudo`.

### The download timeout

`download-timeout-minutes` covers `apt-get update` and the download together, on a run that downloads, and fails the job when they run past it. The install that follows is not covered: stopping dpkg part-way would leave the runner's packages broken. GitHub's 26.04 runner image already fails over to another mirror when one stops answering for 15 seconds, but not when one answers slowly, and a slow mirror is what stalls a build.

The standard list above is about 1.1 GB, and 1.4 GB with `latex-cjk-all`. It normally downloads in under a minute. In QuantEcon's lecture repositories, about one download in twenty takes over five minutes, and the slowest have run for two to six hours, at 60 to 700 kB/s. The default of 30 minutes fails a download slower than about 0.75 MB/s for 1.35 GB, which would also have failed most of those slow runs.

- **Keep the default** in most jobs. With the cache, a full download happens only on a miss: about once per runner image, or when the list changes. A fallback restore downloads only the packages that changed.
- **Lower it,** say to `10`, where a quick failure and a re-run beat a wait, such as a pull request's checks.
- **Raise it, or set `'0'`,** where finishing late is better than failing, such as a scheduled run that nobody is watching. With `'0'` a stalled download runs until the job's own limit, six hours by default.

### What fails the job

- Neither or both of `packages` and `requirements-file` set, a missing file, a list that names no package, or an entry that is not an apt package name.
- A `cache-version` with anything but letters, digits, `.` and `_`, or a `download-timeout-minutes` that is not a whole number.
- A host without apt.
- A failing `apt-get update` or `apt-get install`, or a download that runs past `download-timeout-minutes`.

A failed save does not fail the job: `actions/cache` reports it as a warning.

## Troubleshooting

**`Set one of packages and requirements-file: there is no default list of packages`, or `Set packages or requirements-file, not both`.** Give the list one way: in `packages`, or in a file named by `requirements-file`.

**`requirements-file is '…', but there is no such file …`.** The path is relative to the repository root, and `actions/checkout` must run first.

**`… names no package: it holds only comments or blank lines`.** Add the packages, starting from the [example list](https://github.com/QuantEcon/actions/blob/main/templates/latex-requirements.txt).

**`…: '…' is not an apt package name …`.** Each entry is one package name, in lowercase, optionally with `:<arch>`, and `=<version>` or `/<release>`. Options such as `--no-install-recommends` cannot be passed.

**`The package download did not finish within … minutes, so it was stopped …`.** The mirror the runner was given is slow. Re-run the job. If it keeps happening, raise `download-timeout-minutes`; see [The download timeout](#the-download-timeout).

**`apt-get is not on PATH: installing LaTeX this way needs an apt-based runner …`.** The job runs on macOS, Windows or a Linux without apt. Use an Ubuntu runner, or a QuantEcon container.

**A warning that `The cached archives for this key do not cover the package list …`.** The run went on to download as on a miss, so the job is unaffected. If it repeats, change `cache-version` and say so in an issue.

**`cache-hit` is never `'true'`.** The key changes with the runner image, about weekly, and with anything installed before this step. Move the step before other `apt-get install` steps. A run for a tag never saves, and a pull request's first run restores the default branch's cache through the fallback; the log of the step says which.

**The installed packages are broken.** Change `cache-version`, say from `v1` to `v2`. No cache from another version is restored, so the next run downloads everything afresh. Deleting the repository's `latex-apt-` caches, on the Caches page of its Actions tab, does the same.

**`<input> must be a single line`.** `requirements-file`, `cache-version` and `download-timeout-minutes` are each one value, and a line break would end the line that prints it, and the runner reads a next line that starts with `::` as a workflow command. So the action fails in its first step, before it has done anything. `packages` may span lines. See [Security](../security.md#what-the-actions-themselves-do).
