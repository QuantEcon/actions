#!/usr/bin/env bash
#
# Open (or update) a tracking issue when one of this repository's own unattended
# workflows fails.
#
# Scheduled and workflow_run builds have no author watching them: container
# validation ran red for nine consecutive weeks in Feb-Apr 2026 and nothing
# surfaced it. This is the alert path for those runs.
#
# One open issue is kept per workflow. Repeat failures are appended as comments,
# so the issue accumulates a history instead of the tracker filling with
# duplicates.
#
# Required environment variables (all but GH_TOKEN are set by the runner):
#   GH_TOKEN           - token with `issues: write` on this repository
#   GITHUB_REPOSITORY  - owner/repo
#   GITHUB_RUN_ID      - workflow run id
#   GITHUB_SERVER_URL  - e.g. https://github.com
#   GITHUB_WORKFLOW    - workflow name (used as the dedupe key)
#
# Optional:
#   ISSUE_LABELS       - comma-separated labels (default: bug,infrastructure).
#                        The first label is the one the dedupe lookup is scoped
#                        to, so it must be applied to every issue this script
#                        creates, and it must already exist on the repository.

set -euo pipefail

for var in GH_TOKEN GITHUB_REPOSITORY GITHUB_RUN_ID GITHUB_SERVER_URL GITHUB_WORKFLOW; do
  if [ -z "${!var:-}" ]; then
    echo "::error::$var is required but is not set"
    exit 1
  fi
done

ISSUE_LABELS="${ISSUE_LABELS:-bug,infrastructure}"
DEDUPE_LABEL="$(printf '%s' "$ISSUE_LABELS" | cut -d, -f1 | xargs)"

TITLE="🔴 CI failure: ${GITHUB_WORKFLOW}"
RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

# Which legs failed. Needs `actions: read`; degrade to the run link if absent.
FAILED_JOBS="$(gh run view "$GITHUB_RUN_ID" --repo "$GITHUB_REPOSITORY" --json jobs \
  | jq -r '[.jobs[] | select(.conclusion == "failure") | "- `" + .name + "`"] | join("\n")' \
  || true)"

BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT

{
  echo "## 🔴 \`${GITHUB_WORKFLOW}\` failed"
  echo
  echo "| | |"
  echo "|---|---|"
  echo "| **Run** | [${GITHUB_RUN_ID}](${RUN_URL}) |"
  echo "| **Trigger** | \`${GITHUB_EVENT_NAME:-unknown}\` |"
  echo "| **Branch** | \`${GITHUB_REF_NAME:-unknown}\` |"
  echo "| **Commit** | ${GITHUB_SHA:-unknown} |"
  echo "| **Failed at** | $(date -u +'%Y-%m-%d %H:%M UTC') |"
  echo
  if [ -n "$FAILED_JOBS" ]; then
    echo "### Failed jobs"
    echo
    echo "$FAILED_JOBS"
    echo
  fi
  echo "Nobody was watching this run, so this issue is the alert. The [run log](${RUN_URL}) shows what broke, and any job that uploads artifacts has attached its build output and failure reports to the run."
  echo
  echo "Close this issue once the workflow is green again — the next failure opens a fresh one."
} > "$BODY_FILE"

EXISTING="$(gh issue list \
  --repo "$GITHUB_REPOSITORY" \
  --state open \
  --label "$DEDUPE_LABEL" \
  --limit 100 \
  --json number,title \
  | jq -r --arg title "$TITLE" 'map(select(.title == $title)) | .[0].number // empty')"

if [ -n "$EXISTING" ]; then
  echo "Existing open issue #${EXISTING} — recording this failure as a comment"
  gh issue comment "$EXISTING" --repo "$GITHUB_REPOSITORY" --body-file "$BODY_FILE"
else
  echo "No open issue for this workflow — opening one"
  gh issue create \
    --repo "$GITHUB_REPOSITORY" \
    --title "$TITLE" \
    --body-file "$BODY_FILE" \
    --label "$ISSUE_LABELS"
fi
