# restore-gh-pages

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Restores a site from one of the repository's GitHub releases, where [`publish-gh-pages`](publish-gh-pages.md) attached it as an archive, a checksum and a manifest: see its [Release assets](publish-gh-pages.md#release-assets). The action downloads the release's archive and checksum, checks the archive's SHA-256 before anything is extracted, and extracts the site. It does not deploy it: `publish-gh-pages`, the next step, deploys the restored site as it deploys a build.

A release is a recovery point. Restoring one puts the site back exactly as it was published, in about the time a download takes, with no build: no notebooks are executed, and nothing depends on today's packages still building the lectures as they did.

## When to use it

Use it, through [`restore.yml`](https://github.com/QuantEcon/actions/blob/main/templates/restore.yml), when the published site is broken or gone and a rebuild would be slow, or would not give back the same site.

- **Not to undo a change to the lectures.** Revert the change and publish. A restored site stays up only until the next publish, which replaces it.
- **Not for a site deployed from a `gh-pages` branch.** Its Pages source is a branch, which an Actions deploy does not change, and the branch's history already holds every site it published: revert the branch instead.
- **Only with recovery points.** The repository's publish must attach the site to its releases, with `publish-gh-pages`' `create-release-assets: 'true'` or `mode: release`, as [`publish.yml`](https://github.com/QuantEcon/actions/blob/main/templates/publish.yml)'s `release-assets` job does. A publish that was not triggered by a tag makes none.
- **Only the repository's own releases.** A Pages deploy can only publish the repository's own site, so the action reads no other repository's releases.

## Requirements

- **Runner.** One with `bash`, the GitHub CLI `gh`, `jq`, GNU `tar` and `sha256sum`, as GitHub's hosted Ubuntu runners have. The QuantEcon images have no `gh`, so run it without a container, as `restore.yml` does. It needs no GPU.
- **Node.** None.
- **Permissions.** `contents: read`, to read the release. The deploy that follows needs `pages: write` and `id-token: write`.
- **Secrets.** None. It reads the release with the job's own token.
- **Files in your repository.** None. It needs a release made by `publish-gh-pages`, which holds `<asset-name>-<tag>.tar.gz` and `<asset-name>-checksum.txt`, and usually `<asset-name>-manifest.json`.
- **Repository settings.** Those of the deploy: under **Settings**, **Pages**, **Source** is **GitHub Actions**, and the job runs in the `github-pages` environment, which by default lets only the default branch deploy. See [`publish-gh-pages`' requirements](publish-gh-pages.md#requirements).
- **Setup outside GitHub.** None.

## Inputs

<!-- BEGIN GENERATED: inputs. scripts/generate-docs.py writes this from restore-gh-pages/action.yml: edit that, not this. -->

| Input | Required | Default | Description |
|---|---|---|---|
| `tag` | yes | none | The tag of the release to restore, such as `publish-2026-11-10`. Only letters, digits, `.`, `_` and `-`, starting with a letter or a digit: an empty tag, or any other character, fails the job before anything is downloaded. |
| `asset-name` | no | `''` | The start of the release's asset names, as `publish-gh-pages` was given it in `asset-name`: the archive is `<asset-name>-<tag>.tar.gz` and its checksum `<asset-name>-checksum.txt`. Empty, the default, takes the release's one asset whose name ends in `-<tag>.tar.gz`, and fails if it has none or several. Only letters, digits, `.`, `_` and `-`: any other character fails the job before anything is downloaded. |

<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs. scripts/generate-docs.py writes this from restore-gh-pages/action.yml: edit that, not this. -->

| Output | Description |
|---|---|
| `build-dir` | The directory that holds the restored site, under the runner's temporary directory, to pass to `publish-gh-pages` as `build-dir`. Set only once the archive has matched its checksum and been extracted, and holds nothing but files and directories. Empty otherwise. |
| `commit` | The full SHA of the commit the restored site was built from, as the release's manifest records it. Empty when the release has no manifest, or its manifest gives no such SHA. |

<!-- END GENERATED -->

## Examples

### Minimal

Restores the release a person names when they run the workflow, and deploys it:

```yaml
name: Restore
on:
  workflow_dispatch:
    inputs:
      tag:
        description: 'The tag of the release to restore'
        required: true
        type: string

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  restore:
    runs-on: ubuntu-latest
    permissions:
      contents: read    # the release
      pages: write      # the Pages deploy
      id-token: write   # the Pages deploy's OIDC token
    environment:
      name: github-pages
      url: ${{ steps.publish.outputs.page-url }}
    steps:
      - uses: quantecon/actions/restore-gh-pages@v0
        id: restore
        with:
          tag: ${{ inputs.tag }}
      - uses: quantecon/actions/publish-gh-pages@v0
        id: publish
        with:
          build-dir: ${{ steps.restore.outputs.build-dir }}
```

The job runs no repository or notebook code, so the Pages permissions can sit in the same job as the download. `group: pages` is the group `publish.yml` uses, so that a restore and a publish never deploy at once.

### In the templates

[`restore.yml`](https://github.com/QuantEcon/actions/blob/main/templates/restore.yml) is the workflow above, with comments. Copy it into `.github/workflows/` before you need it. To run it, open **Actions**, **Restore**, **Run workflow**, choose the default branch and give the release's tag, or run:

```bash
gh workflow run restore.yml -f tag=publish-2026-11-10
```

The **Releases** page lists the tags, newest first. After a publish that broke the site, the newest release is the broken one, so give the tag before it.

## Behaviour

1. **Inputs.** Before anything is downloaded, the action checks that `tag` is given, and holds only letters, digits, `.`, `_` and `-`, starting with a letter or a digit, and that `asset-name`, if given, holds only those characters. Any of these fails the job with nothing downloaded.
2. **The release.** It reads the list of the release's assets, with `gh release view`. With `asset-name` given, the archive is `<asset-name>-<tag>.tar.gz`. Without it, the archive is the release's one asset whose name ends in `-<tag>.tar.gz`, and the asset name is what comes before. The checksum, `<asset-name>-checksum.txt`, must be there too, and the manifest, `<asset-name>-manifest.json`, is read if it is. A missing release, archive or checksum, or two archives for the tag, fails the job, and the error lists what the release holds. Then it downloads those files, with `gh release download`, into a new directory under the runner's temporary directory.
3. **The checksum.** The checksum file must be the one line `publish-gh-pages` writes: a SHA-256 in hexadecimal, two spaces, and the archive's file name. `sha256sum --check --strict` must then pass. Either failing fails the job with nothing extracted.
4. **The extract.** The archive is extracted into `site/` beside the downloads. GNU tar extracts an absolute path inside `site/`, and refuses a path that holds `..`, which fails the job. If the extracted site then holds anything but files and directories, such as a symlink, the action lists the first 20, removes the site and fails the job: the Pages upload follows symlinks, and would publish whatever one points at on the runner. `publish-gh-pages` makes no such archive. Otherwise the action prints the number of files and their size, and sets `build-dir`.
5. **The report.** The manifest, if there is one, is printed, and its `commit` becomes the `commit` output. A manifest that is not valid JSON, or gives no full commit SHA, only warns, since the checksum is what the restore relies on. A notice names the archive, the commit and the directory, and says that the next publish replaces the restored site.

The archive holds the whole site, files whose names start with a dot and any `CNAME` file included. `publish-gh-pages`' upload leaves out the files and directories whose names start with a dot, as it did when the site was first published, so the restored site serves what that publish served. The custom domain, if any, is set in the repository's Pages settings, and a restore does not change it.

The checksum is attached to the same release as the archive. So it catches a download that is incomplete or corrupt, and an archive replaced without its checksum, but not someone who replaces both. Only someone who can write the repository's releases can do that, which takes `contents: write`.

### Beside publish.yml

A restore and a publish in the `pages` concurrency group run one at a time, in the order they started. GitHub keeps only one waiting run in a group: a restore that waits behind a running publish is cancelled when another run joins the group, and needs running again.

The next publish, from a push to `main`, a dispatch or a tag, replaces the restored site with a new build. If the fault that took the site down is in the source, fix it before the next push, or disable `publish.yml` under **Actions** until it is fixed.

## Troubleshooting

**`tag is required: the tag of the release to restore`.** Give the release's tag, such as `publish-2026-11-10`. The **Releases** page lists them.

**`tag […] must be letters, digits, '.', '_' and '-' only, starting with a letter or a digit`.** `publish-gh-pages` attaches assets only to such tags, since the tag is part of the archive's name. Check for a stray space or slash. Nothing was downloaded.

**`asset-name […] must be letters, digits, '.', '_' and '-' only`.** Give `asset-name` as `publish-gh-pages` was given it, such as `lecture-python-html`, or leave it out. Nothing was downloaded.

**`could not read the release for tag […] in …`.** `gh`'s own message is just above it. `release not found` means the tag has no release: check the tag on the **Releases** page, case included. `Resource not accessible by integration`, or HTTP 403 or 404, means the job lacks `contents: read`: a `permissions:` block drops every scope it does not list.

**`the release for tag […] holds no site: no asset's name ends in -<tag>.tar.gz`.** The run that published it did not make release assets, or failed before it attached them. The error lists what the release holds. Restore an earlier release.

**`the release for tag […] holds 2 archives whose names end in -<tag>.tar.gz`**, or more. Give `asset-name`, as `publish-gh-pages` was given it, to choose one.

**`the release for tag […] has no asset named …`.** With `asset-name` given, the archive is `<asset-name>-<tag>.tar.gz`, and the release holds no file of that name. The error lists what it holds. Correct `asset-name`, or leave it out.

**`the archive … starts with […], which is not letters, digits, '.', '_' and '-' only`.** The archive was not made by `publish-gh-pages`, which allows no other character. Restore a release that it made.

**`the release for tag […] has the archive … but no checksum, …`.** Without the checksum the archive cannot be checked, so the action does not restore it. A release whose files were made by hand, with other names, is not one the action reads.

**`… is not one line of a SHA-256, two spaces and …`.** The checksum file was changed, or made by something other than `publish-gh-pages`. Nothing was extracted.

**`… does not match its SHA-256 in …`.** The archive is not the one the checksum was made for. Run the job again, in case the download was cut short. If it fails again, the release's files have been changed: restore another release, and find out who changed them. Nothing was extracted.

**`… matched its checksum but could not be extracted`.** `tar`'s message is above it. The archive is damaged in a way its checksum records, so it was made that way: restore another release.

**`… holds something other than files and directories, such as a symlink`.** The log lists the first 20. The action does not restore such an archive, since the Pages upload would follow the links. `publish-gh-pages` makes none from a built site: restore a release that it made.

**A warning that the manifest `is not valid JSON`, or `gives no full commit SHA`.** The site was restored, and `commit` is empty. The manifest is only a record of the site, and the restore does not rely on it.

**`Branch "…" is not allowed to deploy to github-pages due to environment protection rules`, from the deploy.** The workflow was run on a branch other than the default. Run it on the default branch: the release it restores does not depend on the branch.

**`<input> must be a single line`.** Both inputs are one value, and a line break would end the line that prints it, and the runner reads a next line that starts with `::` as a workflow command. So the action fails in its first step, before it has done anything. Write the value on one line. See [Security](../security.md#what-the-actions-themselves-do).
