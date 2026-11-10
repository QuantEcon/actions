#!/usr/bin/env bash
#
# Delete the container images' old candidate versions from GHCR (#277).
# prune-images.yml runs this monthly and by dispatch, and with DRY_RUN=true
# on each pull request that changes it, so that the list it prints there is
# what a live run would delete.
#
#   OWNER=QuantEcon IMAGES="quantecon quantecon-build" DRY_RUN=false \
#     scripts/prune-images.sh
#   scripts/prune-images.sh --self-test
#
# GHCR has no "untag": a tag goes only when the package version carrying it
# is deleted, with every other tag on it. And each manifest is a version of
# its own, so a build of main, an index with an image manifest and a
# provenance attestation, is three versions, two of them untagged. Deleting a
# manifest an index lists breaks the index. So, per image, it lists every
# version and classifies it by its tags:
#   main      every tag is main-<sha7> or main-<YYYYMMDD>-<HHMMSS>-<sha7>.
#             The newest KEEP_BUILDS are kept, and every one younger than
#             KEEP_DAYS: they are the rollback targets.
#   branch    every tag is <branch>-<sha7> or <branch>-<date>-<time>-<sha7>,
#             a dispatch from a branch, never promoted. Kept for BRANCH_DAYS.
#   untagged  no tag. Kept when younger than UNTAGGED_DAYS, by default
#             KEEP_DAYS, so that every version of the last KEEP_DAYS is kept,
#             tagged or not: a build whose tags moved on to a later build of
#             the same commit is still one someone may have pinned. The age
#             also covers a build in progress, which pushes an index's
#             manifests before the index.
#   anything else is kept: :latest, a pull request's pr-<N> candidates, which
#             delete-pr-images.sh removes when it closes, and any version
#             carrying a tag this script does not own, which someone has put
#             to another use. A tag ending in -<7 hex digits> is owned.
# It also keeps every digest in PINS_FILE, `<image>@sha256:<digest>` per line,
# which pins by digest elsewhere rely on, and :latest's digest as the
# registry resolves it. Then it reads the manifest of everything it keeps,
# and keeps every manifest those list. What is left is deleted: tagged
# versions first, then untagged ones, each newest first, so an index goes
# before the manifests it lists and a run that stops part-way leaves no
# broken index.
#
# It plans every image before it deletes anything, and stops with nothing
# deleted when a listing or a kept manifest cannot be read, or when an image
# has more than MAX_DELETE versions to delete. A dry run prints the same
# plan, and only warns at the ceiling.
#
# Prints a Markdown summary on stdout, for the step summary: for each image,
# every version it deletes or would delete, and what it keeps, by rule.
# Diagnostics go to stderr.
#
# Required environment:
#   GH_TOKEN    a token that can list the package versions, and delete them
#               unless DRY_RUN is true (`packages: write`, and the admin role
#               on the package, which a repository holds on the packages its
#               own workflows published)
#   OWNER       the organisation that owns the packages (any case)
#   IMAGES      space-separated image (package) names
# Optional:
#   DRY_RUN        false to delete (default true)
#   KEEP_BUILDS    default 10
#   KEEP_DAYS      default 90
#   BRANCH_DAYS    default 14
#   UNTAGGED_DAYS  default KEEP_DAYS
#   MAX_DELETE     per image, default 50
#   PINS_FILE      default .github/container-pins.txt
#   NOW            the time to age versions against, in Unix seconds (default now)
# docker must be logged in to ghcr.io, to read the manifests.
set -euo pipefail

fail() { echo "::error::$*" >&2; exit 1; }

MAIN_RE='^main-([0-9]{8}-[0-9]{6}-)?[0-9a-f]{7}$'
PR_RE='^pr-[0-9]+(-[0-9]{8}-[0-9]{6}-[0-9a-f]{7})?$'
BRANCH_RE='^[a-z0-9][a-z0-9._-]*-([0-9]{8}-[0-9]{6}-)?[0-9a-f]{7}$'

# A manifest's digest, then the digest of each manifest it lists, one per
# line. Fails when it cannot be read.
manifest_digests() {
  docker buildx imagetools inspect "$1" --format '{{json .Manifest}}' | jq -er '.digest, (.manifests[]?.digest)'
}

