#!/usr/bin/env bash
#
# Versioning
# ----------
#   dev builds : mitct02/weewx:5.4.0-1, -2, -3 ...   (build number suffix)
#   GA release : mitct02/weewx:5.4.0                 (no suffix)
#
# The build number lives in .build-number and auto-increments on each dev
# build. It resets to 1 whenever WEEWX_VERSION changes.
#
#   ./build.sh                   build+push the next dev build   (5.4.0-13)
#   ./build.sh -n 12             rebuild a specific dev number   (5.4.0-12)
#   ./build.sh release           promote the last dev build to GA (5.4.0)
#   ./build.sh release 12        promote a specific dev build to GA
#   ./build.sh release --build   build GA fresh instead of promoting
#   ./build.sh release --latest  also move the :latest tag
#
# "release" retags an existing dev manifest rather than rebuilding, so the
# GA image is byte-identical to the dev build you actually tested. Use
# --build only when there is no dev build to promote.

set -euo pipefail
cd "$(dirname "$0")"

WEEWX_VERSION=5.4.0
IMAGE=mitct02/weewx
PLATFORMS=linux/arm/v7,linux/arm64/v8,linux/amd64
COUNTER_FILE=.build-number

MODE=dev
NUM=
FRESH=false
LATEST=false

while [ $# -gt 0 ]; do
  case "$1" in
    release|ga) MODE=release; shift ;;
    -n|--number) [ $# -ge 2 ] || { echo "-n needs a number" >&2; exit 2; }; NUM=$2; shift 2 ;;
    --build) FRESH=true; shift ;;
    --latest) LATEST=true; shift ;;
    -h|--help) sed -n '3,22p' "$0" | sed 's/^#\ \?//'; exit 0 ;;
    [0-9]*) NUM=$1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# .build-number holds "<version> <counter>" so the counter resets on a
# WEEWX_VERSION bump instead of silently continuing the old series.
read_counter() {
  local v n
  if [ -f "$COUNTER_FILE" ]; then
    read -r v n < "$COUNTER_FILE" || true
    if [ "${v:-}" = "$WEEWX_VERSION" ]; then echo "${n:-0}"; return; fi
  fi
  echo 0
}

build() {
  local version=$1; shift
  local tag_args=()
  for t in "$@"; do tag_args+=(-t "$IMAGE:$t"); done

  echo "==> Building $IMAGE:$1"
  BUILDKIT_COLORS="run=123,20,245:error=yellow:cancel=blue:warning=white" \
  docker buildx build --no-cache --push --platform "$PLATFORMS" \
    --build-arg "IMAGE_VERSION=$version" \
    "${tag_args[@]}" .
}

if [ "$MODE" = dev ]; then
  [ -n "$NUM" ] || NUM=$(( $(read_counter) + 1 ))
  VERSION=$WEEWX_VERSION-$NUM

  build "$VERSION" "$VERSION"

  printf '%s %s\n' "$WEEWX_VERSION" "$NUM" > "$COUNTER_FILE"
  echo "==> Pushed $IMAGE:$VERSION"
  echo "    Promote to GA once tested:  ./build.sh release $NUM"

else
  TAGS=("$WEEWX_VERSION")
  $LATEST && TAGS+=(latest)

  if $FRESH; then
    build "$WEEWX_VERSION" "${TAGS[@]}"
    echo "==> Pushed GA $IMAGE:$WEEWX_VERSION (fresh build)"
  else
    [ -n "$NUM" ] || NUM=$(read_counter)
    if [ "$NUM" = 0 ]; then
      echo "ERROR: no dev build recorded for $WEEWX_VERSION." >&2
      echo "       Run ./build.sh first, or ./build.sh release --build." >&2
      exit 1
    fi
    SRC=$IMAGE:$WEEWX_VERSION-$NUM
    to_args=()
    for t in "${TAGS[@]}"; do to_args+=(-t "$IMAGE:$t"); done

    echo "==> Promoting $SRC -> ${TAGS[*]}"
    docker buildx imagetools create "${to_args[@]}" "$SRC"
    echo "==> $IMAGE:${TAGS[*]} now points at $SRC"
  fi
fi