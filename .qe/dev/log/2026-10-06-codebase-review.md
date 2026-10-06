# Codebase review, 2026-10-06

*A raw record under QEP-7: a whole-codebase review of `QuantEcon/actions` at `4550f69`, with
every finding validated against the code and against the repository's issues, pull requests and
plan before deciding whether it becomes work. This file is not edited after it lands; what
happens next is recorded in later `dev/log/` entries and on the issues it names.*

## Scope and method

**Read in full:** the eight composite actions (`*/action.yml`), the shared scripts (`scripts/`),
the five workflows under `.github/workflows/` (including the 1,818-line action harness), both
container images (`containers/*/Dockerfile`, `environment.yml`), the consumer templates
(`templates/`), `CONTRIBUTING.md`, `.github/dependabot.yml` and the developer docs
(`docs/dev/`).

**Static check:** `shellcheck -S warning` over the 50 `run:` blocks of the composite actions. Each
block was extracted with PyYAML from `*/action.yml` into its own file, with every `${{ … }}`
replaced by a placeholder word, and checked as bash. Its only hits (21, all SC2050/SC2157) are
constant comparisons left where a `${{ }}` expression is substituted into the script, the sites
finding M6 is about. At that severity the shell is clean. Info- and style-level hits, mostly
unquoted `$GITHUB_OUTPUT` (SC2086), were not counted.

**Review dimensions:** architecture and consistency; security; reliability and error handling;
performance and scalability; test coverage.

**Validation.** Each of the 15 findings went through three independent checks:

1. a **refuter** that read the cited code and tried to disprove the claim, its line references
   and its proposed fix;
2. a **prior-art search** over open and closed issues and pull requests, `docs/dev/PLAN.md`,
   `CHANGELOG.md`, `CONTRIBUTING.md` and `git log`, reading every plausible match's body and
   recording its parent tracker;
3. a **judge** that, given both, decided between *new work*, *amend an existing issue*,
   *already owned* and *drop*. The bar was high-quality improvements only: real defects or risks
   with material impact on the lecture repositories that consume these actions, on security,
   or on maintainer cost. Not churn, not cosmetic tidying, not speculative hardening.

No finding was refuted outright. Five were confirmed as stated and ten partially, mostly with
narrower impact or corrected line references. The corrections are recorded under each finding.

## Summary

