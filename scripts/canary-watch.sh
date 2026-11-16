#!/usr/bin/env bash
#
# Watch the canary's scheduled workflows (#302). canary-watch.yml runs it
# daily. The canary runs the released actions through @v0 on a schedule, and
# nobody watches those runs: its cache.yml was red for eight Sundays from
# February 2026, then GitHub disabled its schedule after 60 days with no
# push, and 16 Sundays passed with no run at all. A check inside the canary
# cannot see the second, so this one runs here and reads the canary through
# the API.
#
#   scripts/canary-watch.sh                  one markdown list item per
#                                            workflow; exits 1 if any is red
#   scripts/canary-watch.sh --report FILE    record FILE's findings, for
#                                            TOPIC, on the open issue
#   scripts/canary-watch.sh --verdict FILE STATUS HEADING
#                                            a job's verdict, from its
#                                            findings and their exit status,
#                                            as its summary and outputs
#   scripts/canary-watch.sh --self-test
#
# A workflow is red when it is not `active`, when its newest completed
# scheduled run on main is missing or more than MAX_AGE_HOURS old, or when
# that run did not succeed. One the API does not answer for is red too:
# the watcher cannot tell.
#
# --report keeps one open issue with the `canary` label, on which each TOPIC
# keeps its own record: `runs`, these findings, and `drift`,
# scripts/canary-drift.py's. A red verdict opens the issue, or comments on
# it, and assigns it to ASSIGNEES; a green one comments that the topic is
# green again. Each body and comment ends in a hidden marker of the state it
# records for its topic: the red findings' hash, or `green`. The watcher
# runs daily, so a state the topic's last marker already records adds
# nothing: a red that persists is reported once, and the same red after a
# green run is reported again. Only markers that MARKER_AUTHOR wrote count,
# since anyone can comment on a public repository's issue.
#
# The check's environment:
#   CANARY_REPO       the canary, as owner/name
#   CANARY_WORKFLOWS  the workflows' file names, separated by spaces
#   MAX_AGE_HOURS     the oldest the newest scheduled run may be, in hours
#   GH_TOKEN          any token: the canary is public
#   NOW               optional: the time to measure from, in epoch seconds
#
# The report's, besides CANARY_REPO:
#   GH_REPO           where the issue goes, as owner/name
#   GH_TOKEN          a token with issues: write there
#   RUN_URL           the watcher's run
#   WATCH_RESULT      the result of the job that gave the findings: `success`
#                     is a green verdict, anything else a red one
#   TOPIC             optional: `runs`, the default, or `drift`
#   MARKER_AUTHOR     optional: the login that writes the issue, as the REST
#                     API names it; `github-actions[bot]`, the default, is
#                     GITHUB_TOKEN's. A token of another kind needs its own.
#   ASSIGNEES         optional: the logins to assign, separated by commas
#                     or spaces
set -euo pipefail

# shellcheck source=scripts/workflow-command.sh
. "$(dirname "${BASH_SOURCE[0]}")/workflow-command.sh"

fail() { annotate error "$*" >&2; exit 2; }

