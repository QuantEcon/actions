#!/usr/bin/env bash
#
# Map a pull request's changed paths to the container images it must build and
# smoke-test before it merges (#142). validate-containers.yml runs this.
#
#   scripts/detect-changed-images.sh < changed-paths   # JSON list of image names
#   scripts/detect-changed-images.sh --all             # every image
#   scripts/detect-changed-images.sh --self-test       # check the mapping
#
# Run it from the repository root, on the commit under test: an image is a
# directory containers/<name>/ that holds a Dockerfile in the working tree, and
# its name is the package name under ghcr.io/quantecon.
#
# A changed path selects:
#   - containers/**/README.md            nothing. The Dockerfiles COPY only
#                                        environment.yml, and build-containers.yml
#                                        does not rebuild for a README either.
#   - containers/<any>/tests/**          every image. test-container.yml runs
#                                        containers/quantecon/tests/smoke-test.sh
#                                        in each of them.
#   - containers/<name>/**               <name>, if it has a Dockerfile.
#   - any other path under containers/   every image: build rather than skip what
#                                        this script does not recognise.
#   - the workflows that build and test  every image, so a pull request that
#     candidates, this script and        changes them runs them (each build
#     delete-pr-images.sh                dry-runs the cleanup script).
#   - anything else                      nothing.
set -euo pipefail

WHOLE_SET='^(\.github/workflows/(build-containers|validate-containers|test-container)\.yml|scripts/(detect-changed-images|delete-pr-images)\.sh)$'

fail() { echo "::error::$*" >&2; exit 1; }

all_images() {
  local dockerfile name
  for dockerfile in containers/*/Dockerfile; do
    [ -f "$dockerfile" ] || continue
    name=${dockerfile#containers/}
    echo "${name%/Dockerfile}"
  done
}

# Changed paths on stdin, one per line; image names on stdout, one per line.
select_images() {
  local path name
  while IFS= read -r path; do
    if [[ $path =~ $WHOLE_SET ]]; then
      all_images
    elif [[ $path != containers/* || $path == */README.md ]]; then
      continue
    elif [[ $path =~ ^containers/[^/]+/tests/ ]]; then
      all_images
    else
      name=${path#containers/}
      name=${name%%/*}
      if [[ $path == containers/"$name"/* && -f containers/$name/Dockerfile ]]; then
        echo "$name"
      else
        all_images
      fi
    fi
  done
}

as_json() { sort -u | jq -R . | jq -sc .; }

self_test() {
  local all got
  all=$(all_images | as_json)
  [ "$(jq length <<< "$all")" -ge 2 ] \
    || fail "self-test: found $all under containers/, expected at least two images. Run this from the repository root."
  check() {
    local want=$1
    shift
    got=$(printf '%s\n' "$@" | select_images | as_json)
    [ "$got" = "$want" ] || fail "self-test: [$*] selected $got, expected $want"
  }
  check '["quantecon"]' containers/quantecon/environment.yml
  check '["quantecon-build"]' containers/quantecon-build/Dockerfile
  check '["quantecon","quantecon-build"]' containers/quantecon/Dockerfile containers/quantecon-build/environment.yml
  check "$all" containers/quantecon/tests/smoke-test.sh
  check "$all" containers/quantecon/tests/minimal-jupyter-book/intro.md
  check "$all" .github/workflows/validate-containers.yml
  check "$all" containers/unrecognised.txt
  check '[]' containers/quantecon/README.md containers/quantecon-build/README.md containers/README.md
  check '[]' CHANGELOG.md docs/dev/PLAN.md .github/workflows/test-actions.yml
  check '[]'
  echo "detect-changed-images self-test passed; images: $all"
}

case "${1:-}" in
  --self-test) self_test ;;
  --all) all_images | as_json ;;
  '') select_images | as_json ;;
  *) fail "unknown argument [$1]" ;;
esac
