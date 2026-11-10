#!/usr/bin/env bash
#
# Report how long each leg of a lecture-matrix run took, against its ceiling
# and its own recent past, and warn when one is growing (#141, #196).
# test-containers-lectures.yml's `durations` job runs this after the matrix,
# on every run, for the run's step summary.
#
#   REPO=QuantEcon/actions RUN_ID=42548828726 RUN_ATTEMPT=1 scripts/leg-durations.sh
#   scripts/leg-durations.sh --self-test
#
# A leg is a job named `<repository> · <image>`. For each, it prints its
# result, minutes, the minutes of its HTML build, its ceiling (the job's
# timeout-minutes, read from the workflow's matrix, so the matrix stays its
# one source), its share of the ceiling, and the median of its last HISTORY
# green runs on BRANCH before this run, with the change against it. A green
# leg is warned about when it takes
#   - more than CEILING_PCT% of its ceiling: a build growing towards its
#     limit, which would next be cancelled; or
#   - more than GROWTH_PCT% and GROWTH_MIN minutes over that median, with at
#     least 3 green runs behind it: a jump. Two legs of one run, on identical
#     inputs, have taken 130 and 79 minutes, so one previous run is no
#     baseline, and a few minutes on a short leg are noise.
# A warning is an annotation and a line in the summary; it fails nothing.
# The script fails only when it cannot read what it reports.
#
# Required environment:
#   GH_TOKEN      a token with actions: read
#   REPO          the repository, as owner/name
#   RUN_ID        the run to report
#   RUN_ATTEMPT   its attempt
# Optional:
#   WORKFLOW       the workflow's file name (default test-containers-lectures.yml)
#   WORKFLOW_FILE  where its ceilings are read (default .github/workflows/$WORKFLOW),
#                  with yq
#   CEILINGS       instead, a JSON object of ceilings by repository, and "*"
#                  for the rest
#   BRANCH         whose runs are the history (default main)
#   HISTORY        default 5
#   CEILING_PCT    default 80
#   GROWTH_PCT     default 50
#   GROWTH_MIN     default 15
set -euo pipefail

fail() { echo "::error::$*" >&2; exit 1; }

# The legs of one attempt's jobs, from the jobs API, as one JSON object each.
legs() {
  jq -c '.jobs[] | select(.name | contains(" · ")) | {
      leg: .name, repo: (.name | split(" · ")[0]), conclusion,
      minutes: (if .started_at and .completed_at then
        (((.completed_at | fromdateiso8601) - (.started_at | fromdateiso8601)) / 60 | round) else null end),
      html: ([.steps[]? | select(.name | startswith("Build HTML")) | select(.started_at and .completed_at)
        | ((.completed_at | fromdateiso8601) - (.started_at | fromdateiso8601))] | if length > 0 then add / 60 | round else null end)
    }'
}

# The ceilings, as {"<repository>": minutes, "*": the default}.
ceilings() {
  if [ -n "${CEILINGS:-}" ]; then
    jq -ce 'if type == "object" and (.["*"] | type) == "number" then . else error("CEILINGS needs a number at \"*\"") end' <<< "$CEILINGS"
    return
  fi
  [ -f "$WORKFLOW_FILE" ] || { echo "::error::$WORKFLOW_FILE: no such file" >&2; return 1; }
  command -v yq > /dev/null \
    || { echo "::error::yq is not installed, so the ceilings cannot be read from $WORKFLOW_FILE. GitHub's Ubuntu runner images include it; install it, or set CEILINGS" >&2; return 1; }
  # The job's timeout-minutes is `${{ matrix.repo.timeout-minutes || <default> }}`.
  yq -o=json '.jobs.test' "$WORKFLOW_FILE" | jq -ce '
    (.["timeout-minutes"] | tostring | capture("\\|\\| *(?<n>[0-9]+)").n | tonumber) as $default
    | [.strategy.matrix.repo[] | select(.["timeout-minutes"]) | {key: .repo, value: .["timeout-minutes"]}]
    | from_entries + {"*": $default}'
}

