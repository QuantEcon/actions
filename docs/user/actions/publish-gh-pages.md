# publish-gh-pages

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Publishes a built site to the repository's GitHub Pages site, through GitHub's own Pages deploy: [configure-pages](https://github.com/actions/configure-pages), [upload-pages-artifact](https://github.com/actions/upload-pages-artifact) and [deploy-pages](https://github.com/actions/deploy-pages). The site goes to Pages as an artifact of the run, so there is no `gh-pages` branch, and the repository does not grow with every publish.

On a run triggered by a tag it can also attach the site to that tag's GitHub release, as an archive, its SHA-256 checksum and a manifest. Their format is described in [Release assets](#release-assets), and is a contract that other tools can rely on.

## When to use it

Use it to publish a public site, after [`build-lectures`](build-lectures.md), as [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) does for each push to `main`.

- **Not for pull requests.** [`preview-netlify`](preview-netlify.md) or [`preview-cloudflare`](preview-cloudflare.md) gives each pull request a preview of its own.
- **Not for a site only members may see.** Every GitHub Pages site is public, unless the organisation is on GitHub Enterprise Cloud. [`deploy-cloudflare`](deploy-cloudflare.md) publishes behind a login instead.

## Requirements

- **Runner.** Any.
- **Node.** None.
- **Permissions.** `pages: write` and `id-token: write`, for the deploy. The job also needs `contents: read` for `actions/checkout`, or `contents: write` with `create-release-assets: 'true'`, for the release.
- **Secrets.** None. The deploy authenticates with the job's OIDC token, and the release upload with the `github-token` you pass, which can be the job's own `GITHUB_TOKEN`.
- **Files in your repository.** None beyond the built site.
- **Repository settings.**
  - Under **Settings**, **Pages**, set **Source** to **GitHub Actions**, not **Deploy from a branch**.
  - Run the job in the `github-pages` environment, with `environment: github-pages`, as the templates do. The environment's protection rules decide which branches and tags may deploy, and by default only the default branch may.
  - A custom domain is set under **Settings**, **Pages**, **Custom domain**; see [Custom domain](#custom-domain).
- **Setup outside GitHub.** Only for a custom domain: its DNS records, at the domain's provider.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from publish-gh-pages/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `build-dir` | yes | none | The directory that holds the built site, such as `_build/html`, which `build-lectures` gives in its `build-path` output. The job fails if it does not exist. |
| `cname` | no | `''` | A domain to write into `build-dir` as a `CNAME` file, which also lands in the release archive. It does not set the site's custom domain, and a warning says so: a GitHub Actions Pages deploy ignores `CNAME` files, so set the domain under Settings, Pages. Empty, the default, writes no file. |
| `create-release-assets` | no | `false` | `'true'` also attaches the site to the GitHub release of the tag the run was triggered by, creating the release if there is none: an archive, its SHA-256 checksum and a manifest. It needs `github-token`, and a run triggered by a tag: any other run skips it, with a warning. `'false'`, the default, attaches nothing. |
| `asset-name` | no | `''` | With `create-release-assets: 'true'`: the start of each asset's file name. Empty, the default, uses the repository's name followed by `-html`, as in `<repository>-html`. |
| `github-token` | no | `''` | With `create-release-assets: 'true'`: a token that can write the repository's releases, such as `secrets.GITHUB_TOKEN` in a job with `contents: write`. The job fails if it is empty. The Pages deploy does not use it. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from publish-gh-pages/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `page-url` | The URL of the published site, as GitHub Pages reports it: `https://<owner>.github.io/<repository>/`, or the custom domain's. Set once the deploy succeeds. |

<!-- END GENERATED -->

## Examples

### Minimal

Publishes each push to `main`, one run at a time:

```yaml
name: Publish
on:
  push:
    branches: [main]

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  publish:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    permissions:
      contents: read
      pages: write      # the Pages deploy
      id-token: write   # the Pages deploy's OIDC token
      packages: read    # the image pull, as the templates grant it
    environment:
      name: github-pages
      url: ${{ steps.publish.outputs.page-url }}
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0   # each page's "Last changed" date comes from git log
      - uses: quantecon/actions/setup-environment@v0
      - uses: quantecon/actions/build-lectures@v0
        id: build
      - uses: quantecon/actions/publish-gh-pages@v0
        id: publish
        with:
          build-dir: ${{ steps.build.outputs.build-path }}
```

`cancel-in-progress: false` lets a publish that has started finish, while a newer one waits its turn.

### With release assets

Publishes on each tag that starts with `publish`, and attaches the site to the tag's release:

```yaml
name: Publish
on:
  push:
    tags: ['publish*']

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  publish:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
    permissions:
      contents: write   # the release assets
      pages: write
      id-token: write
      packages: read
    environment:
      name: github-pages
      url: ${{ steps.publish.outputs.page-url }}
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: quantecon/actions/setup-environment@v0
      - uses: quantecon/actions/build-lectures@v0
        id: build
      - uses: quantecon/actions/publish-gh-pages@v0
        id: publish
        with:
          build-dir: ${{ steps.build.outputs.build-path }}
          create-release-assets: 'true'
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

The `github-pages` environment must also allow the tags to deploy: under **Settings**, **Environments**, **github-pages**, **Deployment branches and tags**, add the pattern `publish*`.

### In the templates

[`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml) publishes each push to `main`, and runs on manual dispatch too, after restoring the build cache and building the site. Release assets are there as comments, with the three changes a workflow needs before it can make them: a tag trigger, `contents: write`, and the tag pattern allowed in the `github-pages` environment.

## Behaviour

1. **Checks.** `build-dir` must exist. The action prints how many files it holds and its size.
2. **`cname`.** When set, the domain is written to `<build-dir>/CNAME`, with a warning that the deploy ignores it.
3. **The deploy.** configure-pages reads the repository's Pages settings, upload-pages-artifact packs `build-dir` as the run's `github-pages` artifact, and deploy-pages publishes it and reports the URL in `page-url`.
4. **Release assets**, with `create-release-assets: 'true'`, after the deploy:
   - On a run not triggered by a tag, a warning says they are skipped, and the job carries on.
   - With `github-token` empty, the job fails.
   - Otherwise the action writes the three files in [Release assets](#release-assets), and uploads them with [action-gh-release](https://github.com/softprops/action-gh-release) to the release named after the tag, which it creates if there is none.
5. **Summary.** A "Deployment Summary" log group gives the page URL, the `CNAME` domain if any, and the release's URL if assets were uploaded.

The site is live before the release assets are made, so a failure in making or uploading them leaves the new site published.

## Release assets

With `create-release-assets: 'true'`, a run triggered by the tag `<tag>` attaches three files to that tag's release, where `<asset-name>` is the `asset-name` input or, when that is empty, `<repository>-html`:

| File | Contents |
|---|---|
| `<asset-name>-<tag>.tar.gz` | The whole of `build-dir`, including any `CNAME` file, as a gzip-compressed tar whose paths are relative to `build-dir`, as in `./index.html`. |
| `<asset-name>-checksum.txt` | One line in `sha256sum`'s format: the archive's SHA-256 in hexadecimal, two spaces, and the archive's file name, with no directory. |
| `<asset-name>-manifest.json` | A JSON object that describes the archive, with the fields below. |

| Manifest field | Type | Value |
|---|---|---|
| `name` | string | `<asset-name>` |
| `tag` | string | `<tag>` |
| `commit` | string | The full SHA of the commit the run built. |
| `timestamp` | string | When the assets were made: ISO 8601 date and time to the second, with the UTC offset, as in `2026-09-28T10:04:05+00:00`. |
| `size_mb` | number | The disk space `build-dir` takes, in mebibytes, as `du -sm` reports it: a whole number, rounded up. |
| `file_count` | number | The number of files in `build-dir`, not counting a `CNAME` file that `cname` writes. |
| `repository` | string | `<owner>/<repository>`. |

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

This is the contract. A release of this project that changes a file name, the archive's layout, the checksum's format, or a manifest field's name or meaning says so in its CHANGELOG entry. Read the manifest as JSON, and ignore any field you do not know, so that a field added later does no harm. The checksum's and the manifest's names do not carry the tag, so keep each release's files in a directory of their own.

## Custom domain

1. **Set the domain** under **Settings**, **Pages**, **Custom domain**. A GitHub Actions deploy reads it only from there, and ignores any `CNAME` file in the site, which is why `cname` has no effect on it.
2. **Point the domain's DNS at GitHub Pages**, at the domain's provider: for a subdomain such as `lectures.example.org`, a `CNAME` record pointing at `<owner>.github.io`. GitHub's [custom domain guide](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site) gives the records for an apex domain.
3. **Turn on Enforce HTTPS** in the same settings, once GitHub has issued the certificate, which can take a while after the DNS change.

## Moving from a `gh-pages` branch

A repository that publishes by pushing to a branch, with peaceiris/actions-gh-pages or a version of this action that took a `target-branch` input, moves over in five steps:

1. Under **Settings**, **Pages**, change **Source** from **Deploy from a branch** to **GitHub Actions**.
2. Give the job `pages: write` and `id-token: write`, and run it in the `github-pages` environment. It no longer needs `contents: write`, unless it makes release assets.
3. Replace the deploy step with this action, passing only `build-dir`. The deploy needs no token.
4. Set the custom domain under **Settings**, **Pages**: a `CNAME` file in the site no longer applies.
5. Once the new deploy is live, delete the `gh-pages` branch, if you like, to shrink the repository.

## Troubleshooting

**`❌ Error: Build directory not found: …`.** `build-dir` is wrong, or the build did not run. Pass `build-lectures`' `build-path` output.

**`Get Pages site failed`, from configure-pages.** GitHub Pages is not enabled with the GitHub Actions source. Set **Settings**, **Pages**, **Source** to **GitHub Actions**.

**The deploy fails asking for `id-token: write`, or for `pages: write`.** A `permissions:` block drops every scope it does not list: add both.

**`Tag "…" is not allowed to deploy to github-pages due to environment protection rules`.** Allow the tag pattern under **Settings**, **Environments**, **github-pages**, **Deployment branches and tags**. A branch other than the default is refused the same way.

**`create-release-assets is enabled but this run was not triggered by a tag …; skipping release assets`.** Release assets need a tag trigger, such as `tags: ['publish*']` under `on.push`.

**`create-release-assets is enabled but 'github-token' is empty`.** Pass `github-token: ${{ secrets.GITHUB_TOKEN }}`.

**The release upload fails with `Resource not accessible by integration`, or a 403.** The job lacks `contents: write`.

**A warning that `cname has no effect on the GitHub Pages deployment`.** Set the domain under **Settings**, **Pages**, and drop `cname`, unless you want the `CNAME` file in the release archive.

**The site answers 404.** Check that the Pages source is **GitHub Actions**, and that `build-dir` has an `index.html` at its top. A new site can take a minute or two to appear.

**The custom domain does not resolve.** Check the DNS records, and allow for DNS to propagate, which can take up to a day. The domain must be set under **Settings**, **Pages**.
