#!/usr/bin/env bash
#
# Smoke-test the QuantEcon container image this script is running inside.
#
#   containers/quantecon/tests/smoke-test.sh              # normal run
#   containers/quantecon/tests/smoke-test.sh --self-test  # assert the fixture CAN fail
#
# Run it from inside a GitHub Actions `container:` job (see
# .github/workflows/test-container.yml). Do NOT wrap it in `docker run`: the
# runner mounts an empty directory at /github/home and forces HOME=/github/home,
# whereas `docker run` leaves HOME=/root. That difference is not cosmetic — it
# is exactly why #85 (kaleido v1 losing its bundled chromium, provisioned under
# /root at image build time) passed the old container tests while failing the
# real lecture matrix, which does use a container job.
#
# The --self-test mode exists because the failure this fixture guards against is
# silence. Before #108 the book executed nothing at all: `execute_notebooks` was
# "off" and the one code block was a plain ```python fence rather than a
# {code-cell}, so an image with a completely broken scientific stack still
# produced a green test. A fixture that cannot fail is worse than no fixture,
# because it reads as coverage. --self-test stages a deliberate failure and
# fails if the build does NOT go red.
set -euo pipefail

MODE="${1:-normal}"
SENTINEL="SMOKE-SELF-TEST-SENTINEL"
TESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Fresh directory per invocation. Never rm -rf a fixed path: builds write as the
# container's uid, and reusing a deterministic directory turns cleanup into a
# permission error that masquerades as a test result.
WORK="$(mktemp -d "${RUNNER_TEMP:-/tmp}/smoke-XXXXXX")"
echo "workdir: $WORK"
echo "HOME:    ${HOME:-unset}"

cp -R "$TESTS_DIR/minimal-jupyter-book" "$WORK/book"
cp "$TESTS_DIR/test-xelatex.tex" "$WORK/"
cd "$WORK"

if [ "$MODE" = "--self-test" ]; then
  printf '\n```{code-cell} python3\nraise RuntimeError("%s")\n```\n' "$SENTINEL" >> "$WORK/book/intro.md"
fi

echo "== container marker =="
cat /etc/quantecon-container

if [ "$MODE" != "--self-test" ]; then
  echo "== xelatex =="
  xelatex -interaction=nonstopmode test-xelatex.tex
  ls -lh test-xelatex.pdf
fi

echo "== jupyter-book html (executes the cells) =="
set +e
jb build book --builder html -W --keep-going 2>&1 | tee "$WORK/html.log"
rc=${PIPESTATUS[0]}
set -e

if [ "$MODE" = "--self-test" ]; then
  if [ "$rc" -eq 0 ]; then
    echo "::error::self-test: a raising {code-cell} did NOT fail the build — the fixture is inert. Check execute.execute_notebooks (must not be \"off\"), execute.raise_on_error, the jupytext front matter, and that cells use {code-cell} rather than a plain \`\`\`python fence."
    exit 1
  fi
  # Attribute the red, for the same reason build-fail-guard does in
  # test-actions.yml: a non-zero exit is also produced by a bad mount, an OOM,
  # or an unrelated -W warning, any of which would let this guard pass while the
  # fixture was in fact inert.
  #
  # Unlike build-fail-guard this greps captured stdout rather than
  # _build/html/reports/*.err.log — with execute.raise_on_error: true myst-nb
  # raises before Sphinx writes the report, so that file does not exist here.
  grep -q "$SENTINEL" "$WORK/html.log" || {
    echo "::error::self-test: the build failed (rc=$rc) but not on the staged exception — the red is not attributable to the fixture."
    tail -60 "$WORK/html.log"
    exit 1
  }
  echo "✅ self-test: the staged raising cell failed the build (rc=$rc)"
  exit 0
fi

[ "$rc" -eq 0 ] || exit "$rc"

echo "== jupyter-book pdflatex =="
jb build book --builder pdflatex -W --keep-going
ls -lh book/_build/latex/*.pdf

echo "== OK =="
