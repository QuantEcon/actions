#!/usr/bin/env bash
#
# Point each image's :latest at the digest a build-containers.yml run pushed
# and smoke-tested (#142). That run's promote job calls this once, for every
# image the run built, after every smoke test has passed, so the images move
# together. validate-containers.yml runs it with DRY_RUN=true on each pull
# request's candidate, so that a promotion that cannot work fails a pull
# request rather than a merge.
#
#   OWNER=QuantEcon TAG=main-20261109-031500-abc1234 \
#     scripts/promote-image.sh quantecon@sha256:<digest> quantecon-build@sha256:<digest>
#   scripts/promote-image.sh --self-test
#
# Before it moves anything, it checks for every image that
#   1. <image>:$TAG, the tag the smoke test pulled, still resolves to the
#      digest given, so the image promoted is the one that passed, and
#   2. <image>:latest can be read, and records its digest: the rollback
#      target. An image with no :latest yet has none; any other error stops.
# Then, image by image, `docker buildx imagetools create` points :latest at
# the digest. With one source and --prefer-index=false it pushes the source's
# manifest unchanged, an index or a single image manifest alike, and the
# script checks that :latest now resolves to the digest given. With
# DRY_RUN=true it runs create with --dry-run instead, which prints the
# manifest it would push, and checks that the manifest has that digest.
#
# Prints a Markdown summary on stdout, for the step summary: for each image,
# the candidate, its digest, :latest before and after, and the command that
# puts :latest back. Each image's rows are printed before it moves, so a
# failure part-way still names what moved and how to undo it. Diagnostics go
# to stderr.
#
# Required environment:
#   OWNER    the organisation that owns the packages (any case)
#   TAG      the candidate tag the smoke test pulled, the same in every image
# Optional:
#   DRY_RUN  true to check everything and move nothing (default false)
# docker must be logged in to ghcr.io, with write access to the packages
# unless DRY_RUN is true.
set -euo pipefail

fail() { echo "::error::$*" >&2; exit 1; }

sha256() { if command -v sha256sum > /dev/null; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }

# A stand-in for `docker buildx imagetools`, for the self-test: a registry of
# files under $FAKE_REGISTRY, tags/<ref> holding a digest and
# manifests/<digest> the manifest. Every manifest is a single image manifest,
# as a pull request's candidate is, so create without --prefer-index=false
# wraps it in a new index, as buildx does. A tag holding `unreadable` fails as
# an authorisation error would, and a file named rewrap makes create push a
# changed manifest whatever its flags.
fake_docker() {
  cat << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
R=$FAKE_REGISTRY
echo "$*" >> "$R/calls"
sha256() { if command -v sha256sum > /dev/null; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }
lookup() {
  local d f
  if [[ $1 == *@* ]]; then
    d=${1#*@}
    [ -f "$R/manifests/$d" ] || { echo "ERROR: $1: not found" >&2; exit 1; }
  else
    f="$R/tags/${1//\//_}"
    [ -f "$f" ] || { echo "ERROR: $1: not found" >&2; exit 1; }
    d=$(cat "$f")
    [ "$d" != unreadable ] || { echo "ERROR: $1: unexpected status from HEAD request: 401 Unauthorized" >&2; exit 1; }
  fi
  echo "$d"
}
[ "$1 $2" = "buildx imagetools" ] || { echo "fake docker: unexpected [$*]" >&2; exit 2; }
case $3 in
  inspect)
    d=$(lookup "$4")
    printf '{"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"%s","size":2}\n' "$d" ;;
  create)
    shift 3
    dry=false copy=false
    while [ "$#" -gt 1 ]; do
      case $1 in
        --dry-run) dry=true ;;
        --prefer-index=false) copy=true ;;
        --tag) dst=$2; shift ;;
        *) echo "fake docker: unexpected [$1]" >&2; exit 2 ;;
      esac
      shift
    done
    manifest=$(cat "$R/manifests/$(lookup "$1")")
    if [ "$copy" != true ] || [ -f "$R/rewrap" ]; then manifest="{\"manifests\":[$manifest]}"; fi
    if [ "$dry" = true ]; then
      printf '%s\n' "$manifest"
    else
      d=sha256:$(printf '%s' "$manifest" | sha256)
      printf '%s' "$manifest" > "$R/manifests/$d"
      echo "$d" > "$R/tags/${dst//\//_}"
    fi ;;
  *) echo "fake docker: unexpected [$*]" >&2; exit 2 ;;
esac
EOF
}