The codebase is mature for a 0.x project. Its failure-path engineering, deploy-path security and
docs-as-code checks are better than most production Actions repositories. Validation found the
team already owns most of the material risk. The review's two High findings were both already
tracked (#142 under #188; #135 under #138), and nine findings extend open issues or a plan row.
Four gaps had no owner and become new work:

- the consumer templates run notebook code in the same job as long-lived deploy credentials;
- the weekly container rebuild republishes a fully cached image, contradicting the documented
  weekly security updates. This is confirmed from the run logs;
- `restore-jupyter-cache` accepts mistyped inputs without complaint;
- `build-jupyter-cache`'s failure alert can be routed to a pull request instead of an issue.

| ID | Finding | Severity: review → validated | Verdict | Existing coverage | Disposition |
|---|---|---|---|---|---|
| H1 | Container `:latest` is published before it is tested | High → Medium | partially confirmed | #142 phase 2 (parent #188) | Amend #142 |
| H2 | `build-jupyter-cache` runs its siblings at floating `@v0` | High → Low | partially confirmed | #135, open decision in #138 | Amend #135 |
| M1 | Notebook code shares a job with deploy credentials in the templates | Medium → Medium | partially confirmed | none | **New work** |
| M2 | Preview comment lookup misses comments past the first 30 | Medium → Low | partially confirmed | #153 (extraction only) | Amend #153 |
| M3 | Cache storage growth can evict the main build cache | Medium → Low | partially confirmed | none | Amend #149 |
| M4 | Weekly image rebuild replays its layer cache | Medium → Medium | **confirmed** (run logs) | #129 (parked, adjacent) | **New work** (decision + task) |
| M5 | Consumer-facing paths and the repo's own workflows go untested | Medium → Medium | confirmed | #100, #215, #153, #135 | Amend #100 |
| M6 | Caller text expanded into `run:` scripts | Medium → Low | partially confirmed | `docs/dev/PLAN.md` backlog item 18 | Already owned |
| L1 | Failure-alert dedupe can match a pull request | Low → Low | confirmed | none | **New work** |
| L2 | Cache-key formula duplicated across two actions | Low → Low | partially confirmed | guarded by the harness | Dropped |
| L3 | `restore-jupyter-cache` validates none of its inputs | Low → Low | partially confirmed | none | **New work** |
| L4 | Change detection hides git failures | Low → Low | confirmed | #215 (the base-tip half) | Amend #215 |
| L5 | Release manifest JSON built by an unescaped heredoc | Low → Low | confirmed, reproduced | none (#30 rewrites it) | Amend #30 |
| L6 | The two Dockerfiles are near-copies kept in sync by hand | Low → Low | partially confirmed | none (#151 adds a third copy) | Amend #151 |
| L7 | Standard-mode Conda cache never refreshes unpinned packages | Low → Low | partially confirmed | none | Dropped |

## Strengths

1. **Failure checks that fail closed.** Guards test `!= 'true'` rather than `== 'false'`, so a
   value nobody wrote never reads as success (#123). Postconditions are asserted rather than
   trusted ("Verify the failure alert was filed"). `always()` and implicit-`success()` behaviour
   in composites is handled correctly throughout. The harness tests failure paths
   (`bjc-abort-guard`, `build-fail-guard`), and the container smoke test proves its fixture can
   fail.
2. **A careful deploy path.** `deploy-cloudflare` proves the site is behind Access before and
   after every deploy, matching the redirect host exactly. The deploy CLIs are pinned by lockfile
   and installed outside the workspace. Tokens reach CLIs through `env:`, never on the command
   line. Third-party actions are pinned by SHA, and Miniconda, Node and actionlint by checksum.
3. **Docs and pins checked like code.** The user manual's input and output tables are generated
   from each `action.yml` and checked for drift. Every example is validated against the actions'
   declared inputs and with actionlint. The harness's relevance gate is an ignore list that fails
   closed and tests itself.

## Findings

### H1. Container `:latest` is published before it is tested

- **Where:** `.github/workflows/build-containers.yml:3-18` (push, weekly schedule, dispatch),
  `:62-80` and `:104-122` (`push: true` with `type=raw,value=latest`);
  `.github/workflows/test-container.yml:6-11` and `test-containers-lectures.yml:22-27` (both
  `workflow_run`, after the push); the templates pin `quantecon:latest` at `templates/ci.yml:32`,
  `templates/cache.yml:43` and `templates/publish.yml:38`.
- **Claim, as validated:** every build moves `:latest` the moment it succeeds, and both test
  workflows start only after that, so they can find a bad image only once consumers are already
  pulling it. The review also said the `main-<sha>` tag is overwritten weekly. That holds only
  when `main` has not moved since the last build; otherwise a new tag is added. But a tag named
  after a commit does not name an image's contents, since unpinned apt, conda and pip packages
  can change under it. Older digests stay pullable, so rollback by digest is possible. What is
  missing is a recorded, findable rollback handle.
- **Corrections:** two template line references in the original review were wrong (now fixed
  above). `CONTRIBUTING.md:105` already records the gap as a known limit ("Container images do
  not stage").
- **Existing coverage:** #142 (sub-issue of tracker #188) describes the same defect, and its
  phase 2 proposes the same fix: publish a candidate, smoke-test it, retag `:latest` on green.
  #150 (under #92) adds a dispatch tag input to `test-container.yml` for one zstd change.
- **Disposition: amend #142.** Additions #142 does not have yet:
  - an immutable candidate tag (dated plus SHA), because `main-<sha>` can be reused;
  - the pushed digest written to the step summary as the rollback handle;
  - `test-container.yml` called through `workflow_call` with an image input, with its
    `workflow_run` trigger removed;
  - promotion per image with `docker buildx imagetools create` (a retag, so the promoted digest
    is the tested digest), in a job of the same run so a cancelled newer run cannot promote an
    older candidate;
  - cleanup of candidate tags;
  - `test-containers-lectures.yml` (two hours or more per `lecture-python.myst` leg, and red
    from mid-September until #159 closed on 2026-10-05) kept as a check after promotion, not a
    gate;
  - a `:latest` rollback entry in CONTRIBUTING.

### H2. `build-jupyter-cache` runs its siblings at the floating `@v0` ref

- **Where:** `build-jupyter-cache/action.yml:216`, `:232`, `:242`, `:252`; `CONTRIBUTING.md:36`
  (the version table) and `README.md:181`.
- **Claim, as validated:** a composite action's nested `uses:` is resolved when the job runs and
  cannot take an expression. So pinning `build-jupyter-cache` to an exact tag or a commit does
  not pin the actions it calls: they follow `v0`. That makes "`@v0.x.y`: maximum
  reproducibility" untrue for this one action, and `docs/user/actions/build-jupyter-cache.md:129`
  already says so, so the documents disagree.
- **Corrections:** impact as of 2026-10-06 is nil. Every consumer of `build-jupyter-cache` is on `@v0`, and
  every exact pin is on an action that calls no sibling (`docs/dev/PLAN.md` consumers table). The
  mechanism itself is already documented as a release-process limit (CONTRIBUTING step 5 and
  Known limits; the harness header).
- **Existing coverage:** #135 (under #138) lists "rewrite sibling refs at release time" as an
  option, and #138's open decisions ask whether the residual is accepted or worth the rewrite.
  The #143 spike showed a gate can test the sibling chain by rewriting the four `uses:` lines at
  test time. #83 part 1 asked for the same hermeticity and was marked resolved by the earlier move
  of the refs from `@main` to `@v0` (#83 closed with #122), which met only half of it.
- **Disposition: amend #135**, as input to #138's accept-or-rewrite decision:
  - pinning the outer action does not pin its siblings;
  - a rewrite in the released tree (to the release tag or to a commit) makes pins hermetic, and
    lets the staged-release dispatch exercise the candidate's own siblings;
  - the cost: release tags then point at commits that are not ancestors of `main`;
  - a release check that no `quantecon/actions/...@v0` remains in a tagged tree.

  Whatever the decision, the version table in `CONTRIBUTING.md` and `README.md` should say that
  `build-jupyter-cache` follows `v0` for its siblings.

### M1. The templates run notebook code in the same job as deploy credentials

- **Where:** `templates/ci.yml:40-47` (`pull-requests: write`, checkout) and `:90-96` (the
  Netlify token passed to `preview-netlify`); `templates/publish.yml:44-60` (`pages: write`,
  `id-token: write`, the `github-pages` environment, checkout) and `:99-112` (build and publish
  in one job); `templates/cache.yml:53-64` (`issues: write`, checkout);
  `publish-gh-pages/action.yml:95-105` (configure, upload and deploy in one composite).
- **Claim, as validated:** building lectures runs code the repository does not fully control:
  notebook cells, including unpinned packages installed at build time, and network fetches. In
  every template that code runs in the same job, and the same container, as later privileged
  steps, and code that runs earlier in a job can affect the steps after it. The material
  exposure is in `ci.yml`: on a pull request from a branch of the same repository, the long-lived
  Netlify or Cloudflare token is handed to the deploy CLI in a later step of the build job. Fork
  and Dependabot pull requests get no secrets, and the preview actions skip them. In
  `publish.yml` the same job holds the Pages OIDC capability and a `pages: write` token. No
  template sets `persist-credentials: false` on checkout, so the job token stays available to
  build code.
- **Corrections:** the original cited lines past the end of two files (fixed above), and it
  overstated how widely this repository's own workflows set `persist-credentials: false` (three
  checkouts do). Splitting `publish.yml` isolates credentials but does not protect the site's
  integrity, because the build already controls the files that get deployed. The `issues: write`
  and `pull-requests: write` grants are low value.
- **Existing coverage:** none. #105 closed the fork (`pull_request_target`) variant and pinned
  the CLIs. #168 edited these exact checkout lines without adding `persist-credentials`. Work
  that should be built in the same shape: #27 (a `restore-gh-pages` action that would copy the
  bundled deploy), #151 (a preview image with the deploy CLI baked in) and #153 (a comment job
  that runs no repository code).
- **Disposition: new work**, as two items:
  1. *Templates:* `persist-credentials: false` on every checkout. Build the preview in one job,
     upload the site as an artifact, and deploy it from a second job that holds the provider
     token and runs no repository code. Keep change detection working: `ci.yml` checks out with
     depth 1, and `detect-changed-lectures.sh` fetches the base and head commits.
  2. *Publishing:* a deploy-only mode for `publish-gh-pages` (or a documented two-job shape), so
     `publish.yml` builds with `contents: read` and deploys from a job that holds `pages: write`
     and `id-token: write` and only deploys. Release assets, which need `contents: write`, move
     to their own job.

### M2. The preview comment lookup misses comments past the first 30

- **Where:** `preview-netlify/action.yml:250-257`, `preview-cloudflare/action.yml:286-293`.
- **Claim, as validated:** both actions find their earlier comment with one unpaginated
  `listComments` call, which returns the first 30 comments, oldest first. The preview comment is
  usually posted early, so the bug fires only when a pull request already has more than 30
  comments before its first preview, for example when the action is added to a long-running
  pull request. From then on every push adds a new comment. The match `c.body.includes(marker)`
  accepts any author's comment, so in rare cases the bot could update a person's comment that
  quotes the heading. The trusted-actor check, the CLI install and the comment script are copied
  between the two actions (about 130-140 lines).
- **Corrections:** narrower than "any pull request with more than 30 comments". The user manual
  already lists the symptom as a known limitation (`docs/user/actions/preview-netlify.md:224`,
  `preview-cloudflare.md:159`), but no issue was filed for it.
- **Existing coverage:** #153 (under #92) extracts the comment script into one shared file. PLAN
  item 6 and #100 Stage 1.5 cover the same extraction and its tests. Neither mentions
  pagination or author matching. The remaining duplication (trust check, CLI install) fails the
  quality bar on its own.
- **Disposition: amend #153**, with the lookup fix:
  - use `github.paginate(github.rest.issues.listComments, {per_page: 100})`;
  - match only `github-actions[bot]` comments carrying a hidden marker per provider;
  - keep accepting the old heading, so open pull requests do not each get one duplicate at
    upgrade;
  - remove the two troubleshooting entries once fixed;
  - if the script is shared, resolve its path from `$GITHUB_ACTION_PATH` in a bash step, the
    concern PR #46 raised.

  The fix is a few lines and can ship on its own if #153 stalls.

### M3. Cache storage growth can evict the main build cache

- **Where:** `build-jupyter-cache/action.yml:385-397` (two saves);
  `restore-jupyter-cache/action.yml:101-121` and `:173-180` (save mode, keyed on the run ID).
- **Claim, as validated:** every successful cache build saves `_build`, then saves
  `_build/.jupyter_cache` again as a separate entry. No shipped template restores
  `cache-type: execution`, so the second copy is duplication. With `save-cache: 'true'`, every
  successful pull-request run adds a full `_build` entry. GitHub evicts the least recently
  accessed caches once a repository passes its cache budget (10 GB by default), and a miss
  caused by eviction reads as an ordinary miss.
- **Corrections:** `save-cache` is opt-in and commented out in `templates/ci.yml:73`. Publish runs
  refresh main's entry, so it is not the first thing evicted. As of 2026-10-06 only `lecture-dp` and
  the canary run the cache chain. The user manual already mentions LRU eviction
  (`docs/user/actions/restore-jupyter-cache.md:97`). Deleting superseded entries from inside the
  pull-request run, as the review proposed, does not work: a fork's token is read-only.
- **Existing coverage:** none on storage. #149 (under #92) plans to turn `save-cache` on in
  `lecture-dp` and add a save on every push to `main`, which is when this becomes a real risk.
  #160 may make `cache-type: execution` the template default, which would turn the full `_build`
  save into the redundant one.
- **Disposition: amend #149**, so the rollout ships with:
  - a `pull_request: closed` cleanup workflow (GitHub's documented pattern) that deletes the
    caches scoped to that pull request;
  - the storage arithmetic (size of `_build` × open pull requests × pushes, against the budget)
    in the `save-cache` description;
  - a decision, made with #160, on making the separate execution-cache save opt-in through a new
    input, with a CHANGELOG note.

### M4. The weekly image rebuild replays its layer cache and republishes an unchanged image

- **Where:** `.github/workflows/build-containers.yml:15-17` (the Monday schedule), `:79-80` and
  `:121-122` (`cache-from` the published `:latest`, `cache-to: type=inline`, no `no-cache`);
  `containers/quantecon-build/environment.yml:32-79` (unpinned conda packages and `>=` pip
  floors); the promise in `README.md:156`, `containers/quantecon/README.md:135` and
  `docs/dev/ARCHITECTURE.md:55`.
- **Claim, as validated:** the review stated this as an inference, and the build logs confirm
  it. BuildKit keys each layer on its instruction text and its parent. So when `ubuntu:24.04`
  resolves to the same digest as the last build, a scheduled run replays every layer from cache,
  including `apt-get install`, `conda env create` and the `build_date=$(date …)` marker, and
  republishes the same image:
  - **fully cached** (about 20-40 s): the scheduled runs of 2026-08-31 (33350436635),
    2026-09-07 (34076033213), 2026-09-21 (35554031894) and 2026-09-28 (36369978971);
  - **full rebuild** (about 7-8 min, because the base digest had moved): 2026-08-24
    (32683376393), 2026-09-14 (34799041786) and 2026-10-05 (37255750631).

  The documentation promises weekly security updates, but OS updates arrive only when the base
  image is republished or someone pushes, with gaps of up to about three weeks. When the base
  does move, three things re-resolve together with no pull request: the lean image's unpinned
  conda packages (19 of them, including `jupyter`, `jupyterlab`, `notebook`, `ipykernel`,
  `ipywidgets`, `plotly` and `mkl`), its `>=` pip floors, and `quantecon-book-networks`, which is
  unpinned in both images.
- **Corrections:** "no TeX updates" barely applies, because Ubuntu 24.04 does not move TeX Live
  within the release; the loss is apt security and bugfix updates. `no-cache-filters` cannot
  isolate the apt step in a single-stage Dockerfile. Turning on `no-cache` for scheduled runs
  without first pinning the Python layer would make the silent drift weekly instead of every
  two or three weeks. Dependabot cannot propose bumps for packages that carry no version.
- **Existing coverage:** #129 (discuss, low priority, parked) covers part of the pinning half and
  assumes the schedule republishes changed content. #166 and #199 noted the lean image's floating
  Jupyter stack in their bodies, but neither filed an issue. #111 made the registry cache work,
  which is what made the replay possible.
- **Disposition: new work**, as a decision and the task that follows it. The decision is one
  policy for scheduled runs:
  - **(a) refresh weekly:** pin the lean image's Python layer, then make scheduled runs actually
    rebuild, with `no-cache` on schedule or a weekly cache-bust argument on the apt step;
  - **(b) pin the base:** pin `ubuntu:24.04` by digest so Dependabot proposes each base move as a
    pull request, drop the schedule, and correct the documentation.

  The task implements the chosen option and brings the docs into line.

### M5. Consumer-facing paths and the repository's own workflows go untested

- **Where:** `.github/workflows/test-actions.yml` (no `uses: ./preview-netlify`,
  `./preview-cloudflare` or `./publish-gh-pages`; the actionlint step at `:298-305`);
  `scripts/generate-docs.py:425-469` (actionlint is fed only templates and manual examples);
  `scripts/detect-changed-lectures.sh` (no harness reference);
  `publish-gh-pages/action.yml:107-169` (release assets).
- **Claim, as validated:** three of the eight actions never run in the harness, and only their
  CLIs' installation is tested. `detect-changed-lectures.sh` and the release-asset packaging are
  not exercised. actionlint never sees `.github/workflows/*.yml`, about 2,400 lines including the
  harness gate whose self-test the required check depends on. Nothing shellchecks the composite
  actions' `run:` blocks, which actionlint does not read.
- **Corrections:** the gaps are documented and deliberate (the gate comment, the
  `preview-cli-install` comment and CONTRIBUTING's Known limits), because a deploy needs secrets.
- **Existing coverage:** #100 Stage 1.5 covers the comment-renderer and release-asset tests.
  #215 proposes the unit job for `detect-changed-lectures.sh`. #153 and PLAN item 6 cover the
  extraction those tests need. #135 and #212 cover running `publish-gh-pages` in the canary.
- **Disposition: amend #100** with the two static checks nobody has filed:
  - actionlint over `.github/workflows/*.yml`, with the binary the gate already installs and
    verifies;
  - shellcheck over the composite actions' `run:` blocks, extracted with PyYAML, with each
    `${{ }}` replaced by a placeholder variable so the expressions do not produce noise.

### M6. Caller-supplied text is expanded into `run:` scripts

- **Where:** `restore-jupyter-cache/action.yml:94-98` (and `:146-149`, `:191`, `:280`);
  `build-lectures/action.yml:92-93`, `:111-112`, `:334-344`;
  `setup-environment/action.yml:178-179`, `:264`; `publish-gh-pages/action.yml:64-88`, `:128`,
  `:147`.
- **Claim, as validated:** several actions substitute caller-supplied inputs, and step outputs
  that carry them, directly into shell scripts instead of passing them through `env:`. Caller
  text that reaches those spots is interpreted by the shell rather than passed as data, the
  pattern the repository otherwise avoids.
- **Corrections:** as of 2026-10-06, no consumer, template or document passes untrusted context
  into these inputs. A fork `pull_request` run gets a read-only token and no secrets.
- **Existing coverage:** `docs/dev/PLAN.md` backlog item 18 names every one of these sites, and
  also covers the preview actions' trusted-actor check. It has no GitHub issue, and #192 plans to
  trim PLAN.
- **Disposition: already owned.** When item 18 is done:
  - move the step outputs that carry caller text into `env:` as well as the inputs;
  - quote the resulting variables;
  - validate `key` and `path` before writing them to `$GITHUB_OUTPUT`.

  If item 18 should be tracked as an issue before #192 trims PLAN, that is one issue for item 18,
  not one for this finding.

### L1. The failure-alert dedupe can match a pull request

- **Where:** `build-jupyter-cache/action.yml:564-586` (lookup), `:601-609` (verification).
- **Claim, as validated:** the alert looks for an open issue with
  `listForRepo({labels: labels[0], per_page: 1})` and takes the first result. The Issues API also
  returns pull requests, so if an open pull request carries `build-failure` (a fix PR, say) and
  is newer than any open failure issue, the failure report becomes a comment on that pull
  request, no issue is filed, and `failure-issue-url` points at the pull request. The
  verification step checks only that a URL was produced, so it passes.
- **Corrections:** the alert is misrouted to a visible thread, not lost. The sibling
  `scripts/create-ci-failure-issue.sh` uses `gh issue list` and is not affected.
- **Existing coverage:** none. #122 introduced the lookup and its review did not consider pull
  requests.
- **Disposition: new work (low priority).** Fix:
  - list with a larger page and take the first entry that has no `pull_request` key; the search
    API is worse here, being eventually consistent and more tightly rate-limited;
  - make the verification fail if the URL points at a pull request.

### L2. The cache-key formula is duplicated across two actions

- **Where:** `build-jupyter-cache/action.yml:142-152`, `:392-397`;
  `restore-jupyter-cache/action.yml:99-140`.
- **Validated:** the duplication is real. But the harness already catches drift:
  `bjc-restore-build` and `bjc-restore-exec` restore a fixture salted per run with
  `fail-on-miss: 'true'` and assert the exact key, so a one-sided change fails CI before a
  release. The proposed shared script cannot call `hashFiles()`, so the parts most likely to
  drift would stay duplicated anyway.
- **Disposition: dropped.** At most, a "keep in sync; pinned by `bjc-restore-*`" comment at each
  site the next time these files are edited.

### L3. `restore-jupyter-cache` validates none of its inputs

- **Where:** `restore-jupyter-cache/action.yml:99`, `:101`, `:120`, `:146`, `:174`, `:242`,
  `:276`.
- **Claim, as validated:** `cache-type` is compared only to `execution`, so a typo such as `exec`
  silently restores the whole build cache. Validation added a sharper failure: the shell checks
  of `save-cache` are case-sensitive, but the step condition `inputs.save-cache == 'true'` is
  not. With `save-cache: 'True'`, the first run saves under a key without the run ID, later runs
  match it exactly, and the cache stops updating without a word. `fail-on-miss: yes` is silently
  false. `build-jupyter-cache` (`builders`) and `deploy-cloudflare` (`require-access`) already
  reject values they do not know.
- **Existing coverage:** none. #160 raises the stakes: it wants `cache-type: execution` to be the
  default, and a mistyped value would silently bring back the stale-asset mode #160 avoids.
- **Disposition: new work (low priority).** Add a first step that reads the three inputs through
  `env:` and fails on any value outside `build|execution` and `true|false`, on every call. Add a
  harness case modelled on `bjc-builders-parse`.

### L4. Change detection hides git failures

- **Where:** `scripts/detect-changed-lectures.sh:26-27` (`git fetch … 2>/dev/null || true`),
  `:33` (`git diff … 2>/dev/null || echo ""`), `:56`.
- **Claim, as validated:** when git fails, the list of changed lectures is empty and the preview
  comment omits it without a warning. This happened in the field: #164 recorded a canary preview
  that listed no changed lectures. The two-dot `BASE..HEAD` diff also lists lectures changed on
  the base branch after the pull request branched off.
- **Existing coverage:** #215 owns the two-dot half: three-dot diffs, a warning when the merge
  base is unreachable, and a harness unit job. #164 fixed one cause (git ownership in containers)
  and left the error swallowing in place.
- **Disposition: amend #215** with the general half: warn, with git's own message, whenever the
  diff fails, not only when the merge base is unreachable. This matters more once #215's
  three-dot diff and #147's shallow fetches land. The pull request files API (as the harness gate
  uses) is an option that avoids reading the checkout at all. Its caveats: renames arrive as
  `renamed`, results are capped at 3,000 files, and it can race a new push.

### L5. The release manifest JSON is built by an unescaped heredoc

- **Where:** `publish-gh-pages/action.yml:152-163`.
- **Claim, as validated:** the manifest writes the asset name and the tag into JSON strings
  without escaping. `"` is legal in a git tag name, and a tag containing one produced a manifest
  that does not parse. Reproduced by rendering the heredoc with `TAG_NAME='publish-"x'` and
  piping the result to `jq .`, which reports a parse error. The manifest is documented as a JSON
  contract (`docs/user/actions/publish-gh-pages.md`).
- **Corrections:** as of 2026-10-06 no tag in use can trigger it. QuantEcon's publish tags use
  only letters, digits and dashes, such as `publish-2026sep27`, `publish-2026jan15b` and
  occasionally `publish-2026-07-17`. The step still runs often: eight consumers pass
  `create-release-assets: 'true'` (#27), so every tag-triggered publish of those sites writes this
  manifest.
- **Existing coverage:** none on escaping. #30 (parent `QuantEcon/meta#321`) plans to rewrite
  this generator into a versioned schema.
- **Disposition: amend #30.** The rewrite should build the manifest with a JSON encoder
  (`jq -n --arg/--argjson` or `json.dump`), keeping field names, order and number types. Add a
  fixture test, under #100 Stage 1.5, with a tag containing `"`.

### L6. The two Dockerfiles are near-copies kept in sync by hand

- **Where:** `containers/quantecon/Dockerfile` (151 lines) and
  `containers/quantecon-build/Dockerfile` (153 lines).
- **Validated:** the security-relevant blocks are identical as of 2026-10-06: the Miniconda version and
  checksum (`quantecon:76-80`, `quantecon-build:72-76`), the Node version and checksum
  (`:108-114` and `:109-115`) and the `safe.directory` line (`:136` and `:138`). Recent changes
  edited both files together. Incidental drift exists: the fontconfig cache is mode `777` in one
  image and `755` in the other. The `==`/`>=` split is in the environment files and is covered by
  #129. #32 was this kind of drift: the full image fetched Miniconda without the checksum the
  lean image verified. Merging the files (one Dockerfile with a variant argument) costs more than the risk.
- **Existing coverage:** none. #151 (under #92) will add a third copy and already plans a parity
  assertion for its package pins.
- **Disposition: amend #151.** Widen its parity check to the security-relevant lines across every
  Dockerfile, the existing pair included. Or, if #151 introduces a shared base stage, have both
  existing images use it.

### L7. The standard-mode Conda cache never refreshes unpinned packages

- **Where:** `setup-environment/action.yml:240` (the key), `:258-263` (update only without an
  exact hit), `:195` (`auto-update-conda: true`).
- **Validated:** the mechanism holds. But no current consumer uses standard mode (the planned
  migrations are all container mode). A frozen environment is also a reproducibility feature.
  Bumping `cache-version` already forces a fresh environment. A period added to the key would
  only fall back through `restore-keys`, so little would refresh. `auto-update-conda` is a
  deliberate choice from #78.
- **Disposition: dropped.** At most, one sentence in the `setup-environment` chapter: bump
  `cache-version` to pick up newer releases of unpinned packages.

## What validation changed

- Both High findings were already tracked. H1 is #142's phase 2, under #188, and H2 is an open
  decision in #138. Neither needs a new issue, only additions to the existing one.
- M4 moved from inference to fact: the build logs show four of the seven scheduled runs from
  2026-08-24 to 2026-10-05 republishing a fully cached image.
- L3 gained a concrete failure the review had not seen (`save-cache: 'True'` freezing the cache).
- Several line references were wrong in the review's draft (two template files cited past their
  end). This record uses the corrected references.
- Impact was narrowed for M1, M2, M3 and M6. M1's real exposure is the preview deploy token, not
  Pages.

## Recommended next step

Isolate the preview deploy token from the notebook build in `templates/ci.yml` (M1, item 1). Of
the work nobody owned, it is the one change that protects a long-lived credential in every lecture
repository that copies the template, and it follows a documented pattern: a build job, an
artifact, and a deploy job that runs no repository code. For the repository as a whole, #142 (the
container promotion gate) remains the highest-impact open item. It is owned by #188 and sequenced
there.
