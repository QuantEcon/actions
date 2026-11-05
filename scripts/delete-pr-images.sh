#!/usr/bin/env bash
#
# Delete a pull request's candidate images from GHCR when it closes (#142).
# validate-containers.yml runs this from its cleanup job, and with DRY_RUN=true
# from each build, to check that the candidate it just pushed is one this
# cleanup will select.
#
#   OWNER=QuantEcon PR_NUMBER=231 IMAGES="quantecon quantecon-build" \
#     scripts/delete-pr-images.sh
#
# Prints one line per version it deletes (or, with DRY_RUN=true, would delete):
#   ghcr.io/quantecon/<image>@<digest> <tag>,<tag>
# and its diagnostics on stderr.
#
# validate-containers.yml pushes each candidate as a single image manifest
# (provenance off, so no index with untagged children), tagged pr-<N> and
# pr-<N>-<YYYYMMDD>-<HHMMSS>-<sha7>. GHCR has no "untag": a tag goes only when
# the package version carrying it is deleted, and every other tag on that
# version goes with it. So a version is deleted only when
#   1. every tag on it is one of this pull request's two forms, and
#   2. it is not :latest, nor a manifest listed in :latest's index.
# A version with a pr-<N> tag that fails either test is kept, with a warning:
# someone has put it to another use, and only a person should remove it.
#
# Required environment:
#   GH_TOKEN   a token that can list and delete the package versions. A
#              workflow's GITHUB_TOKEN needs `packages: write`, and deleting
#              needs the admin role on the package, which a repository holds on
#              the packages its own workflows published.
#   OWNER      the organisation that owns the packages (any case)
#   PR_NUMBER  the pull request's number
#   IMAGES     space-separated image (package) names
# Optional:
#   DRY_RUN    true to select without deleting
# docker must be logged in to ghcr.io, to read :latest's index.
set -euo pipefail

for var in GH_TOKEN OWNER PR_NUMBER IMAGES; do
  [ -n "${!var:-}" ] || { echo "::error::$var is required but is not set" >&2; exit 1; }
done
[[ $PR_NUMBER =~ ^[1-9][0-9]*$ ]] || { echo "::error::PR_NUMBER [$PR_NUMBER] is not a pull request number" >&2; exit 1; }
DRY_RUN="${DRY_RUN:-false}"

# GHCR image paths are lowercase, whatever the owner's casing on GitHub.
REGISTRY="ghcr.io/$(tr '[:upper:]' '[:lower:]' <<< "$OWNER")"
TAG_RE="^pr-${PR_NUMBER}(-[0-9]{8}-[0-9]{6}-[0-9a-f]{7})?\$"

WORK=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/delete-pr-images-XXXXXX")
trap 'rm -rf "$WORK"' EXIT

for image in $IMAGES; do
  [[ $image =~ ^[a-z0-9][a-z0-9._-]*$ ]] || { echo "::error::[$image] is not an image name" >&2; exit 1; }

  # One {id, digest, tags} per version. A package that does not exist has no
  # candidates; any other failure (a token that cannot read the package) is an
  # error, never "nothing to delete".
  if ! gh api --paginate "orgs/$OWNER/packages/container/$image/versions?per_page=100" \
      --jq '.[] | {id, digest: .name, tags: (.metadata.container.tags // [])}' \
      > "$WORK/versions" 2> "$WORK/err"; then
    if grep -q 'HTTP 404' "$WORK/err"; then
      echo "$image: no such package, nothing to delete" >&2
      continue
    fi
    cat "$WORK/err" >&2
    echo "::error::cannot list the versions of $REGISTRY/$image" >&2
    exit 1
  fi

  ours=$(jq -c --arg re "$TAG_RE" 'select(any(.tags[]; test($re)))' "$WORK/versions")
  if [ -z "$ours" ]; then
    echo "$image: no pr-$PR_NUMBER candidates" >&2
    continue
  fi

  # Everything :latest resolves to: the version tagged latest (an index, as
  # build-push-action pushes it with a provenance attestation) and the
  # manifests it lists. Read only when :latest exists; if it exists and cannot
  # be read, stop rather than delete without the guard.
  protected=''
  if jq -e 'select(any(.tags[]; . == "latest"))' "$WORK/versions" > /dev/null; then
    protected=$(docker buildx imagetools inspect "$REGISTRY/$image:latest" --format '{{json .Manifest}}' \
      | jq -r '.digest, (.manifests[]?.digest)') \
      && [ -n "$protected" ] \
      || { echo "::error::cannot read $REGISTRY/$image:latest, so cannot rule out deleting what it points at" >&2; exit 1; }
  fi

  while IFS= read -r version; do
    id=$(jq -r .id <<< "$version")
    digest=$(jq -r .digest <<< "$version")
    tags=$(jq -r '.tags | join(",")' <<< "$version")
    if ! jq -e --arg re "$TAG_RE" 'all(.tags[]; test($re))' <<< "$version" > /dev/null; then
      echo "::warning::keeping $REGISTRY/$image@$digest: it also carries tags that are not pr-$PR_NUMBER's [$tags]" >&2
      continue
    fi
    if grep -qxF "$digest" <<< "$protected"; then
      echo "::warning::keeping $REGISTRY/$image@$digest [$tags]: it is what :latest points at" >&2
      continue
    fi
    echo "$REGISTRY/$image@$digest $tags"
    if [ "$DRY_RUN" != true ]; then
      gh api --method DELETE "orgs/$OWNER/packages/container/$image/versions/$id" --silent
    fi
  done <<< "$ours"
done
