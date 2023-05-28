#!/usr/bin/env bash
VERSION=4.10.2-1

#docker build --no-cache -t mitct02/weewx:$VERSION .
BUILDKIT_COLORS="run=123,20,245:error=yellow:cancel=blue:warning=white" docker buildx build --push --platform linux/amd64,linux/arm64,linux/arm/v7 -t mitct02/weewx:$VERSION .
