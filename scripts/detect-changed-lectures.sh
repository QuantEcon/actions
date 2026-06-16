#!/usr/bin/env bash
#
# Detect added/modified lecture .md files between a PR's base and head commit.
# Shared by the preview-netlify and preview-cloudflare actions so the change
# detection (and its filtering rules) live in one place.
#
# Inputs (environment variables):
#   LECTURES_DIR  - directory holding lecture .md files (e.g. "lectures")
#   BASE_SHA      - PR base commit SHA
#   HEAD_SHA      - PR head commit SHA
#
# Outputs (appended to $GITHUB_OUTPUT):
#   changed-files       - newline-separated list of changed lecture files
#   strip-lectures-dir  - "true" if _toc.yml lives inside LECTURES_DIR
#
# Note: lectures_dir is treated as a *literal* path (quoted-glob matching),
# not a regex, so values containing regex metacharacters behave correctly.

: "${BASE_SHA:?BASE_SHA is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"
lectures_dir="${LECTURES_DIR:-lectures}"

echo "Detecting changed lecture files in ${lectures_dir}..."

# Make sure both endpoints are available locally (best effort).
git fetch origin "${BASE_SHA}:refs/remotes/origin/pr-base" 2>/dev/null || true
git fetch origin "${HEAD_SHA}:refs/remotes/origin/pr-head" 2>/dev/null || true

all_changed=$(git diff --name-status "${BASE_SHA}..${HEAD_SHA}" 2>/dev/null || echo "")

changed_lecture_files=""
if [ -n "$all_changed" ]; then
  while IFS=$'\t' read -r status file; do
    [ -z "$status" ] && continue

    # Only Added (A) or Modified (M) files.
    case "$status" in
      A*|M*) ;;
      *) continue ;;
    esac

    # Path filters — quoted "$lectures_dir" keeps it literal, so a dir name
    # with '.', '+', etc. doesn't act as a regex.
    [[ "$file" == "$lectures_dir"/*.md ]] || continue   # under lectures dir, .md
    [[ "$file" != "$lectures_dir"/_* ]]   || continue   # skip _config, _toc, ...
    [[ "$file" != "$lectures_dir/intro.md" ]] || continue
    [ -f "$file" ] || continue

    # Require actual content changes (ignore pure rename/metadata diffs).
    content_diff=$(git diff "${BASE_SHA}..${HEAD_SHA}" -- "$file" \
      | grep -E '^[+-]' | grep -vE '^[+-]{3}' | wc -l)
    content_diff=$(echo "$content_diff" | tr -d '[:space:]')
    if [ "${content_diff:-0}" -gt 0 ]; then
      echo "✓ Changed: $file"
      if [ -z "$changed_lecture_files" ]; then
        changed_lecture_files="$file"
      else
        changed_lecture_files="${changed_lecture_files}"$'\n'"$file"
      fi
    fi
  done <<< "$all_changed"
fi

if [ -n "$changed_lecture_files" ]; then
  {
    echo "changed-files<<EOF"
    echo "$changed_lecture_files"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
else
  echo "changed-files=" >> "$GITHUB_OUTPUT"
fi

if [ -f "${lectures_dir}/_toc.yml" ]; then
  echo "strip-lectures-dir=true" >> "$GITHUB_OUTPUT"
  echo "📁 _toc.yml found in ${lectures_dir}/ - will strip directory from URLs"
else
  echo "strip-lectures-dir=false" >> "$GITHUB_OUTPUT"
  echo "📁 _toc.yml not in ${lectures_dir}/ - will keep directory in URLs"
fi