# Plans one image into $work/<image>.plan, one JSON object per version with
# `delete`, `rule` and `why`. Called under ||, so set -e is off: every step
# returns 1 itself when it fails.
plan_image() {
  local image=$1 registry=$2 digest pin
  if ! gh api --paginate "orgs/$OWNER/packages/container/$image/versions?per_page=100" > "$work/$image.raw" 2> "$work/err"; then
    cat "$work/err" >&2
    echo "::error::cannot list the versions of $registry/$image" >&2
    return 1
  fi
  jq -c '.[] | {id, digest: .name, created: .created_at, tags: (.metadata.container.tags // [])}' "$work/$image.raw" > "$work/$image.versions" \
    || { echo "::error::cannot read the versions of $registry/$image" >&2; return 1; }
  [ -s "$work/$image.versions" ] || { echo "::error::$registry/$image lists no versions" >&2; return 1; }

  # Classified, aged, and decided by tags and age alone.
  jq -sc --argjson now "$NOW" --argjson keep_builds "$KEEP_BUILDS" --argjson keep_days "$KEEP_DAYS" \
      --argjson branch_days "$BRANCH_DAYS" --argjson untagged_days "$UNTAGGED_DAYS" \
      --arg main_re "$MAIN_RE" --arg pr_re "$PR_RE" --arg branch_re "$BRANCH_RE" '
    def keep($rule; $why): {delete: false, rule: $rule, why: $why};
    def drop($rule; $why): {delete: true, rule: $rule, why: $why};
    map(. + {days: ((($now - (.created | sub("\\.[0-9]+"; "") | fromdateiso8601)) / 86400) | floor)})
    | map(. + {kind: (
        if (.tags | length) == 0 then "untagged"
        elif any(.tags[]; . == "latest") then "latest"
        elif all(.tags[]; test($main_re)) then "main"
        elif all(.tags[]; test($pr_re)) then "pr"
        elif all(.tags[]; test($branch_re) and ((test($main_re) or test($pr_re)) | not)) then "branch"
        else "other" end)})
    | (map(select(.kind == "main")) | sort_by(.created) | reverse | map(.digest)) as $mains
    | map(. as $v | . + (
        if .kind == "main" then
          ($mains | index($v.digest)) as $i
          | if $i < $keep_builds then keep("main build, among the newest \($keep_builds)"; "main build, \($i + 1) of the newest \($keep_builds)")
            elif .days < $keep_days then keep("main build, under \($keep_days) days old"; "main build, \(.days) days old")
            else drop("main build"; "main build, \(.days) days old, with \($i) newer") end
        elif .kind == "branch" then
          if .days < $branch_days then keep("branch dispatch, under \($branch_days) days old"; "branch dispatch, \(.days) days old")
          else drop("branch dispatch"; "branch dispatch, \(.days) days old") end
        elif .kind == "untagged" then
          if .days < $untagged_days then keep("untagged, under \($untagged_days) days old"; "untagged, \(.days) days old")
          else drop("untagged"; "untagged, \(.days) days old, listed by no kept manifest") end
        elif .kind == "latest" then keep(":latest"; ":latest")
        elif .kind == "pr" then keep("a pull request candidate, for delete-pr-images.sh"; "a pull request candidate")
        else keep("carries a tag this script does not own"; "carries a tag this script does not own") end))
    | .[]' "$work/$image.versions" > "$work/$image.byrule" \
    || { echo "::error::cannot classify the versions of $registry/$image" >&2; return 1; }

  # What :latest resolves to now, each pin, and each tagged version kept, with
  # every manifest each lists. An untagged version kept is young, and a
  # build's index is tagged, so none of them needs reading.
  manifest_digests "$registry/$image:latest" > "$work/$image.protected" \
    || { echo "::error::cannot read $registry/$image:latest, so cannot rule out deleting what it points at" >&2; return 1; }
  # This image's pins, by its name as a fixed string: each line is already
  # <image>@sha256:<digest>.
  while IFS= read -r pin; do
    if [ "${pin%%@*}" = "$image" ]; then echo "${pin#*@}"; fi
  done < "$work/pins" > "$work/$image.read"
  jq -r 'select(.delete == false and (.tags | length) > 0) | .digest' "$work/$image.byrule" >> "$work/$image.read" \
    || return 1
  while IFS= read -r digest; do
    manifest_digests "$registry/$image@$digest" >> "$work/$image.protected" \
      || { echo "::error::cannot read $registry/$image@$digest, which is pinned or kept, so cannot rule out deleting what it lists" >&2; return 1; }
  done < "$work/$image.read"

  jq -c --rawfile protected "$work/$image.protected" '
    ($protected | split("\n")) as $p
    | if .delete and (.digest as $d | $p | index($d)) then
        . + {delete: false, rule: "pinned, or listed by a kept manifest", why: "pinned, or listed by a kept manifest"}
      else . end
  ' "$work/$image.byrule" > "$work/$image.plan" \
    || { echo "::error::cannot apply the kept manifests to $registry/$image" >&2; return 1; }
}