LABEL=canary
# A watcher that stopped before its verdict, whichever job or step finds
# it. The text is fixed, so a watcher that stays broken is reported once;
# the run's link is in the comment's first line, outside the hash.
STOPPED="- 🔴 The watcher stopped before it reached a verdict: see the run's log."
WORK=$(mktemp -d "${TMPDIR:-/tmp}/canary-watch.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# The last line gh wrote to the file, without its "gh: " prefix.
reason() {
  local last
  last=$(tail -n 1 "$1")
  printf '%s' "${last#gh: }"
}

check() {
  local wf json state fields id conclusion created epoch url when age red=0 err enable stale
  [[ ${CANARY_REPO:-} =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "CANARY_REPO [${CANARY_REPO:-}] is not owner/name"
  [[ ${MAX_AGE_HOURS:-} =~ ^[1-9][0-9]*$ ]] || fail "MAX_AGE_HOURS [${MAX_AGE_HOURS:-}] is not a positive whole number"
  [[ ${NOW:-0} =~ ^[0-9]+$ ]] || fail "NOW [$NOW] is not a time in epoch seconds"
  [ -n "${CANARY_WORKFLOWS// /}" ] || fail "CANARY_WORKFLOWS lists no workflow"
  for wf in $CANARY_WORKFLOWS; do
    [[ $wf =~ ^[A-Za-z0-9_.-]+\.ya?ml$ ]] || fail "CANARY_WORKFLOWS: [$wf] is not a workflow's file name"
  done
  err=$WORK/err

  for wf in $CANARY_WORKFLOWS; do
    enable="\`gh workflow enable $wf --repo $CANARY_REPO\`"
    : > "$err"
    if ! json=$(gh api "repos/$CANARY_REPO/actions/workflows/$wf" 2> "$err") \
      || ! state=$(jq -r '.state | strings' <<< "$json" 2> /dev/null) || [ -z "$state" ]; then
      echo "- 🔴 \`$wf\`: the API did not say whether it is enabled ($(reason "$err" | grep . || echo 'its answer had no state'))."
      red=1; continue
    fi
    case $state in
      active) ;;
      disabled_inactivity)
        echo "- 🔴 \`$wf\` is disabled: GitHub turned its schedule off after 60 days with no activity in the canary, so it runs nothing. Enable it with $enable, and push to the canary at least every 60 days."
        red=1; continue ;;
      disabled_manually)
        echo "- 🔴 \`$wf\` was disabled by hand, so it runs nothing. Enable it with $enable, or, if that was meant, take it off the list in \`canary-watch.yml\`."
        red=1; continue ;;
      *)
        echo "- 🔴 \`$wf\` is \`$state\`, not \`active\`, so it runs nothing."
        red=1; continue ;;
    esac

    : > "$err"
    # Five lines for the newest completed run, or none when there is no
    # such run; anything else is an answer this cannot read. A run that is
    # queued or in progress is not listed.
    if ! json=$(gh api "repos/$CANARY_REPO/actions/workflows/$wf/runs?event=schedule&branch=main&status=completed&per_page=1" 2> "$err") \
      || ! fields=$(jq -r '
          if (.workflow_runs | type) != "array" then error("no workflow_runs")
          elif (.workflow_runs | length) == 0 then empty
          else .workflow_runs[0]
            | (.id | numbers | tostring), (.conclusion | strings), (.created_at | strings),
              (.created_at | strings | fromdate | tostring), (.html_url | strings)
          end' <<< "$json" 2> /dev/null); then
      echo "- 🔴 \`$wf\`: the API did not list its scheduled runs ($(reason "$err" | grep . || echo 'its answer was not a list of runs'))."
      red=1; continue
    fi
    if [ -z "$fields" ]; then
      echo "- 🔴 \`$wf\` has never completed a scheduled run on \`main\`."
      red=1; continue
    fi
    if [ "$(wc -l <<< "$fields")" -ne 5 ]; then
      echo "- 🔴 \`$wf\`: the API listed a scheduled run with no id, conclusion, time or URL."
      red=1; continue
    fi
    { read -r id; read -r conclusion; read -r created; read -r epoch; read -r url; } <<< "$fields"
    when="${created:0:10} ${created:11:5} UTC"
    age=$(( (${NOW:-$(date +%s)} - epoch) / 3600 ))
    stale=''
    [ "$age" -le "$MAX_AGE_HOURS" ] || stale=" more than $MAX_AGE_HOURS hours ago, and no scheduled run has completed since. The workflow is enabled, so check its \`on.schedule\`, and the canary's Actions tab for a run that is queued or stuck."
    if [ -n "$stale" ] && [ "$conclusion" = success ]; then
      echo "- 🔴 \`$wf\`: its newest completed scheduled run on \`main\`, [$id]($url), succeeded on $when,$stale"
      red=1
    elif [ -n "$stale" ]; then
      echo "- 🔴 \`$wf\`: its newest completed scheduled run on \`main\`, [$id]($url), concluded \`$conclusion\` on $when,$stale"
      red=1
    elif [ "$conclusion" != success ]; then
      echo "- 🔴 \`$wf\`: its newest scheduled run on \`main\`, [$id]($url) on $when, concluded \`$conclusion\`."
      red=1
    else
      echo "- ✅ \`$wf\`: its newest scheduled run on \`main\`, [$id]($url) on $when, succeeded."
    fi
  done
  return "$red"
}

# The logins in ASSIGNEES, each added to the issue. One that cannot be
# assigned is warned about, and the rest are still added.
assign() {
  local issue=$1 login logins list=${ASSIGNEES:-}
  read -ra logins <<< "${list//,/ }"
  if [ "${#logins[@]}" -eq 0 ]; then
    annotate warning "CANARY_ASSIGNEES is not set, so #$issue is assigned to nobody: it reaches only those watching this repository"
    return 0
  fi
  for login in "${logins[@]}"; do
    if [[ ! $login =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,38})$ ]]; then
      annotate warning "CANARY_ASSIGNEES: [$login] is not a GitHub login, so it was not assigned"
    elif ! gh issue edit "$issue" --add-assignee "$login" > /dev/null; then
      annotate warning "#$issue could not be assigned to $login"
    fi
  done
}

