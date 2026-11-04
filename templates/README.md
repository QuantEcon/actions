# Workflow Templates

Reference GitHub Actions workflows for QuantEcon lecture repositories. Copy these into your repository's `.github/workflows/` directory and customize the commented options.

## Quick Start

1. Copy all three templates to `.github/workflows/`
2. Configure secrets (see [Secrets](#secrets) below)
3. Enable GitHub Pages: **Settings → Pages → Source → "GitHub Actions"**
4. Run the cache workflow manually once to generate the initial cache
5. Open a PR to verify CI and preview work

## Templates

| Template | Trigger | Purpose |
|----------|---------|---------|
| [ci.yml](ci.yml) | Pull requests | Restore cache → incremental build → Netlify preview, then a PDF check |
| [cache.yml](cache.yml) | Weekly / manual / env change | Full build → save cache for CI and publish |
| [publish.yml](publish.yml) | Push to main | Restore cache → build → deploy to GitHub Pages |

Also here: [latex-requirements.txt](latex-requirements.txt), an example LaTeX package list for PDF builds on a standard runner (see [Using a Standard Runner](#using-a-standard-runner-no-container)).

### [ci.yml](ci.yml) — PR Preview

Runs on every pull request to `main`. Restores the build cache, runs an incremental HTML build (only changed notebooks re-execute), and deploys a Netlify preview with links to changed pages.

A second job, `pdf-check`, then builds the PDF and fails the pull request's checks when the LaTeX build fails. Malformed LaTeX can pass the HTML build and still break the PDF build, and with it the publish. The preview never waits for it: `pdf-check` starts when the preview job has finished, and builds from the execution cache that job uploads, so it executes no notebook and needs no GPU. See [The PDF check](#the-pdf-check).

**Key features:**
- Container-based (fast startup, pre-installed packages)
- Build cache restore for incremental builds
- Netlify PR preview with changed-page links
- A PDF check beside the preview, which a site can switch off
- Failure report artifacts for debugging
- Cloudflare Pages alternative included as comments

**Secrets required:** `NETLIFY_AUTH_TOKEN`, `NETLIFY_SITE_ID`

### [cache.yml](cache.yml) — Build Cache Generation

Runs weekly on Sunday, on manual dispatch, and when `environment.yml` changes on main. Builds all requested formats and saves the `_build/` directory as a GitHub Actions cache.

**Key features:**
- Saves cache only when ALL builds pass (preserves last-good cache on failure)
- Auto-creates GitHub issues on build failure
- Uploads the `_build` directory as an artifact when a build fails, for inspection
- Configurable builders: `html`, `jupyter`, `pdflatex`

### [publish.yml](publish.yml) — GitHub Pages Deployment

Runs on push to `main`. Restores the build cache, builds HTML, and deploys to GitHub Pages using native deployment (no `gh-pages` branch needed).

**Key features:**
- Native GitHub Pages deployment (OIDC, no tokens)
- Custom domain via Settings → Pages (the `cname` input has no effect on this deploy)
- Optional release asset creation for tagged releases
- Optional PDF and notebook download staging

## How They Work Together

```
┌──────────────────────────────────────────────────────────┐
│  cache.yml (weekly / manual / env change on main)        │
│                                                          │
│  build-jupyter-cache                                     │
│   ├── Build html (+ optional jupyter, pdflatex)          │
│   ├── ALL pass → save new cache (build-{hash}-{run_id})  │
│   └── ANY fail → keep old cache, create issue            │
└─────────────────────┬────────────────────────────────────┘
                      │ cache
          ┌───────────┴───────────┐
          ▼                       ▼
┌─────────────────────┐ ┌─────────────────────────────────┐
│  ci.yml (PRs)       │ │  publish.yml (push to main)     │
│                     │ │                                  │
│  restore cache      │ │  restore cache                   │
│  build HTML         │ │  build HTML                      │
│  Netlify preview    │ │  deploy to GitHub Pages          │
│  upload exec cache  │ │                                  │
│   └─ pdf-check:     │ │                                  │
│      build PDF      │ │                                  │
└─────────────────────┘ └─────────────────────────────────┘
```

## Secrets

| Secret | Used by | How to obtain |
|--------|---------|---------------|
| `NETLIFY_AUTH_TOKEN` | ci.yml | Netlify → User Settings → Applications → Personal access tokens |
| `NETLIFY_SITE_ID` | ci.yml | Netlify → Site Settings → General → Site ID |
| `CLOUDFLARE_API_TOKEN` | ci.yml (alternative) | Cloudflare dashboard → API Tokens |
| `CLOUDFLARE_ACCOUNT_ID` | ci.yml (alternative) | Cloudflare dashboard → Account ID |

GitHub Pages deployment uses OIDC (`id-token: write`) — no token secret needed.

## Customization

### Adding PDF / Notebook Downloads

To enable PDF and notebook download links on the built site:

1. **cache.yml** — change builders to include the formats:
   ```yaml
   builders: 'jupyter,pdflatex,html'
   ```

2. **publish.yml** — uncomment the jupyter and pdflatex build steps, then enable staging:
   ```yaml
   html-copy-pdf: 'true'
   html-copy-notebooks: 'true'
   ```

3. **ci.yml** — same as publish.yml if you want downloads in PR previews.

### The PDF Check

`ci.yml`'s `pdf-check` job is on by default. A site that publishes no PDF switches it off by setting `PDF_CHECK` to `'false'` in the workflow's top-level `env:` block. The job is then reported as skipped, not failed, and the preview job uploads nothing for it. The switch is in the workflow file rather than in a repository variable because a workflow run for a pull request from a fork does not receive repository variables, so a variable could not switch the check off for those pull requests.

A failed `pdf-check` marks the pull request's checks red but does not block a merge. To make a broken PDF block merges, make `pdf-check` a required status check, under **Settings → Branches** or in a ruleset. Require `preview` as well: `pdf-check` is skipped whenever the preview job fails, and GitHub counts a skipped required check as passed.

How it gets the executed notebooks: the preview job uploads `_build/.jupyter_cache` as an artifact once it has deployed. That cache holds every lecture's outputs, the ones restored from the build cache and the ones the pull request's build executed. `pdf-check` downloads it and builds the PDF without executing anything. The other way to get them, restoring the build cache from `main` in a job that runs alongside the preview, would execute every lecture the pull request changed a second time, which on a GPU site needs a second GPU runner. The cost of the hand-off is that `pdf-check` starts only when the preview job has finished. It relies on `execute_notebooks: cache` in `_config.yml`, which the build cache needs anyway.

`pdf-check` runs on `ubuntu-latest` even where the preview job needs a GPU runner, and passes the same arguments to `build-lectures` as the PDF builds in `cache.yml` and `publish.yml`, so it fails where they would. On a failure, the LaTeX log is uploaded as the `latex-log` artifact.

### Using a Standard Runner (No Container)

Remove the `container:` block from each workflow and uncomment the standard runner `with:` block under `setup-environment`. See comments in each template.

A `pdflatex` build on a standard runner installs LaTeX from `latex-requirements.txt` at the repository root, and fails if that file is missing. Copy [latex-requirements.txt](latex-requirements.txt) there to start: it lists the TeX packages and build tools the two container images have in common.

### Custom Domain

Set the domain in **Settings → Pages → Custom domain**. The Actions Pages deploy that `publish.yml` uses ignores a CNAME file, so `publish-gh-pages`' `cname` input has no effect.

### Switching to Cloudflare Pages

In **ci.yml**, replace the Netlify step with the commented Cloudflare Pages alternative. Update secrets accordingly.
