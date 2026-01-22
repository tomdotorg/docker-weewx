#!/usr/bin/env bash
REV=3
WEEWX_VERSION=5.2.0
IMAGE_VERSION=$WEEWX_VERSION-$REV

# Use an array to hold all tags
TAGS=(
  "mitct02/weewx:$IMAGE_VERSION"
  "mitct02/weewx:latest"
)

# Construct the list of -t arguments for buildx
TAG_ARGS=""
for TAG in "${TAGS[@]}"; do
  TAG_ARGS+="-t $TAG "
done

BUILDKIT_COLORS="run=123,20,245:error=yellow:cancel=blue:warning=white" \
  docker buildx build --no-cache --push --platform linux/arm/v7,linux/arm64/v8,linux/amd64 $TAG_ARGS .

if [ $? -eq 0 ]; then
    echo "Successfully built and pushed images with tags: ${TAGS[*]}"
fi
