# Handover: GitHub follow-ups from the 2026-10-06 codebase review

*A raw record under QEP-7, written by a Claude Code cloud session
(<https://claude.ai/code/session_01UTWsCYpwmgYdsz4AwRZjUy>) for a **local agent** to carry out.
The cloud session could not make these changes itself, because its GitHub tools cannot write
native issue dependencies, which QEP-6 requires for real constraints.*

- **The review:** `.qe/dev/log/2026-10-06-codebase-review.md`, added by QuantEcon/actions#220. It
  holds every finding's evidence and validation.
- **This handover:** branch `claude/sweet-clarke-ugjrlm-handover`. Step 0 finds its pull request.
- **Merge order:** that pull request merges only after #220. #220 adds `.qe/README.md`, the folder
  contract, which includes the rule this handover relies on: the agent that carries out a handover
  records the outcome in a new `dev/log/` entry. #220 also adds the review record that every body
  below cites.

## How to use this handover

1. **Review it before running anything.** Check every precondition in Step 0 against GitHub on
   the day you run it. If something changed after 2026-10-06 (an issue closed, a fix merged, a
   duplicate filed), adapt the step, and record what changed and why in the outcome entry.
2. **Run each block as one bash invocation**, for example `bash <<'SH' … SH`, or save the block to
   a file and run `bash file`. Shell variables and functions do not carry over between separate
   tool calls, and `${!name}` works only in bash. Every block after Step 0 starts by sourcing the
   state file that Step 0 writes, and a failed check ends the block. Stop at a failed check rather
   than working around it.
3. **Update the pull request that carries this file before it merges** (branch
   `claude/sweet-clarke-ugjrlm-handover`). Add the outcome entry (Step 9) to that branch. Until the
   pull request merges, correct an error found in review in place, and list the correction under
   Deviations in the outcome entry. Once it merges, never edit this file.
4. **Leave the decisions to people.** Do not close the decision issue this handover creates. Do
   not change the labels, parents or bodies of the existing issues it comments on. Do not merge.

## The rules this follows

- **QEP-2** (labels, accepted):
  - Every work item has exactly one Type label: `bug`, `enhancement`, `documentation`,
    `infrastructure`, `maintenance`, `question` or `discuss`, plus `refactor` on this software
    repository.
  - `security` is a cross-cutting modifier for credentials and tokens, supply-chain surface
    (base images, pinned actions and packages) and workflow permissions.
  - Priority labels mark outliers only.
  - A tracker carries no Type label.
- **QEP-6** (project trackers, a draft: pull request QuantEcon/qeps#18, discussion
  QuantEcon/qeps#15):
  - A project is one issue of type `Project`. Its work items are its native sub-issues, in plan
    order (top = next).
  - An issue belongs only if closing it advances the project's definition of done. A goal widened
    to fit an item means the item is not a member, and an issue with no parent is the normal case.
  - Kind lives in issue types: `Task` for work, `Decision` for a choice the plan waits on.
  - Real constraints are native blocked-by edges, and the test is output, not order. Edges work
    with or without a parent.
  - Titles carry no sequence tokens.
  - The body follows QEP-6 Appendix A. Its one machine-read element,
    `## Where we stand (verified YYYY-MM-DD)`, appears exactly once.
  - The body never mirrors structure.
  - Membership is single-parent, so issues that other projects own are commented on, never
    attached.
  - Types are asserted by reading them back.
- **QEP-7** (project-management protocols, a draft: pull request QuantEcon/qeps#40, discussion
  QuantEcon/qeps#39):
  - State lives in a tracker's stamped section, and history in its comments.
  - This handover and its outcome are raw `dev/log/` records.
  - `.qe/` is public content: no credentials, no unpatched-vulnerability specifics, absolute dates
    only. This handover applies the same rule to the issue and comment bodies it posts, stating
    each security item as a principle and a fix, never as a technique.

## What gets created, and why it is shaped this way

The review left four findings that no existing issue owned. They do not share a definition of
done, so they do not form one project. Under QEP-6, a goal that names three unrelated outcomes
is a goal widened to fit its items. So:

- **One project.** Finding M1, deploy credentials sharing a job with notebook execution, is one
  coherent goal with two work items. It becomes the `Project` tracker `P`.
- **Standalone issues.** The rebuild decision and the task that follows it, and the two
  cache-action bugs, are filed as standalone issues. The one real constraint between them is a
  native dependency edge, which works without a parent.
- **Comments.** Eight findings that other issues already own are recorded as comments on those
  issues.

Every new issue opens with "From the 2026-10-06 codebase review", so one search finds them all:
`gh issue list -R QuantEcon/actions --search '"2026-10-06 codebase review" in:body'`.

| Key | Type | Parent | Title | Labels |
|---|---|---|---|---|
| `T_PREVIEW` | Task | `P` | templates: deploy pull request previews from a job that runs no notebook code, and stop persisting checkout credentials | `enhancement`, `security` |
| `T_PUBLISH` | Task | `P` | publish-gh-pages: a deploy-only mode, so Pages is deployed from a job that runs no notebook code | `enhancement`, `security` |
| `D_REBUILD` | Decision | none | Scheduled container rebuilds: refresh OS packages weekly, or pin the base image by digest and move it by pull request? | `discuss`, `security` |
| `T_REBUILD` | Task | none | build-containers: scheduled rebuilds republish a cached image, while the docs promise weekly security updates | `bug`, `security` |
| `T_RESTORE` | Task | none | restore-jupyter-cache: a mis-cased save-cache value silently stops the cache updating, and unknown input values are accepted | `bug` |
| `T_ALERT` | Task | none | build-jupyter-cache: the failure alert can land on an open pull request instead of an issue | `bug`, `low-priority` |
| `P` | Project | none | Keep deploy credentials out of the jobs that execute notebooks | none |

Also created:

- one dependency: `T_REBUILD` is blocked by `D_REBUILD`;
- eight comments, on #142, #135, #153, #149, #100, #215, #30 and #151;
- one revision-log comment on the tracker.

No milestones.

## Step 0: preconditions and state

Run from anywhere: Steps 0 to 8 use only the GitHub API. Step 9 needs a clone of
QuantEcon/actions.

```bash
W="$HOME/qe-handover-2026-10-06"; mkdir -p "$W"
if [ ! -f "$W/env.sh" ]; then        # written once, so a re-run cannot reset it or move DATE
  cat > "$W/env.sh" <<'EOF'
R=QuantEcon/actions
HB=claude/sweet-clarke-ugjrlm-handover
W="$HOME/qe-handover-2026-10-06"
PH='\{\{(T_PREVIEW|T_PUBLISH|D_REBUILD|T_REBUILD|T_RESTORE|T_ALERT|P|DATE|HPR)\}\}'
set -o pipefail                      # a failed gh call is not hidden by the tee or grep after it
stop() { echo "STOP: $*" >&2; exit 1; }
[ -f "$W/ids.env" ] && . "$W/ids.env"
# create <KEY> <type> <title> <label>... : skips a key already created; appends to ids.env only on success
create() {
  local key=$1 type=$2 title=$3; shift 3
  if grep -q "^$key=" "$W/ids.env" 2>/dev/null; then echo "$key already created: $(grep "^$key=" "$W/ids.env")"; return 0; fi
  sed -f "$W/subst.sed" "$W/$key.md" > "$W/$key.final.md"
  if grep -nE "$PH" "$W/$key.final.md"; then echo "unfilled placeholder in $key" >&2; return 1; fi
  jq -n --arg title "$title" --rawfile body "$W/$key.final.md" --arg type "$type" \
        '{title: $title, body: $body, type: $type, labels: $ARGS.positional}' --args "$@" \
    | gh api -X POST "repos/$R/issues" --input - --jq '"\(.number) \(.id)"' > "$W/$key.out" || return 1
  read -r num id < "$W/$key.out"
  [ -n "$id" ] || return 1
  printf '%s=%s\n%s_ID=%s\n' "$key" "$num" "$key" "$id" >> "$W/ids.env"
  printf 's/{{%s}}/%s/g\n' "$key" "$num" >> "$W/subst.sed"
  eval "$key=$num ${key}_ID=$id"
  echo "$key -> #$num"
}
EOF
  echo "DATE=$(date +%F)" >> "$W/env.sh"     # your local calendar date: the tracker's stamp
fi
. "$W/env.sh"

gh auth status
[ "$(gh api repos/$R --jq .permissions.push)" = true ] \
  || stop "no push access on $R. Triage is not enough: without push, the REST API silently drops labels and type."
gh api repos/$R/issues/188 --jq '.type.name'                        # expect: Project (issue types are on)
for l in bug enhancement discuss security low-priority; do gh api repos/$R/labels/$l --jq '"\(.name) #\(.color)"' || stop "label $l missing"; done

# Not carried out already: no outcome entry on main or on this branch, no tracker with this title.
for ref in main $HB; do
  gh api "repos/$R/contents/.qe/dev/log?ref=$ref" --jq '.[].name' 2>/dev/null | grep -- '-github-handover-outcome\.md$' \
    && stop "an outcome entry exists on $ref: this handover has been carried out"
done
[ -f "$W/ids.env" ] || ! gh issue list -R $R --state all --search '"Keep deploy credentials out of the jobs that execute notebooks" in:title' --json number --jq '.[].number' | grep -q . \
  || stop "a tracker with this title exists: read it before going on"

# The pull request carrying this handover (Step 9 updates it; the tracker's log cites it).
HPR=$(gh pr list -R $R --head $HB --state open --json number --jq '.[0].number // empty')
[ -n "$HPR" ] || stop "no open pull request for $HB"
grep -q '^HPR=' "$W/env.sh" || echo "HPR=$HPR" >> "$W/env.sh"
echo "handover PR #$HPR; review record PR #220: $(gh pr view 220 -R $R --json state --jq .state)"

# The issues Step 6 comments on are still open; read any that is not.
for n in 142 135 153 149 100 215 30 151; do gh api repos/$R/issues/$n --jq '"#\(.number) \(.state) \(.title)"'; done

# Nothing filed since the review already covers a new item.
gh issue list -R $R --state all --search "created:>=2026-10-06" --limit 100 --json number,title,state --jq '.[] | "#\(.number) \(.state) \(.title)"'
for q in persist-credentials deploy-only "scheduled rebuild" "cache-type" "failure alert"; do
  echo "== $q"; gh issue list -R $R --state all --search "$q" --limit 10 --json number,title --jq '.[] | "#\(.number) \(.title)"'
done
```

**Check:**

- push access reads `true`;
- all five labels exist, and #188 reads `Project`;
- the handover's pull request is found;
- each of the eight issues is open, or its comment is dropped with the reason recorded;
- no new issue duplicates a row of the table above. If one does, use it instead of creating that
  item, and do not attach it if it already has a parent.

If #220 has not merged, the outcome entry says so, because every body cites its record.

## Step 1: the bodies

The bodies are in [Bodies](#bodies) below, one under each heading. Extract them mechanically: do
not retype them. A retyped body loses text silently. An unquoted heredoc would also expand
`$GITHUB_ACTION_PATH` (in `C153.md`), run every backticked span as a command, and fail on
`${{ … }}` (in `C100.md`).

```bash
. "$HOME/qe-handover-2026-10-06/env.sh"
gh api "repos/$R/contents/.qe/dev/log/2026-10-06-github-handover.md?ref=$HB" \
  -H 'Accept: application/vnd.github.raw' > "$W/handover.md" || stop "cannot fetch the handover"
awk -v W="$W" '
  /^### `[A-Za-z0-9_]+\.md`$/ { f = $2; gsub(/`/, "", f); next }
  /^~~~~markdown$/ && f != ""   { out = W "/" f; printf "" > out; inb = 1; next }
  /^~~~~$/ && inb               { close(out); inb = 0; f = ""; next }
  inb                           { print > out }
' "$W/handover.md"
[ "$(ls "$W"/[A-Z]*.md | wc -l)" -eq 16 ] || stop "expected 16 bodies"
[ -s "$W/subst.sed" ] || printf 's/{{DATE}}/%s/g\ns/{{HPR}}/%s/g\n' "$DATE" "$HPR" > "$W/subst.sed"
```

Placeholders such as `{{T_PREVIEW}}` are filled in from `$W/subst.sed`, which grows as issues are
created. Every write checks first that none is left. The check matches the placeholder names only,
because `C142.md` quotes `{{branch}}` from `build-containers.yml` on purpose.

**Check:** `$W` holds the 16 body files.

## Step 2: create the work items

The tracker's two items come first, because `T_PUBLISH`'s body cites `T_PREVIEW`. Then the
decision comes before its task, because the task's body cites the decision. Re-running this block
is safe: keys already in `$W/ids.env` are skipped.

```bash
. "$HOME/qe-handover-2026-10-06/env.sh"
create T_PREVIEW Task     "templates: deploy pull request previews from a job that runs no notebook code, and stop persisting checkout credentials" enhancement security &&
create T_PUBLISH Task     "publish-gh-pages: a deploy-only mode, so Pages is deployed from a job that runs no notebook code" enhancement security &&
create D_REBUILD Decision "Scheduled container rebuilds: refresh OS packages weekly, or pin the base image by digest and move it by pull request?" discuss security &&
create T_REBUILD Task     "build-containers: scheduled rebuilds republish a cached image, while the docs promise weekly security updates" bug security &&
create T_RESTORE Task     "restore-jupyter-cache: a mis-cased save-cache value silently stops the cache updating, and unknown input values are accepted" bug &&
create T_ALERT   Task     "build-jupyter-cache: the failure alert can land on an open pull request instead of an issue" bug low-priority \
  || stop "Step 2 stopped: fix the cause, then re-run this block"

# Assert each type by reading it back; set it where it is missing; show the labels.
for pair in T_PREVIEW:Task T_PUBLISH:Task D_REBUILD:Decision T_REBUILD:Task T_RESTORE:Task T_ALERT:Task; do
  key=${pair%%:*}; want=${pair#*:}; n=${!key}
  [ "$(gh api repos/$R/issues/$n --jq '.type.name // "NONE"')" = "$want" ] \
    || gh api -X PATCH repos/$R/issues/$n -f type="$want" >/dev/null
  echo "#$n want=$want $(gh api repos/$R/issues/$n --jq '"type=\(.type.name) labels=\([.labels[].name] | join(","))"')"
done
```

**Check:** six issues exist, each with exactly the type and labels in the table. Stop if any
differs.

## Step 3: create the tracker

```bash
. "$HOME/qe-handover-2026-10-06/env.sh"
[ -z "${P:-}" ] || { echo "tracker already created: #$P"; exit 0; }
[ "$(grep -cE '^(T|D)_[A-Z]+(_ID)?=[0-9]+$' "$W/ids.env")" -eq 12 ] || stop "Step 2 is incomplete"
sed -f "$W/subst.sed" "$W/P.md" > "$W/P.final.md"
grep -nE "$PH" "$W/P.final.md" && stop "unfilled placeholder in P"
jq -n --arg title "Keep deploy credentials out of the jobs that execute notebooks" \
      --rawfile body "$W/P.final.md" '{title: $title, body: $body, type: "Project"}' \
  | gh api -X POST repos/$R/issues --input - --jq '"P=\(.number)\nP_ID=\(.id)"' > "$W/P.out" \
  || stop "tracker create failed: see $W/P.out"
grep -qE '^P=[0-9]+$' "$W/P.out" || stop "unexpected response: see $W/P.out"
cat "$W/P.out" >> "$W/ids.env"; . "$W/ids.env"
printf 's/{{P}}/%s/g\n' "$P" >> "$W/subst.sed"
[ "$(gh api repos/$R/issues/$P --jq '.type.name // "NONE"')" = Project ] || gh api -X PATCH repos/$R/issues/$P -f type=Project >/dev/null
gh api repos/$R/issues/$P --jq '"#\(.number) type=\(.type.name) labels=\([.labels[].name])"'
```

**Check:** the tracker reads type `Project` and carries no labels.

## Step 4: attach the tracker's two work items, in plan order

The REST call below sends no `replace_parent`, so GitHub refuses an issue that already has a
parent rather than taking it from that parent. Do not substitute
`gh issue edit --add-sub-issue`, which replaces a parent silently. The parent check fails closed:
any answer other than "no parent" stops the block.

```bash
. "$HOME/qe-handover-2026-10-06/env.sh"
for key in T_PREVIEW T_PUBLISH; do
  n=${!key}; idvar=${key}_ID
  have=$(gh api repos/$R/issues/$P/sub_issues --jq '[.[].number] | map(tostring) | join(" ")')
  case " $have " in *" $n "*) echo "#$n already attached"; continue;; esac
  out=$(gh api repos/$R/issues/$n/parent 2>&1)
  case "$out" in *'No parent issue found'*|*'Not Found'*) ;; *) stop "#$n parent check: $out";; esac
  gh api -X POST repos/$R/issues/$P/sub_issues -F sub_issue_id=${!idvar} >/dev/null && echo "attached #$n"
