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
#   scripts/canary-watch.sh --report FILE    file FILE's findings as an issue
#   scripts/canary-watch.sh --self-test
#
# A workflow is red when it is not `active`, when its newest completed
# scheduled run on main is missing or more than MAX_AGE_HOURS old, or when
# that run did not succeed. One the API does not answer for is red too:
# the watcher cannot tell.
#
# --report opens one issue with the `canary` label, or comments on the open
# one, and assigns it to ASSIGNEES. The watcher runs daily, so a comment is
# added only when the red findings differ from the last ones the issue
# records, in a hidden marker: a state that persists is reported once.
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
#   ASSIGNEES         optional: the logins to assign, separated by commas
#                     or spaces
set -euo pipefail

# shellcheck source=scripts/workflow-command.sh
. "$(dirname "${BASH_SOURCE[0]}")/workflow-command.sh"

fail() { annotate error "$*" >&2; exit 2; }

LABEL=canary
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
    # Five lines for the newest run, or none when there is no run; anything
    # else is an answer this cannot read.
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
    [ "$age" -le "$MAX_AGE_HOURS" ] || stale=" is more than $MAX_AGE_HOURS hours old"
    if [ -n "$stale" ] && [ "$conclusion" = success ]; then
      echo "- 🔴 \`$wf\`: its newest scheduled run on \`main\`, [$id]($url) on $when,$stale. The workflow is enabled, so its schedule has not run since: check its \`on.schedule\`, and the canary's Actions tab."
      red=1
    elif [ -n "$stale" ]; then
      echo "- 🔴 \`$wf\`: its newest scheduled run on \`main\`, [$id]($url) on $when,$stale, and concluded \`$conclusion\`. The workflow is enabled, so its schedule has not run since: check its \`on.schedule\`, and the canary's Actions tab."
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
  local issue=$1 login logins
  read -ra logins <<< "${ASSIGNEES//,/ }"
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