self_test() {
  local work d1 d2 o1 o2 other status
  work=$(mktemp -d "${TMPDIR:-/tmp}/promote-image-test-XXXXXX")
  # shellcheck disable=SC2064 # expand now: $work is local, gone when the trap runs
  trap "rm -rf '$work'" EXIT
  mkdir -p "$work/bin"
  fake_docker > "$work/bin/docker"
  chmod +x "$work/bin/docker"

  local tag=main-20261109-031500-abc1234 q=ghcr.io/quantecon/quantecon b=ghcr.io/quantecon/quantecon-build
  add() { printf '%s' "$1" > "$work/reg/manifests/$(digest_of "$1")"; }
  digest_of() { echo "sha256:$(printf '%s' "$1" | sha256)"; }
  set_tag() { echo "$2" > "$work/reg/tags/${1//\//_}"; }
  get_tag() { cat "$work/reg/tags/${1//\//_}"; }
  d1=$(digest_of '{"n":"quantecon new"}') d2=$(digest_of '{"n":"quantecon-build new"}')
  o1=$(digest_of '{"n":"quantecon old"}') o2=$(digest_of '{"n":"quantecon-build old"}')
  other=$(digest_of '{"n":"someone else"}')
  reset() {
    rm -rf "$work/reg"
    mkdir -p "$work/reg/tags" "$work/reg/manifests"
    : > "$work/reg/calls"
    for m in '{"n":"quantecon new"}' '{"n":"quantecon-build new"}' '{"n":"quantecon old"}' '{"n":"quantecon-build old"}' '{"n":"someone else"}'; do add "$m"; done
    set_tag "$q:$tag" "$d1"; set_tag "$b:$tag" "$d2"
    set_tag "$q:latest" "$o1"; set_tag "$b:latest" "$o2"
  }
  # A separate process, so that its set -e holds whatever this one tests.
  run() {
    status=0
    env PATH="$work/bin:$PATH" FAKE_REGISTRY="$work/reg" OWNER=QuantEcon TAG="${RUN_TAG:-$tag}" \
      DRY_RUN="${RUN_DRY:-false}" RUNNER_TEMP="$work" bash "$0" "$@" > "$work/out" 2> "$work/err" || status=$?
  }
  bad() { echo "::error::self-test: $*" >&2; cat "$work/err" >&2; exit 1; }
  ok() { [ "$status" -eq 0 ] || bad "$1: exited $status"; }
  refused() { [ "$status" -ne 0 ] || bad "$1: exited 0"; grep -q '::error::' "$work/err" || bad "$1: no ::error:: line"; }
  unmoved() { [ "$(get_tag "$q:latest")" != "$d1" ] && [ "$(get_tag "$b:latest")" != "$d2" ] || bad "$1: :latest moved"; }

  reset; run "quantecon@$d1" "quantecon-build@$d2"; ok "promote both"
  [ "$(get_tag "$q:latest")" = "$d1" ] && [ "$(get_tag "$b:latest")" = "$d2" ] || bad "promote both: :latest is not the candidates"
  for previous in "$q@$o1" "$b@$o2"; do
    grep -qF "imagetools create --tag ${previous%@*}:latest $previous" "$work/out" \
      || bad "promote both: the summary has no command to put back $previous"
  done

  reset; RUN_DRY=true run "quantecon@$d1" "quantecon-build@$d2"; ok "dry run"; unmoved "dry run"
  ! grep 'create' "$work/reg/calls" | grep -qv -- '--dry-run' || bad "dry run: ran create without --dry-run"

  # Together: a later image's failed check stops the earlier one moving too.
  reset; set_tag "$b:$tag" "$other"; run "quantecon@$d1" "quantecon-build@$d2"; refused "a candidate tag that moved"; unmoved "a candidate tag that moved"
  reset; set_tag "$b:latest" unreadable; run "quantecon@$d1" "quantecon-build@$d2"; refused "an unreadable :latest"; unmoved "an unreadable :latest"
  reset; rm "$work/reg/tags/${q//\//_}:$tag"; run "quantecon@$d1"; refused "a candidate tag that is gone"; unmoved "a candidate tag that is gone"

  reset; rm "$work/reg/tags/${q//\//_}:latest"; run "quantecon@$d1"; ok "an image with no :latest"
  [ "$(get_tag "$q:latest")" = "$d1" ] || bad "an image with no :latest: not promoted"

  reset; touch "$work/reg/rewrap"; RUN_DRY=true run "quantecon@$d1"; refused "a dry run that is not a copy"
  reset; touch "$work/reg/rewrap"; run "quantecon@$d1"; refused "a promotion that is not a copy"
  grep -qF "imagetools create --tag $q:latest $q@$o1" "$work/out" || bad "a promotion that is not a copy: no rollback command"

  reset
  for args in "quantecon" "quantecon@sha256:abc" "Quantecon@$d1" ""; do
    # shellcheck disable=SC2086 # split on purpose: "" is no arguments at all
    run $args; refused "arguments [$args]"
  done
  RUN_TAG=latest run "quantecon@$d1"; refused "TAG=latest"
  RUN_DRY=yes run "quantecon@$d1"; refused "DRY_RUN=yes"
  unmoved "bad arguments"
  echo "promote-image self-test passed"
}

