#!/usr/bin/env bash
#
# Decide whether a preview action deploys on this run, and to which alias
# (#227). Shared by the preview-netlify and preview-cloudflare actions, so the
# two cannot disagree. Each calls it once, first: its change detection, CLI
# install, deploy and comment all follow the `deploy` output, so the install
# can never run without the deploy (#193), nor the deploy without these checks.
#
# The events are an ALLOW-list, never a deny-list:
#
#   pull_request                 deploys to pr-<number>, except for a pull
#                                request from a fork (its runs get no secrets)
#   workflow_dispatch, schedule  deploys to DISPATCH_ALIAS, only when it is set
#   anything else                deploys nothing
#
# and a run by Dependabot, which gets no secrets either, deploys nothing on any
# event. The `pull_request` literal is what keeps `pull_request_target` out
# (#105): that event runs a pull request's code with this repository's secrets,
# so no input may make it deploy.
#
# Inputs (environment variables; the action passes the github context through
# env, never into a script body):
#   PROVIDER        - "Netlify" or "Cloudflare", for the messages
#   EVENT_NAME      - github.event_name
#   ACTOR           - github.actor
#   REPOSITORY      - github.repository
#   HEAD_REPO       - github.event.pull_request.head.repo.full_name
#   PR_NUMBER       - github.event.pull_request.number
#   DISPATCH_ALIAS  - the dispatch-alias input, empty for none
#
# Outputs (appended to $GITHUB_OUTPUT):
#   deploy  - "true" or "false", always
#   alias   - pr-<number> or DISPATCH_ALIAS when deploy is "true", else empty
#
# A run that deploys nothing says why in a ::notice::, or a ::warning:: on
# pull_request_target. An invalid DISPATCH_ALIAS fails on every event, so a
# typo shows on the next pull request, not on the first scheduled run.
# Exit 0 = decided, 1 = invalid input.

set -euo pipefail

: "${PROVIDER:?PROVIDER is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
EVENT_NAME=${EVENT_NAME:-}
ACTOR=${ACTOR:-}
REPOSITORY=${REPOSITORY:-}
HEAD_REPO=${HEAD_REPO:-}
PR_NUMBER=${PR_NUMBER:-}
DISPATCH_ALIAS=${DISPATCH_ALIAS:-}

decided() {  # <deploy> <alias>
  { echo "deploy=$1"; echo "alias=$2"; } >> "$GITHUB_OUTPUT"
  exit 0
}
skip() {  # <reason> [annotation]
  echo "::${2:-notice}::No $PROVIDER preview deployed: $1"
  decided false ''
}
fail() { echo "::error::$1"; exit 1; }

# The `dispatch-` prefix keeps the alias clear of every pull request's
# pr-<number> and of the production site. Single dashes only: Netlify writes
# the URL as <alias>--<site>, so a `--` inside the alias would be ambiguous.
# Both actions build the URL from the alias rather than reading it back, so it
# must reach the provider unchanged: Netlify's --alias takes at most 37
# characters, and Pages documents no length rule for branch aliases, only that
# it lowercases them and maps other characters to `-`. 28 stays well inside
# both, with room enough for dispatch-canary-weekly.
if [ -n "$DISPATCH_ALIAS" ]; then
  [[ "$DISPATCH_ALIAS" =~ ^dispatch(-[a-z0-9]+)+$ && ${#DISPATCH_ALIAS} -le 28 ]] \
    || fail "dispatch-alias [$DISPATCH_ALIAS] must be dispatch- followed by lowercase letters and digits, in words joined by single dashes, at most 28 characters in all, such as dispatch-canary."
fi

[ "$ACTOR" != "dependabot[bot]" ] || skip "runs by Dependabot get no secrets."

case "$EVENT_NAME" in
  pull_request)
    # A deleted fork leaves HEAD_REPO empty, which is treated as a fork.
    [ "$HEAD_REPO" = "$REPOSITORY" ] || skip "pull requests from forks get no secrets."
    # The #143 spike's control deployed to a bare `pr-` when the number was
    # missing; refuse instead.
    [[ "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]] \
      || fail "a pull_request event without a pull request number [$PR_NUMBER]; refusing to deploy."
    [ -z "$DISPATCH_ALIAS" ] || echo "dispatch-alias is not used on pull_request: this preview goes to pr-$PR_NUMBER."
    alias="pr-$PR_NUMBER"
    ;;
  workflow_dispatch|schedule)
    [ -n "$DISPATCH_ALIAS" ] || skip "a $EVENT_NAME run deploys only when dispatch-alias is set."
    alias=$DISPATCH_ALIAS
    ;;
  pull_request_target)
    skip "the action never deploys on pull_request_target, which runs a pull request's code with this repository's secrets. Use pull_request." warning
    ;;
  *)
    skip "the action deploys on pull_request, and on workflow_dispatch or schedule with dispatch-alias set, not on ${EVENT_NAME:-an unnamed event}."
    ;;
esac

echo "Deploying the $PROVIDER preview to the alias $alias."
decided true "$alias"