# One image's deletions in the order they run: tagged first, then untagged,
# each newest first.
deletions() {
  jq -sc 'map(select(.delete)) | group_by((.tags | length) == 0) | map(sort_by(.created) | reverse) | add // [] | .[]' "$work/$1.plan"
}

# One image's plan, as Markdown.
report() {
  local image=$1 registry=$2 verb=$3
  echo "### $registry/$image"
  echo
  jq -rs --arg verb "$verb" '"\(length) versions: \(map(select(.delete | not)) | length) kept, \(map(select(.delete)) | length) \($verb)."' "$work/$image.plan"
  echo
  deletions "$image" > "$work/$image.deletions"
  if [ -s "$work/$image.deletions" ]; then
    echo "| $(tr '[:lower:]' '[:upper:]' <<< "${verb:0:1}")${verb:1} | Tags | Created | Why |"
    echo "|---|---|---|---|"
    jq -r '"| `\(.digest)` | \(if (.tags | length) > 0 then .tags | map("`\(.)`") | join(", ") else "none" end) | \(.created) | \(.why) |"' "$work/$image.deletions"
    echo
  fi
  echo "Kept:"
  jq -rs 'map(select(.delete | not)) | group_by(.rule) | .[] | "- \(.[0].rule): \(length)"' "$work/$image.plan"
  echo
}

main() {
  local registry image n failed=0 verb id
  for var in GH_TOKEN OWNER IMAGES; do
    [ -n "${!var:-}" ] || fail "$var is required but is not set"
  done
  DRY_RUN=${DRY_RUN:-true}
  case $DRY_RUN in true | false) ;; *) fail "DRY_RUN [$DRY_RUN] is neither true nor false" ;; esac
  KEEP_BUILDS=${KEEP_BUILDS:-10} KEEP_DAYS=${KEEP_DAYS:-90} BRANCH_DAYS=${BRANCH_DAYS:-14}
  UNTAGGED_DAYS=${UNTAGGED_DAYS:-$KEEP_DAYS} MAX_DELETE=${MAX_DELETE:-50}
  for var in KEEP_BUILDS KEEP_DAYS BRANCH_DAYS UNTAGGED_DAYS MAX_DELETE; do
    [[ ${!var} =~ ^[1-9][0-9]*$ ]] || fail "$var [${!var}] is not a positive integer"
  done
  NOW=${NOW:-$(date +%s)}
  [[ $NOW =~ ^[0-9]+$ ]] || fail "NOW [$NOW] is not a time in Unix seconds"
  PINS_FILE=${PINS_FILE:-.github/container-pins.txt}
  [ -f "$PINS_FILE" ] || fail "$PINS_FILE: no such file, so the pins cannot be kept"
  for image in $IMAGES; do
    [[ $image =~ ^[a-z0-9][a-z0-9._-]*$ ]] || fail "[$image] is not an image name"
  done

  # GHCR image paths are lowercase, whatever the owner's casing on GitHub.
  registry="ghcr.io/$(tr '[:upper:]' '[:lower:]' <<< "$OWNER")"
  work=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/prune-images-XXXXXX")
  trap 'rm -rf "$work"' EXIT

  # Comments and blank lines aside, every line must be a pin.
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$PINS_FILE" > "$work/pins"
  if grep -vnE '^[a-z0-9][a-z0-9._-]*@sha256:[0-9a-f]{64}$' "$work/pins" > "$work/bad"; then
    fail "$PINS_FILE: not <image>@sha256:<digest>: $(paste -sd' ' - < "$work/bad")"
  fi

  for image in $IMAGES; do
    plan_image "$image" "$registry" || exit 1
  done

  for image in $IMAGES; do
    n=$(jq -s 'map(select(.delete)) | length' "$work/$image.plan")
    [ "$n" -gt "$MAX_DELETE" ] || continue
    if [ "$DRY_RUN" = true ]; then
      echo "::warning::$registry/$image has $n versions to delete, more than MAX_DELETE ($MAX_DELETE): a live run would stop" >&2
    else
      echo "::error::$registry/$image has $n versions to delete, more than MAX_DELETE ($MAX_DELETE), so nothing is deleted. Check the plan below, then run with a MAX_DELETE of $n" >&2
      failed=1
    fi
  done
  if [ "$failed" -ne 0 ]; then
    for image in $IMAGES; do report "$image" "$registry" "would delete"; done
    exit 1
  fi

  verb=$([ "$DRY_RUN" = true ] && echo "would delete" || echo "deleted")
  for image in $IMAGES; do
    report "$image" "$registry" "$verb"
    [ "$DRY_RUN" = false ] || continue
    while IFS= read -r version; do
      id=$(jq -r .id <<< "$version")
      gh api --method DELETE "orgs/$OWNER/packages/container/$image/versions/$id" --silent \
        || fail "cannot delete $registry/$image@$(jq -r .digest <<< "$version"); those above it in the list are deleted"
    done < "$work/$image.deletions"
  done
}

