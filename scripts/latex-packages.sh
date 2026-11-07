#!/usr/bin/env bash
#
# Install apt packages, TeX Live's in practice, from a cache of their
# downloaded archives (#224). The Ubuntu mirror a runner is given can trickle
# at 60 kB/s without ever failing, which stalls a TeX Live download of 1 GB
# or more for hours; with the archives in the repository's Actions cache, a
# run that finds them contacts no mirror at all. Used by setup-latex, which
# runs, in order:
#
#   latex-packages.sh list      parse and check the package list
#   latex-packages.sh prepare   the cache key, and an empty archive directory
#   actions/cache/restore       the archives, by key, then by fallback
#   latex-packages.sh install   install, without apt-get update on an exact hit
#   actions/cache/save          when install says so
#
# It caches the .deb archives, not the installed files, so dpkg still runs
# every package's maintainer scripts and triggers (TeX Live's mktexlsr,
# updmap-sys and fmtutil): what is installed is what a plain apt-get install
# gives.
#
# The key hashes the installed package set. The archives a run downloads are
# exactly the packages that host lacked, so a host with the same installed
# set needs exactly those archives, and an exact hit can install them as
# local files with no apt-get update. A new runner image, or an earlier step
# that installed something, changes the set: the fallback then restores the
# last archives for the same list, apt-get downloads only what changed, and
# the archives no longer installed are pruned before the save.
#
# Subcommands and their environment (each action passes its inputs through
# env, never into a script body):
#
#   list     PACKAGES, REQUIREMENTS_FILE: the two ways to give the list, of
#            which exactly one must be set; PACKAGES_INPUT and
#            REQUIREMENTS_INPUT name them in messages
#            -> list-file: the parsed list, one package per line
#   prepare  LIST_FILE, CACHE_VERSION
#            -> key, restore-keys, path: actions/cache's inputs
#   install  LIST_FILE, PRIMARY_KEY and MATCHED_KEY (actions/cache/restore's
#            cache-primary-key and cache-matched-key), TIMEOUT_MINUTES (0 for
#            no limit), and TIMEOUT_INPUT, the input that sets it
#            -> cache-hit: 'true' exact, 'false' fallback, '' miss
#            -> save: 'true' when actions/cache/save should run
#
# Outputs are appended to $GITHUB_OUTPUT. Every error is an ::error:: line.

set -euo pipefail

# shellcheck source=scripts/workflow-command.sh
. "$(dirname "${BASH_SOURCE[0]}")/workflow-command.sh"

# Fixed, and outside $HOME: actions/cache only restores to the path it saved
# from, and apt's unprivileged _apt user must be able to read the archives.
ARCHIVES=/var/cache/quantecon-actions/latex-apt

SUDO=()
[ "$(id -u)" -eq 0 ] || SUDO=(sudo)

# An apt package name, as apt-get install takes one: the name, then
# optionally :<arch>, then =<version> or /<release>. Nothing that starts with
# '-', so no token is read as an option, and nothing that can start a
# workflow command.
PKG_RE='^[a-z0-9][a-z0-9+.-]+(:[a-z0-9-]+)?(=[A-Za-z0-9.+~:-]+|/[A-Za-z0-9.+-]+)?$'

cmd_list() {
  local packages=${PACKAGES:-} file=${REQUIREMENTS_FILE:-}
  local pi=${PACKAGES_INPUT:-packages} ri=${REQUIREMENTS_INPUT:-requirements-file}
  local dir source tok bad=0
  local -a tokens=()

  # The directory first: the harness checks that a line break in an input
  # gets no further than the first step by looking for it.
  dir=$(mktemp -d "${RUNNER_TEMP:?RUNNER_TEMP is not set}/setup-latex.XXXXXX")

  if [ -n "${packages//[[:space:]]/}" ] && [ -n "$file" ]; then
    annotate error "Set $pi or $ri, not both"
    return 1
  elif [ -n "$file" ]; then
    if [ ! -f "$file" ]; then
      annotate error "$ri is '$file', but there is no such file (paths are relative to the workspace, so check that actions/checkout runs first)"
      return 1
    fi
    source=$file
    # Whitespace-separated, several to a line if need be; '#' starts a
    # comment anywhere on a line; CRLF is tolerated.
    mapfile -t tokens < <(sed -e 's/#.*//' -e 's/\r$//' "$file" | tr -s '[:space:]' '\n' | grep -v '^$' || true)
  elif [ -n "${packages//[[:space:]]/}" ]; then
    source=$pi
    mapfile -t tokens < <(printf '%s\n' "$packages" | sed -e 's/#.*//' -e 's/\r$//' | tr -s '[:space:]' '\n' | grep -v '^$' || true)
  else
    annotate error "Set one of $pi and $ri: there is no default list of packages"
    return 1
  fi

  if [ "${#tokens[@]}" -eq 0 ]; then
    annotate error "$source names no package: it holds only comments or blank lines"
    return 1
  fi
  for tok in "${tokens[@]}"; do
    if ! [[ $tok =~ $PKG_RE ]]; then
      annotate error "$source: '$tok' is not an apt package name (a name, optionally with :arch, and =version or /release)"
      bad=1
    fi
  done
  [ "$bad" -eq 0 ] || return 1

  # Sorted and unique, so the key does not change with the list's order.
  printf '%s\n' "${tokens[@]}" | LC_ALL=C sort -u > "$dir/packages"
  echo "Packages ($(wc -l < "$dir/packages")): $(tr '\n' ' ' < "$dir/packages")"
  echo "list-file=$dir/packages" >> "$GITHUB_OUTPUT"
}