done
gh api repos/$R/issues/$P/sub_issues --jq '[.[].number]'
echo "expect: [$T_PREVIEW,$T_PUBLISH]"
```

If the order differs, run
`gh api -X PATCH repos/$R/issues/$P/sub_issues/priority -F sub_issue_id=$T_PUBLISH_ID -F after_id=$T_PREVIEW_ID`,
or drag it in the UI. Both record the same fact.

## Step 5: the one dependency

The rebuild fix cannot start until the decision names which change to make. Its done-when is
defined separately for each option, and only the decision's ruling says which one applies. That
passes QEP-6's output test, so it gets a native edge, with or without a parent. No other pair
qualifies. For example, the publish split follows the preview split by preference only: it uses
the same build and deploy split, and needs nothing the preview split produces.

```bash
. "$HOME/qe-handover-2026-10-06/env.sh"
have=$(gh api repos/$R/issues/$T_REBUILD/dependencies/blocked_by --jq '[.[].number] | map(tostring) | join(" ")')
case " $have " in *" $D_REBUILD "*) echo "edge exists";; *)
  gh api -X POST repos/$R/issues/$T_REBUILD/dependencies/blocked_by -F issue_id=$D_REBUILD_ID >/dev/null || stop "dependency write failed";; esac
gh api repos/$R/issues/$T_REBUILD/dependencies/blocked_by --jq '[.[].number]'     # expect: [D_REBUILD]
```

If the API refuses, add the edge in the UI instead: on the `T_REBUILD` issue, open
*Relationships*, choose *Mark as blocked by*, and pick the `D_REBUILD` issue. Record that you did.

## Step 6: comments on the issues that own the other findings

Post each body as written. Do not touch those issues' labels, parents or bodies. The `posted`
file keeps a re-run from posting twice.

```bash
. "$HOME/qe-handover-2026-10-06/env.sh"
for n in 142 135 153 149 100 215 30 151; do
  grep -qx "$n" "$W/posted" 2>/dev/null && { echo "#$n already commented"; continue; }
  sed -f "$W/subst.sed" "$W/C$n.md" > "$W/C$n.final.md"
  grep -qE "$PH" "$W/C$n.final.md" && stop "unfilled placeholder in C$n"
  gh issue comment $n -R $R --body-file "$W/C$n.final.md" | tee -a "$W/comment-urls" && echo "$n" >> "$W/posted"
