#!/usr/bin/env bash
#
# Check that each container image pins its base image by digest, and that the
# images agree on it (#235) and on the versions and checksums they pin by hand
# (#342). validate-containers.yml runs this on every event.
#
#   scripts/check-base-pins.sh                  # containers/*/Dockerfile
#   scripts/check-base-pins.sh Dockerfile...    # these Dockerfiles
#   scripts/check-base-pins.sh --self-test      # check the checker
#
# Run it from the repository root. Every FROM must name its image as
# <image>:<tag>@sha256:<64 hex digits>, and every FROM of one <image>:<tag>, in
# any of the Dockerfiles, must name the same digest.
#
# The pin is what makes a base move a pull request: unpinned, each rebuild took
# whatever the tag pointed at that day, unreviewed, and the floating packages
# in later layers re-resolved with it (#222). The tag is required as well as
# the digest because it is what Dependabot holds while it moves the digest; a
# bare digest is updated from `latest`, which is another release. And the
# images must agree so that a base move cannot land in one image only.
#
# A FROM that names an earlier build stage, or `scratch`, pins nothing and is
# skipped. One whose image comes from a build argument cannot be checked, so
# it fails.
#
# The images pin Miniconda, Node and Chrome by hand, as ENV <NAME>_VERSION and
# ENV <NAME>_SHA256, which no Dependabot ecosystem tracks (#342). Each such ENV
# must have one value in every Dockerfile that sets it, so that a bump cannot
# land in one image only either. These print nothing when they agree.
set -euo pipefail

fail() { echo "::error::$*" >&2; exit 1; }

PIN_RE='^[a-z0-9]([a-z0-9._/-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9._-]+)*:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}@sha256:[0-9a-f]{64}$'

