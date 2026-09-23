#!/usr/bin/env bash
set -euo pipefail

# Usage: verify-gated.sh <URL>
# Checks that the given URL returns a 401 Unauthorized response
# when accessed without authentication.

URL="${1:-}"
if [[ -z "$URL" ]]; then
  echo "Usage: $0 <URL>"
  exit 1
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
if [[ "$HTTP_CODE" -eq 401 ]]; then
  echo "✅ Gated correctly: $URL returned 401."
else
  echo "❌ Gating failed: $URL returned $HTTP_CODE."
  exit 1
fi