done
```

## Step 7: the tracker's first revision-log comment

History goes in the tracker's comments, not in its stamped section (QEP-7, *State, not story*).

```bash
. "$HOME/qe-handover-2026-10-06/env.sh"
grep -qx "LOG" "$W/posted" 2>/dev/null && { echo "already posted"; exit 0; }
sed -f "$W/subst.sed" "$W/LOG.md" > "$W/LOG.final.md"
grep -nE "$PH" "$W/LOG.final.md" && stop "unfilled placeholder in LOG"
gh issue comment $P -R $R --body-file "$W/LOG.final.md" | tee -a "$W/comment-urls" && echo LOG >> "$W/posted"
```

## Step 8: check the result

```bash
. "$HOME/qe-handover-2026-10-06/env.sh"
BODY=$(gh api repos/$R/issues/$P --jq .body)
gh api repos/$R/issues/$P --jq '"tracker: type=\(.type.name) labels=\([.labels[].name])"'         # Project, []
echo "stamps:   $(grep -c 'verified [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' <<<"$BODY")"                   # 1
echo "heading:  $(grep -c '^## Where we stand (verified [0-9-]*)$' <<<"$BODY")"                     # 1
echo "next:     $(grep -c '\*\*Next:\*\*' <<<"$BODY")"                                              # 1
echo "checkbox: $(grep -cE '^[[:space:]]*[-*] \[[ xX]\]' <<<"$BODY")"                               # 0
echo "unfilled: $(grep -cE "$PH" <<<"$BODY")"                                                      # 0
gh api repos/$R/issues/$P --jq '"sub-issues: \(.sub_issues_summary.total)"'                        # 2
for key in T_PREVIEW T_PUBLISH D_REBUILD T_REBUILD T_RESTORE T_ALERT; do
  n=${!key}
  parent=$(gh api repos/$R/issues/$n/parent --jq .number 2>/dev/null) || parent=none
  printf '%s #%s %s type-labels=%s parent=%s\n' "$key" "$n" \
    "$(gh api repos/$R/issues/$n --jq '"type=\(.type.name) labels=\([.labels[].name] | join(","))"')" \
    "$(gh api repos/$R/issues/$n --jq '[.labels[].name | select(test("^(bug|enhancement|documentation|infrastructure|maintenance|question|discuss|refactor|new-lecture)$"))] | length')" \
    "$parent"
