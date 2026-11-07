#!/usr/bin/env bash
#
# For the setup-latex harness jobs: each named package is installed and
# configured, and pdflatex compiles a page. pdflatex needs the format that
# fmtutil builds from tex-common's dpkg trigger, so a pass shows the
# maintainer scripts ran, on a cache hit as on a miss.
#
# Usage: check-tex.sh <package>...

set -euo pipefail

for p in "$@"; do
  status=$(dpkg-query -W -f='${db:Status-Abbrev}' "$p" 2> /dev/null || true)
  if [ "$status" != "ii " ]; then
    echo "::error::$p is not installed and configured: dpkg status [$status]"
    exit 1
  fi
done

d=$(mktemp -d)
printf '%s\n' '\documentclass{article}' '\begin{document}' 'harness' '\end{document}' > "$d/t.tex"
if ! (cd "$d" && pdflatex -interaction=nonstopmode -halt-on-error t.tex > pdflatex.log 2>&1); then
  tail -n 20 "$d/pdflatex.log"
  echo "::error::pdflatex could not compile a page: is the pdflatex format, which fmtutil builds from dpkg's trigger, missing?"
  exit 1
fi
[ -s "$d/t.pdf" ] || { echo "::error::pdflatex wrote no PDF"; exit 1; }
echo "✓ installed and configured: $*; pdflatex compiled a page ($(pdflatex --version | sed -n 1p))"
