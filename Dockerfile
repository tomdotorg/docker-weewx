FROM debian:bookworm-slim

  LABEL maintainer="Tom Mitchell <tom@tom.org>"
  ENV VERSION=5.2.0
  ENV TAG=v5.2.0
  ENV WEEWX_ROOT=/home/weewx/weewx-data
  ENV WEEWX_VERSION=5.2.0
  ENV HOME=/home/weewx
  ENV TZ=America/New_York
  ENV PATH=/usr/bin:$PATH
  ENV LANG=en_US.UTF-8

  # Define build-time dependencies that can be removed after build
  ARG BUILD_DEPS="wget unzip git python3-dev libffi-dev libjpeg-dev gcc g++ build-essential zlib1g-dev"

  RUN apt-get update \
      && apt-get install --no-install-recommends -y \
          $BUILD_DEPS \
          python3 \
          python3-pip \
          python3-venv \
          tzdata \
          rsync \
          openssh-client \
          openssl \
          python3-setuptools \
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
          Pillow \
          CT3 \
          configobj \
          paho-mqtt \
          pyserial \
          pyusb \
          ephem \
          PyMySQL \
          db-sqlite3 \
          requests

  RUN git clone https://github.com/weewx/weewx ~/weewx \
      && cd ~/weewx \
      && git checkout $TAG \
      && rm -rf ~/weewx/.git \
      && rm -rf ~/weewx/docs ~/weewx/tests ~/weewx/.github ~/weewx/examples \
      && find /home/weewx/weewx-venv -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true \
      && find /home/weewx/weewx-venv -type f -name '*.pyc' -delete 2>/dev/null || true

  RUN . /home/weewx/weewx-venv/bin/activate \
      && python3 ~/weewx/src/weectl.py station create --no-prompt

  COPY conf-fragments/*.conf /home/weewx/tmp/conf-fragments/
  RUN mkdir -p /home/weewx/tmp \
      && mkdir -p /home/weewx/weewx-data \
      && cat /home/weewx/tmp/conf-fragments/* >> /home/weewx/weewx-data/weewx.conf

  ## Install extensions
  RUN cd /var/tmp \
    && . /home/weewx/weewx-venv/bin/activate \
    ## Belchertown extension
    && wget https://github.com/poblabs/weewx-belchertown/releases/download/weewx-belchertown-1.3.1/weewx-belchertown-release.1.3.1.tar.gz \
    && tar zxf weewx-belchertown-release.1.3.1.tar.gz \
    && cd weewx-belchertown-master \
    && python3 ~/weewx/src/weectl.py extension install -y . \
    && cd /var/tmp \
    && rm -rf weewx-belchertown-release.1.3.1.tar.gz weewx-belchertown-master \
    ## MQTT extension
    && wget -O weewx-mqtt.zip https://github.com/matthewwall/weewx-mqtt/archive/master.zip \
    && unzip -q weewx-mqtt.zip \
    && cd weewx-mqtt-master \
    && python3 ~/weewx/src/weectl.py extension install -y . \
    && cd /var/tmp \
    && rm -rf weewx-mqtt.zip weewx-mqtt-master \
    ## WLL Driver
    && wget -O WLLDriver.zip https://github.com/Drealine/weatherlinklive-driver-weewx/releases/download/2022.02.27-2/WLLDriver.zip \
    && python3 ~/weewx/src/weectl.py extension install -y WLLDriver.zip \
    && rm -f WLLDriver.zip \
    # Clean up all temp directories
    && rm -rf /tmp/* /var/tmp/* \
    # Clean up Python bytecode from extensions
    && find /home/weewx -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true \
    && find /home/weewx -type f -name '*.pyc' -delete 2>/dev/null || true

  # Switch back to root to remove build dependencies
  USER root
  RUN apt-get purge -y $BUILD_DEPS \
      && apt-get autoremove -y \
      && apt-get clean \
      && rm -rf /var/lib/apt/lists/*

  USER weewx

  ADD ./bin/run.sh $WEEWX_ROOT/bin/run.sh
  CMD ["sh", "-c", "$WEEWX_ROOT/bin/run.sh"]
  WORKDIR $WEEWX_ROOT