done                    # type-labels=1 for all; parent=$P for T_PREVIEW and T_PUBLISH, none for the rest
gh api repos/$R/issues/$T_REBUILD/dependencies/blocked_by --jq '"blocked by: \([.[].number])"'    # [D_REBUILD]
for key in P T_PREVIEW T_PUBLISH D_REBUILD T_REBUILD T_RESTORE T_ALERT; do gh api repos/$R/issues/${!key} --jq .title; done \
  | grep -nE '(^|[ (])(W[0-9]+|[Pp]hase [0-9]+|[Ss]tage ?[0-9]+|[Ss]tep [0-9]+)([ :)]|$)' || echo "no sequence tokens in titles"
wc -l < "$W/comment-urls"                                                                        # 9
```

**Check:** every line matches its expected value. Open the tracker in the browser once: its
sub-issue list shows the preview item above the publish item. Then open the rebuild task: it
shows as blocked by the decision.

## Step 9: update the pull request that carries this handover

From a clone of QuantEcon/actions:

```bash
. "$HOME/qe-handover-2026-10-06/env.sh"
git fetch origin $HB && git switch $HB
```

Write `.qe/dev/log/<DATE>-github-handover-outcome.md`, a new raw record with this shape:

```markdown
# GitHub handover outcome, <DATE>

