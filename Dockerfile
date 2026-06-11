FROM mitct02/weewx-base:5.3.1
ENV WEEWX_ROOT=/home/weewx/weewx-data
ENV WEEWX_TAG=247d228

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
&& weectl extension install https://github.com/uajqq/weewx-belchertown-new/archive/refs/tags/v2.0.zip --yes \
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