# markers ISSUE TAG: the markers MARKER_AUTHOR wrote on the issue for a
# topic, in its body and its comments, oldest first, one a line. TAG is
# empty for `runs`, whose markers are `<!-- canary-watch: … -->`, and
# ` drift` for `drift`'s, `<!-- canary-watch drift: … -->`. A marker anyone
# else wrote is not read. It fails when the issue or its comments cannot be read: run inside
# $(...), where set -e does not stop it, a failed read would otherwise give
# no markers, and a duplicate comment.
markers() {
  gh api "repos/$GH_REPO/issues/$1" > "$WORK/issue.json" || return 1
  gh api --paginate "repos/$GH_REPO/issues/$1/comments?per_page=100" > "$WORK/comments.json" || return 1
  { jq -c '[.]' "$WORK/issue.json" && cat "$WORK/comments.json"; } \
    | jq -rs --arg author "$MARKER_AUTHOR" --arg tag "$2" '
        add | map(select(.user.login == $author) | (.body // "")
          | scan("<!-- canary-watch" + $tag + ": ([0-9a-f]{64}|green) -->")[0]) | .[]'
}

report() {
  local file=$1 red state title issue last body url what again green about tag
  [ -f "$file" ] || fail "no findings file [$file]"
  [[ ${CANARY_REPO:-} =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "CANARY_REPO [${CANARY_REPO:-}] is not owner/name"
  : "${GH_REPO:?GH_REPO is required, as owner/name}" "${RUN_URL:?RUN_URL is required}" \
    "${WATCH_RESULT:?WATCH_RESULT is required: the result of the job that gave the findings}"
  MARKER_AUTHOR=${MARKER_AUTHOR:-github-actions[bot]}
  [[ $MARKER_AUTHOR =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,38})(\[bot\])?$ ]] || fail "MARKER_AUTHOR [$MARKER_AUTHOR] is not a GitHub login"
  title="🔴 Canary watch: $CANARY_REPO"
  case ${TOPIC:-runs} in
    runs)
      tag=''
      what="The canary's scheduled runs need attention"
      again="The canary's scheduled runs are red again"
      green="The canary's scheduled runs are green again"
      about="The canary, [$CANARY_REPO](https://github.com/$CANARY_REPO), runs the released actions through \`@v0\` on a schedule. A red run there can be a regression in a release, or in something the actions call that changes without one: a floating major version, a deploy service, a token. A disabled or missing run means the canary has stopped testing anything." ;;
    drift)
      tag=' drift'
      what="The canary's workflows have drifted from \`templates/\` at \`v0\`"
      again="The canary's workflows have drifted again"
      green="The canary's workflows match \`templates/\` at \`v0\` again"
      about="The canary, [$CANARY_REPO](https://github.com/$CANARY_REPO), runs \`templates/\` as they are at \`v0\`, so that a real lecture repository runs what consumers copy, with the differences \`.github/canary-drift.yml\` declares. A release that changes a template turns this red until a canary pull request realigns its copy, unless the change is to a third-party action's version, or under a path that file declares. A difference the canary keeps on purpose goes in that file instead, with its reason." ;;
    *) fail "TOPIC [$TOPIC] is not runs or drift" ;;
  esac
  red=$(grep '^- 🔴' "$file" || true)
  if [ "$WATCH_RESULT" = success ] && [ -z "$red" ]; then
    state=green
  else
    if [ -z "$red" ]; then
      # A job that timed out, or failed before its verdict.
      red=$STOPPED
      printf '%s\n' "$red" >> "$file"
    fi
    state=$(printf '%s\n' "$red" | sha256sum | cut -d' ' -f1)
  fi
  body=$WORK/body

  # A green run reads before the label exists: listing by a label the
  # repository does not have yet lists nothing, and exits 0.
  [ "$state" = green ] || gh label create "$LABEL" --color B60205 --force \
    --description "The canary's scheduled runs are red, missing or disabled, or its workflows have drifted (canary-watch.yml)" > /dev/null
  issue=$(gh issue list --state open --label "$LABEL" --limit 100 --json number,title \
    | jq -r --arg title "$title" 'map(select(.title == $title)) | .[0].number // empty')

  if [ -z "$issue" ] && [ "$state" = green ]; then
    echo "Green, with no open issue: nothing to record"
    return 0
  fi
  if [ -n "$issue" ]; then
    markers "$issue" "$tag" > "$WORK/markers" || fail "#$issue or its comments could not be read, so nothing was recorded"
    last=$(tail -n 1 "$WORK/markers")
    if [ "$last" = "$state" ]; then
      echo "#$issue already records this state, so nothing was added"
      return 0
    fi
    if [ "$state" = green ] && [ -z "$last" ]; then
      echo "#$issue records nothing red for this topic, so nothing was added"
      return 0
    fi
    if [ "$state" = green ]; then
      {
        echo "$green, in [this run]($RUN_URL):"
        echo
        cat "$file"
        echo
        echo "Close this issue once nothing more is needed. A later red finding comments here, or opens a fresh issue if this one is closed."
        echo
        echo "<!-- canary-watch$tag: green -->"
      } > "$body"
      echo "Recording on #$issue that the topic is green again"
      gh issue comment "$issue" --body-file "$body" > /dev/null
      return 0
    fi
    {
      if [ -z "$last" ]; then
        echo "$what, as [this run]($RUN_URL) found:"
      elif [ "$last" = green ]; then
        echo "$again, in [this run]($RUN_URL):"
      else
        echo "The findings changed, in [this run]($RUN_URL):"
      fi
      echo
      cat "$file"
      if [ -z "$last" ]; then
        echo
        echo "$about"
      fi
      echo
      echo "<!-- canary-watch$tag: $state -->"
    } > "$body"
    echo "Commenting on the open issue, #$issue"
    gh issue comment "$issue" --body-file "$body" > /dev/null
  else
    {
      echo "$what, as [this run]($RUN_URL) of \`canary-watch.yml\` found:"
      echo
      cat "$file"
      echo
      echo "$about"
      echo
      echo "The watcher runs daily, and both of its checks, the scheduled runs and drift, report here. It comments when a check's findings change, and once when a check is green again. Close this issue once nothing more is needed: the next red finding then opens a fresh one."
      echo
      echo "<!-- canary-watch$tag: $state -->"
    } > "$body"
    echo "No open issue: opening one"
    url=$(gh issue create --title "$title" --label "$LABEL" --body-file "$body")
    issue=${url##*/}
    [[ $issue =~ ^[0-9]+$ ]] || fail "gh issue create printed [$url], not an issue's URL"
  fi
  assign "$issue"
}