*A raw record under QEP-7. It carries out `.qe/dev/log/2026-10-06-github-handover.md` (QuantEcon/actions#<HPR>).*

## Created

| Key | Issue | Type | Parent | Labels |
|---|---|---|---|---|
| P | #… | Project | none | none |
| T_PREVIEW | #… | Task | P | enhancement, security |
| … | | | | |

Dependency: #<T_REBUILD> blocked by #<D_REBUILD>.

## Comments posted

The nine URLs from `$W/comment-urls`.

## Checks

The Step 8 output, pasted.

## Deviations

What differed from the handover, and why ("None" if nothing did). Include #220's state if it had not merged.
```

Commit it to this branch and push. Then comment on the pull request with the tracker link and
the result of `gh pr view 220 -R $R --json state --jq .state`. If that is not `MERGED`, say that
this pull request must wait for #220. Also say whether any deviation needs a maintainer's eye.
Leave the merge to a maintainer.

## Bodies

### `T_PREVIEW.md`

~~~~markdown
From the 2026-10-06 codebase review (finding M1; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

## Problem

Building the lectures runs code the repository does not fully control: notebook cells, including packages installed at build time, and network fetches. In `templates/ci.yml` that code runs in the same job, and the same container, as the later step that hands the Netlify (or Cloudflare) token to the deploy CLI (`templates/ci.yml:77-96`). Code that runs earlier in a job can affect the steps after it. So a compromised build dependency, on a pull request from a branch of the repository, shares a job with a long-lived deploy credential. Fork and Dependabot pull requests are not exposed: they get no secrets, and the preview actions skip them.

Separately, no template sets `persist-credentials: false` on `actions/checkout` (`templates/ci.yml:46-47`, `templates/cache.yml:59-64`, `templates/publish.yml:55-60`). The job token therefore stays available to build code for the whole job. This repository's own harness gate sets `persist-credentials: false` for that reason.

## Proposal

- Set `persist-credentials: false` on the checkout in all three templates. `cache.yml` and `publish.yml` run only local `git log` afterwards.
- Split `ci.yml` into two jobs:
  - **Build:** runs in the container with `contents: read`, builds the site, and uploads `_build/html` as an artifact.
  - **Deploy:** `needs:` the build job and needs no container. It holds `pull-requests: write` and the provider secret, checks out with `persist-credentials: false`, downloads the artifact, and runs `preview-netlify` (or `preview-cloudflare`). It never runs `jb build` or any repository script.
- Keep change detection working. `scripts/detect-changed-lectures.sh` fetches the base and head commits after a depth-1 checkout. Confirm it still lists the changed lectures without persisted credentials (a public repository fetches anonymously), and state what a private repository needs.
- Update the template comments, `docs/user/actions/preview-netlify.md`, `docs/user/actions/preview-cloudflare.md` and `CHANGELOG.md`.

## Done when

- All three templates check out with `persist-credentials: false`.
- `templates/ci.yml` deploys the preview from a job that runs no repository code, and the preview comment still links the changed lectures.
- The manual shows the two-job shape, and the harness's example check (`scripts/generate-docs.py --check-examples` with actionlint) passes on the new template.

## Related

- #153 plans a pull-request comment job that runs no repository code. The deploy job can host it.
- #151 bakes the deploy CLI into a preview image. Once the deploy runs in its own job, the build image no longer needs the CLI.
~~~~

### `T_PUBLISH.md`

~~~~markdown
From the 2026-10-06 codebase review (finding M1; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

## Problem

`publish-gh-pages` runs `configure-pages`, `upload-pages-artifact` and `deploy-pages` in one composite action (`publish-gh-pages/action.yml:95-105`), so a caller must build and deploy in the same job. That is why `templates/publish.yml` grants `pages: write` and `id-token: write` (`:44-48`) to the job that executes the notebooks.

GitHub's documented shape for Pages separates the two: the build job needs only `contents: read`, and the deploy job only deploys. The split does not protect the site's content, which the build produces either way. It keeps the Pages OIDC capability and the `pages: write` token away from code that runs at build time.

## Proposal

- A deploy-only mode for `publish-gh-pages`. For example, an input that selects upload, deploy or both, defaulting to both so callers on `@v0` see no change.
- `templates/publish.yml` in two jobs:
  - **Build:** in the container, `contents: read`, ending with the Pages artifact upload.
  - **Deploy:** `pages: write`, `id-token: write`, the `github-pages` environment, and nothing but the deploy.
- Release assets need `contents: write`, so give them their own job. Eight consumers create release assets (#27).
- Use the same build and deploy job split as #{{T_PREVIEW}}.

## Done when

- `templates/publish.yml` builds without the `pages` or `id-token` permissions, and deploys from a job that runs no repository code.
- By default `publish-gh-pages` behaves as it does now. The new mode is documented in `docs/user/actions/publish-gh-pages.md` and the CHANGELOG.
- The template passes the harness's example check (actionlint).

## Related

- #27 plans a `restore-gh-pages` action. It can use the deploy-only shape instead of copying the bundled one.
- A deploy-only job can run on a GitHub-hosted runner. That sidesteps the open question in `docs/dev/PLAN.md` about the Pages OIDC flow from RunsOn runners.
~~~~

### `D_REBUILD.md`

~~~~markdown
From the 2026-10-06 codebase review (finding M4; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

## The choice

What should a scheduled run of `build-containers.yml` do: refresh the images' OS packages every week, or leave the images alone until a pull request changes them?

## Why it needs deciding

`build-containers.yml` rebuilds both images every Monday (`:15-17`) and takes the layer cache from the published `:latest` (`cache-from` at `:79` and `:121`, `cache-to: type=inline`). BuildKit reuses a layer when its instruction and its parent are unchanged. So when `ubuntu:24.04` resolves to the same digest as last time, a scheduled run replays every layer from cache, including `apt-get install`, `conda env create` and the `build_date` marker, and republishes the same image. The build logs show this:

- fully cached, in about 20-40 s: the scheduled runs of 2026-08-31, 2026-09-07, 2026-09-21 and 2026-09-28;
- rebuilt, in about 7-8 min, because the base digest had moved: 2026-08-24, 2026-09-14 and 2026-10-05.

The documentation says something different:

- `README.md:156` promises "Weekly automated builds (Monday 2am UTC) for security updates".
- `containers/quantecon/README.md:135` says the image "automatically stays current with Ubuntu 24.04 security updates".
- `docs/dev/ARCHITECTURE.md:55` lists "Weekly rebuilds".

When the base does move, these re-resolve together, with no pull request:

- the lean image's unpinned conda packages: every entry in `containers/quantecon-build/environment.yml:32-57` except the ten pinned scientific packages, including `jupyter`, `jupyterlab`, `notebook`, `ipykernel`, `ipywidgets`, `plotly` and `mkl`;
- its `>=` pip floors;
- `quantecon-book-networks`, which is unpinned in both images.

## Options

**(a) Refresh weekly.**

- First pin the lean image's Python layer. The full image already uses `==` for its build tools.
- Then make scheduled runs actually rebuild, with `no-cache` on `schedule` events or a weekly cache-bust build argument on the apt step.
- OS updates then arrive weekly, and the Python stack moves only through pull requests.
- Cost: a cold build of about 7-8 min per image every week.
- Two cautions:
  - `no-cache-filters` cannot isolate the apt step in a single-stage Dockerfile.
  - Without the pinning first, this option turns the silent drift from every two or three weeks into every week.

**(b) Pin the base.**

- Pin `FROM ubuntu:24.04@sha256:…` in both Dockerfiles, so each base move arrives as a Dependabot pull request, which #142's planned pull-request builds would test.
- The Dependabot `docker` entry currently ignores `ubuntu` entirely (`.github/dependabot.yml`). It would need to allow digest updates while still holding the 24.04 tag.
- Drop the schedule, or keep it and document it as a cache warm-up.
- OS updates then arrive whenever Canonical republishes the base (every few weeks), reviewed rather than silent.

Either way, the three documents above must say what the images actually do. The task that implements the choice waits on this issue (native dependency).

**The review's recommendation:** (b), with the lean image's Python layer pinned too. Every change to an image then arrives as a pull request. That fits the dependency policy in `docs/dev/PLAN.md`, the reproducibility goal of #129 and the validation plan of #142. Choose (a) if weekly OS patches matter more than reviewing each image change.

## Closing

Close as completed, with the choice and its reasons recorded in a comment. If the question is mooted, close it as not planned, then re-scope or close the task that waits on it.
~~~~

### `T_REBUILD.md`

~~~~markdown
From the 2026-10-06 codebase review (finding M4; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

Scheduled runs of `build-containers.yml` replay the layer cache and republish an unchanged image whenever the `ubuntu:24.04` digest has not moved. Four of the seven Monday runs from 2026-08-24 to 2026-10-05 did this. Meanwhile:

- `README.md:156` promises weekly builds for security updates;
- `containers/quantecon/README.md:135` says the image stays current with Ubuntu security updates;
- `docs/dev/ARCHITECTURE.md:55` says it is rebuilt weekly.

The evidence and the options are in #{{D_REBUILD}}. This issue implements the policy chosen there, so it waits on that decision.

## Done when

- The two READMEs, `docs/dev/ARCHITECTURE.md` and the comments in `build-containers.yml` all describe the same policy for scheduled runs, and the workflow does what they say.
- Under option (a): the lean image's Python layer is pinned (`==`), and a scheduled run's log shows the apt layer executed, not `CACHED`.
- Under option (b): both Dockerfiles pin the base by digest, Dependabot can propose digest updates while holding the 24.04 tag, and the schedule is either removed or documented as a cache warm-up.
- #129 is cross-referenced for the reproducibility questions this does not settle.
~~~~

### `T_RESTORE.md`

~~~~markdown
From the 2026-10-06 codebase review (finding L3; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

`restore-jupyter-cache` checks none of its enumerated inputs:

- **`save-cache`** is tested case-sensitively in the shell (`restore-jupyter-cache/action.yml:101`, `:120`) but case-insensitively by the step condition `inputs.save-cache == 'true'` (`:174`). With `save-cache: 'True'`:
  - the first run saves under the read-only key, which has no run ID;
  - later runs match that key exactly, so the job-end save is skipped;
  - the pull request's cache stops updating, with no message.
- **`cache-type`** is compared only to `execution` (`:99`, `:146`). A typo such as `exec` silently restores the whole build cache, and the status report (`:231`, `:242`) prints neither type's section.
- **`fail-on-miss: yes`** is silently treated as false.

`build-jupyter-cache` already rejects unknown `builders` values, and `deploy-cloudflare` rejects unknown `require-access` values (`deploy-cloudflare/action.yml:120-123`). #160 raises the stakes: if `cache-type: execution` becomes the template default, a mistyped value silently brings back the stale-asset mode that #160 avoids.

## Done when

- A first step reads `cache-type`, `save-cache` and `fail-on-miss` through `env:` on every call, including calls with a custom `key`. It fails with an `::error::` on anything outside `build`/`execution` and `true`/`false`.
- A harness job modelled on `bjc-builders-parse` shows that `cache-type: exec` and `save-cache: True` fail the run.
- Each input's description states its accepted values, and so does the generated manual table.

This can ship with `docs/dev/PLAN.md` backlog item 18, which moves the same inputs into `env:`.
~~~~

### `T_ALERT.md`

~~~~markdown
From the 2026-10-06 codebase review (finding L1; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

`build-jupyter-cache` looks for an open failure issue with `listForRepo({state: 'open', labels: labels[0], per_page: 1})` and takes the first result (`build-jupyter-cache/action.yml:567-571`). The Issues API returns pull requests too. So suppose an open pull request carries `build-failure` (a fix PR, say) and is newer than any open failure issue. Then:

- the failure report is posted as a comment on that pull request;
- no issue is filed;
- `failure-issue-url` points at the pull request.

"Verify the failure alert was filed" (`:601-609`) checks only that a URL was produced, so it passes. Yet the `issue-labels` description promises that the first label "finds an open failure issue".

The alert is misrouted to a visible thread, not lost. `scripts/create-ci-failure-issue.sh` uses `gh issue list`, which returns issues only, so it is not affected.

## Done when

- The lookup lists more than one item (`per_page: 100`) and takes the first with no `pull_request` key. A labelled pull request then never receives the report, and a new issue is filed when none is open. Filtering the list is better here than the search API, which is eventually consistent and could let a second failure file a duplicate.
- The verification step fails if the URL points at a pull request.
- A test covers the case where the only open item with the label is a pull request.
~~~~

### `P.md`

~~~~markdown
*Goal: no workflow template in this repository runs notebook or repository code in a job that holds a deploy credential, a Pages or OIDC permission, or a persisted checkout token.*

## Where we stand (verified {{DATE}})

**Next:** #{{T_PREVIEW}}. Start from the checkout and deploy steps in `templates/ci.yml:46-96`; the two-job shape and the done-when are in the issue.

- Nothing is in flight. Both work items are open and unassigned.

## Plan

The work items and their order are the sub-issues below. The top one is next, and completed items keep their place.

**Sequencing rationale:** the preview split ranks first. The credential it protects is a long-lived provider token, which every repository that copies the preview template inherits. The publish split protects a short-lived Pages OIDC capability instead. It applies the same build and deploy split and needs nothing the preview split produces, so its place in the order is a preference, not a gate.

## Related work

- #92, preview-build speed:
  - its #153 plans a pull-request comment job that runs no repository code, and that job can share the deploy job this project adds;
  - its #151 bakes the deploy CLI into a preview image, which the build image no longer needs once the deploy runs in its own job.

## Out of scope / what does not change

- The integrity of the site's content. The build produces the deployed files either way: this project isolates credentials, not content.
- The other findings of the 2026-10-06 codebase review. Their dispositions are in `.qe/dev/log/2026-10-06-codebase-review.md` (QuantEcon/actions#220), and every issue filed from it opens with "From the 2026-10-06 codebase review".
~~~~

### `LOG.md`

~~~~markdown
**{{DATE}}: created** from the 2026-10-06 codebase review (record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220), by a local agent carrying out `.qe/dev/log/2026-10-06-github-handover.md` (QuantEcon/actions#{{HPR}}).

The review's fifteen findings were each checked against the code and searched for in existing issues and pull requests. This project is finding M1, deploy credentials sharing a job with notebook execution, as two work items: #{{T_PREVIEW}} and #{{T_PUBLISH}}.

The review's other new work does not share this goal, so it was filed as standalone issues:

- #{{D_REBUILD}}, a decision, and #{{T_REBUILD}}, which waits on it;
- #{{T_RESTORE}};
- #{{T_ALERT}}.

Of the remaining findings:

- eight were recorded as comments on the issues that own them (#142, #135, #153, #149, #100, #215, #30, #151);
- one is owned by `docs/dev/PLAN.md` backlog item 18;
- two were dropped.
~~~~

### `C142.md`

~~~~markdown
From the 2026-10-06 codebase review (finding H1; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

The review reached this issue's diagnosis independently, and its validation confirmed it against `build-containers.yml` at `4550f69`. These additions for phase 2 are not here yet:

- **An immutable candidate tag.** `type=sha,prefix={{branch}}-` gives `main-<sha>`. A scheduled or dispatched rebuild of an unchanged `main` overwrites that tag, and its contents can differ between builds because apt, conda and pip packages are unpinned. Gate on a tag that cannot be reused, such as a dated tag plus the SHA.
- **A rollback handle.** Write the pushed digest to the step summary. Old digests stay pullable, so `docker buildx imagetools create -t …:latest …@sha256:<old>` is a rollback, but nothing records which digest was last good. CONTRIBUTING's Rollback section covers only `v0`.
- **The mechanism.**
  - Call `test-container.yml` through `workflow_call` with an image input, and remove its `workflow_run` trigger, or it re-tests `:latest`.
  - Add a promote job in the same run, `needs:` the smoke test, that uses `imagetools create`, so the promoted digest is the tested digest.
  - Keeping the promote job in the same run means a cancelled newer run cannot leave an older candidate to be promoted.
  - Promote each image on its own, unless the two should move together.
- **What gates.** `test-containers-lectures.yml` takes two hours or more per `lecture-python.myst` leg, and it was red from mid-September until #159 closed on 2026-10-05. It fits better as a check after promotion than as the gate.
- **Clean-up.** Remove old candidate tags. Once this lands, replace CONTRIBUTING's "Container images do not stage" limit with the rollback procedure.

#150's dispatch tag input for `test-container.yml` overlaps the mechanism.
~~~~

### `C135.md`

~~~~markdown
From the 2026-10-06 codebase review (finding H2; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

Input for #138's open decision on whether the `build-jupyter-cache` residual is accepted or worth the ref rewrite. This issue frames the residual as release gating. The review found a consumer-facing side as well:

- **Pins are not hermetic.** A composite action's nested `uses:` is resolved when the job runs. So pinning `build-jupyter-cache` to an exact tag or a commit does not pin `setup-environment` or `build-lectures` (`build-jupyter-cache/action.yml:216`, `:232`, `:242`, `:252`): they follow `v0`. Because 0.x minor releases may break, an exactly pinned cache build can break when `v0` moves.
- **The docs disagree.** `CONTRIBUTING.md:36` and `README.md:181` offer exact pins as "maximum reproducibility". `docs/user/actions/build-jupyter-cache.md:129` says this action follows `v0` for its siblings. A one-line caveat in the version tables should land whichever way #138 decides.
- **A release-time rewrite closes both.** Rewriting the sibling refs in the tagged tree (to the release tag, or to a commit) makes pins hermetic, and lets the staged-release dispatch exercise the candidate's own siblings. The costs:
  - release tags point at commits that are not ancestors of `main`;
  - every release, patches included, repeats the rewrite, so a release check is needed that no `quantecon/actions/…@v0` remains in a tagged tree.

Impact as of 2026-10-06 is nil: every `build-jupyter-cache` consumer is on `@v0`, and every exact pin is on an action that calls no sibling. #83 part 1 asked for the same hermeticity. It was marked resolved by the earlier move of the refs from `@main` to `@v0` (#83 closed with #122), which met half of the ask.
~~~~

### `C153.md`

~~~~markdown
From the 2026-10-06 codebase review (finding M2; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

A bug for the extracted script to fix rather than carry over. Both actions find their earlier comment with one unpaginated `listComments` call (`preview-netlify/action.yml:250-257`, `preview-cloudflare/action.yml:286-293`), which returns only the first 30 comments.

Suppose a pull request already has more than 30 comments before its first preview, for example when the action is added to a long-running pull request. Then the comment is never found, and every push posts a new one. The user manual documents the symptom (`docs/user/actions/preview-netlify.md:224`, `docs/user/actions/preview-cloudflare.md:159`), but no issue tracks it. The match `c.body.includes(marker)` also accepts a comment from any author.

- Look up comments with `github.paginate(github.rest.issues.listComments, {owner, repo, issue_number, per_page: 100})`.
- Match only `github-actions[bot]` comments that carry a hidden marker for each provider (for example `<!-- quantecon-preview:netlify -->`). Keep accepting the current heading as well, so open pull requests do not each get one duplicate when this ships.
- Remove the two troubleshooting entries once fixed.
- Load the shared script from a path resolved from `$GITHUB_ACTION_PATH` in a bash step, as `detect-changed-lectures.sh` is, not from `github.action_path`. That answers the concern PR #46 raised.

The fix is a few lines, so it can also ship on its own, ahead of the extraction.
~~~~

### `C149.md`

~~~~markdown
From the 2026-10-06 codebase review (finding M3; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

Before `save-cache` is turned on here, it is worth bounding the cache storage it adds:

- With `save-cache: 'true'`, `restore-jupyter-cache` keys on the run ID (`restore-jupyter-cache/action.yml:101-121`) and registers a job-end save (`:173-180`). Every successful pull-request run therefore adds a full `_build` entry, and a save on every push to `main` adds another. GitHub evicts the least recently accessed caches when a repository passes its budget (10 GB by default), and an eviction reads as an ordinary miss in the status report.
- `build-jupyter-cache` already stores the execution cache twice: inside `_build`, and again as its own `jupyter-cache-…` entry (`build-jupyter-cache/action.yml:385-397`). No template restores the second copy.

Suggested to ship with the rollout:

- A `pull_request: closed` workflow that deletes the caches scoped to that pull request, which is GitHub's documented cleanup pattern. Deleting from inside the pull-request run does not work: a fork's token is read-only.
- The storage arithmetic (size of `_build` × open pull requests × pushes, against the budget) in the `save-cache` description.
- A decision, made with #160, on making the separate execution-cache save opt-in through a new input. Keep the default unchanged for one release, since `@v0` callers float, and add a CHANGELOG note.
~~~~

### `C100.md`

~~~~markdown
From the 2026-10-06 codebase review (finding M5; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

Two static checks for this coverage issue that nothing tracks yet:

- **actionlint over this repository's own workflows.** The harness gate installs and verifies actionlint, but `scripts/generate-docs.py --check-examples` gives it only `templates/` and the manual's examples. So `.github/workflows/*.yml` is never linted: about 2,400 lines, including the relevance gate whose self-test the required check depends on. Expect the first run to need a few fixes or documented `-ignore` flags.
- **shellcheck over the composite actions' `run:` blocks.** actionlint does not read `action.yml`, so nothing checks the 50 `run:` blocks in the eight actions. Extract them with PyYAML, replacing each `${{ … }}` with a placeholder word, then run shellcheck. A trial on `4550f69` at `shellcheck -S warning` found only constant-comparison hits (SC2050/SC2157), all at expression sites that `docs/dev/PLAN.md` backlog item 18 covers. At that severity the check should go green once those sites are handled. Default severity also reports info-level SC2086 hits, mostly unquoted `$GITHUB_OUTPUT`.

The rest of the finding is already filed:

- the comment-renderer and release-asset tests, in Stage 1.5 above;
- the `detect-changed-lectures.sh` unit job, in #215;
- running `publish-gh-pages` in the canary, in #135.
~~~~

### `C215.md`

~~~~markdown
From the 2026-10-06 codebase review (finding L4; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

The base-tip half of the review's finding is this issue. The general half is not filed anywhere: `scripts/detect-changed-lectures.sh` hides every git failure. Both fetches end in `2>/dev/null || true` (`:26-27`), and the name-status diff in `2>/dev/null || echo ""` (`:33`). So any failure yields an empty list, and the preview comment loses its lecture links without a warning. #164 saw this in the field and fixed one cause (git ownership in containers), but left the swallowing in place.

- Warn, with git's own message, whenever the diff fails, not only when the merge base is unreachable. This matters more once the three-dot diffs here and #147's shallow fetches land, since together they make an unreachable merge base more likely.
- At `:56`, a `git diff --quiet` that errors returns 128, which the `!` test reads as "changed": it fails open.
- One option avoids the checkout altogether: the pull request files API, which the harness gate already uses (`test-actions.yml:163-164`). Its caveats: renames come back as `renamed` with the new path, results stop at 3,000 files, and the list can race a new push.
~~~~

### `C30.md`

~~~~markdown
From the 2026-10-06 codebase review (finding L5; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

A requirement for the manifest rewrite. Today's generator (`publish-gh-pages/action.yml:152-163`) writes the asset name and the tag into JSON strings through a heredoc, with no escaping. `"` is legal in a git tag name, and a tag containing one produces a manifest that does not parse. This was reproduced by rendering the heredoc with such a tag and piping the result to `jq .`.

As of 2026-10-06 no QuantEcon publish tag contains one. But eight consumers write this manifest on every tagged publish (see #27), so the fix belongs in the rewrite:

- Build the manifest with a JSON encoder (`jq -n --arg … --argjson …`, or `json.dump`), keeping field names, order and number types.
- Add a fixture test (#100 Stage 1.5) whose tag contains `"`, and check that the manifest parses and round-trips the tag.
~~~~

### `C151.md`

~~~~markdown
From the 2026-10-06 codebase review (finding L6; record: `.qe/dev/log/2026-10-06-codebase-review.md`, QuantEcon/actions#220).

This issue will add a third copy of the image recipe, and it already plans a parity assertion for its package pins. Worth widening that assertion to the security-relevant lines every Dockerfile repeats by hand:

- `MINICONDA_VERSION` / `MINICONDA_SHA256`;
- `NODE_VERSION` / `NODE_SHA256`;
- `git config --system --add safe.directory '*'`.

As of 2026-10-06 these lines match exactly between `containers/quantecon/Dockerfile` and `containers/quantecon-build/Dockerfile`. They match only by convention, though: only the full image carries a "kept in sync" note, and #32 was exactly this drift. Alternatively, if this issue introduces a shared base stage, both existing images could use it.

One incidental drift to settle at the same time: the fontconfig cache directory is mode `777` in the full image and `755` in the lean one.
~~~~
