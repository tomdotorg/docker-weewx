#!/usr/bin/env bash
# Rebuild when: python version, weewx version, or pip deps (numpy/pandas/skyfield/etc.) change.
# Rarely needed — most builds should use build.sh instead.
WEEWX_VERSION=5.4.0
BASE_TAG="mitct02/weewx-base:$WEEWX_VERSION"

BUILDKIT_COLORS="run=123,20,245:error=yellow:cancel=blue:warning=white" \
docker buildx build --no-cache --platform linux/arm/v7,linux/arm64/v8,linux/amd64 \
  -t "$BASE_TAG" \
  -f Dockerfile.base \
  .

if [ $? -eq 0 ]; then
    echo "Successfully built and pushed base image: $BASE_TAG"
fi
