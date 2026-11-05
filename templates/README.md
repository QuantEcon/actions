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
| [ci.yml](ci.yml) | Pull requests | Restore cache → incremental build, then a Netlify preview from its own job, and a PDF check |
| [cache.yml](cache.yml) | Weekly / manual / env change | Full build → save cache for CI and publish |
| [publish.yml](publish.yml) | Push to main | Restore cache → build → deploy to GitHub Pages |

Also here: [latex-requirements.txt](latex-requirements.txt), an example LaTeX package list for PDF builds on a standard runner (see [Using a Standard Runner](#using-a-standard-runner-no-container)).

### [ci.yml](ci.yml) — PR Preview

Runs on every pull request to `main`, in three jobs:

| Job | What it does | What it holds |
|---|---|---|
| `build` | Restores the build cache, runs an incremental HTML build (only changed notebooks re-execute), and uploads the site as an artifact | `contents: read`, no secrets |
| `deploy` | Deploys that site as a Netlify preview, and comments on the pull request with links to changed pages | the Netlify secrets, `pull-requests: write` |
| `pdf-check` | Builds the PDF from the notebooks `build` executed, and fails the pull request's checks when the LaTeX build fails | `contents: read`, no secrets |

`deploy` and `pdf-check` both start when `build` has finished, and run side by side, so the preview never waits for the PDF. The deploy has a job of its own so that the Netlify token is never in a job that runs notebook code: see [Why the preview deploys from its own job](#why-the-preview-deploys-from-its-own-job). Malformed LaTeX can pass the HTML build and still break the PDF build, and with it the publish, which is what `pdf-check` catches. It builds from the execution cache `build` uploads, so it executes no notebooks and needs no GPU. See [The PDF check](#the-pdf-check).

**Key features:**
- Container-based build (fast startup, pre-installed packages)
- Build cache restore for incremental builds
- Netlify PR preview with changed-page links, deployed from a job that runs no notebook code
- A PDF check beside the preview, which a site can switch off
- Failure report artifacts for debugging
- Cloudflare Pages alternative included as comments

**Secrets required:** `NETLIFY_AUTH_TOKEN`, `NETLIFY_SITE_ID`, used only by the `deploy` job

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
│                     │ │                                 │
│  build:             │ │  restore cache                  │
│   restore cache     │ │  build HTML                     │
│   build HTML        │ │  deploy to GitHub Pages         │
│   upload site and   │ │                                 │
│   exec cache        │ │                                 │
│  then side by side: │ │                                 │
│   ├─ deploy:        │ │                                 │
│   │   Netlify       │ │                                 │
│   │   preview       │ │                                 │
│   └─ pdf-check:     │ │                                 │
│       build PDF     │ │                                 │
└─────────────────────┘ └─────────────────────────────────┘
```

## Secrets

| Secret | Used by | How to obtain |
|--------|---------|---------------|
| `NETLIFY_AUTH_TOKEN` | ci.yml, `deploy` job | Netlify → User Settings → Applications → Personal access tokens |
| `NETLIFY_SITE_ID` | ci.yml, `deploy` job | Netlify → Site Settings → General → Site ID |
| `CLOUDFLARE_API_TOKEN` | ci.yml, `deploy` job (alternative) | Cloudflare dashboard → API Tokens |
| `CLOUDFLARE_ACCOUNT_ID` | ci.yml, `deploy` job (alternative) | Cloudflare dashboard → Account ID |

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

3. **ci.yml** — the same as publish.yml, in the `build` job, if you want downloads in PR previews.

### Why the Preview Deploys From Its Own Job

Building the lectures runs code the repository does not fully control: notebook cells, packages installed at build time, and network fetches. Code that runs earlier in a job can affect the steps after it, so a compromised build dependency in the same job as the deploy could reach the provider token the deploy step is handed. `ci.yml` therefore splits the two:

- **`build`** runs the notebooks, with `contents: read` and no secrets. It ends by uploading `_build/html` as the `html` artifact, with every file the build wrote, hidden ones included.
- **`deploy`** holds the Netlify (or Cloudflare) secrets and `pull-requests: write`, and runs no notebook or repository code: no container, no `setup-environment`, no build. It checks out the repository, sets up Node for the deploy CLI, downloads the `html` artifact, and runs `preview-netlify`. It needs no GPU, so it runs on `ubuntu-latest` wherever `build` runs.

Every checkout in the three templates sets `persist-credentials: false`, so no job leaves its `GITHUB_TOKEN` in git's config, where any later step could read it.

`deploy` checks out the repository only for the comment's links to changed lectures, which come from comparing the pull request with its base branch in git. From the template's shallow checkout, the preview action fetches the history it needs. A public repository serves that fetch without credentials. A private repository does not, so with `persist-credentials: false` the fetch fails, and the comment lists no lectures, with a warning in the log. A private repository sets `fetch-depth: 0` on `deploy`'s checkout instead, as the comment there says: the checkout then has the history already, and nothing is fetched.

The split does not protect the site's content: `deploy` publishes whatever `build` produced. It keeps the provider token away from the code that runs at build time.

The `html` artifact is kept for one day. To run `deploy` again after that, use **Re-run all jobs**, which builds and uploads the site again.

### The PDF Check

`ci.yml`'s `pdf-check` job is on by default. A site that publishes no PDF switches it off by setting `PDF_CHECK` to `'false'` in the workflow's top-level `env:` block. The job is then reported as skipped, not failed, and the `build` job uploads nothing for it. The switch is in the workflow file rather than in a repository variable because a workflow run for a pull request from a fork does not receive repository variables, so a variable could not switch the check off for those pull requests.

A failed `pdf-check` marks the pull request's checks red but does not block a merge. To make a broken PDF block merges, make `pdf-check` a required status check, under **Settings → Branches** or in a ruleset. Require `build` as well: `pdf-check` is skipped whenever the `build` job fails, and GitHub counts a skipped required check as passed. For the same reason, a site that requires `deploy` must require `build` too.

How it gets the executed notebooks: the `build` job uploads `_build/.jupyter_cache` as an artifact, after the site. That cache holds every lecture's outputs, the ones restored from the build cache and the ones the pull request's build executed. `pdf-check` downloads it and builds the PDF without executing anything. The other way to get them, restoring the build cache from `main` in a job that runs alongside the build, would execute every lecture the pull request changed a second time, which on a GPU site needs a second GPU runner. The cost of the hand-off is that `pdf-check` starts only when the `build` job has finished, at the same time as `deploy`. It relies on `execute_notebooks: cache` in `_config.yml`, which the build cache needs anyway.

`pdf-check` runs on `ubuntu-latest` even where the `build` job needs a GPU runner, and passes the same arguments to `build-lectures` as the PDF builds in `cache.yml` and `publish.yml`, so it fails where they would. On a failure, the LaTeX log is uploaded as the `latex-log` artifact.

To run `pdf-check` again, use **Re-run all jobs** once the hand-off artifact has expired, which is one day after the `build` job uploaded it. Re-running `pdf-check` alone needs that artifact, so after it has expired the job fails at the download. **Re-run all jobs** runs the `build` job again, which uploads a fresh one.

### Using a Standard Runner (No Container)

Remove the `container:` block from each job that has one and uncomment the standard runner `with:` block under `setup-environment`. See comments in each template. `ci.yml`'s `deploy` job already runs on a standard runner.

A `pdflatex` build on a standard runner installs LaTeX from `latex-requirements.txt` at the repository root, and fails if that file is missing. Copy [latex-requirements.txt](latex-requirements.txt) there to start: it lists the TeX packages and build tools the two container images have in common.

### Custom Domain

Set the domain in **Settings → Pages → Custom domain**. The Actions Pages deploy that `publish.yml` uses ignores a CNAME file, so `publish-gh-pages`' `cname` input has no effect.

### Switching to Cloudflare Pages

In **ci.yml**, replace the Netlify step with the commented Cloudflare Pages alternative. Update secrets accordingly.
