#!/usr/bin/env bash
#
# Print how many runs of a workflow on a branch are newer than a given run
# (#142). A workflow whose concurrency group cancels a run in progress when a
# newer one starts calls this from its failure alert: a cancelled run with a
# newer run behind it leaves the reporting to that run. build-containers.yml
# calls it; another workflow that takes the same rule calls it too, so that
# their rules cannot drift apart. The caller passes the branch its
# concurrency group is keyed on, github.ref_name when the group is
# <name>-${{ github.ref }}: for a workflow_run or scheduled run that is the
# default branch, whatever branch triggered it.
#
#   REPO=QuantEcon/actions scripts/newer-runs.sh build-containers.yml main 123
#   scripts/newer-runs.sh --self-test
#
# Newer means a higher run number: a workflow numbers its runs in the order
# they start, and a re-run keeps its number. Any newer run is among the
# branch's 20 most recent, which is all that is listed.
#
# It exits non-zero with nothing on stdout when the runs cannot be listed or
# read, so that the caller can report the cancellation rather than stay
# silent.
#
# Required environment:
#   REPO      the repository, as owner/name
#   GH_TOKEN  a token with actions: read
set -euo pipefail

fail() { echo "::error::$*" >&2; exit 1; }

# The workflow's file name, the branch and the run number as arguments.
newer_runs() {
  local workflow=$1 branch=$2 number=$3 runs
  [[ $number =~ ^[1-9][0-9]*$ ]] || { echo "::error::run number [$number] is not a positive integer" >&2; return 1; }
  runs=$(gh run list --repo "$REPO" --workflow "$workflow" --branch "$branch" --limit 20 --json number) || return 1
  jq --argjson n "$number" 'map(select(.number > $n)) | length' <<< "$runs"
}

self_test() {
  local out
  REPO=owner/repo
  # A stand-in for gh: it checks the call, then prints $RUNS, or fails when
  # RUNS is `fail`.
  gh() {
    [ "$*" = "run list --repo owner/repo --workflow w.yml --branch main --limit 20 --json number" ] \
      || fail "self-test: gh called as [gh $*]"
    [ "$RUNS" != fail ] || return 1
    printf '%s\n' "$RUNS"
  }
  # A case is a name, the run list gh returns, the run number, and the count
  # expected, or `error` for a non-zero exit with nothing on stdout.
  case_() {
    local name=$1 want=$4
    RUNS=$2
    if out=$(newer_runs w.yml main "$3" 2> /dev/null); then
      [ "$out" = "$want" ] || fail "self-test: case [$name] printed [$out], expected [$want]"
    else
      [ "$want" = error ] || fail "self-test: case [$name] failed, expected [$want]"
      [ -z "$out" ] || fail "self-test: case [$name] failed, but printed [$out]"
    fi
  }
  case_ newest '[{"number":7},{"number":6},{"number":5}]' 7 0
  case_ one-newer '[{"number":7},{"number":6},{"number":5}]' 6 1
  case_ two-newer '[{"number":7},{"number":6},{"number":5}]' 5 2
  case_ not-listed '[{"number":12},{"number":11}]' 9 2
  case_ none '[]' 3 0
  case_ list-fails fail 3 error
  case_ not-json 'HTTP 502' 3 error
  case_ bad-number '[{"number":7}]' 'x' error
  case_ empty-number '[{"number":7}]' '' error
  echo "newer-runs self-test passed"
}

case "${1:-}" in
  --self-test) self_test ;;
  *)
    [ "$#" -eq 3 ] || fail "usage: scripts/newer-runs.sh <workflow file> <branch> <run number>"
    : "${REPO:?REPO is required, as owner/name}"
    newer_runs "$@"
    ;;
esac