self_test() {
  local want got case
  # Global, so that the trap can still read it when a failing case exits.
  dir=$(mktemp -d "${TMPDIR:-/tmp}/prune-images-test.XXXXXX")
  trap 'rm -rf "$dir"' EXIT
  d() { printf 'sha256:%064x' "$1"; }
  # Stand-ins. gh lists $dir/<image>.json, or fails for an image named in
  # LIST_FAILS, and records each DELETE. docker reads $dir/manifests, one
  # `<digest> <listed digest>...` per line, and :latest's digest from
  # LATEST_IS or $dir/latest, and fails for a digest in INSPECT_FAILS.
  gh() {
    if [ "$1 $2" = "api --method" ]; then echo "DELETE ${4##*/}" >> "$dir/calls"; return 0; fi
    [ "$1 $2" = "api --paginate" ] || { echo "fake gh: unexpected [$*]" >&2; return 2; }
    local image=${3#orgs/*/packages/container/}
    image=${image%%/*}
    [[ " ${LIST_FAILS:-} " != *" $image "* ]] || { echo "HTTP 502" >&2; return 1; }
    cat "$dir/$image.json"
  }
  docker() {
    local ref=$4 digest line
    if [[ $ref == *:latest ]]; then digest=${LATEST_IS:-$(cat "$dir/latest")}; else digest=${ref#*@}; fi
    [[ " ${INSPECT_FAILS:-} " != *" $digest "* ]] || { echo "ERROR: 401 Unauthorized" >&2; return 1; }
    line=$(grep "^$digest" "$dir/manifests") || { echo "ERROR: $ref: not found" >&2; return 1; }
    jq -nc --arg d "$digest" --arg l "${line#"$digest"}" '{digest: $d, manifests: ($l | split(" ") | map(select(. != "")) | map({digest: .}))}'
  }
  # A version: id, digest number, days old, tags. The digest number also
  # orders versions of one age: a higher number is pushed earlier.
  now=$(jq -n '"2026-11-10T00:00:00Z" | fromdateiso8601')
  v() {
    local id=$1 n=$2 days=$3
    shift 3
    jq -nc --argjson id "$id" --arg digest "$(d "$n")" --argjson t "$((now - days * 86400 - n))" --args \
      '{id: $id, name: $digest, created_at: ($t | todate), metadata: {container: {tags: $ARGS.positional}}}' "$@"
  }
  {
    v 1 1 9 latest main-0000001 main-20261101-000000-0000001; v 2 2 9; v 3 3 9   # :latest and its two
    v 10 10 5 main-000000a; v 11 11 5; v 12 12 5                                 # newest main build
    v 20 20 10 main-20261031-000000-000000b; v 21 21 10; v 22 22 10              # second newest
    v 30 30 20 main-000000c; v 31 31 20; v 32 32 20                              # young, beyond KEEP_BUILDS
    v 40 40 40 main-000000d main-20260930-000000-000000d; v 41 41 40; v 42 42 40 # old: goes, with its two
    v 50 50 50 main-000000e; v 51 51 50; v 52 52 50                              # old, but pinned
    v 60 60 20 feat-x-00000f1                                                    # old branch dispatch: goes
    v 61 61 2 feat-y-20261108-000000-00000f2 feat-y-00000f2                      # young branch dispatch
    v 70 70 40 pr-5 pr-5-20261001-000000-0000a05                                 # a pull request's
    v 71 71 50 pr-5-20260920-000000-0000a04                                      # its last run's, pr-5 moved on
    v 80 80 100 keep-theme-tests                                                 # an unowned tag
    v 81 81 100 main-0000b81 rollback-good                                       # a main tag and an unowned one
    v 90 90 30                                                                   # an old orphan: goes
    v 91 91 2                                                                    # a young orphan
  } | jq -s . > "$dir/img.json"
  cp "$dir/img.json" "$dir/img2.json"
  {
    for n in 1 10 20 30 40 50; do echo "$(d "$n") $(d $((n + 1))) $(d $((n + 2)))"; done
    for n in 60 61 70 71 80 81; do d "$n"; echo; done
  } > "$dir/manifests"
  d 1 > "$dir/latest"
  printf '# pins\nimg@%s  # a test pin\n\n' "$(d 50)" > "$dir/pins"

  # A case's settings as NAME=value arguments, over these defaults.
  run() {
    : > "$dir/calls"
    (
      export OWNER=Owner IMAGES=img GH_TOKEN=x NOW="$now" KEEP_BUILDS=2 KEEP_DAYS=25 BRANCH_DAYS=14 \
        UNTAGGED_DAYS=7 PINS_FILE="$dir/pins"
      for setting in "$@"; do export "${setting?}"; done
      main
    ) > "$dir/out" 2> "$dir/err"
  }
  deleted() { [ ! -s "$dir/calls" ] || fail "self-test: [$1] deleted [$(paste -sd' ' - < "$dir/calls")]"; }

  # By default a dry run: the plan, and nothing deleted.
  run || fail "self-test: the dry run failed: $(cat "$dir/err")"
  deleted "the dry run"
  # shellcheck disable=SC2016 # the report's own backticks, not a command
  got=$(sed -n 's/^| `sha256:0*\([0-9a-f]*\)`.*/\1/p' "$dir/out" | paste -sd' ' -)
  [ "$got" = "3c 28 5a 29 2a" ] || fail "self-test: the dry run lists [$got], expected versions 60 40 90 41 42 (hex 3c 28 5a 29 2a): $(cat "$dir/out" "$dir/err")"
  grep -qF '26 versions: 21 kept, 5 would delete.' "$dir/out" || fail "self-test: the dry run's counts are wrong: $(sed -n 3p "$dir/out")"
  grep -qF -- '- a pull request candidate, for delete-pr-images.sh: 2' "$dir/out" || fail "self-test: both pull request candidates should be kept: $(cat "$dir/out")"
  grep -qF -- '- pinned, or listed by a kept manifest: 9' "$dir/out" || fail "self-test: the dry run should keep 9 versions for the pin and the kept manifests: $(cat "$dir/out")"
  # Live: exactly those, tagged first, each index before what it lists.
  want='DELETE 60 DELETE 40 DELETE 90 DELETE 41 DELETE 42'
  run DRY_RUN=false || fail "self-test: the live run failed: $(cat "$dir/err")"
  got=$(paste -sd' ' - < "$dir/calls")
  [ "$got" = "$want" ] || fail "self-test: the live run deleted [$got], expected [$want]"
  # By default an untagged version is kept as long as a main build: at
  # KEEP_DAYS=35, the 30-day-old orphan stays, and only build 40's go.
  run DRY_RUN=false UNTAGGED_DAYS= KEEP_DAYS=35 || fail "self-test: the run with the default UNTAGGED_DAYS failed: $(cat "$dir/err")"
  got=$(paste -sd' ' - < "$dir/calls")
  [ "$got" = "DELETE 60 DELETE 40 DELETE 41 DELETE 42" ] || fail "self-test: with UNTAGGED_DAYS defaulting to KEEP_DAYS=35, deleted [$got]"
  # A pin names its image exactly: for image i.g, a pin for ixg protects nothing.
  cp "$dir/img.json" "$dir/i.g.json"
  printf 'ixg@%s\ni.g@%s\n' "$(d 40)" "$(d 50)" > "$dir/dotpins"
  run DRY_RUN=false IMAGES=i.g PINS_FILE="$dir/dotpins" || fail "self-test: the run for i.g failed: $(cat "$dir/err")"
  got=$(paste -sd' ' - < "$dir/calls")
  [ "$got" = "$want" ] || fail "self-test: for i.g, with a pin for ixg, deleted [$got], expected [$want]"
  # After a quiet spell, the newest KEEP_BUILDS still stay.
  run DRY_RUN=false KEEP_DAYS=1 || fail "self-test: the run with KEEP_DAYS=1 failed: $(cat "$dir/err")"
  got=$(paste -sd' ' - < "$dir/calls")
  [ "$got" = "DELETE 30 DELETE 60 DELETE 40 DELETE 31 DELETE 32 DELETE 90 DELETE 41 DELETE 42" ] \
    || fail "self-test: with KEEP_DAYS=1, deleted [$got]"
  # :latest as the registry has it now, even when the listing says otherwise.
  run DRY_RUN=false "LATEST_IS=$(d 40)" || fail "self-test: the run with :latest moved failed: $(cat "$dir/err")"
  got=$(paste -sd' ' - < "$dir/calls")
  [ "$got" = "DELETE 60 DELETE 90" ] || fail "self-test: with :latest at version 40, deleted [$got]"
  # Over the ceiling: a live run deletes nothing, and a dry run warns.
  run DRY_RUN=false MAX_DELETE=4 && fail "self-test: a live run over MAX_DELETE should fail"
  deleted "a live run over MAX_DELETE"
  run MAX_DELETE=4 || fail "self-test: a dry run over MAX_DELETE should pass: $(cat "$dir/err")"
  grep -q 'a live run would stop' "$dir/err" || fail "self-test: a dry run over MAX_DELETE should warn"
  # Anything unreadable stops it with nothing deleted, in any image.
  for case in "INSPECT_FAILS=$(d 1)" "INSPECT_FAILS=$(d 20)" "INSPECT_FAILS=$(d 50)" LIST_FAILS=img LIST_FAILS=img2; do
    run DRY_RUN=false "IMAGES=img img2" "$case" && fail "self-test: [$case] should fail"
    deleted "$case"
  done
  # Without the pin, the pinned build goes with its two.
  printf '# none\n' > "$dir/nopins"
  run DRY_RUN=false PINS_FILE="$dir/nopins" || fail "self-test: the run without pins failed: $(cat "$dir/err")"
  got=$(paste -sd' ' - < "$dir/calls")
  [ "$got" = "DELETE 60 DELETE 40 DELETE 50 DELETE 90 DELETE 41 DELETE 42 DELETE 51 DELETE 52" ] \
    || fail "self-test: without the pin, deleted [$got]"
  # A missing or malformed pins file, or a bad setting, stops it.
  run PINS_FILE="$dir/absent" && fail "self-test: a missing pins file should fail"
  printf 'img@sha256:abc\n' > "$dir/badpins"
  run PINS_FILE="$dir/badpins" && fail "self-test: a malformed pin should fail"
  grep -q 'not <image>@sha256:<digest>' "$dir/err" || fail "self-test: a malformed pin failed for another reason: $(cat "$dir/err")"
  for case in DRY_RUN=no MAX_DELETE=0 KEEP_BUILDS=x KEEP_DAYS=-1 NOW=soon OWNER= IMAGES=Bad/Name; do
    run "$case" && fail "self-test: [$case] should fail"
    deleted "$case"
  done
  echo "prune-images self-test passed"
}

case "${1:-}" in
  --self-test) self_test ;;
  '') main ;;
  *) fail "unknown argument [$1]" ;;
esac