# A job's verdict, from the findings FILE and the exit STATUS of what wrote
# them: the findings in the log and under HEADING in the step summary, and
# as the step's outputs `findings` and `red`. A non-zero status with no red
# finding, as from a script that stopped, adds STOPPED, so the findings say
# why they are red.
verdict() {
  local file=$1 status=$2 heading=$3 delim
  [[ $status =~ ^[0-9]+$ ]] || fail "STATUS [$status] is not an exit status"
  : "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}" "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is required}"
  touch "$file"
  # A last line with no newline would take the output's delimiter with it.
  if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then echo >> "$file"; fi
  if [ "$status" -ne 0 ] && ! grep -q '^- 🔴' "$file"; then
    annotate error "what wrote the findings exited $status with no red finding"
    printf '%s\n' "$STOPPED" >> "$file"
  fi
  cat "$file"
  { echo "### $heading"; echo; cat "$file"; } >> "$GITHUB_STEP_SUMMARY"
  delim="FINDINGS_$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  {
    echo "findings<<$delim"
    cat "$file"
    echo "$delim"
    if [ "$status" -eq 0 ]; then echo "red=false"; else echo "red=true"; fi
  } >> "$GITHUB_OUTPUT"
}

self_test() {
  local out got H failures=0
  local LOG=$WORK/log SENT=$WORK/sent
  CANARY_REPO=o/r
  MAX_AGE_HOURS=192
  NOW=$(jq -n '"2026-11-16T06:30:00Z" | fromdate')
  mkdir "$WORK/api"
  # A failed case is reported, and the rest still run.
  bad() { annotate error "$*" >&2; failures=$((failures + 1)); }
  # answer PATH VALUE: what the stand-in gh prints for `gh api PATH`.
  answer() { printf '%s\n' "$2" > "$WORK/api/${1//[^A-Za-z0-9._-]/_}"; }

  # A run's list, as the API answers: an id, a conclusion and a time.
  runs_json() { printf '{"workflow_runs":[{"id":%s,"conclusion":"%s","created_at":"%s","html_url":"https://github.com/o/r/actions/runs/%s"}]}' "$1" "$2" "$3" "$1"; }
  # A stand-in for gh. `api` prints what `answer` gave its path, and fails
  # as gh does for `fail`. Every other call is logged, with BODY for the
  # file given as --body-file, which is kept in SENT; the issue commands
  # answer from ISSUES. A call it does not expect fails the self-test.
  gh() {
    local key arg prev='' logged=() path=''
    if [ "$1" = api ]; then
      for arg in "${@:2}"; do
        [[ $arg == --* ]] || { path=$arg; break; }
      done
      case $path in
        *'?'*)
          [[ $path == *'/runs?event=schedule&branch=main&status=completed&per_page=1' \
            || ( $path == */comments'?per_page=100' && $2 == --paginate ) ]] \
            || fail "self-test: gh called as [gh $*]" ;;
      esac
      key=$WORK/api/${path//[^A-Za-z0-9._-]/_}
      [ -f "$key" ] || fail "self-test: no answer for [gh $*]"
      if [ "$(cat "$key")" = fail ]; then echo 'gh: Not Found (HTTP 404)' >&2; return 1; fi
      cat "$key"
      return 0
    fi
    for arg in "$@"; do
      if [ "$prev" = --body-file ]; then cp "$arg" "$SENT"; logged+=(BODY); else logged+=("$arg"); fi
      prev=$arg
    done
    printf '%s\n' "${logged[*]}" >> "$LOG"
    case "$1 $2" in
      'label create' | 'issue comment') ;;
      'issue list') printf '%s\n' "$ISSUES" ;;
      'issue create') echo 'https://github.com/o/actions/issues/9' ;;
      'issue edit') [ "$5" != ghost ] ;;
      *) fail "self-test: gh called as [gh $*]" ;;
    esac
  }

  # A check case: a name, the exit status expected, and the line expected
  # for each workflow in CANARY_WORKFLOWS, in order.
  check_case() {
    local name=$1 want=$2 status=0
    shift 2
    out=$(check) || status=$?
    got=$(printf '%s\n' "$@")
    if [ "$status" != "$want" ]; then
      bad "self-test: check [$name] exited $status, expected $want; it printed [$out]"
    elif [ "$out" != "$got" ]; then
      bad "self-test: check [$name] printed [$out], expected [$got]"
    fi
  }

  CANARY_WORKFLOWS=a.yml
  local wf=repos/o/r/actions/workflows/a.yml
  local rk='repos/o/r/actions/workflows/a.yml/runs?event=schedule&branch=main&status=completed&per_page=1'
  local link='[7](https://github.com/o/r/actions/runs/7) on 2026-11-15 03:07 UTC'
  local since=" more than 192 hours ago, and no scheduled run has completed since. The workflow is enabled, so check its \`on.schedule\`, and the canary's Actions tab for a run that is queued or stuck."
  answer "$wf" '{"state":"active"}'

  answer "$rk" "$(runs_json 7 success 2026-11-15T03:07:35Z)"
  check_case green 0 "- ✅ \`a.yml\`: its newest scheduled run on \`main\`, $link, succeeded."
  for c in failure cancelled timed_out startup_failure skipped; do
    answer "$rk" "$(runs_json 7 "$c" 2026-11-15T03:07:35Z)"
    check_case "$c" 1 "- 🔴 \`a.yml\`: its newest scheduled run on \`main\`, $link, concluded \`$c\`."
  done
  # 06:30 on the 16th is 192 hours after 06:30 on the 8th, and 193 after 05:30.
  answer "$rk" "$(runs_json 7 success 2026-11-08T06:30:00Z)"
  check_case 'at the limit' 0 "- ✅ \`a.yml\`: its newest scheduled run on \`main\`, [7](https://github.com/o/r/actions/runs/7) on 2026-11-08 06:30 UTC, succeeded."
  answer "$rk" "$(runs_json 7 success 2026-11-08T05:30:00Z)"
  check_case stale 1 "- 🔴 \`a.yml\`: its newest completed scheduled run on \`main\`, [7](https://github.com/o/r/actions/runs/7), succeeded on 2026-11-08 05:30 UTC,$since"
  answer "$rk" "$(runs_json 7 failure 2026-11-08T05:30:00Z)"
  check_case 'stale and red' 1 "- 🔴 \`a.yml\`: its newest completed scheduled run on \`main\`, [7](https://github.com/o/r/actions/runs/7), concluded \`failure\` on 2026-11-08 05:30 UTC,$since"
  answer "$rk" '{"total_count":0,"workflow_runs":[]}'
  check_case never 1 "- 🔴 \`a.yml\` has never completed a scheduled run on \`main\`."
  answer "$rk" fail
  check_case 'runs not listed' 1 "- 🔴 \`a.yml\`: the API did not list its scheduled runs (Not Found (HTTP 404))."
  answer "$rk" '<html>502</html>'
  check_case 'runs not JSON' 1 "- 🔴 \`a.yml\`: the API did not list its scheduled runs (its answer was not a list of runs)."
  answer "$rk" '{"message":"rate limited"}'
  check_case 'no runs key' 1 "- 🔴 \`a.yml\`: the API did not list its scheduled runs (its answer was not a list of runs)."
  answer "$rk" '{"workflow_runs":[{"id":7,"conclusion":null,"created_at":"2026-11-15T03:07:35Z","html_url":"u"}]}'
  check_case 'run without a conclusion' 1 "- 🔴 \`a.yml\`: the API listed a scheduled run with no id, conclusion, time or URL."
  answer "$rk" '{"workflow_runs":[{"id":7,"conclusion":"success","created_at":"Sunday","html_url":"u"}]}'
  check_case 'run with a bad time' 1 "- 🔴 \`a.yml\`: the API did not list its scheduled runs (its answer was not a list of runs)."

  answer "$rk" "$(runs_json 7 success 2026-11-15T03:07:35Z)"
  answer "$wf" '{"state":"disabled_inactivity"}'
  check_case 'disabled for inactivity' 1 "- 🔴 \`a.yml\` is disabled: GitHub turned its schedule off after 60 days with no activity in the canary, so it runs nothing. Enable it with \`gh workflow enable a.yml --repo o/r\`, and push to the canary at least every 60 days."
  answer "$wf" '{"state":"disabled_manually"}'
  check_case 'disabled by hand' 1 "- 🔴 \`a.yml\` was disabled by hand, so it runs nothing. Enable it with \`gh workflow enable a.yml --repo o/r\`, or, if that was meant, take it off the list in \`canary-watch.yml\`."
  answer "$wf" '{"state":"deleted"}'
  check_case deleted 1 "- 🔴 \`a.yml\` is \`deleted\`, not \`active\`, so it runs nothing."
  answer "$wf" fail
  check_case 'not found' 1 "- 🔴 \`a.yml\`: the API did not say whether it is enabled (Not Found (HTTP 404))."
  answer "$wf" '{"id":1}'
  check_case 'no state' 1 "- 🔴 \`a.yml\`: the API did not say whether it is enabled (its answer had no state)."

  # Two workflows: each gets its line, and one red makes the whole red.
  answer "$wf" '{"state":"active"}'
  answer "repos/o/r/actions/workflows/b.yml" '{"state":"disabled_inactivity"}'
  CANARY_WORKFLOWS='a.yml b.yml'
  check_case 'one of two red' 1 \
    "- ✅ \`a.yml\`: its newest scheduled run on \`main\`, $link, succeeded." \
    "- 🔴 \`b.yml\` is disabled: GitHub turned its schedule off after 60 days with no activity in the canary, so it runs nothing. Enable it with \`gh workflow enable b.yml --repo o/r\`, and push to the canary at least every 60 days."

  # A bad setting is refused before any call.
  for bad in '../a.yml' 'a.txt' ' '; do
    CANARY_WORKFLOWS=$bad
    if (check > /dev/null 2>&1); then bad "self-test: check accepted CANARY_WORKFLOWS [$bad]"; fi
  done
  CANARY_WORKFLOWS=a.yml
  for bad in 0 x 1.5; do
    if (MAX_AGE_HOURS=$bad check > /dev/null 2>&1); then bad "self-test: check accepted MAX_AGE_HOURS [$bad]"; fi
  done
  echo "canary-watch self-test: check done"

  # The report. A case reports FINDINGS with the watch job's WATCH_RESULT,
  # ASSIGNEES, and the open issues in ISSUES, whose body and comments
  # on_issue sets; it compares the calls made with those given.
  GH_REPO=o/actions
  RUN_URL=https://github.com/o/actions/actions/runs/1
  local findings=$WORK/findings title="🔴 Canary watch: o/r" bot='github-actions[bot]'
  local label="label create canary --color B60205 --force --description The canary's scheduled runs are red, missing or disabled, or its workflows have drifted (canary-watch.yml)"
  local list="issue list --state open --label canary --limit 100 --json number,title"
  local create="issue create --title $title --label canary --body-file BODY"
  local RED GREEN Z A
  RED=$(printf '%s\n' "- ✅ \`a.yml\`: fine." "- 🔴 \`b.yml\`: red.")
  GREEN=$(printf '%s\n' "- ✅ \`a.yml\`: fine." "- ✅ \`b.yml\`: fine.")
  H=$(printf '%s\n' "- 🔴 \`b.yml\`: red." | sha256sum | cut -d' ' -f1)
  Z=$(printf '0%.0s' {1..64})
  A=$(printf 'a%.0s' {1..64})
  m() { printf '<!-- canary-watch: %s -->' "$1"; }
  # on_issue BODY [LOGIN:COMMENT]...: issue 5 is open, with BODY by the
  # workflow's token, or by BODY_BY, and each comment by its login.
  on_issue() {
    local c json='[]'
    ISSUES='[{"number":5,"title":"'"$title"'"}]'
    answer repos/o/actions/issues/5 "$(jq -nc --arg by "${BODY_BY:-$bot}" --arg b "$1" '{user: {login: $by}, body: $b}')"
    shift
    for c in "$@"; do
      json=$(jq -c --arg by "${c%%:*}" --arg b "${c#*:}" '. + [{user: {login: $by}, body: $b}]' <<< "$json")
    done
    answer 'repos/o/actions/issues/5/comments?per_page=100' "$json"
  }
  report_case() {
    local name=$1 want
    shift
    : > "$LOG"; : > "$SENT"
    printf '%s\n' "$FINDINGS" > "$findings"
    if ! out=$(report "$findings" 2>&1); then
      bad "self-test: report [$name] failed: [$out]"
      return
    fi
    want=$(printf '%s\n' "$@")
    [ "$(cat "$LOG")" = "$want" ] || bad "self-test: report [$name] called [$(cat "$LOG")], expected [$want]"
  }
  sent() { grep -qF -- "$2" "$SENT" || bad "self-test: report [$1] sent no [$2]: [$(cat "$SENT")]"; }
  said() { [[ $out == *"$2"* ]] || bad "self-test: report [$1] said [$out], with no [$2]"; }

  WATCH_RESULT=failure FINDINGS=$RED ASSIGNEES=mmcky ISSUES='[]' BODY_BY=''
  report_case 'new issue' "$label" "$list" "$create" "issue edit 9 --add-assignee mmcky"
  sent 'new issue' "- 🔴 \`b.yml\`: red."
  sent 'new issue' "- ✅ \`a.yml\`: fine."
  sent 'new issue' "$(m "$H")"
  sent 'new issue' "($RUN_URL)"

  on_issue "old $(m "$Z")" "$bot:$(m "$H")"
  report_case 'same findings' "$label" "$list"
  said 'same findings' '#5 already re'

  ASSIGNEES='mmcky,other'
  on_issue "$(m "$H")" "$bot:$(m "$A")"
  report_case 'changed findings' "$label" "$list" "issue comment 5 --body-file BODY" \
    "issue edit 5 --add-assignee mmcky" "issue edit 5 --add-assignee other"
  sent 'changed findings' "$(m "$H")"
  sent 'changed findings' 'The findings changed'

  # A red, a green run, then the same red: reported again.
  ASSIGNEES=mmcky
  on_issue "$(m "$H")" "$bot:$(m green)"
  report_case 'the same red after a green run' "$label" "$list" "issue comment 5 --body-file BODY" "issue edit 5 --add-assignee mmcky"
  sent 'the same red after a green run' "$(m "$H")"
  sent 'the same red after a green run' 'red again'

  # A green run records itself once on the open issue, and opens none.
  WATCH_RESULT=success FINDINGS=$GREEN
  on_issue "$(m "$H")"
  report_case 'green on an open issue' "$list" "issue comment 5 --body-file BODY"
  sent 'green on an open issue' "$(m green)"
  sent 'green on an open issue' 'green again'
  on_issue "$(m "$H")" "$bot:$(m green)"
  report_case 'green, already recorded' "$list"
  ISSUES='[]'
  report_case 'green, no open issue' "$list"
  said 'green, no open issue' 'nothing to record'
  # A success with a red line in it is not green.
  FINDINGS=$RED
  on_issue "$(m "$H")"
  report_case 'success with a red finding' "$label" "$list"

  # Only the workflow token's markers count: anyone can comment on a public
  # issue.
  WATCH_RESULT=failure FINDINGS=$RED
  on_issue "$(m "$Z")" "someone:$(m "$H")"
  report_case 'a marker in another account'"'"'s comment' "$label" "$list" "issue comment 5 --body-file BODY" "issue edit 5 --add-assignee mmcky"
  BODY_BY=someone
  on_issue "$(m "$H")"
  report_case 'a marker in another account'"'"'s issue body' "$label" "$list" "issue comment 5 --body-file BODY" "issue edit 5 --add-assignee mmcky"
  BODY_BY=''

  ISSUES='[{"number":5,"title":"something else"}]' ASSIGNEES=''
  report_case 'another title' "$label" "$list" "$create"
  said 'another title' '::warning::CANARY_ASSIGNEES is not set'

  # Unset, as when the script runs outside canary-watch.yml: still a warning.
  unset ASSIGNEES
  ISSUES='[]'
  report_case 'ASSIGNEES unset' "$label" "$list" "$create"
  said 'ASSIGNEES unset' '::warning::CANARY_ASSIGNEES is not set'

  ASSIGNEES='bad!login, ghost mmcky'
  report_case 'bad logins' "$label" "$list" "$create" \
    "issue edit 9 --add-assignee ghost" "issue edit 9 --add-assignee mmcky"
  said 'bad logins' '[bad!login] is not a GitHub login'
  said 'bad logins' '#9 could not be assigned to ghost'

  # A watcher that stopped: reported once, whichever run finds it.
  ASSIGNEES=mmcky WATCH_RESULT=cancelled FINDINGS='' ISSUES='[]'
  report_case 'the watcher stopped' "$label" "$list" "$create" "issue edit 9 --add-assignee mmcky"
  sent 'the watcher stopped' "$STOPPED"
  sent 'the watcher stopped' "$(m "$(printf '%s\n' "$STOPPED" | sha256sum | cut -d' ' -f1)")"
  sent 'the watcher stopped' "($RUN_URL)"
  local first
  first=$(grep -o '<!-- canary-watch: [0-9a-f]* -->' "$SENT" || true)
  RUN_URL=https://github.com/o/actions/actions/runs/2
  on_issue "$first"
  report_case 'the watcher stopped, the next day' "$label" "$list"
  RUN_URL=https://github.com/o/actions/actions/runs/1

  # MARKER_AUTHOR names the token's login, for a token of another kind.
  WATCH_RESULT=failure FINDINGS=$RED
  on_issue "$(m "$Z")" "some-app[bot]:$(m "$H")"
  MARKER_AUTHOR='some-app[bot]'
  report_case 'markers by MARKER_AUTHOR' "$label" "$list"
  said 'markers by MARKER_AUTHOR' '#5 already re'
  MARKER_AUTHOR='not a login'
  : > "$LOG"
  if out=$(report "$findings" 2>&1); then bad "self-test: report accepted MARKER_AUTHOR [$MARKER_AUTHOR]"; fi
  unset MARKER_AUTHOR

  # An issue that cannot be read stops the report, which records nothing:
  # it would otherwise find no markers and comment again.
  on_issue "$(m "$H")"
  answer repos/o/actions/issues/5 fail
  : > "$LOG"
  if out=$(report "$findings" 2>&1); then
    bad "self-test: report went on when the issue could not be read: [$out]"
  fi
  [ "$(cat "$LOG")" = "$(printf '%s\n' "$label" "$list")" ] \
    || bad "self-test: report with an unreadable issue called [$(cat "$LOG")]"
  on_issue "$(m "$H")"
  answer 'repos/o/actions/issues/5/comments?per_page=100' fail
  : > "$LOG"
  if out=$(report "$findings" 2>&1); then
    bad "self-test: report went on when the comments could not be read: [$out]"
  fi

  # The drift topic: the same issue, with its own record and its own words.
  # A runs marker of the same hash does not stand for drift's, nor a drift
  # marker for the runs'.
  d() { printf '<!-- canary-watch drift: %s -->' "$1"; }
  TOPIC=drift
  on_issue "$(m "$H")"
  report_case 'drift, on the open runs issue' "$label" "$list" "issue comment 5 --body-file BODY" "issue edit 5 --add-assignee mmcky"
  sent 'drift, on the open runs issue' "drifted from \`templates/\` at \`v0\`, as [this run]"
  sent 'drift, on the open runs issue' '.github/canary-drift.yml'
  sent 'drift, on the open runs issue' "$(d "$H")"
  on_issue "$(m "$Z")" "$bot:$(d "$H")"
  report_case 'drift, same findings' "$label" "$list"
  said 'drift, same findings' '#5 already re'
  on_issue "$(m "$Z")" "$bot:$(d "$A")"
  report_case 'drift, changed findings' "$label" "$list" "issue comment 5 --body-file BODY" "issue edit 5 --add-assignee mmcky"
  sent 'drift, changed findings' 'The findings changed'
  sent 'drift, changed findings' "$(d "$H")"
  ISSUES='[]'
  report_case 'drift, no open issue' "$label" "$list" "$create" "issue edit 9 --add-assignee mmcky"
  sent 'drift, no open issue' "$(d "$H")"
  WATCH_RESULT=success FINDINGS=$GREEN
  on_issue "$(m "$H")"
  report_case 'drift green, on an issue with no drift record' "$list"
  said 'drift green, on an issue with no drift record' 'records nothing red for this topic'
  on_issue "$(m "$H")" "$bot:$(d "$H")"
  report_case 'drift, green again' "$list" "issue comment 5 --body-file BODY"
  sent 'drift, green again' "match \`templates/\` at \`v0\` again"
  sent 'drift, green again' "$(d green)"
  TOPIC=runs WATCH_RESULT=failure FINDINGS=$RED
  on_issue "$(m "$Z")" "$bot:$(d "$H")"
  report_case 'runs, beside a drift record of the same hash' "$label" "$list" "issue comment 5 --body-file BODY" "issue edit 5 --add-assignee mmcky"
  sent 'runs, beside a drift record of the same hash' "$(m "$H")"
  TOPIC=other
  if out=$(report "$findings" 2>&1); then bad "self-test: report accepted TOPIC [$TOPIC]"; fi
  unset TOPIC

  # --verdict: the findings, the summary and the outputs.
  local vout=$WORK/output vsum=$WORK/summary vf=$WORK/verdict
  verdict_case() {
    local name=$1 status=$2 text=$3 want_red=$4 want_stopped=$5 got
    printf '%s' "$text" > "$vf"; : > "$vout"; : > "$vsum"
    if ! out=$(GITHUB_OUTPUT=$vout GITHUB_STEP_SUMMARY=$vsum verdict "$vf" "$status" Heading 2>&1); then
      bad "self-test: verdict [$name] failed: [$out]"
      return
    fi
    grep -qx "red=$want_red" "$vout" || bad "self-test: verdict [$name] output [$(cat "$vout")], expected red=$want_red"
    grep -qx '### Heading' "$vsum" || bad "self-test: verdict [$name] summary has no heading: [$(cat "$vsum")]"
    got=$(sed -n '/^findings<</,/^FINDINGS_/p' "$vout" | sed '1d;$d')
    [ "$got" = "$(cat "$vf")" ] || bad "self-test: verdict [$name] findings output [$got], expected [$(cat "$vf")]"
    if [ "$want_stopped" = yes ]; then
      grep -qxF -- "$STOPPED" "$vf" || bad "self-test: verdict [$name] added no STOPPED: [$(cat "$vf")]"
    else
      ! grep -qxF -- "$STOPPED" "$vf" || bad "self-test: verdict [$name] added STOPPED: [$(cat "$vf")]"
    fi
  }
  verdict_case green 0 "$GREEN" false no
  verdict_case red 1 "$RED" true no
  verdict_case 'stopped, with nothing written' 2 '' true yes
  verdict_case 'stopped, after green lines' 1 "$GREEN" true yes
  if (GITHUB_OUTPUT=$vout GITHUB_STEP_SUMMARY=$vsum verdict "$vf" x Heading > /dev/null 2>&1); then
    bad "self-test: verdict accepted the status [x]"
  fi

  [ "$failures" -eq 0 ] || fail "canary-watch self-test: $failures case(s) failed"
  echo "canary-watch self-test passed"
}

case "${1:-}" in
  --self-test) self_test ;;
  --report)
    [ "$#" -eq 2 ] || fail "usage: scripts/canary-watch.sh --report <findings file>"
    report "$2"
    ;;
  --verdict)
    [ "$#" -eq 4 ] || fail "usage: scripts/canary-watch.sh --verdict <findings file> <exit status> <heading>"
    verdict "$2" "$3" "$4"
    ;;
  '') check ;;
  *) fail "usage: scripts/canary-watch.sh [--report <findings file> | --verdict <findings file> <exit status> <heading> | --self-test]" ;;
esac
