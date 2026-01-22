IMAGE_VERSION=5.2.0-2
docker pull mitct02/weewx:$IMAGE_VERSION

export TZ=America/New_York

docker run -it --rm \
    -e TZ=$TZ \
    -v $(pwd)/weewx.conf:/home/weewx/weewx-data/weewx.conf \
    -v $(pwd)/public_html:/home/weewx/weewx-data/public_html \
    -v $(pwd)/archive:/home/weewx/weewx-data/archive \
    -v $(pwd)/keys:/home/weewx/.ssh \
    mitct02/weewx:$IMAGE_VERSION $1

#docker run -it --rm \
#      -v `pwd`/public_html:/home/weewx/weewx-data/public_html -v `pwd`/archive:/home/weewx/weewx-data/archive mitct02/weewx:latest
