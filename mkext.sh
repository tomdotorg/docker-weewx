#!/usr/bin/env bash
#
# Fetch a GitHub source archive at a tag, branch or commit and repackage it
# as a weewx extension zip in extensions/.
#
#   ./mkext.sh <owner/repo> <ref> [name]
#
#   <ref>   tag, branch or commit SHA (full or short)
#   [name]  top-level directory inside the zip, and the zip's basename.
#           Defaults to the repo name with a leading "weewx-" stripped.
#
#   -s <subdir>  extension lives in a subdirectory of the repo
#   -o <dir>     output directory (default: extensions)
#
# Examples:
#   ./mkext.sh uajqq/weewx-belchertown-new v2.1beta3 belchertown
#   ./mkext.sh matthewwall/weewx-mqtt 8f3c1ab
#   ./mkext.sh chaunceygardiner/weewx-skyfield v1.14

set -euo pipefail

OUTDIR=extensions
SUBDIR=

usage() {
  echo "usage: $0 [-s subdir] [-o outdir] <owner/repo> <ref> [name]" >&2
  exit 2
}

# Hand-rolled rather than getopts so flags may appear after the positionals.
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -s) [ $# -ge 2 ] || usage; SUBDIR=$2; shift 2 ;;
    -o) [ $# -ge 2 ] || usage; OUTDIR=$2; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) POS+=("$1"); shift ;;
  esac
done

[ ${#POS[@]} -ge 2 ] || usage

REPO=${POS[0]}
REF=${POS[1]}
NAME=${POS[2]:-$(basename "$REPO" | sed 's/^weewx-//')}

URL="https://github.com/$REPO/archive/$REF.zip"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "==> Fetching $URL"
curl -fsSL "$URL" -o "$WORK/src.zip"

echo "==> Extracting"
unzip -q "$WORK/src.zip" -d "$WORK/x"

# GitHub archives always contain exactly one top-level directory,
# named <repo>-<ref-with-slashes-flattened>. Rename it to $NAME so the
# extension name does not carry the version string.
top=$(find "$WORK/x" -mindepth 1 -maxdepth 1 -type d | head -1)
src=$top${SUBDIR:+/$SUBDIR}

if [ ! -d "$src" ]; then
  echo "ERROR: $SUBDIR not found in archive" >&2
  exit 1
fi

if [ ! -f "$src/install.py" ]; then
  echo "ERROR: no install.py at the root of ${SUBDIR:-the archive}" >&2
  echo "       contents:" >&2
  ls -1 "$src" >&2
  exit 1
fi

mkdir -p "$WORK/stage"
mv "$src" "$WORK/stage/$NAME"

# Record what this was built from; weectl ignores unknown files.
printf '%s@%s\n' "$REPO" "$REF" > "$WORK/stage/$NAME/.source"

mkdir -p "$OUTDIR"
OUT=$(cd "$OUTDIR" && pwd)/$NAME.zip
rm -f "$OUT"

echo "==> Packaging $OUT"
( cd "$WORK/stage" && zip -qr "$OUT" "$NAME" \
    -x '*.DS_Store' '*__MACOSX*' '*/.git/*' '*/.github/*' '*.pyc' '*__pycache__*' )

echo "==> Done: $(du -h "$OUT" | cut -f1)  $OUT"
unzip -l "$OUT" | tail -1
