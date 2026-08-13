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
#   ./build.sh                   build the next dev build, local only (5.4.0-13)
#   ./build.sh --push            ... and push it to the registry
#   ./build.sh -n 12             rebuild a specific dev number   (5.4.0-12)
#   ./build.sh release           promote the last dev build to GA (5.4.0)
#   ./build.sh release 12        promote a specific dev build to GA
#   ./build.sh release --build   build GA fresh instead of promoting
#   ./build.sh release --latest  also move the :latest tag
#
# Pushing is for publishing only. Dev builds stay in the local image store,
# so the usual test loop costs no upload at all. Release always pushes.
#
# "release" retags an existing dev manifest rather than rebuilding, so the
# GA image is byte-identical to the dev build you actually tested. That
# retag happens registry-side, so the dev build you intend to promote must
# have been built with --push. Use --build when there is none to promote.

set -euo pipefail
cd "$(dirname "$0")"

WEEWX_VERSION=5.5.0
IMAGE=mitct02/weewx
PLATFORMS=linux/arm/v7,linux/arm64/v8,linux/amd64
COUNTER_FILE=.build-number

MODE=dev
NUM=
FRESH=false
LATEST=false
PUSH=false

while [ $# -gt 0 ]; do
  case "$1" in
    release|ga) MODE=release; shift ;;
    -n|--number) [ $# -ge 2 ] || { echo "-n needs a number" >&2; exit 2; }; NUM=$2; shift 2 ;;
    --build) FRESH=true; shift ;;
    --latest) LATEST=true; shift ;;
    --push) PUSH=true; shift ;;
    # \? is a GNU extension; macOS ships BSD sed, so spell it \{0,1\}.
    -h|--help) sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    [0-9]*) NUM=$1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Releasing is publishing, so it always pushes regardless of --push.
[ "$MODE" = release ] && PUSH=true

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
  local tag_args=() out_args=()
  for t in "$@"; do tag_args+=(-t "$IMAGE:$t"); done

  # Without --push the build lands in the local containerd image store,
  # multi-platform and all. That needs Docker Desktop's containerd image
  # store enabled (Settings > General); with the old store, a multi-platform
  # build has nowhere local to go and buildx will refuse.
  if $PUSH; then out_args+=(--push); fi

  echo "==> Building $IMAGE:$1$($PUSH && echo ' (push)' || echo ' (local only)')"
  # Do not add --pull. The only FROM is mitct02/weewx-base, an internal
  # artifact that build-base.sh leaves in the local image store and never
  # pushes; --pull would resolve it from the registry and fail with
  # "not found". --no-cache already forces every layer here to rebuild.
  # ${a[@]+"${a[@]}"} not "${a[@]}": under set -u, expanding an empty array
  # is an "unbound variable" error on bash 3.2, which is what macOS ships.
  BUILDKIT_COLORS="run=123,20,245:error=yellow:cancel=blue:warning=white" \
  docker buildx build --no-cache ${out_args[@]+"${out_args[@]}"} --platform "$PLATFORMS" \
    --build-arg "IMAGE_VERSION=$version" \
    "${tag_args[@]}" .
}

if [ "$MODE" = dev ]; then
  [ -n "$NUM" ] || NUM=$(( $(read_counter) + 1 ))
  VERSION=$WEEWX_VERSION-$NUM

  build "$VERSION" "$VERSION"

  printf '%s %s\n' "$WEEWX_VERSION" "$NUM" > "$COUNTER_FILE"
  if $PUSH; then
    echo "==> Pushed $IMAGE:$VERSION"
    echo "    Promote to GA once tested:  ./build.sh release $NUM"
  else
    echo "==> Built $IMAGE:$VERSION (local image store, not pushed)"
    echo "    Publish it:                 ./build.sh -n $NUM --push"
    echo "    Then promote to GA:         ./build.sh release $NUM"
  fi

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

    # imagetools retags registry-side, so a dev build that was only built
    # locally cannot be promoted. Say so plainly instead of letting the
    # retag fail with a bare manifest-unknown.
    if ! docker buildx imagetools inspect "$SRC" >/dev/null 2>&1; then
      echo "ERROR: $SRC is not in the registry." >&2
      echo "       Dev builds are local-only unless built with --push." >&2
      echo "       Push it:  ./build.sh -n $NUM --push" >&2
      echo "       Or build GA fresh:  ./build.sh release --build" >&2
      exit 1
    fi

    echo "==> Promoting $SRC -> ${TAGS[*]}"
    docker buildx imagetools create "${to_args[@]}" "$SRC"
    echo "==> $IMAGE:${TAGS[*]} now points at $SRC"
  fi
fi