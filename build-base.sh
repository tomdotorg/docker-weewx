#!/usr/bin/env bash
# Rebuild when: python version, weewx version, or pip deps (numpy/pandas/skyfield/etc.) change.
# Rarely needed — most builds should use build.sh instead.
WEEWX_VERSION=5.5.0
BASE_TAG="mitct02/weewx-base:$WEEWX_VERSION"

# No --push: the base is an internal artifact and stays in the local image
# store. --pull here refreshes the upstream python:3.14-slim only.
# Consequence: build.sh must NOT use --pull, or it will look for this tag in
# the registry, not find it, and fail.
#
# No --no-cache either, deliberately. --no-cache rebuilt all nine layers every
# run, which gave them fresh digests even when the output was identical, and
# a registry has no way to know that: the last publish uploaded 706MB of base
# layers (256 arm/v7 + 220 arm64 + 230 amd64) that were byte-equivalent to
# what was already there. It also re-ran apt and recompiled numpy from source
# under QEMU for arm/v7 (no armv7 wheel exists), which is most of the wall
# time. An unchanged script now rebuilds in seconds and produces identical
# digests, so publishing it uploads nothing.
#
# --pull still catches OS-level updates: a new python:3.14-slim digest
# invalidates the FROM and everything below it rebuilds anyway.
#
# The tradeoff is that the unpinned pip deps in Dockerfile.base no longer
# move on their own — see the comment there for how to force them.
BUILDKIT_COLORS="run=123,20,245:error=yellow:cancel=blue:warning=white" \
docker buildx build --pull --platform linux/arm/v7,linux/arm64/v8,linux/amd64 \
  -t "$BASE_TAG" \
  -f Dockerfile.base \
  .

if [ $? -eq 0 ]; then
    echo "Successfully built base image (local only): $BASE_TAG"
fi