cmd_prepare() {
  local list=${LIST_FILE:?} version=${CACHE_VERSION:?} c os arch list_hash host_hash prefix delim
  for c in apt-get dpkg dpkg-deb dpkg-query sha256sum; do
    if ! command -v "$c" > /dev/null; then
      annotate error "$c is not on PATH: installing LaTeX this way needs an apt-based runner, such as GitHub's Ubuntu runners"
      return 1
    fi
  done

  # shellcheck source=/dev/null
  os=$(. /etc/os-release && printf '%s-%s' "${ID:-linux}" "${VERSION_ID:-unknown}")
  arch=$(dpkg --print-architecture)
  list_hash=$(sha256sum < "$list" | cut -c1-16)
  # What decides which archives this host needs: every installed package at
  # its version, and the architectures apt fetches for (26.04's runners
  # fetch amd64v3 builds).
  host_hash=$({
    dpkg-query -W -f='${db:Status-Abbrev}${binary:Package}=${Version}\n' | grep '^ii' | LC_ALL=C sort
    apt-config dump APT::Architecture-Variants || true
    dpkg --print-foreign-architectures
  } | sha256sum | cut -c1-16)

  # cache-version before the hashes, so the fallback, a prefix, never leaves
  # a version; the OS release before it, so it never crosses a release.
  prefix="latex-apt-$os-$arch-$version-"
  echo "Cache key: $prefix$list_hash-$host_hash"

  # An empty directory for the restore. The runner user owns it, since
  # actions/cache restores as that user; apt writes partial downloads to
  # partial/ as _apt.
  "${SUDO[@]}" install -d -m 0755 "${ARCHIVES%/*}"
  "${SUDO[@]}" install -d -m 0755 -o "$(id -u)" -g "$(id -g)" "$ARCHIVES"
  rm -f "$ARCHIVES"/*.deb
  if id -u _apt > /dev/null 2>&1; then
    "${SUDO[@]}" install -d -m 0700 -o _apt "$ARCHIVES/partial"
  else
    "${SUDO[@]}" install -d -m 0755 "$ARCHIVES/partial"
  fi

  delim="EOF_$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
  {
    echo "key=$prefix$list_hash-$host_hash"
    echo "restore-keys<<$delim"
    echo "$prefix$list_hash-"
    echo "$prefix"
    echo "$delim"
    echo "path=$ARCHIVES/*.deb"
  } >> "$GITHUB_OUTPUT"
}

timed_out() {
  local msg="The package download did not finish within ${TIMEOUT_MINUTES} minutes, so it was stopped: the Ubuntu mirror this runner was given is slow (the download usually takes under a minute). Re-run the job"
  if [ -n "${TIMEOUT_INPUT:-}" ]; then
    msg="$msg, or raise $TIMEOUT_INPUT ('0' sets no limit)"
  fi
  annotate error "$msg"
  exit 1
}

# Runs apt-get as root, inside the download deadline when there is one. Only
# apt-get update and the download run here, never the install: stopping dpkg
# part-way would leave the runner's packages broken.
DEADLINE=
fetch() {
  local remaining rc=0
  if [ -z "$DEADLINE" ]; then
    "${SUDO[@]}" "$@" || rc=$?
    return "$rc"
  fi
  remaining=$((DEADLINE - SECONDS))
  [ "$remaining" -gt 0 ] || timed_out
  "${SUDO[@]}" timeout --kill-after=30 "$remaining" "$@" || rc=$?
  # 124 when timeout stopped it, 137 when it had to kill it.
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
    timed_out
  fi
  return "$rc"
}

# 0 when installing the archives as local files needs nothing they lack,
# judged from apt-get's simulation, which reads no mirror.
complete() {
  local sim have want f
  sim=$("${SUDO[@]}" apt-get install --simulate --no-download "$@" 2>&1) || return 1
  # apt names each archive <package>_<version>_<arch>.deb.
  have=$(for f in "$@"; do f=${f##*/}; echo "${f%%_*}"; done | LC_ALL=C sort -u)
  want=$(sed -n 's/^Inst \([^ :]*\).*/\1/p' <<< "$sim" | LC_ALL=C sort -u)
  [ -z "$(LC_ALL=C comm -13 <(echo "$have") <(echo "$want"))" ]
}

