FROM python:3.12-slim
ENV WEEWX_TAG=247d228
ENV WEEWX_ROOT=/home/weewx/weewx-data
ENV HOME=/home/weewx
ENV TZ=America/New_York
ENV PATH=/usr/bin:$PATH
ENV LANG=en_US.UTF-8

ARG BUILD_DEPS="wget unzip git libffi-dev libjpeg-dev gcc g++ build-essential zlib1g-dev"

RUN apt-get update \
  && apt-get install --no-install-recommends -y \
      $BUILD_DEPS \
      tzdata \
      rsync \
      vim \
      openssh-client \
      openssl \
      locales \
  && rm -rf /var/lib/apt/lists/* \
  && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
  && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
  && echo "de_DE.UTF-8 UTF-8" >> /etc/locale.gen \
  && echo "nl_NL.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen \
  && addgroup weewx \
  && useradd -m -g weewx weewx \
  && chown -R weewx:weewx /home/weewx \
  && chmod -R 755 /home/weewx

USER weewx

RUN python3 -m venv /home/weewx/weewx-venv \
  && chmod -R 755 /home/weewx

RUN . /home/weewx/weewx-venv/bin/activate \
  && python3 -m pip install --no-cache-dir \
      numpy \
      pandas \
      skyfield \
      paho-mqtt \
      db-sqlite3 \
      requests

RUN . /home/weewx/weewx-venv/bin/activate \
  && pip install weewx==5.3.1 \
  && pip uninstall -y ephem \
  && weectl station create --no-prompt

USER root
RUN apt-get purge -y $BUILD_DEPS \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
USER weewx

COPY conf-fragments/*.conf /home/weewx/tmp/conf-fragments/
RUN mkdir -p /home/weewx/tmp \
  && mkdir -p /home/weewx/weewx-data/archive/skyfield \
  && cat /home/weewx/tmp/conf-fragments/* >> /home/weewx/weewx-data/weewx.conf

## Install extensions
RUN cd /var/tmp \
&& . /home/weewx/weewx-venv/bin/activate \
&& weectl extension install https://github.com/roe-dl/weewx-skyfield-almanac/archive/master.zip --yes \
&& weectl extension install https://github.com/Jterrettaz/weewx-windy/archive/master.zip --yes \
&& weectl extension install https://github.com/weewx-contrib/weewx-ecowitt_local_http/archive/refs/heads/main.zip --yes \
## Belchertown-new extension \
&& weectl extension install https://github.com/uajqq/weewx-belchertown-new/archive/refs/tags/v1.7-new-belchertown.zip --yes \
## MQTT extension \
&& weectl extension install https://github.com/matthewwall/weewx-mqtt/archive/master.zip --yes \
## WLL Driver \
&& weectl extension install https://github.com/Drealine/weatherlinklive-driver-weewx/releases/download/2022.02.27-2/WLLDriver.zip --yes \
# Clean up all temp directories \
&& rm -rf /tmp/* /var/tmp/* \
# Clean up Python bytecode from extensions \
&& find /home/weewx -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true \
&& find /home/weewx -type f -name '*.pyc' -delete 2>/dev/null || true


ADD ./bin/run.sh $WEEWX_ROOT/bin/run.sh
CMD ["sh", "-c", "$WEEWX_ROOT/bin/run.sh"]
WORKDIR $WEEWX_ROOT
