#!/bin/bash
#
# Create failure issue for build-jupyter-cache action
# 
# This script is called when a cache build fails to create or update
# a GitHub issue alerting maintainers.
#
# Required environment variables:
#   GH_TOKEN - GitHub token for API calls
#   GITHUB_RUN_ID - Workflow run ID
#   GITHUB_SERVER_URL - GitHub server (e.g., https://github.com)
#   GITHUB_REPOSITORY - Owner/repo  
#   GITHUB_EVENT_NAME - Trigger event (push, schedule, etc.)
#   GITHUB_REF_NAME - Branch name
#   GITHUB_SHA - Commit SHA
#   SOURCE_DIR - Source directory for lectures
#   ISSUE_LABELS - Labels to apply (comma-separated)
#   ISSUE_ASSIGNEES - Assignees (comma-separated, optional)
#   JUPYTER_STATUS - Status of jupyter build (success/failure/skipped)
#   PDFLATEX_STATUS - Status of pdflatex build (success/failure/skipped)
#   HTML_STATUS - Status of html build (success/failure/skipped)
#

set -e

# Format status with emoji
format_status() {
  case "$1" in
    success) echo "✅ success" ;;
    failure) echo "❌ failure" ;;
    skipped) echo "⏭️ skipped" ;;
    *) echo "$1" ;;
  esac
}

# Generate issue body
CURRENT_DATE=$(date -u +"%Y-%m-%d %H:%M UTC")

cat > /tmp/issue-body.md << EOF
## 🔴 Jupyter Cache Build Failed

**Workflow Run:** [${GITHUB_RUN_ID}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})
**Trigger:** ${GITHUB_EVENT_NAME}
**Branch:** ${GITHUB_REF_NAME}
**Commit:** ${GITHUB_SHA}
**Date:** ${CURRENT_DATE}

### Build Results

| Builder | Status |
|---------|--------|
| jupyter | $(format_status "$JUPYTER_STATUS") |
| pdflatex | $(format_status "$PDFLATEX_STATUS") |
| html | $(format_status "$HTML_STATUS") |

### Impact

⚠️ **The existing cache has been preserved** - PR workflows will continue to use the previous working cache.

### Debug Steps

1. Check the [workflow logs](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})
2. Download the build artifact for detailed execution reports
3. Run locally to reproduce:
   \`\`\`bash
   jb build ${SOURCE_DIR} --builder <failed-builder>
   \`\`\`

### Notes

- This issue was automatically created by the cache build workflow
- Close this issue once the build is fixed
- A new cache will be saved on the next successful build
EOF

echo "Issue content prepared"

# Build assignees flag if provided
ASSIGNEES_FLAG=""
if [ -n "$ISSUE_ASSIGNEES" ]; then
  ASSIGNEES_FLAG="--assignee $ISSUE_ASSIGNEES"
fi

# Check for existing open issue with same label to avoid duplicates
EXISTING=$(gh issue list --label "build-failure" --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -n "$EXISTING" ]; then
  echo "Found existing open issue #$EXISTING, adding comment instead of creating new issue"
  gh issue comment "$EXISTING" --body-file /tmp/issue-body.md
else
  echo "Creating new failure issue"
  # shellcheck disable=SC2086
  gh issue create \
    --title "🔴 Cache Build Failed - $(date -u +%Y-%m-%d)" \
    --body-file /tmp/issue-body.md \
    --label "$ISSUE_LABELS" \
    $ASSIGNEES_FLAG
fi
