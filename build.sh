#!/usr/bin/env bash
VERSION=5.0.2-1
#docker build --no-cache -t mitct02/weewx:$VERSION .
BUILDKIT_COLORS="run=123,20,245:error=yellow:cancel=blue:warning=white" docker buildx build --push --no-cache --platform linux/amd64,linux/arm64 -t mitct02/weewx:$VERSION .
docker pull mitct02/weewx:$VERSION
