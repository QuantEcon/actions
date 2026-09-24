#!/usr/bin/env bash
#
# Prove that a site is behind Cloudflare Access: an unauthenticated request
# must be redirected to the team's own login domain, never answered with the
# content. Used by the deploy-cloudflare action before and after every deploy
# (#163).
#
#   check-access-gate.sh <team-domain> <url> [<url> ...]
#   check-access-gate.sh quantecon.cloudflareaccess.com \
#     https://<worker>.<account-subdomain>.workers.dev/ \
#     https://<worker>.<account-subdomain>.workers.dev/data/latest.json
#
# Every URL must pass. Exit 0 = all gated, 1 = at least one is not, 2 = usage.
#
# Taken from the probe verified in the QuantEcon/status-projects#35 pilot
# (recorded on #163). What matters in it:
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

set -uo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: check-access-gate.sh <team-domain> <url> [<url> ...]" >&2
  exit 2
fi

raw_team=$1
team=$(printf '%s' "$raw_team" | tr '[:upper:]' '[:lower:]')
shift
# An empty team would equal the empty host of a redirect with no Location.
if ! [[ "$team" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?\.cloudflareaccess\.com$ ]]; then
  echo "usage: team-domain must be <team>.cloudflareaccess.com, got [$raw_team]" >&2
  exit 2
fi

failed=0
for url in "$@"; do
  # --retry covers transport errors and 408/429/5xx only; a status we can
  # judge is never retried into a different answer.
  if ! out=$(curl -sS -o /dev/null --max-time 20 \
      --retry 2 --retry-delay 2 --retry-connrefused \
      -w '%{http_code} %{redirect_url}' "$url"); then
    echo "::error::FAIL  $url — could not be reached, so the gate could not be verified"
    failed=1
    continue
  fi
  code=${out%% *}
  location=${out#* }

  case "$code" in
    301|302|303|307|308)
      authority=${location#*://}
      authority=$(printf '%s' "${authority%%[/?#]*}" | tr '[:upper:]' '[:lower:]')
      # Userinfo or a backslash makes the real host ambiguous (browsers read
      # `\` as `/`, so https://x.com\@team... goes to x.com). Access never
      # sends either, so refuse rather than guess.
      case "$authority" in
        *@*|*\\*) host="<ambiguous Location authority: $authority>" ;;
        *) host=${authority%%:*} ;;
      esac
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