report() {
  local file=$1 red hash title issue last body url
  [ -f "$file" ] || fail "no findings file [$file]"
  [[ ${CANARY_REPO:-} =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "CANARY_REPO [${CANARY_REPO:-}] is not owner/name"
  : "${GH_REPO:?GH_REPO is required, as owner/name}" "${RUN_URL:?RUN_URL is required}"
  red=$(grep '^- 🔴' "$file" || true)
  if [ -z "$red" ]; then
    # A watch job that timed out, or failed before its verdict.
    red="- 🔴 The watcher stopped before it reached a verdict: see [its run]($RUN_URL)."
    printf '%s\n' "$red" >> "$file"
  fi
  hash=$(printf '%s\n' "$red" | sha256sum | cut -d' ' -f1)
  title="🔴 Canary watch: $CANARY_REPO"
  body=$WORK/body

  gh label create "$LABEL" --color B60205 --force \
    --description "The canary's scheduled runs are red, missing or disabled (canary-watch.yml)" > /dev/null
  issue=$(gh issue list --state open --label "$LABEL" --limit 100 --json number,title \
    | jq -r --arg title "$title" 'map(select(.title == $title)) | .[0].number // empty')

  if [ -n "$issue" ]; then
    last=$(gh issue view "$issue" --json body,comments \
      | jq -r '[.body, .comments[].body] | map(scan("<!-- canary-watch: ([0-9a-f]{64}) -->")[0]) | last // empty')
    if [ "$last" = "$hash" ]; then
      echo "#$issue already reports these findings, so nothing was added"
      return 0
    fi
    {
      echo "The findings changed, in [this run]($RUN_URL):"
      echo
      cat "$file"
      echo
      echo "<!-- canary-watch: $hash -->"
    } > "$body"
    echo "Commenting on the open issue, #$issue"
    gh issue comment "$issue" --body-file "$body" > /dev/null
  else
    {
      echo "The canary's scheduled runs need attention, as [this run]($RUN_URL) of \`canary-watch.yml\` found:"
      echo
      cat "$file"
      echo
      echo "The canary, [$CANARY_REPO](https://github.com/$CANARY_REPO), runs the released actions through \`@v0\` on a schedule. A red run there can be a regression in a release, or in something the actions call that changes without one: a floating major version, a deploy service, a token. A disabled or missing run means the canary has stopped testing anything."
      echo
      echo "The watcher runs daily, and comments here only when its findings change. Close this issue once it is green again: the next red finding opens a fresh one."
      echo
      echo "<!-- canary-watch: $hash -->"
    } > "$body"
    echo "No open issue: opening one"
    url=$(gh issue create --title "$title" --label "$LABEL" --body-file "$body")
    issue=${url##*/}
    [[ $issue =~ ^[0-9]+$ ]] || fail "gh issue create printed [$url], not an issue's URL"
  fi
  assign "$issue"
}

self_test() {
  local out got H
  local LOG=$WORK/log SENT=$WORK/sent
  CANARY_REPO=o/r
  MAX_AGE_HOURS=192
  NOW=$(jq -n '"2026-11-16T06:30:00Z" | fromdate')
  mkdir "$WORK/api"
  # answer PATH VALUE: what the stand-in gh prints for `gh api PATH`.
  answer() { printf '%s\n' "$2" > "$WORK/api/${1//[^A-Za-z0-9._-]/_}"; }

  # A run's list, as the API answers: an id, a conclusion and a time.
  runs_json() { printf '{"workflow_runs":[{"id":%s,"conclusion":"%s","created_at":"%s","html_url":"https://github.com/o/r/actions/runs/%s"}]}' "$1" "$2" "$3" "$1"; }
  # A stand-in for gh. `api` prints what `answer` gave it, and fails
  # as gh does for `fail`. Every other call is logged, with BODY for the
  # file given as --body-file, which is kept in SENT; the issue commands
  # answer from ISSUES and VIEW. A call it does not expect fails the
  # self-test.
  gh() {
    local key arg prev='' logged=()
    case "$1 ${2:-}" in
      'api '*)
        [[ $2 != *'?'* || $2 == *'/runs?event=schedule&branch=main&status=completed&per_page=1' ]] \
          || fail "self-test: gh called as [gh $*]"
        key=$WORK/api/${2//[^A-Za-z0-9._-]/_}
        [ -f "$key" ] || fail "self-test: no answer for [gh $*]"
        if [ "$(cat "$key")" = fail ]; then echo 'gh: Not Found (HTTP 404)' >&2; return 1; fi
        cat "$key"
        return 0 ;;
    esac
    for arg in "$@"; do
      if [ "$prev" = --body-file ]; then cp "$arg" "$SENT"; logged+=(BODY); else logged+=("$arg"); fi
      prev=$arg
    done
    printf '%s\n' "${logged[*]}" >> "$LOG"
    case "$1 $2" in
      'label create' | 'issue comment') ;;
      'issue list') printf '%s\n' "$ISSUES" ;;
      'issue view') printf '%s\n' "$VIEW" ;;
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
    [ "$status" = "$want" ] || fail "self-test: check [$name] exited $status, expected $want; it printed [$out]"
    got=$(printf '%s\n' "$@")
    [ "$out" = "$got" ] || fail "self-test: check [$name] printed [$out], expected [$got]"
  }

  CANARY_WORKFLOWS=a.yml
  local wf=repos/o/r/actions/workflows/a.yml
  local rk='repos/o/r/actions/workflows/a.yml/runs?event=schedule&branch=main&status=completed&per_page=1'
  local link='[7](https://github.com/o/r/actions/runs/7) on 2026-11-15 03:07 UTC'
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
  check_case stale 1 "- 🔴 \`a.yml\`: its newest scheduled run on \`main\`, [7](https://github.com/o/r/actions/runs/7) on 2026-11-08 05:30 UTC, is more than 192 hours old. The workflow is enabled, so its schedule has not run since: check its \`on.schedule\`, and the canary's Actions tab."
  answer "$rk" "$(runs_json 7 failure 2026-11-08T05:30:00Z)"
  check_case 'stale and red' 1 "- 🔴 \`a.yml\`: its newest scheduled run on \`main\`, [7](https://github.com/o/r/actions/runs/7) on 2026-11-08 05:30 UTC, is more than 192 hours old, and concluded \`failure\`. The workflow is enabled, so its schedule has not run since: check its \`on.schedule\`, and the canary's Actions tab."
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
    if (check > /dev/null 2>&1); then fail "self-test: check accepted CANARY_WORKFLOWS [$bad]"; fi
  done
  CANARY_WORKFLOWS=a.yml
  for bad in 0 x 1.5; do
    if (MAX_AGE_HOURS=$bad check > /dev/null 2>&1); then fail "self-test: check accepted MAX_AGE_HOURS [$bad]"; fi
  done
  echo "canary-watch self-test: check passed"

  # The report. A case is a name, ASSIGNEES, the open issues and the open
  # issue's body and comments as gh returns them; it checks the calls made.
  GH_REPO=o/actions
  RUN_URL=https://github.com/o/actions/actions/runs/1
  local findings title label
  findings=$WORK/findings
  title="🔴 Canary watch: o/r"
  label="label create canary --color B60205 --force --description The canary's scheduled runs are red, missing or disabled (canary-watch.yml)"
  report_case() {
    local name=$1 want
    ASSIGNEES=$2 ISSUES=$3 VIEW=$4
    shift 4
    : > "$LOG"; : > "$SENT"
    printf '%s\n' "- ✅ \`a.yml\`: fine." "- 🔴 \`b.yml\`: red." > "$findings"
    out=$(report "$findings") || fail "self-test: report [$name] failed: [$out]"
    want=$(printf '%s\n' "$@")
    [ "$(cat "$LOG")" = "$want" ] || fail "self-test: report [$name] called [$(cat "$LOG")], expected [$want]"
  }
  H=$(printf '%s\n' "- 🔴 \`b.yml\`: red." | sha256sum | cut -d' ' -f1)
  local list="issue list --state open --label canary --limit 100 --json number,title"

  report_case 'new issue' 'mmcky' '[]' '' \
    "$label" "$list" "issue create --title $title --label canary --body-file BODY" "issue edit 9 --add-assignee mmcky"
  grep -qF -- "- 🔴 \`b.yml\`: red." "$SENT" || fail "self-test: the new issue's body has no finding"
  grep -qF -- "- ✅ \`a.yml\`: fine." "$SENT" || fail "self-test: the new issue's body leaves out the green workflow"
  grep -qF "<!-- canary-watch: $H -->" "$SENT" || fail "self-test: the new issue's body has no marker for its findings"
  grep -qF "($RUN_URL)" "$SENT" || fail "self-test: the new issue's body has no link to the run"

  report_case 'same findings' 'mmcky' '[{"number":5,"title":"'"$title"'"}]' \
    '{"body":"old <!-- canary-watch: '"$(printf '0%.0s' {1..64})"' -->","comments":[{"body":"<!-- canary-watch: '"$H"' -->"}]}' \
    "$label" "$list" "issue view 5 --json body,comments"
  [[ $out == *'#5 already reports these findings'* ]] || fail "self-test: an unchanged finding said [$out]"

  report_case 'changed findings' 'mmcky,other' '[{"number":5,"title":"'"$title"'"}]' \
    '{"body":"<!-- canary-watch: '"$H"' -->","comments":[{"body":"<!-- canary-watch: '"$(printf 'a%.0s' {1..64})"' -->"}]}' \
    "$label" "$list" "issue view 5 --json body,comments" "issue comment 5 --body-file BODY" \
    "issue edit 5 --add-assignee mmcky" "issue edit 5 --add-assignee other"
  grep -qF "<!-- canary-watch: $H -->" "$SENT" || fail "self-test: the comment has no marker for its findings"
  grep -qF "The findings changed" "$SENT" || fail "self-test: the comment does not say the findings changed"

  report_case 'another title' '' '[{"number":5,"title":"something else"}]' '' \
    "$label" "$list" "issue create --title $title --label canary --body-file BODY"
  [[ $out == *'::warning::CANARY_ASSIGNEES is not set'* ]] || fail "self-test: no warning for an empty CANARY_ASSIGNEES: [$out]"

  report_case 'bad logins' 'bad!login, ghost mmcky' '[]' '' \
    "$label" "$list" "issue create --title $title --label canary --body-file BODY" \
    "issue edit 9 --add-assignee ghost" "issue edit 9 --add-assignee mmcky"
  [[ $out == *'[bad!login] is not a GitHub login'* ]] || fail "self-test: no warning for a bad login: [$out]"
  [[ $out == *'#9 could not be assigned to ghost'* ]] || fail "self-test: no warning for a login that cannot be assigned: [$out]"

  : > "$LOG"
  printf '%s\n' "- ✅ \`a.yml\`: fine." > "$findings"
  ASSIGNEES=mmcky ISSUES='[]' VIEW=''
  report "$findings" > /dev/null || fail "self-test: report with no red finding failed"
  grep -qF "The watcher stopped before it reached a verdict" "$SENT" || fail "self-test: a report with no red finding does not say the watcher stopped"
  echo "canary-watch self-test: report passed"
}

case "${1:-}" in
  --self-test) self_test ;;
  --report)
    [ "$#" -eq 2 ] || fail "usage: scripts/canary-watch.sh --report <findings file>"
    report "$2"
    ;;
  '') check ;;
  *) fail "usage: scripts/canary-watch.sh [--report <findings file> | --self-test]" ;;
esac
