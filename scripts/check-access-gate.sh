#!/usr/bin/env bash
#
# Prove who a site is served to: that it is behind Cloudflare Access, or, with
# --public, that it is not. Used by the deploy-cloudflare action before and
# after every deploy (#163, #177).
#
#   check-access-gate.sh <team-domain> <url> [<url> ...]
#   check-access-gate.sh --public [--allow-404] <url> [<url> ...]
#
#   check-access-gate.sh <team>.cloudflareaccess.com \
#     https://<worker>.<account-subdomain>.workers.dev/ \
#     https://<worker>.<account-subdomain>.workers.dev/data/latest.json
#
# Every URL must pass. Exit 0 = all pass, 1 = at least one does not, 2 = usage.
#
# Gated, the first form: an unauthenticated request must be redirected to the
# team's own login domain, never answered with the content. Taken from the
# probe verified in the QuantEcon/status-projects#35 pilot (recorded on #163).
# What matters in it:
#
#   - The Location host must EQUAL the team domain. Matching any
#     *.cloudflareaccess.com would pass a Worker attached to the wrong Access
#     organisation, which is exactly the mistake worth catching.
#   - A 2xx gets its own loud branch. It means anonymous requests are being
#     served the content: the one failure this check exists for.
#   - No -L. Following the redirect lands on the login page and returns 200,
#     which would make the alarm case and the success case look the same.
#   - Anything else fails. A 404 or a redirect back to the site proves nothing
#     about the gate, so it is never treated as a pass.
#
# Public, with --public: the inverse. An unauthenticated request must be served
# the content, a 2xx, with no redirect; still no -L, or a redirect to the
# login page would pass. A redirect to ANY *.cloudflareaccess.com gets its own
# loud branch, since the site is then behind someone's Access. Anything else
# fails, a 404 included, unless --allow-404 is given: then a 404 passes too, as
# "not behind Access". The action's check before a deploy uses it, because the
# version live then need not hold the files of the build about to replace it.

set -uo pipefail

usage() {
  echo "usage: check-access-gate.sh <team-domain> <url> [<url> ...]" >&2
  echo "       check-access-gate.sh --public [--allow-404] <url> [<url> ...]" >&2
  exit 2
}

public=0
allow_404=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --public) public=1 ;;
    --allow-404) allow_404=1 ;;
    *) echo "usage: unknown option [$1]" >&2; usage ;;
  esac
  shift
done

if [ "$public" -eq 1 ]; then
  [ "$#" -ge 1 ] || usage
else
  # A 404 proves nothing about a gate.
  [ "$allow_404" -eq 0 ] || { echo "usage: --allow-404 needs --public" >&2; usage; }
  [ "$#" -ge 2 ] || usage
  raw_team=$1
  team=$(printf '%s' "$raw_team" | tr '[:upper:]' '[:lower:]')
  shift
  # An empty team would equal the empty host of a redirect with no Location.
  if ! [[ "$team" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?\.cloudflareaccess\.com$ ]]; then
    echo "usage: team-domain must be <team>.cloudflareaccess.com, got [$raw_team]" >&2
    exit 2
  fi
fi

# The lowercased host of a redirect's target. Userinfo or a backslash makes
# the real host ambiguous (browsers read `\` as `/`, so
# https://x.com\@team... goes to x.com). Access never sends either, so refuse
# rather than guess.
redirect_host() {
  local authority=${1#*://}
  authority=$(printf '%s' "${authority%%[/?#]*}" | tr '[:upper:]' '[:lower:]')
  case "$authority" in
    *@*|*\\*) printf '%s' "<ambiguous Location authority: $authority>" ;;
    *) printf '%s' "${authority%%:*}" ;;
  esac
}

failed=0
for url in "$@"; do
  # --retry covers transport errors and 408/429/5xx only; a status we can
  # judge is never retried into a different answer.
  if ! out=$(curl -sS -o /dev/null --max-time 20 \
      --retry 2 --retry-delay 2 --retry-connrefused \
      -w '%{http_code} %{redirect_url}' "$url"); then
    if [ "$public" -eq 1 ]; then
      echo "::error::FAIL  $url — could not be reached, so it could not be shown to be served anonymously"
    else
      echo "::error::FAIL  $url — could not be reached, so the gate could not be verified"
    fi
    failed=1
    continue
  fi
  code=${out%% *}
  location=${out#* }

  if [ "$public" -eq 1 ]; then
    case "$code" in
      2??)
        echo "PASS  $code served anonymously  $url"
        ;;
      301|302|303|307|308)
        host=$(redirect_host "$location")
        if [[ "$host" == *.cloudflareaccess.com ]]; then
          echo "::error::FAIL  $url redirected to the Access login '$host' — THE SITE IS BEHIND ACCESS, not public"
        else
          echo "::error::FAIL  $url answered $code to '${host:-<no Location>}' instead of serving the site"
        fi
        failed=1
        ;;
      404)
        if [ "$allow_404" -eq 1 ]; then
          echo "PASS  404 not behind Access, nothing served at this path  $url"
        else
          echo "::error::FAIL  $url answered 404 — the site is not served here (no such Worker, its workers.dev route is off, or the file is missing)"
          failed=1
        fi
        ;;
      *)
        echo "::error::FAIL  $url answered $code, expected the site to be served (2xx) without authentication"
        failed=1
        ;;
    esac
    continue
  fi

  case "$code" in
    301|302|303|307|308)
      host=$(redirect_host "$location")
      if [ "$host" = "$team" ]; then
        echo "PASS  $code -> $host  $url"
      elif [[ "$host" == *.cloudflareaccess.com ]]; then
        echo "::error::FAIL  $url is gated by '$host', expected '$team' — the Worker is attached to the wrong Access organisation"
        failed=1
      else
        echo "::error::FAIL  $url answered $code to '${host:-<no Location>}', not to the Access login domain '$team' — the site is not behind Access"
        failed=1
      fi
      ;;
    2??)
      echo "::error::FAIL  $url answered $code without authentication — THE SITE IS PUBLIC"
      failed=1
      ;;
    404)
      echo "::error::FAIL  $url answered 404 — nothing is gating this hostname (no such Worker, or its workers.dev route is off)"
      failed=1
      ;;
    *)
      echo "::error::FAIL  $url answered $code, expected a redirect to the Access login domain '$team'"
      failed=1
      ;;
  esac
done

exit "$failed"
