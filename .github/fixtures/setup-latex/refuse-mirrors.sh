#!/usr/bin/env bash
#
# For the harness jobs that expect an exact hit of the LaTeX package cache.
# On the seed job's runner image, point apt's http and https proxy at
# apt-proxy.py in refuse mode, show that apt-get update's requests reach it,
# then clear its log: an empty log after the action means it made no
# request to any mirror. On another image, as during a runner image rollout,
# change nothing and say so: the key hashes the installed packages, so the
# job can only check a fallback install there.
#
# Usage: refuse-mirrors.sh <the seed's ImageOS/ImageVersion>
# Writes same=true or same=false to $GITHUB_OUTPUT. The log is
# $RUNNER_TEMP/apt-proxy.log.

set -euo pipefail

image="${ImageOS:-unknown}/${ImageVersion:-unknown}"
if [ "$image" != "$1" ]; then
  echo "::notice::This job runs on $image and the seed ran on $1, as during a runner image rollout, so the installed packages and the key differ: an exact hit cannot be tested on this run, and the job checks the fallback install instead"
  echo "same=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

log="$RUNNER_TEMP/apt-proxy.log"
python3 "$(dirname "${BASH_SOURCE[0]}")/apt-proxy.py" refuse 3128 "$log" > "$RUNNER_TEMP/apt-proxy.out" 2>&1 &
for _ in $(seq 50); do
  curl -s -o /dev/null http://127.0.0.1:3128/ && break
  sleep 0.2
done
printf '%s\n' 'Acquire::http::Proxy "http://127.0.0.1:3128";' 'Acquire::https::Proxy "http://127.0.0.1:3128";' \
  | sudo tee /etc/apt/apt.conf.d/zzz-harness-proxy
: > "$log"
sudo apt-get update -qq > /dev/null 2>&1 || true
[ -s "$log" ] || { echo "::error::apt-get update reached no mirror through the stand-in, so it cannot show the action made no request"; exit 1; }
echo "apt-get update went through the stand-in: $(wc -l < "$log") requests, all refused"
: > "$log"
echo "same=true" >> "$GITHUB_OUTPUT"
