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
#   OUT_DIR     - where to write the files. It must be outside BUILD_DIR, or
#                 the growing tarball would recurse into itself
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

: "${BUILD_DIR:?BUILD_DIR is required}"
: "${ASSET_NAME:?ASSET_NAME is required}"
: "${TAG_NAME:?TAG_NAME is required}"
: "${OUT_DIR:?OUT_DIR is required}"
: "${COMMIT_SHA:?COMMIT_SHA is required}"
: "${REPOSITORY:?REPOSITORY is required}"
: "${SIZE_MB:?SIZE_MB is required}"
: "${FILE_COUNT:?FILE_COUNT is required}"

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
  "name": "$ASSET_NAME",
  "tag": "$TAG_NAME",
  "commit": "$COMMIT_SHA",
  "timestamp": "$(date -Iseconds)",
  "size_mb": $SIZE_MB,
  "file_count": $FILE_COUNT,
  "repository": "$REPOSITORY"
}
EOF

{
  echo "archive-name=$ARCHIVE_PATH"
  echo "checksum-name=$CHECKSUM_PATH"
  echo "manifest-name=$MANIFEST_PATH"
} >> "$GITHUB_OUTPUT"
echo "✅ Release assets created"
