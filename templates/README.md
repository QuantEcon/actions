# Workflow templates

The standard workflows for a QuantEcon lecture repository. Copy them into the repository's `.github/workflows/`, and change the commented options where it differs from the defaults.

| Template | What it does |
|---|---|
| [`cache.yml`](cache.yml) | Builds every lecture from scratch, weekly and on demand, and saves the cache that `ci.yml` and `publish.yml` restore |
| [`ci.yml`](ci.yml) | On each pull request: comments at once with the preview's link, builds the HTML from the cache, then deploys the preview from a job of its own, and checks the PDF build |
| [`publish.yml`](publish.yml) | On each push to `main`: builds from the cache, then deploys to GitHub Pages from a job of its own |
| [`restore.yml`](restore.yml) | By hand, with a release's tag: puts the GitHub Pages site back as that release holds it, without a build |
| [`latex-requirements.txt`](latex-requirements.txt) | An example LaTeX package list, for PDF builds on a standard runner |

Setting them up, what each job does and holds, and how to change them: [Getting started](../docs/user/getting-started.md), in the user manual. What each job can reach, and why each deploy has a job of its own: [Security](../docs/user/security.md).
