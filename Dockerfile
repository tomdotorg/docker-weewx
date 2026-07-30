FROM mitct02/weewx-base:5.4.0
ENV WEEWX_ROOT=/home/weewx/weewx-data

COPY conf-fragments/*.conf /home/weewx/tmp/conf-fragments/
RUN mkdir -p /home/weewx/tmp \
  && cat /home/weewx/tmp/conf-fragments/* >> /home/weewx/weewx-data/weewx.conf

## Install extensions
# `weectl extension install` exits 0 even when an install fails internally,
# so a broken extension would otherwise slip through and produce an image
# whose weewx.conf references a driver/module that was never installed
# (e.g. a missing user.ecowitt_http at runtime). install_ext() requires
# weectl's "Finished installing extension" success line and aborts the
# build if it is absent.
RUN set -e \
&& cd /var/tmp \
&& . /home/weewx/weewx-venv/bin/activate \
&& install_ext() { \
     echo "==> Installing extension: $1"; \
     out=$(weectl extension install "$1" --yes 2>&1) || { echo "$out"; echo "ERROR: weectl failed for $1" >&2; exit 1; }; \
     echo "$out"; \
     echo "$out" | grep -q "Finished installing extension" || { echo "ERROR: extension install did not complete: $1" >&2; exit 1; }; \
   } \
&& install_ext https://github.com/chaunceygardiner/weewx-skyfield/archive/refs/tags/v1.14.zip \
&& install_ext https://github.com/Jterrettaz/weewx-windy/archive/master.zip \
&& install_ext https://github.com/weewx-contrib/weewx-ecowitt_local_http/archive/refs/heads/main.zip \
## Belchertown-new extension \
&& install_ext https://github.com/uajqq/weewx-belchertown-new/archive/refs/tags/v2.0.zip \
## MQTT extension \
&& install_ext https://github.com/matthewwall/weewx-mqtt/archive/master.zip \
## WLL Driver \
&& install_ext https://github.com/Drealine/weatherlinklive-driver-weewx/releases/download/2022.02.27-2/WLLDriver.zip \
# Clean up all temp directories \
&& rm -rf /tmp/* /var/tmp/* \
# Clean up Python bytecode from extensions \
&& find /home/weewx -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true \
&& find /home/weewx -type f -name '*.pyc' -delete 2>/dev/null || true

ADD ./bin/run.sh $WEEWX_ROOT/bin/run.sh
CMD ["sh", "-c", "$WEEWX_ROOT/bin/run.sh"]
WORKDIR $WEEWX_ROOT
