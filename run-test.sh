#!/usr/bin/env bash
set -euo pipefail

IMAGE_VERSION=5.3.1-5
IMAGE=mitct02/weewx:${IMAGE_VERSION}
TZ=America/Los_Angeles
DATA=/home/weewx/weewx-data

docker pull "${IMAGE}"

docker run -it --rm \
    -e TZ="${TZ}" \
    -v "$(pwd)/weewx.conf:${DATA}/weewx.conf" \
    -v "$(pwd)/public_html:${DATA}/public_html" \
    -v "$(pwd)/archive:${DATA}/archive" \
    -v "$(pwd)/keys:/home/weewx/.ssh" \
    "${IMAGE}" "${@}"
