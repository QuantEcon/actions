#!/usr/bin/env bash
#
# Make publish-gh-pages' release assets: the site as a gzip-compressed tar,
# its SHA-256 checksum, and a manifest. The action's release step runs it once
# it has checked that the run was triggered by a tag and has a token. The
# harness runs it on its own, with a stand-in tag, since no pull request run
# is triggered by one.
#
# The three files are a contract that other tools rely on: see "Release
# assets" in docs/user/actions/publish-gh-pages.md. A change to a file name,
# the archive's layout, the checksum's format, or a manifest field's name or
# meaning changes that contract, and its CHANGELOG entry must say so.
#
# Inputs (environment variables):
#   BUILD_DIR   - the site to pack
#   ASSET_NAME  - the start of each file's name, e.g. lecture-python-html
#   TAG_NAME    - the tag the run was triggered by
#   OUT_DIR     - where to write the files, absolute or relative. The script
#                 fails if it is inside BUILD_DIR, where the growing tarball
#                 would take in itself
#   COMMIT_SHA  - the commit the run built
#   REPOSITORY  - <owner>/<repository>
#   SIZE_MB     - `du -sm` of BUILD_DIR, measured before any CNAME was written
#   FILE_COUNT  - the number of files in BUILD_DIR, measured at the same time
#
# Outputs (appended to $GITHUB_OUTPUT):
#   archive-name   - the archive's path
#   checksum-name  - the checksum file's path
#   manifest-name  - the manifest's path

set -euo pipefail

# shellcheck source=scripts/workflow-command.sh
. "$(dirname "${BASH_SOURCE[0]}")/workflow-command.sh"

: "${BUILD_DIR:?BUILD_DIR is required}"
: "${ASSET_NAME:?ASSET_NAME is required}"
: "${TAG_NAME:?TAG_NAME is required}"
: "${OUT_DIR:?OUT_DIR is required}"
: "${COMMIT_SHA:?COMMIT_SHA is required}"
: "${REPOSITORY:?REPOSITORY is required}"
: "${SIZE_MB:?SIZE_MB is required}"
: "${FILE_COUNT:?FILE_COUNT is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

# Absolute, so that the checksum, written from inside OUT_DIR, lands in it
# when OUT_DIR is given as a relative path.
BUILD_ABS=$(cd "$BUILD_DIR" && pwd -P) \
  || { annotate error "BUILD_DIR ($BUILD_DIR) is not a directory"; exit 1; }
OUT_DIR=$(cd "$OUT_DIR" && pwd -P) \
  || { annotate error "OUT_DIR ($OUT_DIR) is not a directory"; exit 1; }
case "$OUT_DIR/" in
  "$BUILD_ABS/"*)
    annotate error "OUT_DIR ($OUT_DIR) is inside BUILD_DIR ($BUILD_DIR), so the archive would take in itself"
    exit 1
    ;;
esac

# json_string VALUE NAME: VALUE as a JSON string, so that the manifest parses
# whatever asset-name or tag it is given. A control character other than a
# newline, carriage return or tab fails, naming the input.
json_string() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  if [[ $s == *[[:cntrl:]]* ]]; then
    echo "::error::$2 contains a control character, which the manifest cannot hold" >&2
    return 1
  fi
  printf '"%s"' "$s"
}
NAME_JSON=$(json_string "$ASSET_NAME" ASSET_NAME)
TAG_JSON=$(json_string "$TAG_NAME" TAG_NAME)
COMMIT_JSON=$(json_string "$COMMIT_SHA" COMMIT_SHA)
REPOSITORY_JSON=$(json_string "$REPOSITORY" REPOSITORY)

ARCHIVE_NAME="${ASSET_NAME}-${TAG_NAME}.tar.gz"
ARCHIVE_PATH="${OUT_DIR}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${OUT_DIR}/${ASSET_NAME}-checksum.txt"
MANIFEST_PATH="${OUT_DIR}/${ASSET_NAME}-manifest.json"

echo "📦 Creating release assets..."
echo "   Archive: $ARCHIVE_NAME"

# Paths relative to BUILD_DIR, as in ./index.html.
tar -czf "$ARCHIVE_PATH" -C "$BUILD_DIR" .

# The checksum names just the archive's file name, not its path.
( cd "$OUT_DIR" && sha256sum "$ARCHIVE_NAME" > "$CHECKSUM_PATH" )

cat > "$MANIFEST_PATH" << EOF
{
  "name": $NAME_JSON,
  "tag": $TAG_JSON,
  "commit": $COMMIT_JSON,
  "timestamp": "$(date -Iseconds)",
  "size_mb": $SIZE_MB,
  "file_count": $FILE_COUNT,
  "repository": $REPOSITORY_JSON
}
EOF

{
  echo "archive-name=$ARCHIVE_PATH"
  echo "checksum-name=$CHECKSUM_PATH"
  echo "manifest-name=$MANIFEST_PATH"
} >> "$GITHUB_OUTPUT"
echo "✅ Release assets created"