[ "${1:-}" != --self-test ] || { self_test; exit 0; }

for var in OWNER TAG; do
  [ -n "${!var:-}" ] || fail "$var is required but is not set"
done
DRY_RUN="${DRY_RUN:-false}"
[[ $DRY_RUN == true || $DRY_RUN == false ]] || fail "DRY_RUN [$DRY_RUN] is neither true nor false"
[[ $TAG =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ && $TAG != latest ]] || fail "TAG [$TAG] is not a candidate tag"
[ "$#" -gt 0 ] || fail "no images to promote: pass <image>@sha256:<digest> for each"

# GHCR image paths are lowercase, whatever the owner's casing on GitHub.
REGISTRY="ghcr.io/$(tr '[:upper:]' '[:lower:]' <<< "$OWNER")"

WORK=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/promote-image-XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# The digest a reference resolves to, or nothing when it does not exist. Any
# other failure to read it stops the script.
resolve() {
  local out digest
  if out=$(docker buildx imagetools inspect "$1" --format '{{json .Manifest}}' 2> "$WORK/err"); then
    digest=$(jq -r .digest <<< "$out") || fail "cannot parse what $1 resolves to: [$out]"
    [[ $digest =~ ^sha256:[0-9a-f]{64}$ ]] || fail "$1 resolves to [$digest], not a digest"
    echo "$digest"
  elif grep -q ': not found' "$WORK/err"; then
    return 0
  else
    cat "$WORK/err" >&2
    fail "cannot read $1"
  fi
}

images=() digests=() befores=()
for arg in "$@"; do
  image=${arg%%@*} digest=${arg#*@}
  [[ $image =~ ^[a-z0-9][a-z0-9._-]*$ && $digest =~ ^sha256:[0-9a-f]{64}$ ]] \
    || fail "[$arg] is not <image>@sha256:<64 hex digits>"
  got=$(resolve "$REGISTRY/$image:$TAG")
  [ "$got" = "$digest" ] \
    || fail "$REGISTRY/$image:$TAG resolves to ${got:-nothing}, not $digest, which the build pushed and the smoke test passed"
  before=$(resolve "$REGISTRY/$image:latest")
  [ -n "$before" ] || echo "::warning::$REGISTRY/$image has no :latest yet, so there is no rollback target" >&2
  images+=("$image") digests+=("$digest") befores+=("$before")
done

if [ "$DRY_RUN" = true ]; then
  echo "## Dry run: \`:latest\` not moved"
else
  echo "## \`:latest\` promoted"
fi
for i in "${!images[@]}"; do
  repo=$REGISTRY/${images[$i]} digest=${digests[$i]} before=${befores[$i]}
  echo
  echo "### \`$repo\`"
  echo
  echo "| | |"
  echo "|---|---|"
  echo "| **Candidate** | \`$repo:$TAG\` |"
  echo "| **Pushed** | \`$repo@$digest\` |"
  if [ -n "$before" ]; then
    echo "| **\`:latest\` before** | \`$repo@$before\` |"
    rollback="To put \`:latest\` back: \`docker buildx imagetools create --tag $repo:latest $repo@$before\`"
  else
    echo "| **\`:latest\` before** | none |"
    rollback="This image had no \`:latest\` before, so there is nothing to roll back to."
  fi

  if [ "$DRY_RUN" = true ]; then
    docker buildx imagetools create --dry-run --prefer-index=false --tag "$repo:latest" "$repo@$digest" > "$WORK/manifest" \
      || fail "docker buildx imagetools create --dry-run failed for $repo@$digest"
    # create prints the manifest it would push, then a newline.
    would=sha256:$(printf '%s' "$(< "$WORK/manifest")" | sha256)
    [ "$would" = "$digest" ] \
      || fail "imagetools create would push $would as $repo:latest, not a copy of $digest"
    echo "| **\`:latest\` after** | would be \`$repo@$digest\` |"
    continue
  fi

  if ! docker buildx imagetools create --prefer-index=false --tag "$repo:latest" "$repo@$digest" >&2; then
    echo "| **\`:latest\` now** | unknown: the promotion failed |"
    echo
    echo "$rollback"
    fail "docker buildx imagetools create failed for $repo:latest"
  fi
  after=$(resolve "$repo:latest")
  echo "| **\`:latest\` now** | \`$repo@${after:-nothing}\` |"
  echo
  echo "$rollback"
  [ "$after" = "$digest" ] || fail "$repo:latest resolves to ${after:-nothing} after the promotion, not $digest"
done