main() {
  local ceil number id
  for var in GH_TOKEN REPO RUN_ID RUN_ATTEMPT; do
    [ -n "${!var:-}" ] || fail "$var is required but is not set"
  done
  WORKFLOW=${WORKFLOW:-test-containers-lectures.yml}
  WORKFLOW_FILE=${WORKFLOW_FILE:-.github/workflows/$WORKFLOW}
  BRANCH=${BRANCH:-main} HISTORY=${HISTORY:-5}
  CEILING_PCT=${CEILING_PCT:-80} GROWTH_PCT=${GROWTH_PCT:-50} GROWTH_MIN=${GROWTH_MIN:-15}
  for var in RUN_ID RUN_ATTEMPT HISTORY CEILING_PCT GROWTH_PCT GROWTH_MIN; do
    [[ ${!var} =~ ^[1-9][0-9]*$ ]] || fail "$var [${!var}] is not a positive integer"
  done
  work=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/leg-durations-XXXXXX")
  trap 'rm -rf "$work"' EXIT

  ceil=$(ceilings) || fail "cannot read the legs' ceilings"
  gh api "repos/$REPO/actions/runs/$RUN_ID/attempts/$RUN_ATTEMPT/jobs?per_page=100" > "$work/jobs.json" \
    || fail "cannot list run $RUN_ID's jobs"
  legs < "$work/jobs.json" > "$work/legs" || fail "cannot read run $RUN_ID's jobs"
  [ -s "$work/legs" ] || fail "run $RUN_ID has no legs named <repository> · <image>"
  number=$(gh api "repos/$REPO/actions/runs/$RUN_ID" --jq .run_number) || fail "cannot read run $RUN_ID"

  # The history: the latest attempt of each completed run on BRANCH before
  # this one, newest first, enough to give each leg HISTORY green runs.
  gh api "repos/$REPO/actions/workflows/$WORKFLOW/runs?branch=$BRANCH&status=completed&per_page=30" > "$work/runs.json" \
    || fail "cannot list $WORKFLOW's runs on $BRANCH"
  jq -r --argjson n "$number" --argjson most "$((HISTORY * 2))" \
    '.workflow_runs | map(select(.run_number < $n)) | sort_by(.run_number) | reverse | .[:$most] | .[] | "\(.id) \(.run_number)"' \
    "$work/runs.json" > "$work/runs" || fail "cannot read $WORKFLOW's runs"
  : > "$work/history"
  while read -r id number; do
    gh api "repos/$REPO/actions/runs/$id/jobs?per_page=100" > "$work/run.json" || fail "cannot list run $id's jobs"
    legs < "$work/run.json" | jq -c --argjson number "$number" 'select(.conclusion == "success") + {number: $number}' >> "$work/history" \
      || fail "cannot read run $id's jobs"
  done < "$work/runs"
  jq -s . "$work/history" > "$work/history.json" || fail "cannot read the history"

  jq -rs --argjson ceil "$ceil" --slurpfile history "$work/history.json" \
      --argjson keep "$HISTORY" --argjson ceiling_pct "$CEILING_PCT" --argjson growth_pct "$GROWTH_PCT" \
      --argjson growth_min "$GROWTH_MIN" '
    def median: sort | if length % 2 == 1 then .[length / 2 | floor] else (.[length / 2 - 1] + .[length / 2]) / 2 end;
    def pct: . * 100 | round;
    ($history[0] | group_by(.leg) | map({key: .[0].leg, value: (sort_by(-.number) | .[:$keep] | map(.minutes))}) | from_entries) as $past
    | map(. as $l
        | ($ceil[.repo] // $ceil["*"]) as $c
        | ($past[.leg] // []) as $p
        | (if ($p | length) >= 3 then ($p | median) else null end) as $m
        | . + {ceiling: $c, share: (if .minutes then .minutes / $c else null end), median: $m, n: ($p | length)}
        | . + {warn: (if .conclusion != "success" or .minutes == null then []
            else [
              (if .share * 100 > $ceiling_pct then "took \(.minutes) of its \($c) minutes, \(.share | pct)%: it will be cancelled if it grows further" else empty end),
              (if $m and .minutes > $m * (1 + $growth_pct / 100) and .minutes - $m >= $growth_min then
                "took \(.minutes) minutes, \(.minutes / $m - 1 | pct)% over the median of its last \(.n) green runs, \($m)" else empty end)
            ] end)})
    | sort_by(.leg)
    | (map(.warn[] as $w | "::warning title=Lecture matrix::\(.leg) \($w)") | .[]),
      "### Leg durations",
      "",
      "| Leg | Result | Minutes | HTML | Ceiling | Share | Median of last green | Change |",
      "|---|---|---|---|---|---|---|---|",
      (.[] | "| \(.leg) | \(.conclusion // "unfinished") | \(.minutes // "") | \(.html // "") | \(.ceiling) | \(if .share then "\(.share | pct)%" else "" end) | \(if .median then "\(.median) (\(.n))" else "too few runs (\(.n))" end) | \(if .median and .minutes then "\(.minutes / .median - 1 | pct | if . > 0 then "+\(.)" else "\(.)" end)%" else "" end) |"),
      "",
      (if any(.[]; .warn | length > 0) then
        "**Warnings:**", "", (.[] | .leg as $leg | .warn[] | "- \($leg) \(.)"), ""
      else "No leg is over \($ceiling_pct)% of its ceiling, or \($growth_pct)% and \($growth_min) minutes over its recent median." end)
  ' "$work/legs" > "$work/report" || fail "cannot build the report"
  # The annotations to the log, the rest to stdout, for the step summary.
  grep '^::warning' "$work/report" >&2 || true
  grep -v '^::warning' "$work/report"
}

self_test() {
  local got
  # Global, so that the trap can still read it when a failing case exits.
  dir=$(mktemp -d "${TMPDIR:-/tmp}/leg-durations-test.XXXXXX")
  trap 'rm -rf "$dir"' EXIT
  # A stand-in for gh: run <id>'s jobs from $dir/jobs-<id>.json, the runs
  # list from $dir/runs.json, and run 9's number; fails for a path in FAILS.
  gh() {
    [[ " ${FAILS:-} " != *" $2 "* ]] || { echo "HTTP 502" >&2; return 1; }
    case $2 in
      */runs/9/attempts/1/jobs*) cat "$dir/jobs-9.json" ;;
      */runs/9) echo 109 ;;
      */workflows/*/runs*) cat "$dir/runs.json" ;;
      */runs/*/jobs*) local id=${2%/jobs*}; cat "$dir/jobs-${id##*/}.json" ;;
      *) echo "fake gh: unexpected [$*]" >&2; return 2 ;;
    esac
  }
  # A job: name, conclusion, minutes, HTML minutes.
  job() {
    jq -nc --arg name "$1" --arg c "$2" --argjson m "$3" --argjson h "${4:-0}" '
      {name: $name, conclusion: (if $c == "-" then null else $c end), started_at: "2026-11-01T00:00:00Z",
       completed_at: ((1793491200 + $m * 60) | todate),
       steps: [{name: "Build HTML (Execute Notebooks)", started_at: "2026-11-01T00:00:00Z", completed_at: ((1793491200 + $h * 60) | todate)}]}'
  }
  jobs() { local id=$1; shift; printf '%s\n' "$@" | jq -s '{jobs: (. + [{name: "Report failure", conclusion: "skipped", steps: []}])}' > "$dir/jobs-$id.json"; }
  A="big · img" B="mid · img" C="small · img" D="new · img" E="flaky · img"
  # History, newest first: runs 8 to 1. Run 6 is A's failure, which is no baseline.
  jobs 8 "$(job "$A" success 100)" "$(job "$B" success 40)" "$(job "$C" success 10)" "$(job "$E" success 30)"
  jobs 7 "$(job "$A" success 110)" "$(job "$B" success 42)" "$(job "$C" success 12)" "$(job "$E" success 31)"
  jobs 6 "$(job "$A" failure 300)" "$(job "$B" success 38)" "$(job "$C" success 11)" "$(job "$D" success 50)" "$(job "$E" success 29)"
  jobs 5 "$(job "$A" success 105)" "$(job "$B" success 41)" "$(job "$C" success 10)" "$(job "$D" success 52)"
  jobs 4 "$(job "$A" success 90)" "$(job "$B" success 39)" "$(job "$C" success 11)"
  jobs 3 "$(job "$A" success 95)" "$(job "$B" success 40)" "$(job "$C" success 10)"
  jobs 2 "$(job "$A" success 500)" "$(job "$B" success 200)" "$(job "$C" success 200)"
  jobs 1 "$(job "$A" success 500)" "$(job "$B" success 200)" "$(job "$C" success 200)"
  # The runs list: a later run and this one (9), neither of them history,
  # and 8 to 1.
  jq -n '{workflow_runs: ([{id: 10, run_number: 110}] + [range(9; 0; -1) | {id: ., run_number: (100 + .)}])}' > "$dir/runs.json"
  run() {
    (
      export GH_TOKEN=x REPO=o/r RUN_ID=9 RUN_ATTEMPT=1 CEILINGS='{"big": 180, "*": 120}'
      for setting in "$@"; do export "${setting?}"; done
      main
    ) > "$dir/out" 2> "$dir/err"
  }
  warned() { grep -c "^::warning title=Lecture matrix::$1 " "$dir/err" || true; }

  # A: 150 of 180 is 83%, over the ceiling share; against a median of 100
  # (runs 8, 7, 5, 4, 3; not 6, a failure, nor 2 and 1, beyond 5), +50% and
  # +50 min, at the line, not over it. B: 61 against 40 is +52% and +21 min:
  # a jump. C: 26 against 11 is +136% and +15 min: a jump, at the floor.
  # D: two green runs, too few. E: a failure, never warned. small2: unfinished.
  jobs 9 "$(job "$A" success 150 140)" "$(job "$B" success 61)" "$(job "$C" success 26)" \
    "$(job "$D" success 80)" "$(job "$E" failure 119)" "$(job "small2 · img" - 0)"
  run || fail "self-test: the report failed: $(cat "$dir/err")"
  { [ "$(warned "$A")" = 1 ] && grep -q "$A took 150 of its 180 minutes, 83%" "$dir/err"; } \
    || fail "self-test: [$A] should warn once, on its ceiling share: $(cat "$dir/err")"
  { [ "$(warned "$B")" = 1 ] && grep -q "$B took 61 minutes, 52% over the median of its last 5 green runs, 40" "$dir/err"; } \
    || fail "self-test: [$B] should warn on growth: $(cat "$dir/err")"
  [ "$(warned "$C")" = 1 ] || fail "self-test: [$C] should warn on growth, at the 15-minute floor: $(cat "$dir/err")"
  [ "$(warned "$D")" = 0 ] || fail "self-test: [$D] has too few green runs to warn on growth: $(cat "$dir/err")"
  [ "$(warned "$E")" = 0 ] || fail "self-test: [$E] failed, and should not warn: $(cat "$dir/err")"
  grep -qF "| $A | success | 150 | 140 | 180 | 83% | 100 (5) | +50% |" "$dir/out" || fail "self-test: [$A]'s row is wrong: $(cat "$dir/out")"
  grep -qF "| $D | success | 80 | 0 | 120 | 67% | too few runs (2) |  |" "$dir/out" || fail "self-test: [$D]'s row is wrong: $(cat "$dir/out")"
  grep -qF "| $E | failure | 119 | 0 | 120 | 99% | 30 (3) | +297% |" "$dir/out" || fail "self-test: [$E]'s row is wrong: $(cat "$dir/out")"
  grep -qF "| small2 · img | unfinished |" "$dir/out" || fail "self-test: an unfinished leg should be listed: $(cat "$dir/out")"
  ! grep -q "Report failure" "$dir/out" || fail "self-test: a job that is not a leg was listed"
  # Under the floor, or a threshold, quiet.
  jobs 9 "$(job "$B" success 54)" "$(job "$C" success 25)" "$(job "$A" success 144)"
  run || fail "self-test: the quiet report failed: $(cat "$dir/err")"
  [ ! -s "$dir/err" ] || fail "self-test: 54 against 40 (+35%), 25 against 11 (+14 min) and 144 of 180 (80%) should not warn: $(cat "$dir/err")"
  grep -q '^No leg is over 80% of its ceiling' "$dir/out" || fail "self-test: the quiet report should say so: $(cat "$dir/out")"
  # Settings move the lines: now A's 80% and C's +14 min warn, and B's +35% does not.
  run CEILING_PCT=70 GROWTH_MIN=1 || fail "self-test: the report with settings failed: $(cat "$dir/err")"
  [ "$(warned "$A") $(warned "$B") $(warned "$C")" = "1 0 1" ] \
    || fail "self-test: with CEILING_PCT=70 and GROWTH_MIN=1, warned [$(cat "$dir/err")]"
  # HISTORY=3: B's median is that of 40, 42 and 38.
  run HISTORY=3 || fail "self-test: the report with HISTORY=3 failed: $(cat "$dir/err")"
  grep -qF "| $B | success | 54 | 0 | 120 | 45% | 40 (3) | +35% |" "$dir/out" || fail "self-test: with HISTORY=3, [$B]'s row is wrong: $(cat "$dir/out")"
  # Anything unreadable fails it.
  for case in "FAILS=repos/o/r/actions/runs/9/attempts/1/jobs?per_page=100" "FAILS=repos/o/r/actions/runs/5/jobs?per_page=100" \
      "FAILS=repos/o/r/actions/workflows/test-containers-lectures.yml/runs?branch=main&status=completed&per_page=30" \
      'CEILINGS={"big": 180}' RUN_ID= HISTORY=0 GROWTH_MIN=x; do
    run "$case" && fail "self-test: [$case] should fail"
  done
  # The ceilings as the workflow's matrix gives them, where yq is installed,
  # as it is on the runner.
  if command -v yq > /dev/null; then
    cat > "$dir/wf.yml" << 'EOF'
jobs:
  test:
    timeout-minutes: ${{ matrix.repo.timeout-minutes || 120 }}
    strategy:
      matrix:
        repo:
          - repo: one
          - repo: two
            timeout-minutes: 240
EOF
    got=$(CEILINGS='' WORKFLOW_FILE="$dir/wf.yml" ceilings) || fail "self-test: cannot read the ceilings from a workflow"
    [ "$got" = '{"two":240,"*":120}' ] || fail "self-test: the workflow's ceilings read as [$got]"
  elif [ "${CI:-}" = true ]; then
    fail "self-test: yq is not installed, so reading the ceilings from the workflow is untested"
  else
    echo "leg-durations self-test: yq is not installed here, so reading the ceilings from a workflow was not tested" >&2
  fi
  echo "leg-durations self-test passed"
}

case "${1:-}" in
  --self-test) self_test ;;
  '') main ;;
  *) fail "unknown argument [$1]" ;;
esac