# Dockerfiles as arguments. Prints one line per pinned base and exits 0, or
# reports every problem and exits 1.
check_files() {
  local file n line rest image stage word name digest key value i bad=0
  local -a words=()
  local -A digest_of=() where=() stages=() env_of=() env_where=()
  [ "$#" -gt 0 ] || { echo "::error::no Dockerfiles to check" >&2; return 1; }
  for file in "$@"; do
    [ -f "$file" ] || { echo "::error::$file: no such file" >&2; bad=1; continue; }
    stages=()
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      if [[ $line =~ ^[[:space:]]*[Ee][Nn][Vv][[:space:]]+([A-Za-z0-9_]+_(VERSION|SHA256))=([^[:space:]]*)[[:space:]]*$ ]]; then
        key=${BASH_REMATCH[1]}
        value=${BASH_REMATCH[3]}
        if [ -z "${env_where[$key]:-}" ]; then
          env_of[$key]=$value
          env_where[$key]="$file:$n"
        elif [ "${env_of[$key]}" != "$value" ]; then
          echo "::error file=$file,line=$n::ENV $key=$value, but ${env_where[$key]} sets ${env_of[$key]}: the images must move it together" >&2; bad=1
        fi
        continue
      fi
      # Instructions are case-insensitive. Flags such as --platform come first.
      [[ $line =~ ^[[:space:]]*[Ff][Rr][Oo][Mm][[:space:]]+(.*)$ ]] || continue
      rest=${BASH_REMATCH[1]}
      image=''
      stage=''
      read -r -a words <<< "$rest"
      for ((i = 0; i < ${#words[@]}; i++)); do
        word=${words[i]}
        if [ -z "$image" ]; then
          [[ $word == --* ]] && continue
          image=$word
        elif [[ ${word,,} == as ]]; then
          stage=${words[i + 1]:-}
          break
        fi
      done
      [ -n "$stage" ] && stages[${stage,,}]=1
      if [ -z "$image" ]; then
        echo "::error file=$file,line=$n::FROM with no image" >&2; bad=1; continue
      fi
      [[ ${image,,} == scratch || -n ${stages[${image,,}]:-} ]] && continue
      if [[ $image == *'$'* ]]; then
        echo "::error file=$file,line=$n::FROM $image comes from a build argument, so its pin cannot be checked" >&2; bad=1; continue
      fi
      if [[ ! $image =~ $PIN_RE ]]; then
        echo "::error file=$file,line=$n::FROM $image is not pinned as <image>:<tag>@sha256:<digest>" >&2; bad=1; continue
      fi
      name=${image%@*}
      digest=${image#*@}
      if [ -z "${digest_of[$name]:-}" ]; then
        digest_of[$name]=$digest
        where[$name]="$file:$n"
      elif [ "${digest_of[$name]}" != "$digest" ]; then
        echo "::error file=$file,line=$n::FROM $name pins $digest, but ${where[$name]} pins ${digest_of[$name]}: the images must move their base together" >&2; bad=1
      else
        where[$name]="${where[$name]}, $file:$n"
      fi
    done < "$file"
  done
  [ "$bad" -eq 0 ] || return 1
  [ "${#digest_of[@]}" -gt 0 ] || { echo "::error::no pinned FROM found in: $*" >&2; return 1; }
  for name in "${!digest_of[@]}"; do
    echo "$name@${digest_of[$name]}  (${where[$name]})"
  done | sort
}

self_test() {
  local good other
  # Global, so that the trap can still read it when a failing case exits.
  dir=$(mktemp -d "${TMPDIR:-/tmp}/check-base-pins.XXXXXX")
  trap 'rm -rf "$dir"' EXIT
  good="ubuntu:24.04@sha256:$(printf 'a%.0s' {1..64})"
  other="ubuntu:24.04@sha256:$(printf 'b%.0s' {1..64})"

  # A case is a name, the expected outcome (`pass`, or the error a failure
  # must report, so that no case fails for the wrong reason), and one
  # Dockerfile body per file.
  case_() {
    local name=$1 want=$2 i=0 body err
    local -a files=()
    shift 2
    for body in "$@"; do
      i=$((i + 1))
      printf '%s\n' "$body" > "$dir/$name.$i"
      files+=("$dir/$name.$i")
    done
    if err=$(check_files "${files[@]}" 2>&1 > /dev/null); then
      [ "$want" = pass ] || fail "self-test: case [$name] passed, but should fail with [$want]"
    else
      [ "$want" != pass ] || fail "self-test: case [$name] should pass, but failed: $err"
      grep -qF -- "$want" <<< "$err" || fail "self-test: case [$name] failed, but not with [$want]: $err"
    fi
  }
  case_ pinned pass "FROM $good" "FROM $good"
  case_ platform-and-stages pass "FROM --platform=linux/amd64 $good AS base
RUN true
FROM base
from scratch AS empty
COPY --from=base /x /x"
  case_ registry-and-port pass "FROM ghcr.io:443/quantecon/base:v1@sha256:$(printf 'c%.0s' {1..64})"
  case_ unpinned 'FROM ubuntu:24.04 is not pinned' "FROM $good" "FROM ubuntu:24.04"
  case_ lowercase-unpinned 'FROM ubuntu:24.04 is not pinned' "from ubuntu:24.04"
  case_ digest-without-tag 'is not pinned' "FROM ubuntu@sha256:$(printf 'a%.0s' {1..64})"
  case_ short-digest 'is not pinned' "FROM ubuntu:24.04@sha256:abc123"
  case_ mismatched 'must move their base together' "FROM $good" "FROM $other"
  case_ mismatched-stages 'must move their base together' "FROM $good AS one
FROM $other"
  # shellcheck disable=SC2016 # the Dockerfile's own ${BASE}, unexpanded
  case_ build-arg 'comes from a build argument' 'ARG BASE=ubuntu:24.04
FROM ${BASE}'
  case_ no-from 'no pinned FROM found' "RUN true"
  case_ env-pins-agree pass "FROM $good
ENV NODE_VERSION=24.0.0
ENV NODE_SHA256=abc" "FROM $good
env NODE_VERSION=24.0.0
ENV NODE_SHA256=abc"
  case_ env-pin-differs 'ENV CHROME_VERSION=2, but' "FROM $good
ENV CHROME_VERSION=1" "FROM $good
ENV CHROME_VERSION=2"
  case_ env-checksum-differs 'ENV CHROME_SHA256=def, but' "FROM $good
ENV CHROME_SHA256=abc" "FROM $good
ENV CHROME_SHA256=def"
  case_ env-pin-in-one-image pass "FROM $good
ENV CHROME_VERSION=1" "FROM $good"
  case_ env-other-names pass "FROM $good
ENV PATH=/a" "FROM $good
ENV PATH=/b"
  check_files "$dir/absent" > /dev/null 2>&1 && fail "self-test: a missing Dockerfile should fail"
  check_files > /dev/null 2>&1 && fail "self-test: no Dockerfiles at all should fail"
  echo "check-base-pins self-test passed"
}

case "${1:-}" in
  --self-test) self_test ;;
  -*) fail "unknown argument [$1]" ;;
  '')
    shopt -s nullglob
    files=(containers/*/Dockerfile)
    [ "${#files[@]}" -ge 2 ] \
      || fail "found ${#files[@]} Dockerfile(s) under containers/, expected at least two. Run this from the repository root."
    check_files "${files[@]}"
    ;;
  *) check_files "$@" ;;
esac