cmd_install() {
  local list=${LIST_FILE:?} primary=${PRIMARY_KEY:?} matched=${MATCHED_KEY:-}
  local minutes=${TIMEOUT_MINUTES:-0} hit='' save=false before f p v a q kept=0 removed=0
  local -a pkgs debs apt_env=(env DEBIAN_FRONTEND=noninteractive)
  mapfile -t pkgs < "$list"
  shopt -s nullglob
  debs=("$ARCHIVES"/*.deb)

  if [ -n "$matched" ] && [ "$matched" = "$primary" ]; then
    hit=true
  elif [ -n "$matched" ]; then
    hit=false
  fi

  if [ "$hit" = true ] && [ "${#debs[@]}" -gt 0 ] && complete "${debs[@]}"; then
    echo "::group::Install ${#debs[@]} cached archives (exact cache hit: no apt-get update, no download)"
    "${SUDO[@]}" "${apt_env[@]}" apt-get install -y --no-download "${debs[@]}"
    echo "::endgroup::"
    echo "✅ Installed from the cache: ${#debs[@]} archives, no mirror contacted"
  else
    if [ "$hit" = true ]; then
      # The key says this host needs exactly these archives, so this should
      # not happen; the online path below still installs the list.
      annotate warning "The cached archives for this key do not cover the package list, so the packages are downloaded as on a cache miss"
    elif [ "$hit" = false ]; then
      echo "Restored ${#debs[@]} archives through the fallback: downloading only what they lack"
    else
      echo "No cache: downloading every package"
    fi
    # What the host had before this install, so the prune below can tell
    # the archives this run needed from the ones for packages it already had.
    before=$(dpkg-query -W -f='${db:Status-Abbrev}${Package}:${Architecture}=${Version}\n' | sed -n 's/^ii //p')
    if [ "$minutes" -gt 0 ]; then
      DEADLINE=$((SECONDS + minutes * 60))
    fi
    echo "::group::apt-get update"
    fetch apt-get update
    echo "::endgroup::"
    echo "::group::Download"
    fetch "${apt_env[@]}" apt-get install -y --download-only -o "Dir::Cache::archives=$ARCHIVES/" "${pkgs[@]}"
    echo "::endgroup::"
    echo "::group::Install"
    "${SUDO[@]}" "${apt_env[@]}" apt-get install -y -o "Dir::Cache::archives=$ARCHIVES/" "${pkgs[@]}"
    echo "::endgroup::"

    # Keep exactly the archives this install needed: each installed now at
    # its version, and not before. A fallback restore brings others, for
    # packages this host no longer needs, or already had.
    for f in "$ARCHIVES"/*.deb; do
      read -r p v a <<< "$(dpkg-deb --show --showformat='${Package} ${Version} ${Architecture}' "$f")"
      q=$p
      [ "$a" = all ] || q="$p:$a"
      if [ "$(dpkg-query -W -f='${db:Status-Abbrev}|${Version}' "$q" 2> /dev/null)" = "ii |$v" ] \
        && ! grep -qxF "$p:$a=$v" <<< "$before"; then
        kept=$((kept + 1))
      else
        rm -f "$f"
        removed=$((removed + 1))
      fi
    done
    echo "Archives kept for the cache: $kept; removed as no longer installed: $removed"

    if [ "$hit" = true ]; then
      : # the key already has a cache, and a cache cannot be replaced
    elif [ "$kept" -eq 0 ]; then
      echo "Nothing to cache: every package was installed already"
    elif [[ ${GITHUB_REF:-} == refs/tags/* ]]; then
      # A tag run's cache could only be restored by a run of the same tag.
      echo "Not saving the cache from a tag ($GITHUB_REF): no later run could restore it"
    else
      save=true
    fi
  fi

  {
    echo "cache-hit=$hit"
    echo "save=$save"
  } >> "$GITHUB_OUTPUT"
  if command -v pdflatex > /dev/null; then
    { pdflatex --version || true; } | sed -n 1p
  fi
}

case "${1:-}" in
  list) cmd_list ;;
  prepare) cmd_prepare ;;
  install) cmd_install ;;
  *)
    annotate error "latex-packages.sh: unknown subcommand '${1:-}' (list, prepare or install)"
    exit 1
    ;;
esac
