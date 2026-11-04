#!/usr/bin/env bash
#
# Detect the lecture .md files a pull request added or modified.
# Shared by the preview-netlify and preview-cloudflare actions so the change
# detection (and its filtering rules) live in one place.
#
# Inputs (environment variables):
#   LECTURES_DIR  - directory holding lecture .md files (e.g. "lectures")
#   BASE_SHA      - PR base commit SHA (the tip of the base branch)
#   HEAD_SHA      - PR head commit SHA
#
# Outputs (appended to $GITHUB_OUTPUT):
#   changed-files       - newline-separated list of changed lecture files
#   strip-lectures-dir  - "true" if _toc.yml lives inside LECTURES_DIR
#
# The comparison is BASE...HEAD, from the merge base, so a lecture changed on
# the base branch after the pull request branched off is not listed (#215).
# That needs the merge base locally. A full checkout has it, and nothing is
# fetched. In a shallow one, fetching the two commits with no depth pulls
# their whole history, so the history is deepened instead, from 64 commits
# behind each end and doubling, until the merge base is found or the history
# reaches 1,024 commits. Past that, or when the two share no history at all,
# the comparison falls back to BASE..HEAD, which can also list lectures
# changed only on the base branch.
#
# A git failure never fails the step, since the deploy is worth more than the
# lecture links, but it is reported as a ::warning:: with git's own message,
# not swallowed.
#
# Note: lectures_dir is treated as a *literal* path (quoted-glob matching),
# not a regex, so values containing regex metacharacters behave correctly.

: "${BASE_SHA:?BASE_SHA is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"
lectures_dir="${LECTURES_DIR:-lectures}"

first_depth=64
max_depth=1024

echo "Detecting changed lecture files in ${lectures_dir}..."

# The last git command's stderr, so a warning can quote git's own message.
git_err=$(mktemp "${RUNNER_TEMP:-/tmp}/detect-changed-lectures.XXXXXX")
trap 'rm -f "$git_err"' EXIT

# warn MESSAGE: a ::warning:: annotation, with git's message after it if the
# last git command left one.
warn() {
  local msg="$1" err
  err=$(<"$git_err")
  [ -z "$err" ] || msg="${msg}: ${err}"
  msg=${msg//'%'/'%25'}
  msg=${msg//$'\r'/'%0D'}
  msg=${msg//$'\n'/'%0A'}
  echo "::warning::${msg}"
}

# '+': a ref left by an earlier run in a reused workspace is overwritten, not
# refused as a non-fast-forward.
base_refspec="+${BASE_SHA}:refs/remotes/origin/pr-base"
head_refspec="+${HEAD_SHA}:refs/remotes/origin/pr-head"

# fetch [--depth=N|--deepen=N] REFSPEC...
# --no-auto-gc: a fetch otherwise starts maintenance in the background, which
# can rewrite .git/shallow while the next --deepen runs, and git then aborts
# that fetch with "shallow file has changed since we read it".
fetch() {
  local opts=(--quiet --no-tags --no-recurse-submodules --no-auto-gc)
  case "$1" in --*) opts+=("$1"); shift ;; esac
  git fetch "${opts[@]}" origin "$@" 2>"$git_err"
}

find_merge_base() {
  git merge-base "$BASE_SHA" "$HEAD_SHA" >/dev/null 2>"$git_err"
}

range=""
searched=""
if ! shallow=$(git rev-parse --is-shallow-repository 2>"$git_err"); then
  warn "git cannot read the checkout, so no changed lectures are listed"
else
  if ! find_merge_base; then
    missing=()
    git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null || missing+=("$base_refspec")
    git cat-file -e "${HEAD_SHA}^{commit}" 2>/dev/null || missing+=("$head_refspec")

    if [ "$shallow" != true ]; then
      # The server sends only what the full history here lacks.
      if [ "${#missing[@]}" -gt 0 ] && ! fetch "${missing[@]}"; then
        warn "Could not fetch the pull request's base and head commits"
      fi
    else
      # How many commits behind each end the history reaches, at least. A
      # commit already here counts as reaching nothing, since its depth is
      # not known.
      reach=0
      # --depth only for commits not here yet: on one already here it cuts
      # the history behind it to the depth given.
      if [ "${#missing[@]}" -gt 0 ] && ! fetch --depth="$first_depth" "${missing[@]}"; then
        warn "Could not fetch the pull request's base and head commits"
      else
        [ "${#missing[@]}" -lt 2 ] || reach=$first_depth
        while ! find_merge_base; do
          if [ "$reach" -ge "$max_depth" ]; then
            searched=" within ${max_depth} commits"
            break
          fi
          step=$(( reach > 0 ? reach : first_depth ))
          if ! fetch --deepen="$step" "$base_refspec" "$head_refspec"; then
            warn "Could not fetch more history to find where the pull request branched off"
            break
          fi
          reach=$((reach + step))
        done
      fi
    fi
  fi

  if find_merge_base; then
    range="${BASE_SHA}...${HEAD_SHA}"
  elif [ $? -eq 1 ]; then
    # Both commits are here, but no common ancestor is.
    if [ "$shallow" = true ]; then
      warn "Found no merge base${searched} of the pull request's base and head, so lectures are compared from the base branch's tip, and a lecture changed only on the base branch is listed too"
    else
      warn "The pull request's base and head share no history, so lectures are compared from the base branch's tip, and a lecture changed only on the base branch is listed too"
    fi
    range="${BASE_SHA}..${HEAD_SHA}"
  else
    warn "Could not compare the pull request's base and head, so no changed lectures are listed"
  fi
fi

# --no-renames: a rename is reported as R<score> with two paths, which the
# A/M filter below drops, so a renamed lecture got no preview link. Without
# rename detection it decomposes into D (old path) + A (new path), and the A
# half is kept like any other added lecture.
all_changed=""
[ -z "$range" ] || echo "Comparing ${range}"
if [ -n "$range" ] \
    && ! all_changed=$(git diff --no-renames --name-status "$range" 2>"$git_err"); then
  warn "git diff ${range} failed, so no changed lectures are listed"
  all_changed=""
fi

changed_lecture_files=""
if [ -n "$all_changed" ]; then
  while IFS=$'\t' read -r status file; do
    [ -z "$status" ] && continue

    # Only Added (A) or Modified (M) files. The status is git's own answer to
    # whether the file differs, so the diff text is never parsed: a content
    # line such as a '---' front-matter delimiter could pass for a header.
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

    echo "✓ Changed: $file"
    if [ -z "$changed_lecture_files" ]; then
      changed_lecture_files="$file"
    else
      changed_lecture_files="${changed_lecture_files}"$'\n'"$file"
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
