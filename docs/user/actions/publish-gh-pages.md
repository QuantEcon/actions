# publish-gh-pages

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Publishes a built site to the repository's GitHub Pages site, through GitHub's own Pages deploy: [configure-pages](https://github.com/actions/configure-pages), [upload-pages-artifact](https://github.com/actions/upload-pages-artifact) and [deploy-pages](https://github.com/actions/deploy-pages). The site goes to Pages as an artifact of the run, so there is no `gh-pages` branch, and the repository does not grow with every publish.

On a run triggered by a tag it can also attach the site to that tag's GitHub release, as an archive, its SHA-256 checksum and a manifest. Their format is described in [Release assets](#release-assets), and is a contract that other tools can rely on.

The publish can run in one job, or in up to three, one for each of its parts, chosen by `mode`:

| `mode` | What it does | Permissions the job needs |
|---|---|---|
| `all`, the default | the upload, the deploy, and the release assets with `create-release-assets: 'true'`, in one job | `pages: write` and `id-token: write`, and `contents: write` for release assets |
| `upload` | uploads `build-dir` as the run's `github-pages` artifact | none beyond `contents: read` for `actions/checkout` |
| `deploy` | deploys the `github-pages` artifact that an earlier job's `upload` made | `pages: write` and `id-token: write` |
| `release` | attaches `build-dir` to the tag's release | `contents: write` |

Building the lectures runs code the repository does not fully control: notebook cells, packages installed at build time, and network fetches. Code that runs earlier in a job can reach anything the job holds. So run `upload` at the end of the build job, which then needs only read access, and `deploy` in a job of its own that runs nothing else, as [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) does: see [A build job and a deploy job](#a-build-job-and-a-deploy-job). The split does not protect the site's content, which the build produces either way. It keeps the Pages permissions, and the OIDC token they come with, away from code that runs at build time.

## When to use it

Use it to publish a public site, after [`build-lectures`](build-lectures.md), as [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) does for each push to `main`.

- **Not for pull requests.** [`preview-netlify`](preview-netlify.md) or [`preview-cloudflare`](preview-cloudflare.md) gives each pull request a preview of its own.
- **Not for a site only members may see.** Every GitHub Pages site is public, unless the organisation is on GitHub Enterprise Cloud. [`deploy-cloudflare`](deploy-cloudflare.md) publishes behind a login instead.

## Requirements

- **Runner.** Any. A `deploy` or `release` job needs no container, and no GPU where the build needs one.
- **Node.** None.
- **Permissions.** As the table above gives them for each `mode`. With `mode: all`, the job needs `pages: write` and `id-token: write` for the deploy, and `contents: read` for `actions/checkout`, or `contents: write` with `create-release-assets: 'true'`, for the release.
- **Secrets.** None. The deploy authenticates with the job's own token and its OIDC token, and the release upload with the `github-token` you pass, which can be the job's own `GITHUB_TOKEN`.
- **Files in your repository.** None beyond the built site.
- **Repository settings.**
  - Under **Settings**, **Pages**, set **Source** to **GitHub Actions**, not **Deploy from a branch**.
  - Run the job that deploys, with `mode: all` or `deploy`, in the `github-pages` environment, with `environment: github-pages`, as the templates do. The environment's protection rules decide which branches and tags may deploy, and by default only the default branch may.
  - A custom domain is set under **Settings**, **Pages**, **Custom domain**; see [Custom domain](#custom-domain).
- **Setup outside GitHub.** Only for a custom domain: its DNS records, at the domain's provider.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from publish-gh-pages/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `mode` | no | `all` | Which part of the publish this step does. `all`, the default, does all of it in one job: the upload, the deploy, and the release assets when `create-release-assets` is `'true'`. The other three split it across jobs, so that only the job that deploys holds the Pages permissions. `upload` uploads `build-dir` as the run's `github-pages` artifact, and needs no permission beyond `contents: read`. `deploy` deploys the `github-pages` artifact an earlier job's `upload` made, takes no `build-dir` or `cname`, and needs `pages: write` and `id-token: write`. `release` makes the release assets from `build-dir`, whatever `create-release-assets` says, and needs `contents: write`. Any other value fails the job, as does `create-release-assets: 'true'` with `upload` or `deploy`. |
| `build-dir` | no | `''` | The directory that holds the built site, such as `_build/html`, which `build-lectures` gives in its `build-path` output. Required in every `mode` but `deploy`, which fails if it is given. The job fails if it does not exist. |
| `cname` | no | `''` | A domain to write into `build-dir` as a `CNAME` file, which also lands in the release archive. It does not set the site's custom domain, and a warning says so: a GitHub Actions Pages deploy ignores `CNAME` files, so set the domain under Settings, Pages. Empty, the default, writes no file. `mode: deploy` fails if it is given. |
| `create-release-assets` | no | `false` | `'true'` also attaches the site to the GitHub release of the tag the run was triggered by, creating the release if there is none: an archive, its SHA-256 checksum and a manifest. It needs `github-token`, and a run triggered by a tag: any other run skips it, with a warning. `'false'`, the default, attaches nothing. It applies to `mode: all`; `mode: release` always makes them. |
| `asset-name` | no | `''` | With `create-release-assets: 'true'` or `mode: release`: the start of each asset's file name. Empty, the default, uses the repository's name followed by `-html`, as in `<repository>-html`. Only letters, digits, `.`, `_` and `-`: any other character fails the job before anything runs, in every mode, since a name with a backslash, say, would give a checksum file that `sha256sum --check` cannot read. |
| `github-token` | no | `''` | With `create-release-assets: 'true'` or `mode: release`: a token that can write the repository's releases, such as `secrets.GITHUB_TOKEN` in a job with `contents: write`. On a run triggered by a tag, the job fails if it is empty. The Pages deploy does not use it. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from publish-gh-pages/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `page-url` | The URL of the published site, as GitHub Pages reports it, such as `https://<owner>.github.io/<repository>/`, or the custom domain's. Set once the deploy succeeds, by `mode: all` or `deploy`. |
| `mode` | The `mode` the step ran in, set once the inputs have passed the action's checks. Empty when they did not, and then nothing was uploaded, deployed or released. |

<!-- END GENERATED -->

## Examples

### A build job and a deploy job

Publishes each push to `main`, one run at a time. The build job runs the notebooks with read access alone, and ends by uploading the site. The deploy job holds the Pages permissions and runs nothing but the deploy: no checkout, no container.

```yaml
name: Publish
on:
  push:
    branches: [main]

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    permissions:
      contents: read
      packages: read    # the image pull, as the templates grant it
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0   # each page's "Last changed" date comes from git log
          persist-credentials: false
      - uses: quantecon/actions/setup-environment@v0
      - uses: quantecon/actions/build-lectures@v0
        id: build
      - uses: quantecon/actions/publish-gh-pages@v0
        with:
          mode: upload
          build-dir: ${{ steps.build.outputs.build-path }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      pages: write      # the Pages deploy
      id-token: write   # the Pages deploy's OIDC token
    environment:
      name: github-pages
      url: ${{ steps.publish.outputs.page-url }}
    steps:
      - uses: quantecon/actions/publish-gh-pages@v0
        id: publish
        with:
          mode: deploy
```

`cancel-in-progress: false` lets a publish that has started finish, while a newer one waits its turn. The deploy job is skipped when the build fails.

### In one job

`mode: all`, the default, uploads and deploys in the same job, as the action did before it had `mode`. That job then holds the Pages permissions while it builds:

```yaml
- uses: quantecon/actions/publish-gh-pages@v0
  id: publish
  with:
    build-dir: ${{ steps.build.outputs.build-path }}
```

### With release assets

Publishes on each tag that starts with `publish`, and attaches the site to the tag's release from a third job, the only one with `contents: write`. In the workflow above, trigger on the tags:

```yaml
on:
  push:
    tags: ['publish*']
```

In the build job, upload the site for the release before the Pages upload, so that the release job gets the site as the build left it, hidden files and all:

```yaml
- uses: actions/upload-artifact@v7
  with:
    name: html
    path: ${{ steps.build.outputs.build-path }}
    include-hidden-files: true
    if-no-files-found: error
- uses: quantecon/actions/publish-gh-pages@v0
  with:
    mode: upload
    build-dir: ${{ steps.build.outputs.build-path }}
```

And add the release job:

```yaml
release-assets:
  needs: [build, deploy]
  runs-on: ubuntu-latest
  permissions:
    contents: write   # the release assets
  steps:
    - uses: actions/download-artifact@v8
      with:
        name: html
        path: _build/html
    - uses: quantecon/actions/publish-gh-pages@v0
      with:
        mode: release
        build-dir: _build/html
        github-token: ${{ secrets.GITHUB_TOKEN }}
```

The `github-pages` environment must also allow the tags to deploy: under **Settings**, **Environments**, **github-pages**, **Deployment branches and tags**, add the pattern `publish*`. A site that passes `cname` to the upload passes it to the release too, so that the archive holds the `CNAME` file. In one job, `create-release-assets: 'true'` and `github-token` with `mode: all`, and `contents: write` beside the Pages permissions, do the same.

### In the templates

[`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) publishes each push to `main`, and runs on manual dispatch too, as in [A build job and a deploy job](#a-build-job-and-a-deploy-job): its build job restores the build cache, builds the site and uploads it, and its deploy job deploys it. The release assets are there as comments: a hand-off step in the build job and a `release-assets` job, with the other changes a workflow needs before it can make them, a tag trigger and the tag pattern allowed in the `github-pages` environment.

## Behaviour

1. **Inputs.** Before anything else, the action checks that `mode` is `all`, `upload`, `deploy` or `release`; that `build-dir` is given in every mode but `deploy`, and that `deploy` is given neither `build-dir` nor `cname`; that `create-release-assets: 'true'` does not come with `upload` or `deploy`, whose jobs should not hold `contents: write`; and that `asset-name`, if given, holds only letters, digits, `.`, `_` and `-`. Any of these fails the job with nothing uploaded or deployed, and leaves the `mode` output empty.
2. **Checks**, in every mode but `deploy`. `build-dir` must exist. The action prints how many files it holds and its size.
3. **`cname`**, in every mode but `deploy`. When set, the domain is written to `<build-dir>/CNAME`, with a warning that the deploy ignores it.
4. **The upload**, with `all` or `upload`. upload-pages-artifact packs `build-dir` as the run's `github-pages` artifact. It leaves out files and directories whose names start with a dot, as it always has.
5. **The deploy**, with `all` or `deploy`. configure-pages reads the repository's Pages settings, and deploy-pages publishes the run's `github-pages` artifact and reports the URL in `page-url`. With `deploy`, that artifact comes from an earlier job's `upload`, in the same run, and a deploy with none fails.
6. **Release assets**, with `mode: all` and `create-release-assets: 'true'`, after the deploy, or with `mode: release`:
   - On a run not triggered by a tag, a warning says they are skipped, and the job carries on.
   - With `github-token` empty, the job fails.
   - Otherwise the action writes the three files in [Release assets](#release-assets), and uploads them with [action-gh-release](https://github.com/softprops/action-gh-release) to the tag's release. If the tag has no release, it creates one, named after the tag.
   - A tag whose name contains `/` fails here, after the site is live: the tag is part of the archive's file name, and the slash makes it a path that does not exist.
7. **Summary.** A "Deployment Summary" log group gives the page URL after a deploy, or says the site was uploaded for a later deploy, and gives the `CNAME` domain if any, and the release's URL if assets were uploaded.

The site is live before the release assets are made, with `mode: all` or a release job that `needs:` the deploy job, so a failure in making or uploading them leaves the new site published.

## Release assets

With `create-release-assets: 'true'` and `mode: all`, or with `mode: release`, a run triggered by the tag `<tag>` attaches three files to that tag's release, where `<asset-name>` is the `asset-name` input or, when that is empty, `<repository>-html`:

| File | Contents |
|---|---|
| `<asset-name>-<tag>.tar.gz` | The whole of `build-dir`, including any `CNAME` file, as a gzip-compressed tar whose paths are relative to `build-dir`, as in `./index.html`. |
| `<asset-name>-checksum.txt` | One line in `sha256sum`'s format: the archive's SHA-256 in hexadecimal, two spaces, and the archive's file name, with no directory. |
| `<asset-name>-manifest.json` | A JSON object that describes the archive, with the fields below. |

| Manifest field | Type | Value |
|---|---|---|
| `name` | string | `<asset-name>` |
| `tag` | string | `<tag>` |
| `commit` | string | The full SHA of the commit the run built, `GITHUB_SHA`. |
| `timestamp` | string | When the assets were made: ISO 8601 date and time to the second, with the UTC offset, as in `2026-09-28T10:04:05+00:00`. |
| `size_mb` | number | The disk space `build-dir` takes, in mebibytes, as `du -sm` reports it: a whole number, rounded up. |
| `file_count` | number | The number of files in `build-dir`. |
| `repository` | string | `<owner>/<repository>`. |

`size_mb` and `file_count` are measured before `cname` writes its `CNAME` file, which the archive then includes.

For example:

```json
{
  "name": "lecture-python-html",
  "tag": "publish-2026-09-28",
  "commit": "<the full commit SHA>",
  "timestamp": "2026-09-28T10:04:05+00:00",
  "size_mb": 164,
  "file_count": 1342,
  "repository": "<owner>/<repository>"
}
```

To check an archive, run `sha256sum` in the directory that holds both files:

```bash
sha256sum --check lecture-python-html-checksum.txt
```

This is the contract, and this repository's tests check each part of it on every change to the action. A release of this project that changes a file name, the archive's layout, the checksum's format, or a manifest field's name or meaning says so in its CHANGELOG entry. Read the manifest as JSON, and ignore any field you do not know, so that a field added later does no harm. The checksum's and the manifest's names do not carry the tag, so keep each release's files in a directory of their own. Tags must not contain `/`, as [Behaviour](#behaviour) explains.

## Custom domain

1. **Set the domain** under **Settings**, **Pages**, **Custom domain**. A GitHub Actions deploy reads it only from there, and ignores any `CNAME` file in the site, which is why `cname` has no effect on it.
2. **Point the domain's DNS at GitHub Pages**, at the domain's provider: for a subdomain such as `lectures.example.org`, a `CNAME` record pointing at `<owner>.github.io`. GitHub's [custom domain guide](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site) gives the records for an apex domain.
3. **Turn on Enforce HTTPS** in the same settings, once GitHub has issued the certificate, which can take a while after the DNS change.

## Moving from a `gh-pages` branch

A repository that publishes by pushing to a branch, with peaceiris/actions-gh-pages or a similar action, moves over in six steps:

1. Under **Settings**, **Pages**, change **Source** from **Deploy from a branch** to **GitHub Actions**.
2. Give the job `pages: write` and `id-token: write`, and run it in the `github-pages` environment. It no longer needs `contents: write`, unless it makes release assets.
3. If the workflow publishes on tags, allow their pattern in that environment, under **Settings**, **Environments**, **github-pages**, **Deployment branches and tags**. By default only the default branch may deploy.
4. Replace the deploy step with this action, passing only `build-dir`. The deploy needs no token.
5. Set the custom domain under **Settings**, **Pages**: a `CNAME` file in the site no longer applies.
6. Once the new deploy is live, delete the `gh-pages` branch, if you like, to shrink the repository.

[Migrating an existing repository](../getting-started.md#migrating-an-existing-repository) moves a whole lecture repository onto these actions, publishing included.

## Troubleshooting

**`mode […] must be all, upload, deploy or release`.** Give one of the four, in lowercase.

**`build-dir is required with mode: …`.** Every mode but `deploy` publishes from `build-dir`: pass `build-lectures`' `build-path` output.

**`mode: deploy deploys the github-pages artifact that an earlier job's mode: upload made, so it takes no build-dir or cname`.** Move `build-dir` and `cname` to the `upload` step in the build job. The deploy job publishes whatever that step uploaded.

**`create-release-assets does nothing with mode: …`.** Release assets need `contents: write`, which neither the build job nor the deploy job should hold. Make them in a job of their own with `mode: release`: see [With release assets](#with-release-assets).

**`asset-name […] must be letters, digits, '.', '_' and '-' only`.** Every asset's file name starts with `asset-name`, and a name with a backslash, say, would give a checksum file that `sha256sum --check` cannot read. Use a name such as `lecture-python-html`.

**`No artifacts named "github-pages" were found`, or similar, from deploy-pages.** With `mode: deploy`, nothing in this run uploaded the site. Check that the build job ends with `mode: upload`, and that the deploy job `needs:` it. An artifact from an earlier run, or from another workflow, is not used.

**`❌ Error: Build directory not found: …`.** `build-dir` is wrong, or the build did not run. Pass `build-lectures`' `build-path` output. In a release job, check the artifact's download `path`.

**`Get Pages site failed`, from configure-pages.** GitHub Pages is not enabled with the GitHub Actions source. Set **Settings**, **Pages**, **Source** to **GitHub Actions**.

**The deploy fails asking for `id-token: write`, or for `pages: write`.** A `permissions:` block drops every scope it does not list: add both, to the job that deploys.

**`Tag "…" is not allowed to deploy to github-pages due to environment protection rules`.** Allow the tag pattern under **Settings**, **Environments**, **github-pages**, **Deployment branches and tags**. A branch other than the default is refused the same way.

**`create-release-assets is enabled but this run was not triggered by a tag …; skipping release assets`, or `mode is release but …`.** Release assets need a tag trigger, such as `tags: ['publish*']` under `on.push`.

**`Cannot open: No such file or directory`, when making the release assets.** The tag's name contains `/`. Use a tag without one, such as `publish-2026-09-28`.

**`create-release-assets is enabled but 'github-token' is empty`.** Pass `github-token: ${{ secrets.GITHUB_TOKEN }}`.

**The release upload fails with `Resource not accessible by integration`, or a 403.** The job lacks `contents: write`.

**A warning that `cname has no effect on the GitHub Pages deployment`.** Set the domain under **Settings**, **Pages**, and drop `cname`, unless you want the `CNAME` file in the release archive.

**The site answers 404.** Check that the Pages source is **GitHub Actions**, and that `build-dir` has an `index.html` at its top. A new site can take a minute or two to appear.

**The custom domain does not resolve.** Check the DNS records, and allow for DNS to propagate, which can take up to a day. The domain must be set under **Settings**, **Pages**.

**`<input> must be a single line`.** Every input but `github-token` is one value, and a line break would end the line that prints it, and the runner reads a next line that starts with `::` as a workflow command. So the action fails in its first step, before it has done anything. A YAML block scalar (`|`), or an expression whose value spans lines, puts one there: write the value on one line. See [Security](../security.md#what-the-actions-themselves-do).
